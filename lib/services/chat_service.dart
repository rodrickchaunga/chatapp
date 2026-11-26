import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

typedef Snap = QuerySnapshot<Map<String, dynamic>>;
typedef DocSnap = DocumentSnapshot<Map<String, dynamic>>;

class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Id of the chat that is open on screen (no banner alerts for it).
  static String? openChatId;

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

  static DocumentReference<Map<String, dynamic>> _chat(String otherUid) =>
      _db.collection('chats').doc(chatIdFor(me.uid, otherUid));

  static DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  // ---------------------------------------------------------------- users

  static Future<void> saveUser(User user, String name) {
    return _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Stream<Snap> users() => _db.collection('users').snapshots();

  static Stream<DocSnap> userDoc(String uid) => _user(uid).snapshots();

  static Future<void> setAvatar(String base64Image) {
    return _user(me.uid).set({'avatar': base64Image}, SetOptions(merge: true));
  }

  // ------------------------------------------------------------- presence

  /// Called every 30 seconds while the app is open.
  static Future<void> heartbeat() {
    if (FirebaseAuth.instance.currentUser == null) return Future.value();
    return _user(me.uid)
        .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true))
        .catchError((_) {});
  }

  /// "online", "last seen today at 14:05", "last seen 3/11" or ''.
  static String statusText(Map<String, dynamic>? user) {
    final t = user?['lastSeen'];
    if (t is! Timestamp) return '';
    final d = t.toDate();
    final now = DateTime.now();
    if (now.difference(d).inSeconds < 75) return 'online';
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'last seen today at ${timeLabel(t)}';
    }
    return 'last seen ${d.day}/${d.month}';
  }

  // ---------------------------------------------------------------- chats

  static Stream<Snap> myChats() => _db
      .collection('chats')
      .where('participants', arrayContains: me.uid)
      .snapshots();

  static Stream<DocSnap> chatDoc(String otherUid) => _chat(otherUid).snapshots();

  static Future<void> ensureChat(String otherUid, String otherName) {
    return _chat(otherUid).set({
      'participants': [me.uid, otherUid],
      'names': {me.uid: myName, otherUid: otherName},
    }, SetOptions(merge: true));
  }

  static Stream<Snap> messages(String otherUid) => _chat(otherUid)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .snapshots();

  /// Reset my unread counter and record when I last read the chat.
  static void markRead(String otherUid) {
    _chat(otherUid).set({
      'unread': {me.uid: 0},
      'lastRead': {me.uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true)).catchError((_) {});
  }

  static void setTyping(String otherUid) {
    _chat(otherUid)
        .update({'typing.${me.uid}': FieldValue.serverTimestamp()})
        .catchError((_) {});
  }

  static void send(
    String otherUid,
    String otherName, {
    String text = '',
    String? image,
  }) {
    final chat = _chat(otherUid);
    final batch = _db.batch();

    final msg = <String, dynamic>{
      'senderId': me.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (image != null) msg['image'] = image;
    batch.set(chat.collection('messages').doc(), msg);

    batch.set(
      chat,
      {
        'participants': [me.uid, otherUid],
        'names': {me.uid: myName, otherUid: otherName},
        'lastMessage': (image != null && text.isEmpty) ? '📷 Photo' : text,
        'lastSender': me.uid,
        'lastTime': FieldValue.serverTimestamp(),
        'unread': {otherUid: FieldValue.increment(1), me.uid: 0},
        'typing': {me.uid: FieldValue.delete()},
      },
      SetOptions(merge: true),
    );
    // Not awaited on purpose: works offline, syncs when back online.
    batch.commit().catchError((_) {});
  }

  // --------------------------------------------------------------- images

  /// Pick a photo and return it as base64 text. Photos are stored inside
  /// Firestore (no Firebase Storage needed, so it works on the free Spark plan).
  static Future<String?> pickImage({
    required double size,
    required int quality,
  }) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: size,
      maxHeight: size,
      imageQuality: quality,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > 700 * 1024) {
      throw Exception('That photo is too big. Pick a smaller one.');
    }
    return base64Encode(bytes);
  }

  static final Map<String, Uint8List> _cache = {};

  static Uint8List decode(String key, String b64) =>
      _cache.putIfAbsent(key, () => base64Decode(b64));

  // ----------------------------------------------------------------- time

  /// Pending server timestamps are null locally; treat them as "now".
  static int millis(dynamic t) {
    if (t is Timestamp) return t.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Like [millis] but 0 when the timestamp is not set yet.
  static int millisOrZero(dynamic t) =>
      t is Timestamp ? t.millisecondsSinceEpoch : 0;

  static String timeLabel(dynamic t) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis(t));
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
