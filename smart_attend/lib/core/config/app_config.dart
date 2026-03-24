import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────
//  app_config.dart
//  Central configuration — import this wherever a baseUrl is needed.
//
//  Platform → correct host:
//    Flutter Web (Chrome)    → localhost       (same machine as backend)
//    Android emulator        → 10.0.2.2        (maps to host localhost)
//    iOS simulator           → 127.0.0.1       (maps to host localhost)
//    Physical device         → your LAN IP     (e.g. 192.168.x.x:5000)
//    Production              → your API domain (e.g. api.smartattend.dev)
//
//  kIsWeb is a Flutter built-in compile-time constant — no extra
//  package needed.  It is true when built for the browser and false
//  for all native targets (Android, iOS, desktop).
// ─────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._(); // prevent instantiation

  static String get _host {
    if (kIsWeb) return 'http://localhost:5000'; // Flutter Web / Chrome
    return 'http://10.10.43.251:5000'; // Physical device

  }

  static String get baseUrl => '$_host/api';
  static String get authUrl => '$_host/api/auth';
  static String get attendanceUrl => '$_host/api/attendance';
  static String get adminUrl => '$_host/api/admin';
  static String get deanUrl => '$_host/api/dean';
}
