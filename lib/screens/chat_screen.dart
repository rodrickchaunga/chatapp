import 'package:flutter/material.dart';

import '../services/chat_service.dart';

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
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    // Make sure the chat document exists before we listen to its messages.
    _ready = ChatService.ensureChat(widget.otherUid, widget.otherName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ChatService.send(widget.otherUid, widget.otherName, text);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ChatService.me.uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _ready,
              builder: (context, ready) {
                if (ready.hasError) {
                  return Center(child: Text('Error: ${ready.error}'));
                }
                if (ready.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<Snap>(
                  stream: ChatService.messages(widget.otherUid),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('Say hi 👋'));
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final m = docs[i].data();
                        final mine = m['senderId'] == myUid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  (m['text'] ?? '') as String,
                                  style: TextStyle(
                                    color: mine
                                        ? cs.onPrimary
                                        : cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ChatService.timeLabel(m['createdAt']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: (mine
                                            ? cs.onPrimary
                                            : cs.onSurface)
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
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
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
