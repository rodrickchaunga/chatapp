import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = ChatService.me.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
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
        stream: ChatService.myChats(),
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

              return ListTile(
                leading: CircleAvatar(
                  child: Text(otherName.isEmpty
                      ? '?'
                      : otherName[0].toUpperCase()),
                ),
                title: Text(otherName),
                subtitle: Text(
                  '${mine ? 'You: ' : ''}${data['lastMessage']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  ChatService.timeLabel(data['lastTime']),
                  style: Theme.of(context).textTheme.bodySmall,
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
