// ─────────────────────────────────────────────────────────────────
//  app_config.dart
//  Central configuration — import this wherever a baseUrl is needed.
//  Previously each controller had its own hardcoded copy, meaning a
//  URL change required edits in multiple files.
//
//  To switch environments, change BASE_URL here only.
//
//  Android emulator  → 10.0.2.2 maps to the host machine's localhost
//  iOS simulator     → 127.0.0.1 maps to the host machine's localhost
//  Physical device   → use your machine's LAN IP (e.g. 192.168.x.x)
//  Production        → replace with your deployed API domain
// ─────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._(); // prevent instantiation

  static const String baseUrl = 'http://10.0.2.2:5000/api';

  // Convenience getters for each endpoint group
  static const String authUrl       = '$baseUrl/auth';
  static const String attendanceUrl = '$baseUrl/attendance';
  static const String adminUrl      = '$baseUrl/admin';
}