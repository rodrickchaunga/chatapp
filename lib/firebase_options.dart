import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Fill these in from your Firebase project (see README.md).
/// They all come from the google-services.json file you download
/// from Firebase Console -> Project settings -> Your apps (Android).
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyCjbpPzl-NH2hIZzJ_eLfYPQUy0kC6syS8', // client[0].api_key[0].current_key
    appId: '1:347097457664:android:209befdee2ef224ca164e5', // client[0].client_info.mobilesdk_app_id
    messagingSenderId: '347097457664', // project_info.project_number
    projectId: 'chatapp-23264', // project_info.project_id
    storageBucket: 'chatapp-23264.firebasestorage.app', // project_info.storage_bucket
  );
}
