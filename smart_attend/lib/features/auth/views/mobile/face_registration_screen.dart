import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';

class FaceRegistrationScreen extends StatefulWidget {
  static String id = 'face_registration_screen';
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  // ── Camera ──────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // ── ML Kit face detector ─────────────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableContours: false,
      enableTracking: false,
      minFaceSize: 0.25,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // ── State ────────────────────────────────────────────────────────
  bool _faceDetected   = false;
  bool _isProcessing   = false; // true while analysing a frame
  bool _isUploading    = false; // true while sending photo to backend
  String? _errorMsg;

  // ── Frame processing ─────────────────────────────────────────────
  // We process one frame at a time to avoid flooding the detector.
  bool _processingFrame = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ── CAMERA SETUP ─────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      // Prefer front camera for selfie
      final front = _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      // Start real-time face detection on each frame
      _cameraController!.startImageStream(_onCameraFrame);

      setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _errorMsg = 'Could not open camera. Please try again.');
    }
  }

  // ── FRAME-BY-FRAME FACE DETECTION ────────────────────────────────
  Future<void> _onCameraFrame(CameraImage image) async {
    if (_processingFrame || _isUploading) return;
    _processingFrame = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _processingFrame = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() => _faceDetected = faces.isNotEmpty);
      }
    } catch (_) {
      // Silently ignore frame processing errors
    } finally {
      _processingFrame = false;
    }
  }

  // ── CONVERT CAMERA FRAME TO ML KIT InputImage ────────────────────
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── CAPTURE PHOTO & UPLOAD ────────────────────────────────────────
  Future<void> _captureAndRegister() async {
    if (!_faceDetected || _isUploading || _cameraController == null) return;

    setState(() {
      _isUploading = true;
      _errorMsg    = null;
    });

    try {
      // Stop the image stream before taking a picture
      await _cameraController!.stopImageStream();

      final XFile photo = await _cameraController!.takePicture();
      final bytes       = await File(photo.path).readAsBytes();
      final base64Photo = base64Encode(bytes);

      final session = await SessionService.getSession();
      if (session == null) {
        setState(() {
          _errorMsg    = 'Session expired. Please log in again.';
          _isUploading = false;
        });
        return;
      }

      final response = await http
          .post(
        Uri.parse('${AppConfig.authUrl}/register-face'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({'photo': base64Photo}),
      )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Update local session so welcome_screen doesn't redirect here again
        final updated = session.copyWithFaceRegistered();
        await SessionService.saveSession(updated);

        if (mounted) {
          Navigator.pushReplacementNamed(context, StudentDashboard.id);
        }
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _errorMsg    = body['message'] as String? ?? 'Upload failed. Try again.';
          _isUploading = false;
        });
        // Restart image stream so the user can try again
        await _cameraController!.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg    = 'Connection error. Check your internet and try again.';
          _isUploading = false;
        });
        await _cameraController?.startImageStream(_onCameraFrame);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCameraView()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Column(
      children: [
        Text(
          'Register Your Face',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Position your face in the circle and keep still',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );

  // ── CAMERA VIEW WITH OVAL OVERLAY ────────────────────────────────
  Widget _buildCameraView() {
    if (_errorMsg != null && !_cameraReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _errorMsg!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }

    if (!_cameraReady) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B1B42)),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Full camera preview
        SizedBox.expand(
          child: CameraPreview(_cameraController!),
        ),

        // Dark overlay with oval cutout
        SizedBox.expand(
          child: CustomPaint(
            painter: _OvalOverlayPainter(
              borderColor: _faceDetected
                  ? AppColors.green
                  : Colors.white.withValues(alpha: 0.6),
              borderWidth: _faceDetected ? 4.0 : 2.0,
            ),
          ),
        ),

        // Face detection status indicator
        Positioned(
          bottom: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _faceDetected
                ? _StatusChip(
              key: const ValueKey('detected'),
              icon: Icons.check_circle_rounded,
              label: 'Face detected — hold still',
              color: AppColors.green,
            )
                : _StatusChip(
              key: const ValueKey('scanning'),
              icon: Icons.face_outlined,
              label: 'Looking for your face...',
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),

        // Uploading overlay
        if (_isUploading)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF9B1B42),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saving your face...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── BOTTOM PANEL ─────────────────────────────────────────────────
  Widget _buildBottomPanel() => Container(
    color: Colors.black,
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error message
        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cherry.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.cherry.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.cherry, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.cherry,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Info text
        Text(
          'Your photo is stored securely and only used\nto verify your identity during attendance.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),

        const SizedBox(height: 20),

        // Capture button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _faceDetected && !_isUploading
                  ? AppColors.cherry
                  : Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _faceDetected && !_isUploading
                ? _captureAndRegister
                : null,
            icon: Icon(
              _faceDetected
                  ? Icons.camera_alt_rounded
                  : Icons.face_outlined,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              _faceDetected ? 'Capture & Register' : 'Waiting for face...',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  OVAL OVERLAY PAINTER
//  Draws a dark overlay with a transparent oval
//  cutout where the student positions their face.
// ─────────────────────────────────────────────
class _OvalOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  _OvalOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width:  size.width * 0.75,
      height: size.height * 0.65,
    );

    // Dark overlay — save layer and punch out oval with BlendMode.clear
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      overlayPaint,
    );
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Oval border
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color       = borderColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter old) =>
      old.borderColor != borderColor || old.borderWidth != borderWidth;
}

// ─────────────────────────────────────────────
//  STATUS CHIP
// ─────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;

  const _StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}