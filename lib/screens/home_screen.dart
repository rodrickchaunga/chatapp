import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Stream<Snap> _listStream = ChatService.myChats();
  Timer? _beat;
  StreamSubscription<Snap>? _sub;
  bool _firstSnapshot = true;
  final Map<String, int> _announced = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    _listenForNewMessages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beat?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  // "online" status: refresh lastSeen every 30s while the app is open.
  void _startHeartbeat() {
    _beat?.cancel();
    ChatService.heartbeat();
    _beat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ChatService.heartbeat(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else {
      _beat?.cancel();
    }
  }

  // In-app alert (banner) when a message arrives in a chat you are not viewing.
  void _listenForNewMessages() {
    final myUid = ChatService.me.uid;
    _sub = ChatService.myChats().listen((snap) {
      if (_firstSnapshot) {
        _firstSnapshot = false;
        for (final d in snap.docs) {
          _announced[d.id] = ChatService.millisOrZero(d.data()['lastTime']);
        }
        return;
      }
      for (final change in snap.docChanges) {
        final d = change.doc;
        if (d.metadata.hasPendingWrites) continue;
        final data = d.data();
        if (data == null) continue;
        if (data['lastSender'] == myUid) continue;
        if ((data['lastMessage'] ?? '') == '') continue;

        final unreadMap = data['unread'];
        final unread =
            unreadMap is Map ? ((unreadMap[myUid] ?? 0) as num).toInt() : 0;
        if (unread <= 0) continue;

        final t = ChatService.millisOrZero(data['lastTime']);
        if (t <= (_announced[d.id] ?? 0)) continue;
        _announced[d.id] = t;

        if (ChatService.openChatId == d.id) continue;
        _showBanner(data);
      }
    }, onError: (_) {});
  }

  void _showBanner(Map<String, dynamic> data) {
    if (!mounted) return;
    final names = Map<String, dynamic>.from(data['names'] ?? {});
    final senderUid = data['lastSender'] as String;
    final sender = (names[senderUid] ?? 'New message') as String;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$sender: ${data['lastMessage']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(otherUid: senderUid, otherName: sender),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ChatService.me.uid;
    final cs = Theme.of(context).colorScheme;
    const bold = TextStyle(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chat',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UsersScreen()),
        ),
        child: const Icon(Icons.edit),
      ),
      body: StreamBuilder<Snap>(
        stream: _listStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs
              .where((d) => (d.data()['lastMessage'] ?? '') != '')
              .toList()
            ..sort((a, b) => ChatService.millis(b.data()['lastTime'])
                .compareTo(ChatService.millis(a.data()['lastTime'])));

          if (docs.isEmpty) {
            return const Center(
              child: Text('No chats yet.\nTap the pencil to start one.',
                  textAlign: TextAlign.center),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final participants = List<String>.from(data['participants']);
              final otherUid = participants.firstWhere((u) => u != myUid);
              final names = Map<String, dynamic>.from(data['names'] ?? {});
              final otherName = (names[otherUid] ?? 'User') as String;
              final mine = data['lastSender'] == myUid;
              final unreadMap = data['unread'];
              final unread = unreadMap is Map
                  ? ((unreadMap[myUid] ?? 0) as num).toInt()
                  : 0;

              return ListTile(
                leading: UserAvatar(
                  key: ValueKey(otherUid),
                  uid: otherUid,
                  name: otherName,
                ),
                title: Text(otherName, style: unread > 0 ? bold : null),
                subtitle: Text(
                  '${mine ? 'You: ' : ''}${data['lastMessage']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: unread > 0 ? bold : null,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ChatService.timeLabel(data['lastTime']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unread',
                          style: TextStyle(color: cs.onPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatScreen(otherUid: otherUid, otherName: otherName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
