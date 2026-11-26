import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Snap = QuerySnapshot<Map<String, dynamic>>;

class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User get me => FirebaseAuth.instance.currentUser!;

  static String get myName {
    final n = me.displayName;
    if (n != null && n.trim().isNotEmpty) return n;
    return me.email ?? 'Me';
  }

  /// Same id for both people no matter who starts the chat.
  static String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  static Future<void> saveUser(User user, String name) {
    return _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<Snap> users() => _db.collection('users').snapshots();

  static Stream<Snap> myChats() => _db
      .collection('chats')
      .where('participants', arrayContains: me.uid)
      .snapshots();

  static Future<void> ensureChat(String otherUid, String otherName) {
    return _db.collection('chats').doc(chatIdFor(me.uid, otherUid)).set({
      'participants': [me.uid, otherUid],
      'names': {me.uid: myName, otherUid: otherName},
    }, SetOptions(merge: true));
  }

  static Stream<Snap> messages(String otherUid) => _db
      .collection('chats')
      .doc(chatIdFor(me.uid, otherUid))
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .snapshots();

  static void send(String otherUid, String otherName, String text) {
    final chat = _db.collection('chats').doc(chatIdFor(me.uid, otherUid));
    final batch = _db.batch();
    batch.set(chat.collection('messages').doc(), {
      'senderId': me.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(chat, {
      'participants': [me.uid, otherUid],
      'names': {me.uid: myName, otherUid: otherName},
      'lastMessage': text,
      'lastSender': me.uid,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Not awaited on purpose: works offline, syncs when back online.
    batch.commit();
  }

  /// Pending server timestamps are null locally, treat them as "now".
  static int millis(dynamic t) {
    if (t is Timestamp) return t.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  static String timeLabel(dynamic t) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis(t));
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
