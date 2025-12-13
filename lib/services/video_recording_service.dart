import 'package:camera/camera.dart';

import '../core/config/app_config.dart';
import '../core/utils/logger.dart';

/// Service for video recording operations.
abstract class VideoRecordingService {
  /// Initialize camera with optional quality setting.
  Future<void> initialize({
    bool useFrontCamera = true,
    ResolutionPreset quality = ResolutionPreset.high,
  });

  /// Get camera controller.
  CameraController? get controller;

  /// Check if recording.
  bool get isRecording;

  /// Start recording.
  Future<void> startRecording();

  /// Stop recording and return video path.
  Future<String?> stopRecording();

  /// Switch camera (front/back).
  Future<void> switchCamera();
  
  /// Change video quality (requires reinitialize).
  Future<void> setQuality(ResolutionPreset quality);
  
  /// Get current quality setting.
  ResolutionPreset get currentQuality;

  /// Dispose resources.
  Future<void> dispose();
}

class VideoRecordingServiceImpl implements VideoRecordingService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _useFrontCamera = true;
  bool _isRecording = false;
  ResolutionPreset _currentQuality = ResolutionPreset.high;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isRecording => _isRecording;
  
  @override
  ResolutionPreset get currentQuality => _currentQuality;

  @override
  Future<void> initialize({
    bool useFrontCamera = true,
    ResolutionPreset quality = ResolutionPreset.high,
  }) async {
    try {
      _useFrontCamera = useFrontCamera;
      _currentQuality = quality;
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        logger.e('No cameras available');
        return;
      }

      final camera = _findCamera();
      if (camera == null) {
        logger.e('Requested camera not found');
        return;
      }

      _controller = CameraController(
        camera,
        _currentQuality,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.prepareForVideoRecording();

      logger.i('Camera initialized with quality: ${_currentQuality.name}');
    } catch (e) {
      logger.e('Error initializing camera', e);
      rethrow;
    }
  }
  
  @override
  Future<void> setQuality(ResolutionPreset quality) async {
    if (_isRecording) {
      logger.w('Cannot change quality while recording');
      return;
    }
    
    _currentQuality = quality;
    
    // Reinitialize with new quality
    if (_controller != null) {
      await _controller!.dispose();
      await initialize(useFrontCamera: _useFrontCamera, quality: quality);
    }
  }

  CameraDescription? _findCamera() {
    final direction = _useFrontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    for (final camera in _cameras) {
      if (camera.lensDirection == direction) {
        return camera;
      }
    }

    // Fallback to first available camera
    return _cameras.isNotEmpty ? _cameras.first : null;
  }

  @override
  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      logger.e('Cannot start recording: controller not initialized');
      return;
    }

    if (_isRecording) {
      logger.w('Already recording');
      return;
    }

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      logger.i('Recording started');

      // Auto-stop after max duration
      Future.delayed(
        Duration(seconds: AppConfig.maxRecordingDurationSeconds),
        () {
          if (_isRecording) {
            logger.i('Auto-stopping recording after max duration');
            stopRecording();
          }
        },
      );
    } catch (e) {
      logger.e('Error starting recording', e);
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (_controller == null || !_isRecording) {
      logger.w('Not recording');
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      _isRecording = false;
      logger.i('Recording stopped: ${file.path}');
      return file.path;
    } catch (e) {
      logger.e('Error stopping recording', e);
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_controller == null) return;

    _useFrontCamera = !_useFrontCamera;

    // Dispose current controller
    await _controller!.dispose();

    // Reinitialize with new camera
    await initialize(useFrontCamera: _useFrontCamera);
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _controller?.dispose();
    _controller = null;
    logger.d('Camera disposed');
  }
}
