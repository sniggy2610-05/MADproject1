// Placeholder until `flutterfire configure` is run.
//
// FlutterFire overwrites this file with the real project settings (app ids
// and API keys). Those are public identifiers, not secrets: Firebase
// protects data with the security rules in firebase/firestore.rules, not
// by hiding these values. See docs/FIREBASE_SETUP.md.
//
// While this placeholder is in place, FirebaseBootstrap.start() catches the
// UnsupportedError below and the app runs in guest-only mode.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured for this build. '
        'Run `flutterfire configure` (see docs/FIREBASE_SETUP.md).',
      );
}
