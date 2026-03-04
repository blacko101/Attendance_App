// ─────────────────────────────────────────────
//  CHECK-IN MODEL
// ─────────────────────────────────────────────

enum CheckInStatus { success, tooFar, expired, alreadyMarked, invalid, error }

// ─────────────────────────────────────────────
//  QrPayload
//
//  Represents the data encoded inside the QR code that the lecturer
//  displays to students.
//
//  IMPORTANT CHANGE (Priority 2 backend fix):
//  lecturerLat and lecturerLng have been REMOVED from this model.
//  The backend now stores GPS coordinates server-side in the session
//  document. The QR payload only carries what the backend needs to:
//    1. Identify the session       → sessionId
//    2. Verify the QR is authentic → signature (HMAC-SHA256)
//    3. Reject stale QRs           → expiresAt
//    4. Cross-check course binding → courseCode
//
//  The GPS proximity check is performed entirely server-side using
//  the studentLat/studentLng the student sends at check-in time.
//  There is no longer any reason for the lecturer's GPS to travel
//  inside the QR code.
//
//  courseName is included for UI display on the student side only
//  and is NOT part of the HMAC-signed data.
// ─────────────────────────────────────────────
class QrPayload {
  final String sessionId;
  final String courseCode;
  final String courseName;   // display only — not in HMAC
  final int    expiresAt;    // Unix ms — included in HMAC
  final String signature;    // HMAC-SHA256 generated server-side

  const QrPayload({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.expiresAt,
    required this.signature,
  });

  factory QrPayload.fromJson(Map<String, dynamic> json) => QrPayload(
    sessionId:  json['sessionId']  as String,
    courseCode: json['courseCode'] as String,
    // courseName is optional — the student app adds it for display;
    // fall back gracefully if the QR was built without it.
    courseName: json['courseName'] as String? ?? '',
    expiresAt:  json['expiresAt']  as int,
    signature:  json['signature']  as String,
  );

  Map<String, dynamic> toJson() => {
    'sessionId':  sessionId,
    'courseCode': courseCode,
    'courseName': courseName,
    'expiresAt':  expiresAt,
    'signature':  signature,
  };

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt;

  // Seconds remaining before the QR expires (clamped to ≥ 0)
  int get secondsRemaining {
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return (remaining / 1000).ceil().clamp(0, 999999);
  }
}

// ─────────────────────────────────────────────
//  CheckInResult
// ─────────────────────────────────────────────
class CheckInResult {
  final CheckInStatus status;
  final String        message;
  final double?       distanceMeters;
  final String?       courseCode;
  final String?       courseName;

  const CheckInResult({
    required this.status,
    required this.message,
    this.distanceMeters,
    this.courseCode,
    this.courseName,
  });

  bool get isSuccess => status == CheckInStatus.success;
}