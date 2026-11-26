import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final Stream<Snap> _stream = ChatService.users();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final myUid = ChatService.me.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or email',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<Snap>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snap.data!.docs
                    .map((d) => d.data())
                    .where((u) => u['uid'] != myUid)
                    .where((u) {
                  if (_query.isEmpty) return true;
                  final name = (u['name'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  return name.contains(_query) || email.contains(_query);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final uid = u['uid'] as String;
                    final name = (u['name'] ?? 'User') as String;
                    return ListTile(
                      leading: UserAvatar(
                        key: ValueKey(uid),
                        uid: uid,
                        name: name,
                      ),
                      title: Text(name),
                      subtitle: Text((u['email'] ?? '') as String),
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(otherUid: uid, otherName: name),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
