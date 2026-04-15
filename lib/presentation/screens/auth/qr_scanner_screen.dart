import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';

/// Represents the current camera permission state from the user's perspective.
enum _CameraPermissionState {
  checking,    // Initial state — checking what permission is
  granted,     // Camera permission is given — show scanner
  denied,      // User denied once — show rationale and "Try Again"
  permanentlyDenied, // User denied twice / "Don't ask again" — show Settings button
  unavailable, // Device has no camera
}

/// QR Scanner screen for authenticating web portal sessions.
/// Scans QR codes from the web portal and authenticates the session.
///
/// Handles camera permission gracefully:
/// - Shows rationale (WHY we need camera) before requesting
/// - On denial: explains impact and shows "Try Again"
/// - On permanent denial: explains impact and links to phone Settings
/// - On no camera hardware: shows friendly message
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;

  bool _isProcessing = false;
  String? _errorMessage;
  bool _isSuccess = false;
  _CameraPermissionState _permissionState = _CameraPermissionState.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Re-check permission when the user returns from the phone's Settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _permissionState == _CameraPermissionState.permanentlyDenied) {
      _checkCameraPermission();
    }
  }

  // ---------------------------------------------------------------------------
  // Permission Logic
  // ---------------------------------------------------------------------------

  Future<void> _checkCameraPermission() async {
    setState(() => _permissionState = _CameraPermissionState.checking);

    final status = await Permission.camera.status;
    logger.d('Camera permission status: $status');

    if (status.isGranted) {
      _onPermissionGranted();
    } else if (status.isPermanentlyDenied) {
      setState(
        () => _permissionState = _CameraPermissionState.permanentlyDenied,
      );
    } else if (status.isDenied) {
      // First-time or previously denied — try requesting
      _requestPermission();
    } else {
      // restricted / limited (iOS) — treat as unavailable
      setState(() => _permissionState = _CameraPermissionState.unavailable);
    }
  }

  Future<void> _requestPermission() async {
    final result = await Permission.camera.request();
    logger.d('Camera permission request result: $result');

    if (result.isGranted) {
      _onPermissionGranted();
    } else if (result.isPermanentlyDenied) {
      setState(
        () => _permissionState = _CameraPermissionState.permanentlyDenied,
      );
    } else {
      setState(() => _permissionState = _CameraPermissionState.denied);
    }
  }

  void _onPermissionGranted() {
    _controller ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() => _permissionState = _CameraPermissionState.granted);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Web Login',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Only show torch button when camera is active
          if (_permissionState == _CameraPermissionState.granted &&
              _controller != null)
            IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _controller!,
                builder: (context, state, child) {
                  final isOn = state.torchState == TorchState.on;
                  return Icon(
                    isOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  );
                },
              ),
              onPressed: () => _controller?.toggleTorch(),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_permissionState) {
      case _CameraPermissionState.checking:
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEC4899),
          ),
        );

      case _CameraPermissionState.granted:
        return _buildScanner();

      case _CameraPermissionState.denied:
        return _buildPermissionScreen(
          icon: Icons.camera_alt_outlined,
          iconColor: const Color(0xFFEC4899),
          title: 'Camera Access Needed',
          reason:
              'To scan the QR code on the web portal, ConfidantCam needs to access your camera.\n\n'
              'The camera is only used while this screen is open — it is never accessed in the background.',
          bulletPoints: const [
            '📱 Reads the QR code displayed on your computer',
            '🔐 Authenticates your web session securely',
            '🚫 Never records or stores any video',
          ],
          primaryLabel: 'Allow Camera Access',
          primaryAction: _requestPermission,
          secondaryLabel: 'Go Back',
          secondaryAction: () => Navigator.of(context).pop(),
        );

      case _CameraPermissionState.permanentlyDenied:
        return _buildPermissionScreen(
          icon: Icons.no_photography_outlined,
          iconColor: Colors.orange,
          title: 'Camera Permission Blocked',
          reason:
              'You previously blocked camera access. To use Web Login, please enable '
              'camera permission for ConfidantCam in your phone\'s Settings.',
          bulletPoints: const [
            '1. Tap "Open Phone Settings" below',
            '2. Go to Privacy → Camera',
            '3. Enable camera for ConfidantCam',
            '4. Return here and scan the QR code',
          ],
          primaryLabel: 'Open Phone Settings',
          primaryAction: openAppSettings,
          secondaryLabel: 'Go Back',
          secondaryAction: () => Navigator.of(context).pop(),
          isSettings: true,
        );

      case _CameraPermissionState.unavailable:
        return _buildPermissionScreen(
          icon: Icons.videocam_off_outlined,
          iconColor: Colors.red,
          title: 'Camera Unavailable',
          reason:
              'Your device does not have a camera available, or it is restricted by your organisation.',
          bulletPoints: const [],
          primaryLabel: 'Go Back',
          primaryAction: () => Navigator.of(context).pop(),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Scanner View (permission granted)
  // ---------------------------------------------------------------------------

  Widget _buildScanner() {
    return Stack(
      children: [
        // Camera Preview
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MobileScanner(
                controller: _controller!,
                onDetect: _onDetect,
              ),
            ),
          ),
        ),

        // Scan guide frame
        Positioned.fill(child: _buildScanOverlay()),

        // Bottom instructions + error
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(),
        ),

        // Overlays
        if (_isSuccess) _buildSuccessOverlay(),
        if (_isProcessing) _buildProcessingOverlay(),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEC4899), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned(top: -2, left: -2, child: _buildCorner(true, true)),
                Positioned(
                  top: -2,
                  right: -2,
                  child: _buildCorner(true, false),
                ),
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: _buildCorner(false, true),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: _buildCorner(false, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Color(0xFFEC4899), width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Color(0xFFEC4899), width: 4)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Color(0xFFEC4899), width: 4)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Color(0xFFEC4899), width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF0F0F1A).withValues(alpha: 0.9),
            const Color(0xFF0F0F1A),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, color: Color(0xFFEC4899), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Scan Web Portal QR Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point your camera at the QR code shown on the web portal to log in instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
            ),
            SizedBox(height: 24),
            Text(
              'Authenticating...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.check, size: 60, color: Colors.white),
            ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms),
            const SizedBox(height: 24),
            const Text(
              'Web Portal Authenticated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'You can now use the web portal.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Permission Screen (shared template for denied / permanently denied / unavailable)
  // ---------------------------------------------------------------------------

  Widget _buildPermissionScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String reason,
    required List<String> bulletPoints,
    required String primaryLabel,
    required VoidCallback primaryAction,
    String? secondaryLabel,
    VoidCallback? secondaryAction,
    bool isSettings = false,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon bubble
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 48),
            ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.8),

            const SizedBox(height: 28),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 16),

            Text(
              reason,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            if (bulletPoints.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      bulletPoints.map((point) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            point,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],

            const SizedBox(height: 32),

            // Primary action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: primaryAction,
                icon: Icon(
                  isSettings
                      ? Icons.settings_outlined
                      : Icons.camera_alt_outlined,
                  size: 20,
                ),
                label: Text(
                  primaryLabel,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSettings ? Colors.orange : const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

            if (secondaryLabel != null && secondaryAction != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: secondaryAction,
                  child: Text(
                    secondaryLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // QR Detection & Session Authentication
  // ---------------------------------------------------------------------------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isSuccess) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    logger.d('QR Code scanned: $rawValue');

    try {
      final data = jsonDecode(rawValue);

      if (data['type'] != 'cc_web_auth') {
        setState(() {
          _errorMessage = 'Invalid QR code. Please scan the web portal QR code.';
        });
        return;
      }

      final sessionToken = data['token'] as String?;
      if (sessionToken == null || sessionToken.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid session token in QR code.';
        });
        return;
      }

      await _authenticateSession(sessionToken);
    } catch (e) {
      logger.e('Failed to parse QR code', e);
      setState(() {
        _errorMessage = 'Invalid QR code format. Please try again.';
      });
    }
  }

  Future<void> _authenticateSession(String sessionToken) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'You must be logged in to authenticate web sessions.';
        });
        return;
      }

      final response = await supabase
          .from('web_sessions')
          .update({
            'user_id': userId,
            'status': 'authenticated',
            'authenticated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_token', sessionToken)
          .eq('status', 'pending')
          .gte('expires_at', DateTime.now().toIso8601String()) // Fix #5: reject expired tokens
          .select()
          .maybeSingle();

      if (response == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Session expired or already used. Please refresh the QR code on the web portal.';
        });
        return;
      }

      logger.i('Web session authenticated successfully');

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      logger.e('Failed to authenticate web session', e);
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to authenticate. Please try again.';
      });
    }
  }
}
