import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Simple environment helper that resolves the backend base URL at runtime.
///
/// You can override the value via `--dart-define=CHATBOT_API_BASE=...` when
/// running or building the Flutter app. Otherwise it attempts to choose a sane
/// default per platform, so you don't have to keep editing source code when you
/// switch between Android emulators, Chrome, or desktop.
class Env {
  Env._();

  static String get apiBase {
    const override = String.fromEnvironment('CHATBOT_API_BASE', defaultValue: '');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      // Prefer same-host backend to avoid CORS headaches when running locally.
      final base = Uri.base;
      final scheme = base.scheme.isEmpty ? 'http' : base.scheme;
      final host = base.host.isEmpty ? 'localhost' : base.host;
      // Default FastAPI dev server listens on 8000 when no explicit override.
      return '$scheme://$host:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulators forward host machine localhost through 10.0.2.2
      // (or 10.0.3.2 for Genymotion). Use --dart-define for physical devices.
      return 'http://10.0.2.2:8000';
    }

    // iOS simulator, desktop, etc. can reach 127.0.0.1 directly.
    return 'http://127.0.0.1:8000';
  }
}
