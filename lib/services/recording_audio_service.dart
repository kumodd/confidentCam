import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import '../core/utils/logger.dart';

/// Represents an available microphone / audio input device reported by the OS.
class AudioInputDevice extends Equatable {
  final int id;
  final String name;
  final int type;
  final String typeLabel;
  final bool isExternal;
  final bool isSelected;

  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.isExternal,
    this.isSelected = false,
  });

  factory AudioInputDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioInputDevice(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? 'Microphone',
      type: (map['type'] as num?)?.toInt() ?? 0,
      typeLabel: (map['typeLabel'] as String?) ?? 'Microphone',
      isExternal: map['isExternal'] == true,
      isSelected: map['isSelected'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, type, typeLabel, isExternal, isSelected];
}

/// Bridges Flutter with Android's native [RecordingAudioManager] for:
/// 1. Listing & hot-plug monitoring available microphones (built-in, wired,
///    USB-C, Bluetooth).
/// 2. Selecting the user's preferred audio input device before recording.
/// 3. Suppressing notification sounds, ringtones, and system alerts during
///    recording (exclusive audio focus + stream muting + optional DND).
class RecordingAudioService {
  static const MethodChannel _channel = MethodChannel(
    'com.confidentcam.confident_cam/recording_audio',
  );

  final StreamController<List<AudioInputDevice>> _devicesController =
      StreamController<List<AudioInputDevice>>.broadcast();
  bool _handlerInstalled = false;

  RecordingAudioService() {
    _installHandler();
  }

  void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onInputDevicesChanged') {
        final raw = call.arguments;
        if (raw is List) {
          final parsed = raw
              .whereType<Map>()
              .map(AudioInputDevice.fromMap)
              .toList();
          if (!_devicesController.isClosed) {
            _devicesController.add(parsed);
          }
        }
      }
    });
  }

  /// Emits updated input devices whenever an external mic is plugged/unplugged.
  Stream<List<AudioInputDevice>> get onInputDevicesChanged =>
      _devicesController.stream;

  /// Lists all selectable microphones currently connected to the device.
  Future<List<AudioInputDevice>> listInputDevices() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listInputDevices');
      if (raw == null) return const [];
      return raw.whereType<Map>().map(AudioInputDevice.fromMap).toList();
    } on MissingPluginException {
      return const [];
    } catch (e) {
      logger.w('listInputDevices warning: $e');
      return const [];
    }
  }

  /// Selects a specific microphone by native device [deviceId], or `null` for
  /// automatic system default.
  Future<bool> setPreferredInputDevice(int? deviceId) async {
    try {
      final res = await _channel.invokeMethod<bool>('setPreferredInputDevice', {
        'deviceId': deviceId,
      });
      return res ?? false;
    } on MissingPluginException {
      return true;
    } catch (e) {
      logger.w('setPreferredInputDevice warning: $e');
      return false;
    }
  }

  /// Activates notification & system alert suppression while recording.
  Future<void> beginRecordingAudioGuard({
    bool silenceNotifications = true,
  }) async {
    try {
      await _channel.invokeMethod('beginRecordingAudioGuard', {
        'silenceNotifications': silenceNotifications,
      });
    } on MissingPluginException {
      // Non-Android / unit tests
    } catch (e) {
      logger.w('beginRecordingAudioGuard warning: $e');
    }
  }

  /// Restores notification streams, DND state, and audio focus after recording.
  Future<void> endRecordingAudioGuard() async {
    try {
      await _channel.invokeMethod('endRecordingAudioGuard');
    } on MissingPluginException {
      // Non-Android / unit tests
    } catch (e) {
      logger.w('endRecordingAudioGuard warning: $e');
    }
  }

  /// Returns whether optional Do-Not-Disturb policy access has been granted.
  Future<bool> hasDndPolicyAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasDndPolicyAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's Do-Not-Disturb access settings screen so users who want
  /// system-wide DND silence during recording can grant it in one tap.
  Future<bool> openDndPolicySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openDndPolicySettings') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _devicesController.close();
  }
}
