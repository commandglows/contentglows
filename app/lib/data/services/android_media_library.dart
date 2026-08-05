import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only bridge for media chosen from the device MediaStore library.
/// The returned URI remains local and is never sent to the backend.
class AndroidMediaLibrary {
  AndroidMediaLibrary({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'contentglows/android_media_library';
  final MethodChannel _channel;

  bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<AndroidMediaLibraryFile>> pickPhotoAndVideoFiles() async {
    if (!isAvailable) return const <AndroidMediaLibraryFile>[];
    final result = await _channel.invokeMethod<List<Object?>>('pickMedia');
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(AndroidMediaLibraryFile.fromChannelMap)
        .toList(growable: false);
  }

  /// True only after Android's system deletion confirmation succeeds.
  Future<bool> deleteFromDevice(String contentUri) async {
    if (!isAvailable) return false;
    return await _channel.invokeMethod<bool>('deleteMedia', <String, Object?>{
          'contentUri': contentUri,
        }) ??
        false;
  }
}

class AndroidMediaLibraryFile {
  const AndroidMediaLibraryFile({
    required this.contentUri,
    required this.cachePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String contentUri;
  final String cachePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  factory AndroidMediaLibraryFile.fromChannelMap(Map<Object?, Object?> map) {
    String requiredString(String key) {
      final value = map[key]?.toString().trim();
      if (value == null || value.isEmpty) {
        throw PlatformException(
          code: 'invalid_media_result',
          message: 'Android returned an incomplete media selection.',
        );
      }
      return value;
    }

    return AndroidMediaLibraryFile(
      contentUri: requiredString('contentUri'),
      cachePath: requiredString('cachePath'),
      fileName: requiredString('fileName'),
      mimeType: requiredString('mimeType'),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}
