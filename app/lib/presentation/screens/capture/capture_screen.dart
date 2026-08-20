import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/capture_asset.dart';
import '../../../data/models/capture_content_link.dart';
import '../../../data/models/content_item.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/capture_local_store.dart';
import '../../../data/services/device_capture_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../../providers/providers.dart';
import 'capture_asset_preview.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.captureService, this.localStore});

  final DeviceCaptureClient? captureService;
  final CaptureLocalStore? localStore;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late final DeviceCaptureClient _captureService;
  CaptureLocalStore? _store;
  CaptureSupport? _support;
  StreamSubscription<CaptureNativeEvent>? _eventSubscription;
  List<CaptureAsset> _assets = const <CaptureAsset>[];
  List<CaptureContentLink> _links = const <CaptureContentLink>[];
  bool _loading = true;
  bool _busy = false;
  bool _recording = false;
  bool _paused = false;
  bool _microphoneEnabled = false;
  CaptureRecordingCapabilities? _recordingCapabilities;
  CaptureAudioMode _selectedAudioMode = CaptureAudioMode.screenOnly;
  CaptureCameraMode _selectedCameraMode = CaptureCameraMode.screenOnly;
  int _durationMs = 0;
  int _maxDurationMs = 300000;
  String? _message;
  String? _noticeMessage;

  @override
  void initState() {
    super.initState();
    _captureService = widget.captureService ?? DeviceCaptureService();
    _store = widget.localStore;
    _eventSubscription = _captureService.events.listen(_handleCaptureEvent);
    _load();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final support = await _captureService.checkSupport();
    CaptureRecordingCapabilities? recordingCapabilities;
    if (support.isSupported) {
      try {
        recordingCapabilities = await _captureService
            .checkRecordingCapabilities();
      } catch (_) {
        recordingCapabilities = null;
      }
    }
    CaptureLocalStore? store = _store;
    if (store == null) {
      final prefs = await SharedPreferences.getInstance();
      store = CaptureLocalStore(prefs);
    }
    if (!mounted) return;
    setState(() {
      _support = support;
      _recordingCapabilities = recordingCapabilities;
      _store = store;
      _assets = store!.loadRecentAssets();
      _links = store.loadContentLinks();
      _loading = false;
    });
  }

  Future<void> _takeScreenshot() async {
    setState(() {
      _busy = true;
      _message = context.tr('Waiting for Android screen capture consent.');
      _noticeMessage = null;
    });
    try {
      final asset = await _captureService.takeScreenshot();
      await _addAsset(asset);
      if (!mounted) return;
      setState(() {
        _message = context.tr('Screenshot saved locally.');
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startRecording() async {
    final options = CaptureRecordingOptions(
      audioMode: _selectedAudioMode,
      cameraMode: _selectedCameraMode,
    );
    setState(() {
      _busy = true;
      _message = context.tr('Waiting for Android screen capture consent.');
      _noticeMessage = null;
    });
    try {
      await _captureService.startRecording(
        includeMicrophone: _audioModeNeedsMicrophone(options.audioMode),
        options: options,
      );
    } catch (error) {
      _showError(error);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _busy = true;
      _message = context.tr('Finalizing screen recording.');
    });
    try {
      await _captureService.stopRecording();
    } catch (error) {
      _showError(error);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pauseRecording() async {
    setState(() {
      _busy = true;
      _message = context.tr('Pausing screen recording.');
    });
    try {
      await _captureService.pauseRecording();
    } catch (error) {
      _showError(error);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resumeRecording() async {
    setState(() {
      _busy = true;
      _message = context.tr('Resuming screen recording.');
    });
    try {
      await _captureService.resumeRecording();
    } catch (error) {
      _showError(error);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _shareAsset(CaptureAsset asset) async {
    try {
      await _captureService.shareAsset(asset);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _discardAsset(CaptureAsset asset) async {
    try {
      await _captureService.deleteAsset(asset);
      final next = await _store!.removeAsset(asset.id);
      if (!mounted) return;
      setState(() {
        _assets = next;
        _links = _store!.loadContentLinks();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addAsset(CaptureAsset asset) async {
    final next = await _store!.addAsset(asset);
    if (!mounted) return;
    setState(() => _assets = next);
  }

  Future<void> _createContentFromAsset(CaptureAsset asset) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _message = context.tr(
          'Choose an active project before creating content.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = context.tr('Creating content from capture.');
      _noticeMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final item = await api.createContentDraftFromCapture(
        asset: asset,
        projectId: projectId,
      );
      await _store!.linkAssetToContent(
        CaptureContentLink(
          assetId: asset.id,
          contentId: item.id,
          projectId: projectId,
          syncState: CaptureContentLinkSyncState.backendLinked,
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(pendingContentProvider);
      if (!mounted) return;
      setState(() {
        _links = _store!.loadContentLinks();
        _busy = false;
        _message = context.tr('Content created from capture.');
      });
      context.go('/editor/${item.id}');
    } catch (error) {
      _showError(error);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _attachAssetToContent(CaptureAsset asset) async {
    final projectId = ref.read(activeProjectIdProvider);
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _message = context.tr(
          'Choose an active project before linking assets.',
        );
      });
      return;
    }

    final pending =
        ref.read(pendingContentProvider).value ?? const <ContentItem>[];
    final selected = await showModalBottomSheet<ContentItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ContentPickerSheet(items: pending),
    );
    if (selected == null) return;

    setState(() {
      _busy = true;
      _message = context.tr('Linking capture to content.');
      _noticeMessage = null;
    });

    var syncState = CaptureContentLinkSyncState.backendLinked;
    String? backendAssetId;
    try {
      final response = await ref
          .read(apiServiceProvider)
          .attachCaptureAssetToContent(contentId: selected.id, asset: asset);
      backendAssetId = response?['id']?.toString();
    } catch (error) {
      if (error is ApiException && error.isOffline) {
        syncState = CaptureContentLinkSyncState.pendingBackend;
        if (mounted) {
          _noticeMessage = context.tr(
            'Backend link is unavailable. The local link stays on this device.',
          );
        }
      } else {
        _showError(error);
        if (mounted) setState(() => _busy = false);
        return;
      }
    }

    await _store!.linkAssetToContent(
      CaptureContentLink(
        assetId: asset.id,
        contentId: selected.id,
        projectId: projectId,
        backendAssetId: backendAssetId,
        syncState: syncState,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _links = _store!.loadContentLinks();
      _busy = false;
      _message = context.tr('Capture linked to content.');
    });
  }

  void _handleCaptureEvent(CaptureNativeEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case CaptureEventType.recording:
        setState(() {
          _recording = true;
          _paused = false;
          _busy = false;
          _durationMs = event.durationMs ?? 0;
          _maxDurationMs = event.maxDurationMs ?? _maxDurationMs;
          _microphoneEnabled = event.microphoneEnabled ?? _microphoneEnabled;
          _message = context.tr('Screen recording is active.');
          if (event.effectiveAudioMode != null) {
            _selectedAudioMode = event.effectiveAudioMode!;
          }
          if (event.effectiveCameraMode != null) {
            _selectedCameraMode = event.effectiveCameraMode!;
          }
        });
        break;
      case CaptureEventType.progress:
        setState(() {
          _durationMs = event.durationMs ?? _durationMs;
          _maxDurationMs = event.maxDurationMs ?? _maxDurationMs;
          _paused = event.isPaused ?? _paused;
          _message = event.message ?? _message;
          if (event.degraded && event.message != null) {
            _noticeMessage = event.message;
          }
        });
        break;
      case CaptureEventType.state:
        setState(() {
          _busy = false;
          switch (event.state) {
            case CaptureRecorderState.starting:
              _recording = true;
              _paused = false;
              _message = context.tr('Starting screen recording.');
              break;
            case CaptureRecorderState.recording:
              _recording = true;
              _paused = false;
              _message = context.tr('Screen recording is active.');
              break;
            case CaptureRecorderState.paused:
              _recording = true;
              _paused = true;
              _message = context.tr('Screen recording is paused.');
              break;
            case CaptureRecorderState.stopping:
              _recording = true;
              _paused = false;
              _message = context.tr('Finalizing screen recording.');
              break;
            case CaptureRecorderState.failed:
              _recording = false;
              _paused = false;
              _message =
                  event.message ??
                  context.tr('Capture could not complete. You can try again.');
              break;
            case CaptureRecorderState.idle:
              _recording = false;
              _paused = false;
              break;
            case null:
              break;
          }
          if (event.degraded && event.message != null) {
            _noticeMessage = event.message;
          }
        });
        break;
      case CaptureEventType.completed:
        final asset = event.asset;
        setState(() {
          _recording = false;
          _paused = false;
          _busy = false;
          _durationMs = 0;
          _message = context.tr('Capture saved locally.');
          _noticeMessage = null;
        });
        if (asset != null) {
          unawaited(_addAsset(asset));
        }
        break;
      case CaptureEventType.failed:
        setState(() {
          _busy = false;
          _recording = false;
          _paused = false;
          if (event.recoverable) {
            _noticeMessage = event.message;
          } else {
            _message =
                event.message ??
                context.tr('Capture could not complete. You can try again.');
          }
        });
        break;
      case CaptureEventType.canceled:
        setState(() {
          _busy = false;
          _recording = false;
          _paused = false;
          _message =
              event.message ??
              context.tr(
                'Screen capture was canceled before a file was saved.',
              );
          _noticeMessage = null;
        });
        break;
      case CaptureEventType.notice:
        setState(() {
          _noticeMessage = event.message;
        });
        break;
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _message = error is CaptureException
          ? error.message
          : context.tr('Capture could not complete. You can try again.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final support = _support;
    final contentItems =
        ref.watch(pendingContentProvider).value ?? const <ContentItem>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Capture'))),
      body: _loading || support == null
          ? const Center(child: CircularProgressIndicator())
          : support.isSupported
          ? _SupportedCaptureView(
              assets: _assets,
              busy: _busy,
              recordingCapabilities: _recordingCapabilities,
              recording: _recording,
              microphoneEnabled: _microphoneEnabled,
              selectedAudioMode: _selectedAudioMode,
              selectedCameraMode: _selectedCameraMode,
              durationMs: _durationMs,
              maxDurationMs: _maxDurationMs,
              message: _message,
              noticeMessage: _noticeMessage,
              paused: _paused,
              onToggleMicrophone: _recording || _busy
                  ? null
                  : (value) => setState(() {
                      _microphoneEnabled = value;
                      _selectedAudioMode = value
                          ? CaptureAudioMode.microphone
                          : CaptureAudioMode.screenOnly;
                    }),
              onSelectAudioMode: _recording || _busy
                  ? null
                  : (value) => setState(() {
                      _selectedAudioMode = value;
                      _microphoneEnabled = _audioModeNeedsMicrophone(value);
                    }),
              onSelectCameraMode: _recording || _busy
                  ? null
                  : (value) => setState(() => _selectedCameraMode = value),
              onScreenshot: _busy || _recording ? null : _takeScreenshot,
              onRecord: _busy || _recording ? null : _startRecording,
              onPause:
                  _recording &&
                      !_paused &&
                      (_recordingCapabilities?.supportsPauseResume ?? false)
                  ? _pauseRecording
                  : null,
              onResume: _recording && _paused ? _resumeRecording : null,
              onStop: _recording ? _stopRecording : null,
              onShare: _shareAsset,
              onDiscard: _discardAsset,
              onCreateContent: _busy ? null : _createContentFromAsset,
              onAttachContent: _busy ? null : _attachAssetToContent,
              links: _links,
              contentItems: contentItems,
            )
          : _UnsupportedCaptureView(support: support),
    );
  }
}

bool _audioModeNeedsMicrophone(CaptureAudioMode mode) {
  return mode == CaptureAudioMode.microphone ||
      mode == CaptureAudioMode.microphoneAndSystemAudio;
}

class _UnsupportedCaptureView extends StatelessWidget {
  const _UnsupportedCaptureView({required this.support});

  final CaptureSupport support;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phonelink_off_rounded,
                size: AppSizes.iconDisplay,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr('Android capture only'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                support.reason ??
                    context.tr(
                      'Device screen capture is available only in the Android app for now.',
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportedCaptureView extends StatelessWidget {
  const _SupportedCaptureView({
    required this.assets,
    required this.busy,
    required this.recordingCapabilities,
    required this.recording,
    required this.microphoneEnabled,
    required this.selectedAudioMode,
    required this.selectedCameraMode,
    required this.durationMs,
    required this.maxDurationMs,
    required this.message,
    required this.noticeMessage,
    required this.paused,
    required this.onToggleMicrophone,
    required this.onSelectAudioMode,
    required this.onSelectCameraMode,
    required this.onScreenshot,
    required this.onRecord,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onShare,
    required this.onDiscard,
    required this.onCreateContent,
    required this.onAttachContent,
    required this.links,
    required this.contentItems,
  });

  final List<CaptureAsset> assets;
  final bool busy;
  final CaptureRecordingCapabilities? recordingCapabilities;
  final bool recording;
  final bool microphoneEnabled;
  final CaptureAudioMode selectedAudioMode;
  final CaptureCameraMode selectedCameraMode;
  final int durationMs;
  final int maxDurationMs;
  final String? message;
  final String? noticeMessage;
  final bool paused;
  final ValueChanged<bool>? onToggleMicrophone;
  final ValueChanged<CaptureAudioMode>? onSelectAudioMode;
  final ValueChanged<CaptureCameraMode>? onSelectCameraMode;
  final VoidCallback? onScreenshot;
  final VoidCallback? onRecord;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final ValueChanged<CaptureAsset> onShare;
  final ValueChanged<CaptureAsset> onDiscard;
  final ValueChanged<CaptureAsset>? onCreateContent;
  final ValueChanged<CaptureAsset>? onAttachContent;
  final List<CaptureContentLink> links;
  final List<ContentItem> contentItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context);
    final capabilities = recordingCapabilities;
    return ListView(
      padding: AppSpacing.card(context),
      children: [
        if (capabilities != null) ...[
          Container(
            padding: AppSpacing.card(context),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Recorder profile'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  _capabilitySummary(context, capabilities),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('Audio mode'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _ModeChip<CaptureAudioMode>(
                      label: context.tr('Screen only'),
                      value: CaptureAudioMode.screenOnly,
                      groupValue: selectedAudioMode,
                      enabled: true,
                      onSelected: onSelectAudioMode,
                    ),
                    _ModeChip<CaptureAudioMode>(
                      label: context.tr('Mic'),
                      value: CaptureAudioMode.microphone,
                      groupValue: selectedAudioMode,
                      enabled: capabilities.supportsMicrophoneAudio,
                      onSelected: onSelectAudioMode,
                    ),
                    _ModeChip<CaptureAudioMode>(
                      label: context.tr('System audio'),
                      value: CaptureAudioMode.systemAudio,
                      groupValue: selectedAudioMode,
                      enabled: capabilities.supportsSystemAudio,
                      onSelected: onSelectAudioMode,
                    ),
                    _ModeChip<CaptureAudioMode>(
                      label: context.tr('Mic + system'),
                      value: CaptureAudioMode.microphoneAndSystemAudio,
                      groupValue: selectedAudioMode,
                      enabled:
                          capabilities.supportsSystemAudio &&
                          capabilities.supportsMicrophoneAudio,
                      onSelected: onSelectAudioMode,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('Camera mode'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _ModeChip<CaptureCameraMode>(
                      label: context.tr('Screen only'),
                      value: CaptureCameraMode.screenOnly,
                      groupValue: selectedCameraMode,
                      enabled: true,
                      onSelected: onSelectCameraMode,
                    ),
                    _ModeChip<CaptureCameraMode>(
                      label: context.tr('Front'),
                      value: CaptureCameraMode.frontCamera,
                      groupValue: selectedCameraMode,
                      enabled:
                          capabilities.supportsComposedCameraModes &&
                          capabilities.hasFrontCamera,
                      onSelected: onSelectCameraMode,
                    ),
                    _ModeChip<CaptureCameraMode>(
                      label: context.tr('Rear'),
                      value: CaptureCameraMode.rearCamera,
                      groupValue: selectedCameraMode,
                      enabled:
                          capabilities.supportsComposedCameraModes &&
                          capabilities.hasRearCamera,
                      onSelected: onSelectCameraMode,
                    ),
                    _ModeChip<CaptureCameraMode>(
                      label: context.tr('Dual'),
                      value: CaptureCameraMode.dualCamera,
                      groupValue: selectedCameraMode,
                      enabled: capabilities.supportsDualCamera,
                      onSelected: onSelectCameraMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onScreenshot,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(context.tr('Screenshot')),
            ),
            FilledButton.tonalIcon(
              onPressed: onRecord,
              icon: const Icon(Icons.fiber_manual_record_rounded),
              label: Text(context.tr('Record')),
            ),
            if (recording)
              OutlinedButton.icon(
                onPressed: paused ? onResume : onPause,
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(context.tr(paused ? 'Resume' : 'Pause')),
              ),
            if (recording)
              OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
                label: Text(context.tr('Stop')),
              ),
            FilterChip(
              selected: microphoneEnabled,
              onSelected: onToggleMicrophone,
              avatar: Icon(
                microphoneEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: AppSizes.iconLarge,
              ),
              label: Text(context.tr('Mic')),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        if (busy) const LinearProgressIndicator(),
        if (recording) ...[
          SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: maxDurationMs <= 0 ? null : durationMs / maxDurationMs,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '${_formatDuration(durationMs)} / ${_formatDuration(maxDurationMs)}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (message != null) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (noticeMessage != null) ...[
          SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: AppSizes.iconLarge,
                color: theme.colorScheme.tertiary,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  noticeMessage!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: AppSpacing.xl),
        Text(
          context.tr('Local captures'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        if (assets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.wide),
            child: Center(
              child: Text(
                context.tr('No local captures yet.'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final asset in assets)
            _CaptureAssetCard(
              asset: asset,
              link: _linkForAsset(asset.id),
              linkedContent: _contentForAsset(asset.id),
              onShare: () => onShare(asset),
              onDiscard: () => onDiscard(asset),
              onCreateContent: onCreateContent == null
                  ? null
                  : () => onCreateContent!(asset),
              onAttachContent: onAttachContent == null
                  ? null
                  : () => onAttachContent!(asset),
            ),
      ],
    );
  }

  String _capabilitySummary(
    BuildContext context,
    CaptureRecordingCapabilities capabilities,
  ) {
    final segments = <String>[
      capabilities.hasFrontCamera
          ? context.tr('Front camera detected')
          : context.tr('No front camera detected'),
      capabilities.hasRearCamera
          ? context.tr('Rear camera detected')
          : context.tr('No rear camera detected'),
      capabilities.supportsDualCamera
          ? context.tr('Dual camera is available now')
          : capabilities.dualCameraHardwareHint
          ? context.tr(
              'Dual camera hardware was detected but is not enabled yet',
            )
          : context.tr('Dual camera is unavailable'),
      capabilities.supportsSystemAudio
          ? context.tr('System audio is available')
          : context.tr('System audio is unavailable in this build'),
    ];
    return segments.join(' • ');
  }

  CaptureContentLink? _linkForAsset(String assetId) {
    for (final link in links) {
      if (link.assetId == assetId) return link;
    }
    return null;
  }

  ContentItem? _contentForAsset(String assetId) {
    final link = _linkForAsset(assetId);
    if (link == null) return null;
    for (final item in contentItems) {
      if (item.id == link.contentId) return item;
    }
    return null;
  }
}

class _ModeChip<T> extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final T value;
  final T groupValue;
  final bool enabled;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: value == groupValue,
      onSelected: enabled && onSelected != null
          ? (_) => onSelected!(value)
          : null,
    );
  }
}

class _CaptureAssetCard extends StatelessWidget {
  const _CaptureAssetCard({
    required this.asset,
    required this.link,
    required this.linkedContent,
    required this.onShare,
    required this.onDiscard,
    required this.onCreateContent,
    required this.onAttachContent,
  });

  final CaptureAsset asset;
  final CaptureContentLink? link;
  final ContentItem? linkedContent;
  final VoidCallback onShare;
  final VoidCallback onDiscard;
  final VoidCallback? onCreateContent;
  final VoidCallback? onAttachContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: buildCaptureAssetPreview(asset),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.isScreenshot
                        ? context.tr('Screenshot')
                        : context.tr('Recording'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      '${asset.width}x${asset.height}',
                      _formatBytes(asset.byteSize),
                      if (asset.durationMs != null)
                        _formatDuration(asset.durationMs!),
                      if (asset.microphoneEnabled) context.tr('Mic on'),
                    ].join(' - '),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: AppText.xs,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (link != null) ...[
                    Text(
                      linkedContent == null
                          ? context.tr('Linked to content')
                          : context.tr('Linked to {title}', {
                              'title': linkedContent!.title,
                            }),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: AppText.xs,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      IconButton.filled(
                        tooltip: context.tr('Create content'),
                        onPressed: onCreateContent,
                        icon: const Icon(Icons.note_add_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: context.tr('Link to content'),
                        onPressed: onAttachContent,
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: context.tr('Share'),
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                      IconButton(
                        tooltip: context.tr('Discard'),
                        onPressed: onDiscard,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentPickerSheet extends StatelessWidget {
  const _ContentPickerSheet({required this.items});

  final List<ContentItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            context.tr('Link to content'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                context.tr('No pending content is available for this project.'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final item in items)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(item.title),
                subtitle: Text(item.typeLabel),
                onTap: () => Navigator.of(context).pop(item),
              ),
        ],
      ),
    );
  }
}

String _formatDuration(int ms) {
  final duration = Duration(milliseconds: ms);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
