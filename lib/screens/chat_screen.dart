import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  late final String _chatId;
  late final Future<void> _ready;
  late final Stream<DocSnap> _chatStream;
  late final Stream<DocSnap> _userStream;
  late final Stream<Snap> _messageStream;

  Timer? _tick;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  int _markedCount = -1;

  @override
  void initState() {
    super.initState();
    _chatId = ChatService.chatIdFor(ChatService.me.uid, widget.otherUid);
    ChatService.openChatId = _chatId;

    // Streams are lazy: nothing is listened to until the chat doc exists.
    _chatStream = ChatService.chatDoc(widget.otherUid);
    _userStream = ChatService.userDoc(widget.otherUid);
    _messageStream = ChatService.messages(widget.otherUid);

    // Make sure the chat document exists before we listen to it.
    _ready = ChatService.ensureChat(widget.otherUid, widget.otherName);

    // Re-check every 2s so "typing..." and "online" expire on their own.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (ChatService.openChatId == _chatId) ChatService.openChatId = null;
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds >= 3) {
      _lastTypingSent = now;
      ChatService.setTyping(widget.otherUid);
    }
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ChatService.send(widget.otherUid, widget.otherName, text: text);
  }

  Future<void> _sendPhoto() async {
    try {
      final b64 = await ChatService.pickImage(size: 900, quality: 60);
      if (b64 == null) return;
      ChatService.send(widget.otherUid, widget.otherName, image: b64);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  bool _isOtherTyping(Map<String, dynamic> chat) {
    final typing = chat['typing'];
    if (typing is Map) {
      final v = typing[widget.otherUid];
      if (v is Timestamp) {
        return DateTime.now().difference(v.toDate()).inSeconds < 6;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, ready) {
        if (ready.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.otherName)),
            body: Center(child: Text('Error: ${ready.error}')),
          );
        }
        if (ready.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.otherName)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<DocSnap>(
          stream: _chatStream,
          builder: (context, chatSnap) {
            final chat = chatSnap.data?.data() ?? <String, dynamic>{};
            final lastRead = chat['lastRead'];
            final otherRead = lastRead is Map ? lastRead[widget.otherUid] : null;

            return Scaffold(
              appBar: _buildAppBar(_isOtherTyping(chat)),
              body: Column(
                children: [
                  Expanded(child: _buildMessages(otherRead)),
                  _buildInput(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool typing) {
    return AppBar(
      title: Row(
        children: [
          UserAvatar(uid: widget.otherUid, name: widget.otherName, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<DocSnap>(
              stream: _userStream,
              builder: (context, snap) {
                final status =
                    typing ? 'typing…' : ChatService.statusText(snap.data?.data());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherName,
                      style: const TextStyle(fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status.isNotEmpty)
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: (typing || status == 'online')
                              ? Colors.green
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(dynamic otherRead) {
    return StreamBuilder<Snap>(
      stream: _messageStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        // New messages while this chat is open count as read.
        if (docs.length != _markedCount) {
          _markedCount = docs.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ChatService.markRead(widget.otherUid);
          });
        }

        if (docs.isEmpty) {
          return const Center(child: Text('Say hi 👋'));
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildBubble(docs[i], otherRead),
        );
      },
    );
  }

  Widget _buildBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    dynamic otherRead,
  ) {
    final cs = Theme.of(context).colorScheme;
    final m = doc.data();
    final mine = m['senderId'] == ChatService.me.uid;
    final fg = mine ? cs.onPrimary : cs.onSurface;
    final text = (m['text'] ?? '') as String;
    final image = m['image'];
    final created = m['createdAt'];

    String tick = '';
    if (mine) {
      if (created is! Timestamp) {
        tick = ' …';
      } else if (otherRead is Timestamp &&
          otherRead.millisecondsSinceEpoch >= created.millisecondsSinceEpoch) {
        tick = ' ✓✓';
      } else {
        tick = ' ✓';
      }
    }

    Uint8List? bytes;
    if (image is String && image.isNotEmpty) {
      bytes = ChatService.decode('m:${doc.id}', image);
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: bytes != null
            ? const EdgeInsets.all(5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bytes != null)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen(bytes: bytes!),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    bytes,
                    width: 220,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            if (text.isNotEmpty)
              Padding(
                padding: bytes != null
                    ? const EdgeInsets.fromLTRB(9, 6, 9, 0)
                    : EdgeInsets.zero,
                child: Text(text, style: TextStyle(color: fg)),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                right: bytes != null ? 6 : 0,
              ),
              child: Text(
                '${ChatService.timeLabel(created)}$tick',
                style: TextStyle(fontSize: 10, color: fg.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Send photo',
              icon: const Icon(Icons.photo_outlined),
              onPressed: _sendPhoto,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _sendText,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final Uint8List bytes;

  const ImageViewerScreen({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }
}
