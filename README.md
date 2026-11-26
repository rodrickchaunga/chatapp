# ChatApp (Flutter + Firebase)

Messenger-style chat: email/password sign up, user search, real-time 1-to-1 chat, chat list with last message.

You don't build anything on your phone. GitHub builds the APK for you.

## 1. Firebase setup (5 minutes, on console.firebase.google.com)

1. **Create project** (Analytics is optional).
2. **Add an Android app** (the Android icon on the project home).
   - Package name: `com.example.chatapp` (must be exactly this)
   - Skip the SHA-1 field. Download `google-services.json` (you only need to read values from it).
3. **Build > Authentication > Get started > Email/Password > Enable.**
4. **Build > Firestore Database > Create database** (production mode, pick a region).
5. In Firestore, open the **Rules** tab, paste the contents of `firestore.rules`, and **Publish**.

## 2. Paste your keys

Open `lib/firebase_options.dart` and fill the five values from `google-services.json`:

| Field in the Dart file | Where it is in google-services.json |
|---|---|
| apiKey | client[0].api_key[0].current_key |
| appId | client[0].client_info.mobilesdk_app_id |
| messagingSenderId | project_info.project_number |
| projectId | project_info.project_id |
| storageBucket | project_info.storage_bucket |

## 3. Push to GitHub (Termux)

```bash
pkg install git unzip
unzip chatapp.zip && cd chatapp
git init
git add .
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

(GitHub asks for a username and a Personal Access Token instead of a password.)

## 4. Get the APK

GitHub repo > **Actions** tab > latest "Build APK" run > scroll to **Artifacts** > download `chatapp-apk`.
Unzip it, install `app-release.apk` on your phone (allow "install unknown apps").

The first build takes roughly 5-10 minutes. To rebuild without a new commit, use **Run workflow**.

## Test it

Sign up two accounts (use two phones, or one phone + a friend), search the other person, and chat.

## Features (all work on the free Firebase Spark plan)

- Unread badges and bold chats in the chat list
- Read receipts: ✓ sent, ✓✓ seen
- Photo messages (stored inside Firestore, resized to stay small)
- In-app alert banner when a message arrives in another chat
- Online status ("online" / "last seen") and "typing..." indicator
- Profile pictures (Profile icon in the top bar)

## Spark plan limits

- Photos and avatars are stored as text in Firestore, because Firebase Storage needs the paid Blaze plan.
- Alerts only appear while the app is open. Notifications when the app is closed need a server (Cloud Functions), which also needs Blaze.

## Next steps

- Real push notifications (FCM + Cloud Functions, Blaze plan)
- Group chats
- Delete / edit messages
