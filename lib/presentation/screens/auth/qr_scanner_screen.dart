import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';

enum _CameraPermissionState {
  checking,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

/// QR Scanner screen for authenticating web portal sessions.
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _permissionState == _CameraPermissionState.permanentlyDenied) {
      _checkCameraPermission();
    }
  }

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
      _requestPermission();
    } else {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Web Login'),
        actions: [
          if (_permissionState == _CameraPermissionState.granted &&
              _controller != null)
            IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _controller!,
                builder: (context, state, child) {
                  final isOn = state.torchState == TorchState.on;
                  return Icon(
                    isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: AppColors.primaryText,
                  );
                },
              ),
              onPressed: () => _controller?.toggleTorch(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_permissionState) {
      case _CameraPermissionState.checking:
        return Center(
          child: CircularProgressIndicator(color: AppColors.primaryOlive),
        );

      case _CameraPermissionState.granted:
        return _buildScanner();

      case _CameraPermissionState.denied:
        return _buildPermissionScreen(
          icon: Icons.camera_alt_outlined,
          iconColor: AppColors.primaryOlive,
          title: 'Camera Access Needed',
          reason:
              'To scan the QR code on the web portal, ConfidentCam needs to access your camera.\n\n'
              'The camera is only used while this screen is open — it is never accessed in the background.',
          bulletPoints: [
            'Reads the QR code displayed on your computer',
            'Authenticates your web session securely',
            'Never records or stores any video',
          ],
          primaryLabel: 'Allow Camera Access',
          primaryAction: _requestPermission,
          secondaryLabel: 'Go Back',
          secondaryAction: () => Navigator.of(context).pop(),
        );

      case _CameraPermissionState.permanentlyDenied:
        return _buildPermissionScreen(
          icon: Icons.no_photography_outlined,
          iconColor: AppColors.warning,
          title: 'Camera Permission Blocked',
          reason:
              'You previously blocked camera access. To use Web Login, please enable '
              "camera permission for ConfidentCam in your phone's Settings.",
          bulletPoints: [
            '1. Tap "Open Phone Settings" below',
            '2. Go to Privacy -> Camera',
            '3. Enable camera for ConfidentCam',
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
          iconColor: AppColors.error,
          title: 'Camera Unavailable',
          reason:
              'Your device does not have a camera available, or it is restricted.',
          bulletPoints: [],
          primaryLabel: 'Go Back',
          primaryAction: () => Navigator.of(context).pop(),
        );
    }
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.cardLargeBorder,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller!,
                      onDetect: _onDetect,
                    ),
                    _buildScanOverlay(),
                  ],
                ),
              ),
            ),
            _buildBottomPanel(),
          ],
        ),
        if (_isSuccess) _buildSuccessOverlay(),
        if (_isProcessing) _buildProcessingOverlay(),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Center(
      child: Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.background, width: 2.5),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      child: SageCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.olivePillFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.olivePillBorder),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primaryOlive,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Web Portal QR Code',
                        style: AppTypography.sectionTitle(fontSize: 16.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Point your camera at the QR code shown on the web portal.',
                        style: AppTypography.body(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.body(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppColors.error,
                        size: 18,
                      ),
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
      color: AppColors.background.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOlive),
            const SizedBox(height: 20),
            Text(
              'Authenticating...',
              style: AppTypography.headingMedium(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: AppColors.background.withValues(alpha: 0.95),
      child: Center(
        child: SageCard(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.navPill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 42,
                  color: AppColors.secondaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Web Portal Authenticated!',
                style: AppTypography.headingMedium(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can now use the web portal.',
                style: AppTypography.body(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SageCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.olivePillFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.olivePillBorder),
                    ),
                    child: Icon(icon, color: iconColor, size: 38),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: AppTypography.headingLarge(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reason,
                    style: AppTypography.body(),
                    textAlign: TextAlign.center,
                  ),
                  if (bulletPoints.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: bulletPoints.map((point) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 17,
                                  color: AppColors.secondaryGreen,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: AppTypography.body(
                                      color: AppColors.primaryText,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                label: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null && secondaryAction != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: secondaryAction,
                  child: Text(
                    secondaryLabel,
                    style: AppTypography.body(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
          _errorMessage =
              'Invalid QR code. Please scan the web portal QR code.';
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

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final response = await supabase
          .from('web_sessions')
          .update({
            'user_id': userId,
            'status': 'authenticated',
            'authenticated_at': nowUtc,
          })
          .eq('session_token', sessionToken)
          .eq('status', 'pending')
          .gt('expires_at', nowUtc)
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
