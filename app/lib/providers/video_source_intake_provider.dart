import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/models/video_source_intake.dart';
import '../data/services/android_media_library.dart';
import '../data/services/api_service.dart';
import '../data/services/video_source_device_media_store.dart';
import '../core/shared_preferences_provider.dart';
import 'providers.dart';

class VideoSourceIntakeKey {
  const VideoSourceIntakeKey(this.projectId, this.contentId);

  final String projectId;
  final String contentId;

  @override
  bool operator ==(Object other) =>
      other is VideoSourceIntakeKey &&
      other.projectId == projectId &&
      other.contentId == contentId;

  @override
  int get hashCode => Object.hash(projectId, contentId);
}

class VideoSourceIntakeState {
  const VideoSourceIntakeState({
    this.folder,
    this.isLoading = false,
    this.isUploading = false,
    this.isMutating = false,
    this.isMarkingReady = false,
    this.isGenerating = false,
    this.isDeletingDeviceMedia = false,
    this.deletableSourceIds = const <String>{},
    this.uploadProgress = const <String, double>{},
    this.lastError,
    this.notice,
  });

  final VideoSourceFolder? folder;
  final bool isLoading;
  final bool isUploading;
  final bool isMutating;
  final bool isMarkingReady;
  final bool isGenerating;
  final bool isDeletingDeviceMedia;
  final Set<String> deletableSourceIds;
  final Map<String, double> uploadProgress;
  final String? lastError;
  final String? notice;

  bool get isBusy =>
      isLoading ||
      isUploading ||
      isMutating ||
      isMarkingReady ||
      isGenerating ||
      isDeletingDeviceMedia;
  bool get canFinalize => folder?.canFinalize == true && !isBusy;
  int get blockingSourceCount => folder?.blockingSourceCount ?? 0;

