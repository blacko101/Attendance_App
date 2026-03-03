// ─────────────────────────────────────────────
//  CHECK-IN MODEL
// ─────────────────────────────────────────────

enum CheckInStatus { success, tooFar, expired, alreadyMarked, invalid, error }

class QrPayload {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final double lecturerLat;
  final double lecturerLng;
  final int    expiresAt;    // Unix timestamp ms
  final String signature;   // HMAC-SHA256 for tamper detection

  const QrPayload({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.lecturerLat,
    required this.lecturerLng,
    required this.expiresAt,
    required this.signature,
  });

  factory QrPayload.fromJson(Map<String, dynamic> json) => QrPayload(
    sessionId:   json['sessionId']   as String,
    courseCode:  json['courseCode']  as String,
    courseName:  json['courseName']  as String,
    lecturerLat: (json['lat']        as num).toDouble(),
    lecturerLng: (json['lng']        as num).toDouble(),
    expiresAt:   json['expiresAt']   as int,
    signature:   json['signature']   as String,
  );

  Map<String, dynamic> toJson() => {
    'sessionId':  sessionId,
    'courseCode': courseCode,
    'courseName': courseName,
    'lat':        lecturerLat,
    'lng':        lecturerLng,
    'expiresAt':  expiresAt,
    'signature':  signature,
  };

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt;

  // How many seconds remain before expiry
  int get secondsRemaining {
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return (remaining / 1000).ceil().clamp(0, 999999);
  }
}

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