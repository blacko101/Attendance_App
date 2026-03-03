import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/features/attendance/models/checkin_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';


class CheckInController {
  static const String baseUrl      = 'http://10.0.2.2:5000/api';
  static const double maxDistanceM = 100.0;  // 100 metres radius
  static const String _qrSecret   = 'smart_attend_qr_secret'; // must match backend

  // ── REQUEST LOCATION PERMISSION ───────────────────────────────────────────
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return false;
    if (permission == LocationPermission.denied)        return false;

    return true;
  }

  // ── GET CURRENT STUDENT POSITION ──────────────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:    LocationAccuracy.high,
          timeLimit:   Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── CALCULATE DISTANCE (Haversine formula) ────────────────────────────────
  double calculateDistance(
      double lat1, double lon1,
      double lat2, double lon2,
      ) {
    const R = 6371000.0; // Earth radius in metres
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  // ── VERIFY QR SIGNATURE ───────────────────────────────────────────────────
  // Prevents students from forging QR codes
  bool verifyQrSignature(QrPayload payload) {
    final data = '${payload.sessionId}:${payload.courseCode}:${payload.expiresAt}';
    final key  = utf8.encode(_qrSecret);
    final msg  = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(msg).toString();
    return digest == payload.signature;
  }

  // ── GENERATE QR PAYLOAD (Lecturer side) ───────────────────────────────────
  String generateQrData({
    required String sessionId,
    required String courseCode,
    required String courseName,
    required double lat,
    required double lng,
    int validMinutes = 10,
  }) {
    final expiresAt = DateTime.now()
        .add(Duration(minutes: validMinutes))
        .millisecondsSinceEpoch;

    final data = '$sessionId:$courseCode:$expiresAt';
    final key  = utf8.encode(_qrSecret);
    final msg  = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final signature = hmac.convert(msg).toString();

    final payload = QrPayload(
      sessionId:   sessionId,
      courseCode:  courseCode,
      courseName:  courseName,
      lecturerLat: lat,
      lecturerLng: lng,
      expiresAt:   expiresAt,
      signature:   signature,
    );

    return jsonEncode(payload.toJson());
  }

  // ── PROCESS CHECK-IN ──────────────────────────────────────────────────────
  Future<CheckInResult> processCheckIn(String qrRawData) async {
    try {
      // ── 1. Parse QR payload ──
      final Map<String, dynamic> json = jsonDecode(qrRawData);
      final payload = QrPayload.fromJson(json);

      // ── 2. Verify QR signature ──
      if (!verifyQrSignature(payload)) {
        return const CheckInResult(
          status:  CheckInStatus.invalid,
          message: 'Invalid QR code. Please ask your lecturer to regenerate.',
        );
      }

      // ── 3. Check QR expiry ──
      if (payload.isExpired) {
        return const CheckInResult(
          status:  CheckInStatus.expired,
          message: 'QR code has expired. Ask your lecturer for a new one.',
        );
      }

      // ── 4. Get student location ──
      final position = await getCurrentPosition();
      if (position == null) {
        return const CheckInResult(
          status:  CheckInStatus.error,
          message: 'Could not get your location. Enable GPS and try again.',
        );
      }

      // ── 5. Calculate distance from classroom ──
      final distance = calculateDistance(
        position.latitude,  position.longitude,
        payload.lecturerLat, payload.lecturerLng,
      );

      // ── 6. Check distance ──
      if (distance > maxDistanceM) {
        return CheckInResult(
          status:         CheckInStatus.tooFar,
          message:        'You are ${distance.toInt()}m away. '
              'Must be within ${maxDistanceM.toInt()}m of the classroom.',
          distanceMeters: distance,
          courseCode:     payload.courseCode,
          courseName:     payload.courseName,
        );
      }

      // ── 7. Send check-in to backend ──
      final session = await SessionService.getSession();
      if (session == null) {
        return const CheckInResult(
          status:  CheckInStatus.error,
          message: 'Session expired. Please log in again.',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/checkin'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          'sessionId':    payload.sessionId,
          'courseCode':   payload.courseCode,
          'studentLat':   position.latitude,
          'studentLng':   position.longitude,
          'distanceM':    distance.toInt(),
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return CheckInResult(
          status:         CheckInStatus.success,
          message:        'Attendance marked successfully! ✅',
          distanceMeters: distance,
          courseCode:     payload.courseCode,
          courseName:     payload.courseName,
        );
      } else if (response.statusCode == 409) {
        return CheckInResult(
          status:     CheckInStatus.alreadyMarked,
          message:    'You have already checked in for this class.',
          courseCode: payload.courseCode,
          courseName: payload.courseName,
        );
      } else {
        final msg = body['message'] as String? ?? 'Check-in failed.';
        return CheckInResult(
          status:  CheckInStatus.error,
          message: msg,
        );
      }

    } on FormatException {
      return const CheckInResult(
        status:  CheckInStatus.invalid,
        message: 'Invalid QR code format.',
      );
    } catch (e) {
      return CheckInResult(
        status:  CheckInStatus.error,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}