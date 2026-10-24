import 'package:flutter/foundation.dart';

class Config {
  // Set with: flutter run --dart-define-from-file=.env.local
  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the Therapy Pal API (including /api).
  static String get apiBase {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    // The Android emulator reaches the host machine at 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api';
    }
    return 'http://localhost:4000/api';
  }
}
