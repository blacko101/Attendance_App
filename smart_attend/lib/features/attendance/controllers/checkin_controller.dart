import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/attendance/models/checkin_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';

class CheckInController {
  static const double maxDistanceM = 50.0; // kept for UI display only

  // ── REQUEST LOCATION PERMISSION ──────────────────────────────────
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return false;
    if (permission == LocationPermission.denied) return false;

    return true;
  }

  // ── GET CURRENT STUDENT POSITION ─────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return null;
    }
  }

  // ── PROCESS CHECK-IN ──────────────────────────────────────────────
  Future<CheckInResult> processCheckIn(String qrRawData) async {
    try {
      // ── 1. Parse QR payload ──────────────────────────────────────
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(qrRawData) as Map<String, dynamic>;
      } on FormatException {
        return const CheckInResult(
          status: CheckInStatus.invalid,
          message: 'Invalid QR code format.',
        );
      }

      final QrPayload payload;
      try {
        payload = QrPayload.fromJson(json);
      } catch (_) {
        return const CheckInResult(
          status: CheckInStatus.invalid,
          message: 'Invalid QR code. Please ask your lecturer to regenerate.',
        );
      }

      // ── 2. Client-side expiry pre-check ──────────────────────────
      if (payload.isExpired) {
        return const CheckInResult(
          status: CheckInStatus.expired,
          message: 'QR code has expired. Ask your lecturer for a new one.',
        );
      }

      // ── 3. Get student location ──────────────────────────────────
      final position = await getCurrentPosition();
      if (position == null) {
        return const CheckInResult(
          status: CheckInStatus.error,
          message: 'Could not get your location. Enable GPS and try again.',
        );
      }

      // ── 4. Get auth token ────────────────────────────────────────
      final session = await SessionService.getSession();
      if (session == null) {
        return const CheckInResult(
          status: CheckInStatus.error,
          message: 'Session expired. Please log in again.',
        );
      }

      // ── 5. Send check-in to backend ──────────────────────────────
      final response = await http
          .post(
            Uri.parse('${AppConfig.attendanceUrl}/checkin'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'sessionId': payload.sessionId,
              'courseCode': payload.courseCode,
              'expiresAt': payload.expiresAt,
              'signature': payload.signature,
              'studentLat': position.latitude,
              'studentLng': position.longitude,
              'method': 'qr',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return CheckInResult(
          status: CheckInStatus.success,
          message: 'Attendance marked successfully! ✅',
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );
      } else if (response.statusCode == 409) {
        return CheckInResult(
          status: CheckInStatus.alreadyMarked,
          message: 'You have already checked in for this class.',
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );
      } else if (response.statusCode == 400) {
        final msg = body['message'] as String? ?? 'Check-in failed.';
        final dist = (body['distanceMetres'] as num?)?.toDouble();

        final status = msg.toLowerCase().contains('expired')
            ? CheckInStatus.expired
            : msg.toLowerCase().contains('away')
            ? CheckInStatus.tooFar
            : msg.toLowerCase().contains('invalid')
            ? CheckInStatus.invalid
            : CheckInStatus.error;

        return CheckInResult(
          status: status,
          message: msg,
          distanceMeters: dist,
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );
      } else {
        final msg = body['message'] as String? ?? 'Check-in failed.';
        return CheckInResult(status: CheckInStatus.error, message: msg);
      }
    } catch (e) {
      return CheckInResult(
        status: CheckInStatus.error,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}
