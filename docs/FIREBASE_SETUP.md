# Firebase setup (optional sign-in and backup)

The game works fully offline. Firebase only adds email sign-in and cloud backup. Until someone does the steps below, the app runs in guest-only mode and the sign-in screen says cloud features are not set up.

One team member does steps 1 to 4 once. Every developer does step 5 on their own machine.

## 1. Create the project (once)

1. Go to https://console.firebase.google.com and click **Add project**. Name it `midnight-manor`. Google Analytics can stay off.
2. In the left menu open **Build > Authentication > Get started**. Under **Sign-in method** enable **Email/Password**.
3. Open **Build > Firestore Database > Create database**. Pick a region near you and start in **production mode**.

## 2. Security rules (once)

In Firestore open the **Rules** tab, replace the contents with `firebase/firestore.rules` from this repo, and click **Publish**. The rule lets each user read and write only `users/{their uid}`.

## 3. Register the Android app (once)

In **Project settings > Your apps > Add app > Android**, use the package name `com.midnightminds.midnight_manor`. You do not need to download `google-services.json`; FlutterFire generates what the app needs in step 5.

## 4. Add the other member as a project owner (once)

**Project settings > Users and permissions > Add member**, so both of us can run step 5.

## 5. Connect your checkout (every developer)

```
dart pub global activate flutterfire_cli
flutterfire configure --project=midnight-manor --platforms=android
```

This overwrites `lib/firebase_options.dart` with the real settings. That file is committed on purpose: the values in it are public app identifiers, not secrets (Google's documentation says so), and the security rules protect the data. Keystores and `google-services.json` stay git-ignored.

Then run the app. `FirebaseBootstrap.start()` detects the real options and switches from guest-only to real sign-in and backup.

## How sync behaves

- SQLite is always the source of truth. Every action saves locally first.
- **Backup** uploads a snapshot of all player tables to `users/{uid}`.
- **Restore** downloads it and applies it only if it is newer than the last thing done on this device (last write wins). The settings screen can force a restore.
- If a backup fails (offline), the app marks it pending and `retryPendingBackup()` sends it next time the app comes to the foreground.
- Sign-in failures show a plain message and the player can continue as a guest.
