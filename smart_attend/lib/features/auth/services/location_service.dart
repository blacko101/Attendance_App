import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Handles all GPS/location logic for Smart Attend.
///
/// WHY THIS CLASS EXISTS
/// ─────────────────────
/// Android requires TWO things before location works:
///   1. Permissions declared in AndroidManifest.xml  ← already done
///   2. Runtime permission request shown to the user ← this class handles it
///
/// Without step 2, geolocator throws a "location permission denied"
/// or "location service disabled" error even if the manifest is correct.
///
/// USAGE (in your lecturer session screen):
/// ─────────────────────────────────────────
///   final position = await LocationService.getCurrentLocation();
///   if (position != null) {
///     final lat = position.latitude;
///     final lng = position.longitude;
///   }
class LocationService {
  /// Returns the device's current [Position] or null on failure.
  ///
  /// Handles the full permission + service check flow:
  ///   1. Is location hardware enabled on the device?
  ///   2. Has the user granted location permission?
  ///      a. If permanently denied → open app settings.
  ///      b. If not yet asked → request it now.
  ///   3. Fetch the position with high accuracy.
  ///
  /// Throws a descriptive [Exception] so the caller can show a
  /// user-facing error message rather than crashing silently.
  static Future<Position?> getCurrentLocation() async {
    // ── 1. Is location service (GPS hardware) turned on? ────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. '
            'Please enable GPS in your device settings.',
      );
    }

    // ── 2. Check / request runtime permission ───────────────────────
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // First-time or previously denied (but not permanently) → ask.
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // User tapped "Deny" on the system dialog.
        throw Exception(
          'Location permission was denied. '
              'Please allow location access to start a session.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User tapped "Never ask again". We cannot show the system dialog
      // again — we must direct them to the app settings page.
      await Geolocator.openAppSettings();
      throw Exception(
        'Location permission is permanently denied. '
            'Please enable it in App Settings → Permissions → Location.',
      );
    }

    // ── 3. Fetch the position ────────────────────────────────────────
    // LocationAccuracy.high  = GPS + network (best fix, slower first call)
    // timeLimit ensures we never hang the UI indefinitely.
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      return position;
    } on TimeoutException {
      throw Exception(
        'Could not get your location in time. '
            'Move to an area with better GPS signal and try again.',
      );
    } catch (e) {
      throw Exception('GPS error: ${e.toString()}');
    }
  }

  /// Returns [true] if the app currently has an accepted location
  /// permission (whileInUse or always). Useful for checking before
  /// showing the "Start Session" button.
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}