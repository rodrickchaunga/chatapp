import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _changePhoto() async {
    try {
      final b64 = await ChatService.pickImage(size: 256, quality: 50);
      if (b64 == null) return;
      setState(() => _busy = true);
      await ChatService.setAvatar(b64);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ChatService.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(uid: me.uid, name: ChatService.myName, radius: 64),
            const SizedBox(height: 16),
            Text(
              ChatService.myName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(me.email ?? ''),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _changePhoto,
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo),
              label: const Text('Change photo'),
            ),
          ],
        ),
      ),
    );
  }
}
