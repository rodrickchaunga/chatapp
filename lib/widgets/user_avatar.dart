import 'package:flutter/material.dart';

import '../services/chat_service.dart';

/// Circle avatar that shows the user's profile photo, or their initial.
class UserAvatar extends StatefulWidget {
  final String uid;
  final String name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 20,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  late Stream<DocSnap> _stream;

  @override
  void initState() {
    super.initState();
    _stream = ChatService.userDoc(widget.uid);
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _stream = ChatService.userDoc(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocSnap>(
      stream: _stream,
      builder: (context, snap) {
        final avatar = snap.data?.data()?['avatar'];
        ImageProvider? image;
        if (avatar is String && avatar.isNotEmpty) {
          image = MemoryImage(ChatService.decode(
            'a:${widget.uid}:${avatar.length}:${avatar.hashCode}',
            avatar,
          ));
        }
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: image,
          child: image == null
              ? Text(
                  widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(),
                  style: TextStyle(fontSize: widget.radius * 0.9),
                )
              : null,
        );
      },
    );
  }
}
