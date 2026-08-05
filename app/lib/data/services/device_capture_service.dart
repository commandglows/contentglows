import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/capture_asset.dart';

class CaptureSupport {
  const CaptureSupport({
    required this.isSupported,
    required this.platformLabel,
    this.reason,
  });

  final bool isSupported;
  final String platformLabel;
  final String? reason;
}

class CaptureException implements Exception {
  CaptureException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class CaptureRecordingOptions {
  const CaptureRecordingOptions({
    this.audioMode = CaptureAudioMode.screenOnly,
    this.cameraMode = CaptureCameraMode.screenOnly,
    this.overlayConfig = const CaptureOverlayConfig(
      shape: CaptureOverlayShape.circle,
      size: CaptureOverlaySize.medium,
    ),
  });

  final CaptureAudioMode audioMode;
  final CaptureCameraMode cameraMode;
  final CaptureOverlayConfig overlayConfig;

  Map<String, Object?> toJson() {
    return {
      'audioMode': audioMode.name,
      'cameraMode': cameraMode.name,
      'overlayConfig': overlayConfig.toJson(),
    };
  }
}

abstract class DeviceCaptureClient {
  Stream<CaptureNativeEvent> get events;

  Future<CaptureSupport> checkSupport();

  Future<CaptureRecordingCapabilities> checkRecordingCapabilities();

  Future<CaptureAsset> takeScreenshot();

  Future<void> startRecording({
    bool includeMicrophone = false,
    CaptureRecordingOptions? options,
  });

  Future<void> stopRecording();

  Future<void> pauseRecording();

  Future<void> resumeRecording();

  Future<void> shareAsset(CaptureAsset asset);

  Future<bool> deleteAsset(CaptureAsset asset);
}

class DeviceCaptureService implements DeviceCaptureClient {
  DeviceCaptureService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    TargetPlatform? platformOverride,
    bool? isWebOverride,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('contentglows/device_capture'),
       _eventChannel =
           eventChannel ??
           const EventChannel('contentglows/device_capture_events'),
       _platformOverride = platformOverride,
       _isWebOverride = isWebOverride;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final TargetPlatform? _platformOverride;
  final bool? _isWebOverride;
  Stream<CaptureNativeEvent>? _events;

  bool get _isWebRuntime => _isWebOverride ?? kIsWeb;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  bool get _isAndroidRuntime =>
      !_isWebRuntime && _platform == TargetPlatform.android;

  @override
  Stream<CaptureNativeEvent> get events {
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) {
          return event is Map;
        })
        .map((event) {
          return CaptureNativeEvent.fromPlatformMap(
            Map<Object?, Object?>.from(event as Map),
          );
        });
  }

  @override
  Future<CaptureSupport> checkSupport() async {
    if (!_isAndroidRuntime) {
      return CaptureSupport(
        isSupported: false,
        platformLabel: _platform.name,
        reason: 'Android device capture is not available on this platform yet.',
      );
    }
    final supported =
        await _methodChannel.invokeMethod<bool>('isSupported') ?? false;
    return CaptureSupport(
      isSupported: supported,
      platformLabel: 'android',
      reason: supported
          ? null
          : 'This Android version cannot use screen capture.',
    );
  }

  @override
  Future<CaptureRecordingCapabilities> checkRecordingCapabilities() async {
    if (!_isAndroidRuntime) {
      return const CaptureRecordingCapabilities(
        isSupported: false,
        supportsScreenOnlyRecording: false,
        supportsMicrophoneAudio: false,
        supportsSystemAudio: false,
        supportsPauseResume: false,
        supportsFloatingControls: false,
        supportsComposedCameraModes: false,
        hasFrontCamera: false,
        hasRearCamera: false,
        supportsDualCamera: false,
        requiresFreshConsent: true,
        hasNotificationPermission: false,
        hasMicrophonePermission: false,
      );
    }
    try {
      final result = await _methodChannel.invokeMethod<Object?>(
        'queryRecordingCapabilities',
      );
      if (result is Map) {
        return CaptureRecordingCapabilities.fromJson(
          Map<String, dynamic>.from(Map<Object?, Object?>.from(result)),
        );
      }
    } on PlatformException catch (error) {
      throw CaptureException(
        error.code,
        error.message ?? 'Recorder capability check failed.',
      );
    }
    throw CaptureException(
      'invalid_capabilities',
      'Native recorder capabilities were unavailable.',
    );
  }

  @override
  Future<CaptureAsset> takeScreenshot() async {
    _throwIfUnsupported();
    try {
      final result = await _methodChannel.invokeMethod<Object?>(
        'takeScreenshot',
        const <String, Object?>{'includeMicrophone': false},
      );
      return _assetFromResult(result);
    } on PlatformException catch (error) {
      throw CaptureException(error.code, error.message ?? 'Screenshot failed.');
    }
  }

  @override
  Future<void> startRecording({
    bool includeMicrophone = false,
    CaptureRecordingOptions? options,
  }) async {
    _throwIfUnsupported();
    try {
      await _methodChannel.invokeMethod<Object?>('startRecording', {
        'includeMicrophone': includeMicrophone,
        'options': options?.toJson(),
      });
    } on PlatformException catch (error) {
      throw CaptureException(
        error.code,
        error.message ?? 'Screen recording failed to start.',
      );
    }
  }

  @override
  Future<void> stopRecording() async {
    _throwIfUnsupported();
    try {
      await _methodChannel.invokeMethod<Object?>('stopRecording');
    } on PlatformException catch (error) {
      throw CaptureException(
        error.code,
        error.message ?? 'Screen recording failed to stop.',
      );
    }
  }

  @override
  Future<void> pauseRecording() async {
    _throwIfUnsupported();
    try {
      await _methodChannel.invokeMethod<Object?>('pauseRecording');
    } on PlatformException catch (error) {
      throw CaptureException(
        error.code,
        error.message ?? 'Screen recording failed to pause.',
      );
    }
  }

  @override
  Future<void> resumeRecording() async {
    _throwIfUnsupported();
    try {
      await _methodChannel.invokeMethod<Object?>('resumeRecording');
    } on PlatformException catch (error) {
      throw CaptureException(
        error.code,
        error.message ?? 'Screen recording failed to resume.',
      );
    }
  }

  @override
  Future<void> shareAsset(CaptureAsset asset) async {
    _throwIfUnsupported();
    try {
      await _methodChannel.invokeMethod<Object?>('shareAsset', {
        'path': asset.path,
        'mimeType': asset.mimeType,
      });
    } on PlatformException catch (error) {
      throw CaptureException(error.code, error.message ?? 'Share failed.');
    }
  }

  @override
  Future<bool> deleteAsset(CaptureAsset asset) async {
    if (!_isAndroidRuntime) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('deleteAsset', {
            'path': asset.path,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw CaptureException(error.code, error.message ?? 'Delete failed.');
    }
  }

  CaptureAsset _assetFromResult(Object? result) {
    if (result is Map) {
      return CaptureAsset.fromPlatformMap(Map<Object?, Object?>.from(result));
    }
    throw CaptureException(
      'invalid_asset',
      'Native capture returned no asset.',
    );
  }

  void _throwIfUnsupported() {
    if (!_isAndroidRuntime) {
      throw CaptureException(
        'unsupported_platform',
        'Android device capture is not available on this platform yet.',
      );
    }
  }
}
