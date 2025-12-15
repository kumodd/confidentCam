import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';

/// QR Scanner screen for authenticating web portal sessions.
/// Scans QR codes from the web portal and authenticates the session.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        title: const Text('Web Login', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
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
        child: Stack(
          children: [
            // Camera Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            ),

            // Overlay with scan guide
            Positioned.fill(child: _buildScanOverlay()),

            // Bottom instructions
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),

            // Success overlay
            if (_isSuccess) _buildSuccessOverlay(),

            // Processing overlay
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scan frame guide
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEC4899), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner decorations
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
          top:
              isTop
                  ? const BorderSide(color: Color(0xFFEC4899), width: 4)
                  : BorderSide.none,
          bottom:
              !isTop
                  ? const BorderSide(color: Color(0xFFEC4899), width: 4)
                  : BorderSide.none,
          left:
              isLeft
                  ? const BorderSide(color: Color(0xFFEC4899), width: 4)
                  : BorderSide.none,
          right:
              !isLeft
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
            const Color(0xFF0F0F1A).withOpacity(0.9),
            const Color(0xFF0F0F1A),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: Color(0xFFEC4899),
              size: 48,
            ),
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
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
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
      color: Colors.black.withOpacity(0.7),
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
      color: Colors.black.withOpacity(0.9),
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
            ),
            const SizedBox(height: 24),
            const Text(
              'Web Portal Authenticated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can now use the web portal.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
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

    // Try to parse as our web auth QR code
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

      // Authenticate the session
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

      // Update the web session with our user ID
      final response =
          await supabase
              .from('web_sessions')
              .update({
                'user_id': userId,
                'status': 'authenticated',
                'authenticated_at': DateTime.now().toIso8601String(),
              })
              .eq('session_token', sessionToken)
              .eq('status', 'pending')
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

      // Show success
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      // Wait and pop
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
