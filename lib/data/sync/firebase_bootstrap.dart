import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'auth_service.dart';
import 'backup_store.dart';
import 'firebase_auth_service.dart';
import 'firestore_backup_store.dart';

/// The cloud services the app should use, real or stand-in.
class CloudServices {
  const CloudServices({
    required this.available,
    required this.auth,
    required this.store,
  });

  final bool available;
  final AuthService auth;
  final BackupStore store;
}

/// Starts Firebase if this build is configured for it. If not (no
/// `flutterfire configure` run yet, or the device cannot start Firebase),
/// the app gets guest-only stand-ins and keeps working offline.
class FirebaseBootstrap {
  static Future<CloudServices> start() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return CloudServices(
        available: true,
        auth: FirebaseAuthService(),
        store: FirestoreBackupStore(),
      );
    } on UnsupportedError {
      return unavailable;
    } catch (_) {
      return unavailable;
    }
  }

  static const unavailable = CloudServices(
    available: false,
    auth: UnavailableAuthService(),
    store: UnavailableBackupStore(),
  );
}
