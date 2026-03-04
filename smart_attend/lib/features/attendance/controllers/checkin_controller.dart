import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/attendance/models/checkin_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';

// ─────────────────────────────────────────────────────────────────
//  CheckInController  (STUDENT SIDE ONLY)
//
//  This controller is responsible for one thing: taking the raw
//  string from the QR scanner, validating it locally where possible,
//  and sending the authoritative check-in request to the backend.
//
//  WHAT WAS REMOVED vs the old version:
//
//  1. generateQrData() — DELETED.
//     This was a lecturer-side operation that had no business being
//     in the student check-in controller. It was also wrong: it
//     generated client-side signatures that would never match the
//     server-generated HMAC (Priority 2 backend fix).
//     Signature generation now lives exclusively in
//     LecturerController, which calls the backend API.
//
//  2. verifyQrSignature() — DELETED.
//     The backend is the authoritative verifier. A client-side
//     signature check requires the QR_SECRET to be embedded in the
//     app binary, which is a security risk (the secret can be
//     extracted from the APK/IPA). Trust the server, not the client.
//
//  3. calculateDistance() — DELETED.
//     Distance is now computed server-side using the student's GPS
//     coordinates. We still request GPS and send it to the server,
//     but we do not gate on distance locally — the server decides.
//     This prevents students from spoofing distance client-side
//     (e.g. by modifying the app or intercepting the local check).
//
//  WHAT THE POST BODY NOW SENDS:
//    sessionId   — from QR payload
//    courseCode  — from QR payload
//    expiresAt   — from QR payload (backend verifies expiry)
//    signature   — from QR payload (backend verifies HMAC)
//    studentLat  — current GPS latitude
//    studentLng  — current GPS longitude
//    method      — "qr"
//
//  The backend performs: HMAC verify → expiry check → session
//  lookup → courseCode cross-check → GPS distance check → upsert.
// ─────────────────────────────────────────────────────────────────
class CheckInController {
  static const double maxDistanceM = 100.0; // kept for UI display only

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
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:  LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── PROCESS CHECK-IN ──────────────────────────────────────────────
  // Entry point: called with the raw string from the QR scanner.
  Future<CheckInResult> processCheckIn(String qrRawData) async {
    try {
      // ── 1. Parse QR payload ──────────────────────────────────────
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(qrRawData) as Map<String, dynamic>;
      } on FormatException {
        return const CheckInResult(
          status:  CheckInStatus.invalid,
          message: 'Invalid QR code format.',
        );
      }

      final QrPayload payload;
      try {
        payload = QrPayload.fromJson(json);
      } catch (_) {
        // fromJson will throw if required fields are missing/wrong type
        return const CheckInResult(
          status:  CheckInStatus.invalid,
          message: 'Invalid QR code. Please ask your lecturer to regenerate.',
        );
      }

      // ── 2. Client-side expiry pre-check ─────────────────────────
      // This is a fast local check to give immediate feedback before
      // even touching the network. The server performs its own
      // authoritative expiry check regardless.
      if (payload.isExpired) {
        return const CheckInResult(
          status:  CheckInStatus.expired,
          message: 'QR code has expired. Ask your lecturer for a new one.',
        );
      }

      // ── 3. Get student location ──────────────────────────────────
      // Location is sent to the backend for the server-side proximity
      // check. Only in-person sessions require GPS; the server knows
      // the session type and will reject missing GPS accordingly.
      final position = await getCurrentPosition();
      if (position == null) {
        return const CheckInResult(
          status:  CheckInStatus.error,
          message: 'Could not get your location. Enable GPS and try again.',
        );
      }

      // ── 4. Get auth token ────────────────────────────────────────
      final session = await SessionService.getSession();
      if (session == null) {
        return const CheckInResult(
          status:  CheckInStatus.error,
          message: 'Session expired. Please log in again.',
        );
      }

      // ── 5. Send check-in to backend ──────────────────────────────
      // The backend now requires all four QR fields (sessionId,
      // courseCode, expiresAt, signature) to verify the HMAC and
      // expiry server-side. The old code omitted expiresAt and
      // signature, causing every check-in to return 400.
      final response = await http.post(
        Uri.parse('${AppConfig.attendanceUrl}/checkin'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          // ── QR fields (all required by backend HMAC verification) ──
          'sessionId':  payload.sessionId,
          'courseCode': payload.courseCode,
          'expiresAt':  payload.expiresAt,   // ← was missing — caused 400
          'signature':  payload.signature,   // ← was missing — caused 400
          // ── Student GPS (server does the distance check) ──────────
          'studentLat': position.latitude,
          'studentLng': position.longitude,
          // ── Check-in method ───────────────────────────────────────
          'method': 'qr',
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return CheckInResult(
          status:     CheckInStatus.success,
          message:    'Attendance marked successfully! ✅',
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );

      } else if (response.statusCode == 409) {
        return CheckInResult(
          status:     CheckInStatus.alreadyMarked,
          message:    'You have already checked in for this class.',
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );

      } else if (response.statusCode == 400) {
        // Could be: expired, out of range, invalid QR, missing GPS
        final msg = body['message'] as String? ?? 'Check-in failed.';
        // The backend returns distanceMetres when the student is too far
        final dist = (body['distanceMetres'] as num?)?.toDouble();

        // Determine the correct status from the message so the UI
        // can show the right icon and button set.
        final status = msg.toLowerCase().contains('expired')
            ? CheckInStatus.expired
            : msg.toLowerCase().contains('away')
            ? CheckInStatus.tooFar
            : msg.toLowerCase().contains('invalid')
            ? CheckInStatus.invalid
            : CheckInStatus.error;

        return CheckInResult(
          status:         status,
          message:        msg,
          distanceMeters: dist,
          courseCode:     payload.courseCode,
          courseName:     payload.courseName,
        );

      } else {
        final msg = body['message'] as String? ?? 'Check-in failed.';
        return CheckInResult(
          status:  CheckInStatus.error,
          message: msg,
        );
      }

    } catch (e) {
      return CheckInResult(
        status:  CheckInStatus.error,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  generateQrData({required String sessionId, required String courseCode, required String courseName, required double lat, required double lng, required int validMinutes}) {}
}