  VideoSourceIntakeState copyWith({
    VideoSourceFolder? folder,
    bool clearFolder = false,
    bool? isLoading,
    bool? isUploading,
    bool? isMutating,
    bool? isMarkingReady,
    bool? isGenerating,
    bool? isDeletingDeviceMedia,
    Set<String>? deletableSourceIds,
    Map<String, double>? uploadProgress,
    String? lastError,
    bool clearLastError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return VideoSourceIntakeState(
      folder: clearFolder ? null : (folder ?? this.folder),
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      isMutating: isMutating ?? this.isMutating,
      isMarkingReady: isMarkingReady ?? this.isMarkingReady,
      isGenerating: isGenerating ?? this.isGenerating,
      isDeletingDeviceMedia:
          isDeletingDeviceMedia ?? this.isDeletingDeviceMedia,
      deletableSourceIds: deletableSourceIds ?? this.deletableSourceIds,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

abstract class VideoSourceFilePicker {
  Future<List<VideoSourceUploadFile>> pickMediaFiles();
}

class FilePickerVideoSourceFilePicker implements VideoSourceFilePicker {
  @override
  Future<List<VideoSourceUploadFile>> pickMediaFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'mov',
        'm4v',
        'avi',
        'webm',
        'mkv',
        'mpeg',
        'mpg',
        '3gp',
        'mp3',
        'm4a',
        'wav',
      ],
      withData: kIsWeb,
      withReadStream: !kIsWeb,
    );
    if (result == null) return const <VideoSourceUploadFile>[];

    final now = DateTime.now().microsecondsSinceEpoch;
    return result.files.indexed
        .map((entry) {
          final index = entry.$1;
          final file = entry.$2;
          return VideoSourceUploadFile(
            clientFileId: 'picked-$now-$index',
            fileName: file.name,
            mimeType: _mimeTypeForFile(file.name),
            sizeBytes: file.size,
            bytes: file.bytes,
            path: file.path,
            readStream: file.readStream,
          );
        })
        .toList(growable: false);
  }
}

final videoSourceFilePickerProvider = Provider<VideoSourceFilePicker>((ref) {
  return FilePickerVideoSourceFilePicker();
});

final androidMediaLibraryProvider = Provider<AndroidMediaLibrary>((ref) {
  return AndroidMediaLibrary();
});

final videoSourceDeviceMediaStoreProvider =
    Provider<VideoSourceDeviceMediaStore>((ref) {
      return VideoSourceDeviceMediaStore(
        preferences: ref.watch(sharedPrefsProvider),
        mediaLibrary: ref.watch(androidMediaLibraryProvider),
      );
    });

final videoSourceIntakeProvider = StateNotifierProvider.autoDispose
    .family<
      VideoSourceIntakeController,
      VideoSourceIntakeState,
      VideoSourceIntakeKey
    >((ref, key) {
      return VideoSourceIntakeController(
        apiService: ref.watch(apiServiceProvider),
        deviceMediaStore: ref.watch(videoSourceDeviceMediaStoreProvider),
        key: key,
      );
    });

class VideoSourceIntakeController
    extends StateNotifier<VideoSourceIntakeState> {
  VideoSourceIntakeController({
    required ApiService apiService,
    VideoSourceDeviceMediaStore? deviceMediaStore,
    required this.key,
    bool autoLoad = true,
  }) : _apiService = apiService,
       _deviceMediaStore = deviceMediaStore,
       super(VideoSourceIntakeState(isLoading: autoLoad)) {
    if (autoLoad) unawaited(load());
  }

  final ApiService _apiService;
  final VideoSourceDeviceMediaStore? _deviceMediaStore;
  final VideoSourceIntakeKey key;
  final Map<int, String> _generationKeys = <int, String>{};
  final Map<String, String> _mutationKeys = <String, String>{};
  int _contextEpoch = 0;
  bool _disposed = false;

  Future<void> load() async {
    final epoch = _contextEpoch;
    _setState(
      state.copyWith(isLoading: true, clearLastError: true, clearNotice: true),
    );
    try {
      final folder = await _apiService.openVideoSourceFolder(
        projectId: key.projectId,
        contentId: key.contentId,
      );
      if (!_isCurrent(epoch)) return;
      final deletableSourceIds = await _deletableSourceIds(folder);
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: folder,
          isLoading: false,
          deletableSourceIds: deletableSourceIds,
        ),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isLoading: false,
          lastError: _friendlyError(error, action: 'load'),
        ),
      );
    }
  }

  Future<void> addFiles(
    List<VideoSourceUploadFile> files, {
    bool deleteUploadedFromDevice = false,
  }) async {
    final folder = state.folder;
    if (folder == null || files.isEmpty || state.isUploading) return;
    final epoch = _contextEpoch;
    var currentFolder = folder;
    var failures = 0;
    final uploadedSourceIds = <String>{};
    final progress = <String, double>{
      for (final file in files) file.clientFileId: 0,
    };
    _setState(
      state.copyWith(
        isUploading: true,
        uploadProgress: progress,
        clearLastError: true,
        clearNotice: true,
      ),
    );

    for (final file in files) {
      if (!_isCurrent(epoch)) return;
      try {
        final previousSourceIds = currentFolder.sources
            .map((source) => source.id)
            .toSet();
        currentFolder = await _apiService.uploadVideoSourceFile(
          projectId: key.projectId,
          contentId: key.contentId,
          folderId: currentFolder.id,
          revision: currentFolder.revision,
          file: file,
          onProgress: (sent, total) {
            if (!_isCurrent(epoch)) return;
            final next = Map<String, double>.from(state.uploadProgress);
            next[file.clientFileId] = total <= 0 ? 0 : sent / total;
            _setState(state.copyWith(uploadProgress: next));
          },
        );
        if (!_isCurrent(epoch)) return;
        final newSourceIds = currentFolder.sources
            .where((source) => !previousSourceIds.contains(source.id))
            .map((source) => source.id)
            .toSet();
        if (deleteUploadedFromDevice) {
          uploadedSourceIds.addAll(newSourceIds);
        }
        await _storeDeviceMediaMappingIfReady(
          file: file,
          previousSourceIds: previousSourceIds,
          folder: currentFolder,
        );
        if (!_isCurrent(epoch)) return;
        final next = Map<String, double>.from(state.uploadProgress);
        next[file.clientFileId] = 1;
        _setState(
          state.copyWith(
            folder: currentFolder,
            uploadProgress: next,
            deletableSourceIds: await _deletableSourceIds(currentFolder),
          ),
        );
      } catch (_) {
        failures++;
      }
    }
    if (!_isCurrent(epoch)) return;
    _setState(
      state.copyWith(
        folder: currentFolder,
        isUploading: false,
        uploadProgress: const <String, double>{},
        lastError: failures == 0
            ? null
            : '$failures file(s) could not be added. Retry from the source library.',
        clearLastError: failures == 0,
        notice: failures == 0 ? 'Files added to the source folder.' : null,
        clearNotice: failures != 0,
      ),
    );

    if (deleteUploadedFromDevice && _isCurrent(epoch)) {
      final deletableSourceIds = await _deletableSourceIds(currentFolder);
      final toDelete = uploadedSourceIds
          .where((sourceId) => deletableSourceIds.contains(sourceId))
          .toSet();
      if (toDelete.isNotEmpty) {
        await deleteSourcesFromDevice(sourceIds: toDelete, requireIdle: false);
      }
    }
  }

  Future<void> addText({required String text, String? label}) async {
    final value = text.trim();
    if (value.isEmpty || value.length > 100000) {
      _setState(
        state.copyWith(
          lastError: 'Text must contain between 1 and 100,000 characters.',
          clearNotice: true,
        ),
      );
      return;
    }
    await _mutate(
      action: 'add_text',
      run: (folder) => _apiService.addVideoSourceText(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        revision: folder.revision,
        text: value,
        idempotencyKey: _mutationKey('text', folder, value),
        label: label,
      ),
      notice: 'Text added to the source folder.',
    );
  }

  Future<void> addLink({required String url, String? label}) async {
    final value = url.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _setState(
        state.copyWith(
          lastError: 'Enter a valid public HTTP(S) link.',
          clearNotice: true,
        ),
      );
      return;
    }
    await _mutate(
      action: 'add_link',
      run: (folder) => _apiService.addVideoSourceLink(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        revision: folder.revision,
        url: value,
        idempotencyKey: _mutationKey('link', folder, value),
        label: label,
      ),
      notice: 'Link added to the source folder.',
    );
  }

  Future<void> removeSource(String sourceId) async {
    final folder = state.folder;
    if (folder == null || state.isBusy) return;
    final epoch = _contextEpoch;
    _setState(
      state.copyWith(isMutating: true, clearLastError: true, clearNotice: true),
    );
    try {
      final updated = await _apiService.removeVideoSource(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        sourceId: sourceId,
        revision: folder.revision,
      );
      if (!_isCurrent(epoch)) return;
      await _deviceMediaStore?.remove(sourceId);
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: updated,
          isMutating: false,
          deletableSourceIds: await _deletableSourceIds(updated),
          notice: 'Source removed.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isMutating: false,
          lastError: _friendlyError(error, action: 'remove'),
        ),
      );
    }
  }

  Future<void> deleteFromDevice(VideoSource source) async {
    if (source.status != VideoSourceStatus.ready ||
        !state.deletableSourceIds.contains(source.id) ||
        state.isBusy ||
        state.isDeletingDeviceMedia) {
      return;
    }
    await deleteSourcesFromDevice(sourceIds: {source.id}, requireIdle: true);
  }

  Future<void> deleteSourcesFromDevice({
    required Set<String> sourceIds,
    bool requireIdle = true,
  }) async {
    final folder = state.folder;
    final candidateIds = Set<String>.from(sourceIds);
    if (folder == null || candidateIds.isEmpty || state.isDeletingDeviceMedia) {
      return;
    }

    final deletableIds = folder.activeSources
        .where(
          (source) =>
              candidateIds.contains(source.id) &&
              source.status == VideoSourceStatus.ready &&
              state.deletableSourceIds.contains(source.id),
        )
        .map((source) => source.id)
        .toSet();
    if (deletableIds.isEmpty) return;
    if (requireIdle && state.isBusy) return;

    final epoch = _contextEpoch;
    _setState(
      state.copyWith(
        isDeletingDeviceMedia: true,
        clearLastError: true,
        clearNotice: true,
      ),
    );
    try {
      var deletedCount = 0;
      var cancelledCount = 0;
      final nextIds = Set<String>.from(state.deletableSourceIds);
      for (final sourceId in deletableIds) {
        if (!_isCurrent(epoch)) return;
        final deleted =
            await _deviceMediaStore?.deleteFromDevice(sourceId) ?? false;
        if (!_isCurrent(epoch)) return;
        if (deleted) {
          deletedCount++;
          nextIds.remove(sourceId);
        } else {
          cancelledCount++;
        }
      }
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isDeletingDeviceMedia: false,
          deletableSourceIds: nextIds,
          notice: _deleteFromDeviceNotice(
            deletedCount: deletedCount,
            cancelledCount: cancelledCount,
            total: deletableIds.length,
          ),
        ),
      );
    } catch (_) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isDeletingDeviceMedia: false,
          lastError: 'The media could not be deleted from this device.',
        ),
      );
    }
  }

  String _deleteFromDeviceNotice({
    required int deletedCount,
    required int cancelledCount,
    required int total,
  }) {
    if (deletedCount == 0 && cancelledCount == 0) {
      return 'Device deletion skipped.';
    }
    if (deletedCount > 0 && cancelledCount == 0) {
      return total == 1
          ? 'Media deleted from this device.'
          : '$deletedCount media files deleted from this device.';
    }
    if (deletedCount > 0 && cancelledCount > 0) {
      return '$deletedCount media file(s) deleted from this device. '
          '$cancelledCount deletion request(s) were cancelled.';
    }
    return 'Device deletion was cancelled.';
  }

  Future<void> retrySource(String sourceId) async {
    await _mutate(
      action: 'retry',
      run: (folder) => _apiService.retryVideoSource(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        sourceId: sourceId,
        revision: folder.revision,
      ),
      notice: 'Source retry started.',
    );
  }

  Future<void> replaceSource(
    String sourceId,
    VideoSourceUploadFile file,
  ) async {
    final folder = state.folder;
    if (folder == null || state.isUploading) return;
    final epoch = _contextEpoch;
    _setState(
      state.copyWith(
        isUploading: true,
        uploadProgress: {file.clientFileId: 0},
        clearLastError: true,
        clearNotice: true,
      ),
    );
    try {
      final previousSourceIds = folder.sources
          .map((source) => source.id)
          .toSet();
      final updated = await _apiService.uploadVideoSourceFile(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        revision: folder.revision,
        file: file,
        replaceSourceId: sourceId,
        onProgress: (sent, total) {
          if (!_isCurrent(epoch)) return;
          _setState(
            state.copyWith(
              uploadProgress: {
                file.clientFileId: total <= 0 ? 0 : sent / total,
              },
            ),
          );
        },
      );
      if (!_isCurrent(epoch)) return;
      await _deviceMediaStore?.remove(sourceId);
      await _storeDeviceMediaMappingIfReady(
        file: file,
        previousSourceIds: previousSourceIds,
        folder: updated,
      );
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: updated,
          isUploading: false,
          uploadProgress: const <String, double>{},
          deletableSourceIds: await _deletableSourceIds(updated),
          notice: 'Source replaced.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isUploading: false,
          uploadProgress: const <String, double>{},
          lastError: _friendlyError(error, action: 'replace'),
        ),
      );
    }
  }

  Future<void> markSourcesReady() async {
    final folder = state.folder;
    if (folder == null || !folder.canFinalize || state.isBusy) return;
    final epoch = _contextEpoch;
    _setState(
      state.copyWith(
        isMarkingReady: true,
        clearLastError: true,
        clearNotice: true,
      ),
    );
    try {
      final updated = await _apiService.markVideoSourcesReady(
        projectId: key.projectId,
        contentId: key.contentId,
        folderId: folder.id,
        revision: folder.revision,
      );
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: updated,
          isMarkingReady: false,
          notice: 'Sources saved as ready. No video was generated.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isMarkingReady: false,
          lastError: _friendlyError(error, action: 'ready'),
        ),
      );
    }
  }

  Future<void> generateVideo() async {
    final folder = state.folder;
    if (folder == null || !folder.canFinalize || state.isBusy) return;
    final epoch = _contextEpoch;
    final keyValue = _generationKeys.putIfAbsent(
      folder.revision,
      () => 'video-source-generate-${folder.id}-r${folder.revision}',
    );
    _setState(
      state.copyWith(
        isGenerating: true,
        folder: folder.copyWith(
          enqueueStatus: VideoSourceEnqueueStatus.enqueuePending,
        ),
        clearLastError: true,
        clearNotice: true,
      ),
    );
    try {
      final result = await _apiService.generateVideoFromSources(
        projectId: key.projectId,
        contentId: key.contentId,
        command: VideoSourceGenerateCommand(
          folderId: folder.id,
          revision: folder.revision,
          idempotencyKey: keyValue,
        ),
      );
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: result.folder,
          isGenerating: false,
          notice: 'Video generation request accepted.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          folder: state.folder?.copyWith(
            enqueueStatus: VideoSourceEnqueueStatus.enqueueFailed,
          ),
          isGenerating: false,
          lastError: _friendlyError(error, action: 'generate'),
        ),
      );
    }
  }

  Future<void> _mutate({
    required String action,
    required Future<VideoSourceFolder> Function(VideoSourceFolder folder) run,
    required String notice,
  }) async {
    final folder = state.folder;
    if (folder == null || state.isBusy) return;
    final epoch = _contextEpoch;
    _setState(
      state.copyWith(isMutating: true, clearLastError: true, clearNotice: true),
    );
    try {
      final updated = await run(folder);
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(folder: updated, isMutating: false, notice: notice),
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _setState(
        state.copyWith(
          isMutating: false,
          lastError: _friendlyError(error, action: action),
        ),
      );
    }
  }

  String _mutationKey(String action, VideoSourceFolder folder, String value) {
    final signature = '$action:${folder.id}:${folder.revision}:$value';
    return _mutationKeys.putIfAbsent(
      signature,
      () => 'video-source-$action-${sha256.convert(utf8.encode(signature))}',
    );
  }

  Future<void> _storeDeviceMediaMappingIfReady({
    required VideoSourceUploadFile file,
    required Set<String> previousSourceIds,
    required VideoSourceFolder folder,
  }) async {
    final contentUri = file.deviceMediaUri;
    if (contentUri == null || contentUri.isEmpty) return;
    for (final source in folder.activeSources) {
      if (!previousSourceIds.contains(source.id) &&
          source.status == VideoSourceStatus.ready) {
        await _deviceMediaStore?.save(
          sourceId: source.id,
          contentUri: contentUri,
        );
        return;
      }
    }
  }

  Future<Set<String>> _deletableSourceIds(VideoSourceFolder folder) {
    final deviceMediaStore = _deviceMediaStore;
    if (deviceMediaStore == null) return Future.value(const <String>{});
    return deviceMediaStore.sourceIdsWithMappings(
      folder.activeSources
          .where((source) => source.status == VideoSourceStatus.ready)
          .map((source) => source.id),
    );
  }

  void clearMessages() {
    _setState(state.copyWith(clearLastError: true, clearNotice: true));
  }

  void invalidateContext() {
    _contextEpoch++;
    _setState(
      state.copyWith(
        isLoading: false,
        isUploading: false,
        isMutating: false,
        isMarkingReady: false,
        isGenerating: false,
        isDeletingDeviceMedia: false,
        uploadProgress: const <String, double>{},
        deletableSourceIds: const <String>{},
        clearFolder: true,
        clearLastError: true,
        clearNotice: true,
      ),
    );
  }

  @visibleForTesting
  void replaceFolderForTest(VideoSourceFolder folder) {
    _setState(state.copyWith(folder: folder, isLoading: false));
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _contextEpoch;

  void _setState(VideoSourceIntakeState next) {
    if (!_disposed) state = next;
  }

  String _friendlyError(Object error, {required String action}) {
    if (error is ApiException) {
      if (error.isOffline) {
        return 'The source folder needs an internet connection. Retry when the workspace is online.';
      }
      return switch (error.code) {
        'revision_conflict' || 'stale_revision' =>
          'The source folder changed. Refresh it before trying again.',
        'unsafe_url' => 'This link cannot be used safely.',
        'file_too_large' => 'This file exceeds the supported size.',
        'unsupported_file_type' ||
        'unsupported_media_type' => 'This file type is not supported.',
        'source_not_ready' ||
        'sources_not_ready' => 'Correct the blocked sources before continuing.',
        _ =>
          action == 'generate'
              ? 'The sources remain ready, but generation could not be queued. Retry safely.'
              : 'The source action could not be completed. Retry safely.',
      };
    }
    return action == 'generate'
        ? 'The sources remain ready, but generation could not be queued. Retry safely.'
        : 'The source action could not be completed. Retry safely.';
  }

  @override
  void dispose() {
    _disposed = true;
    _contextEpoch++;
    super.dispose();
  }
}

String _mimeTypeForFile(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    _ => 'application/octet-stream',
  };
}
