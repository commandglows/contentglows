import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

import '../../../data/models/feedback_entry.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_error_view.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  late final TextEditingController _messageController;
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _recordingBytes = <int>[];
  Stopwatch? _recordingStopwatch;
  StreamSubscription<Uint8List>? _recordingSubscription;

  bool _isSubmittingText = false;
  bool _isSubmittingAudio = false;
  bool _isRecording = false;
  int _recordedDurationMs = 0;
  Timer? _durationTimer;
  Uint8List? _wavBytes;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: ref.read(feedbackServiceProvider).loadDraftMessage(),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recordingSubscription?.cancel();
    unawaited(_recorder.dispose());
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final recentSubmissions = ref.watch(feedbackRecentSubmissionsProvider);
    final isSignedIn = session.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Feedback'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            context.tr(
              'Send product feedback directly from the app. Text and audio feedback are sent to the backend and stay anonymous when no account is connected.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FeedbackCard(
            title: 'Text Feedback',
            subtitle: isSignedIn
                ? context.tr('Sent with {account}', {
                    'account': session.email ?? context.tr('your account'),
                  })
                : context.tr('Sent anonymously'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'What is blocking you, missing, or could be improved?',
                    ),
                  ),
                  onChanged: (value) {
                    unawaited(
                      ref.read(feedbackServiceProvider).saveDraftMessage(value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isSubmittingText ? null : _submitText,
                    icon: _isSubmittingText
                        ? const SizedBox(
                            width: AppSpacing.md,
                            height: AppSpacing.md,
                            child: CircularProgressIndicator(
                              strokeWidth: AppSpacing.xxs,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      context.tr(_isSubmittingText ? 'Sending...' : 'Send'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedbackCard(
            title: 'Audio Feedback',
            subtitle: 'Record a short voice message, then send it.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmittingAudio
                          ? null
                          : (_isRecording ? _stopRecording : _startRecording),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isRecording
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      icon: Icon(
                        _isRecording
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none_rounded,
                      ),
                      label: Text(context.tr(_isRecording ? 'Stop' : 'Record')),
                    ),
                    if (_wavBytes != null && !_isRecording)
                      OutlinedButton.icon(
                        onPressed: _isSubmittingAudio ? null : _clearRecording,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(context.tr('Delete')),
                      ),
                    if (_wavBytes != null && !_isRecording)
                      FilledButton.icon(
                        onPressed: _isSubmittingAudio ? null : _submitAudio,
                        icon: _isSubmittingAudio
                            ? const SizedBox(
                                width: AppSpacing.md,
                                height: AppSpacing.md,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppSpacing.xxs,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          context.tr(
                            _isSubmittingAudio ? 'Uploading...' : 'Send',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _audioStatusText(context),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('Recent feedback sent'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          recentSubmissions.when(
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  context.tr('No feedback sent recently from this device.'),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(
                          item.type == FeedbackEntryType.audio
                              ? Icons.mic_rounded
                              : Icons.chat_bubble_outline_rounded,
                        ),
                      ),
                      title: Text(
                        item.type == FeedbackEntryType.audio
                            ? context.tr('Audio message')
                            : (item.messagePreview ??
                                  context.tr('Text message')),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          DateFormat.yMMMd(
                            context.localeTag,
                          ).add_Hm().format(item.createdAt.toLocal()),
                          if (item.durationMs != null)
                            _formatDuration(item.durationMs!),
                        ].join(' • '),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AppErrorView(
              scope: 'feedback.local_history',
              title: context.tr('Could not load local history'),
              error: error,
              stackTrace: stackTrace,
              compact: true,
              showIcon: false,
              onRetry: () => ref.invalidate(feedbackRecentSubmissionsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitText() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnack(context.tr('Message is empty.'));
      return;
    }

    setState(() => _isSubmittingText = true);
    try {
      await ref.read(feedbackServiceProvider).submitText(message);
      if (!mounted) return;
      _messageController.clear();
      _showSnack(context.tr('Feedback sent.'));
    } catch (error, stackTrace) {
      _showSnack(
        context.tr('Failed to send: {error}', {'error': error}),
        error: error,
        stackTrace: stackTrace,
        scope: 'feedback.submit_text',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingText = false);
      }
    }
  }

  Future<void> _startRecording() async {
    final l10n = context.l10n;
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      _showSnack(l10n.tr('Microphone access denied.'));
      return;
    }

    _recordingBytes.clear();
    _wavBytes = null;
    _recordedDurationMs = 0;
    _recordingStopwatch = Stopwatch()..start();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _recordedDurationMs =
            _recordingStopwatch?.elapsedMilliseconds ?? _recordedDurationMs;
      });
    });

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    await _recordingSubscription?.cancel();
    _recordingSubscription = stream.listen((chunk) {
      _recordingBytes.addAll(chunk);
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    await _recordingSubscription?.cancel();
    _durationTimer?.cancel();
    final durationMs = _recordingStopwatch?.elapsedMilliseconds ?? 0;
    _recordingStopwatch?.stop();
    final wavBytes = _encodePcmToWav(
      pcmBytes: Uint8List.fromList(_recordingBytes),
      sampleRate: 16000,
      channels: 1,
      bitsPerSample: 16,
    );
    setState(() {
      _isRecording = false;
      _recordedDurationMs = durationMs;
      _wavBytes = wavBytes;
    });
  }

  Future<void> _submitAudio() async {
    final wavBytes = _wavBytes;
    if (wavBytes == null || wavBytes.isEmpty) {
      _showSnack(context.tr('No audio ready to send.'));
      return;
    }

    setState(() => _isSubmittingAudio = true);
    try {
      await ref
          .read(feedbackServiceProvider)
          .submitAudio(wavBytes: wavBytes, durationMs: _recordedDurationMs);
      if (!mounted) return;
      _clearRecording();
      _showSnack(context.tr('Audio feedback sent.'));
    } catch (error, stackTrace) {
      _showSnack(
        context.tr('Failed to send audio: {error}', {'error': error}),
        error: error,
        stackTrace: stackTrace,
        scope: 'feedback.submit_audio',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAudio = false);
      }
    }
  }

  void _clearRecording() {
    setState(() {
      _wavBytes = null;
      _recordedDurationMs = 0;
      _recordingBytes.clear();
    });
  }

  String _audioStatusText(BuildContext context) {
    if (_isRecording) {
      return context.tr('Recording in progress: {duration}', {
        'duration': _formatDuration(_recordedDurationMs),
      });
    }
    if (_wavBytes != null) {
      return context.tr('Audio ready: {duration}', {
        'duration': _formatDuration(_recordedDurationMs),
      });
    }
    return context.tr('No audio recorded.');
  }

  void _showSnack(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String scope = 'feedback.message',
  }) {
    if (!mounted) return;
    if (error != null) {
      showDiagnosticSnackBar(
        context,
        ref,
        message: message,
        scope: scope,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.tr(subtitle),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

Uint8List _encodePcmToWav({
  required Uint8List pcmBytes,
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLength = pcmBytes.length;
  final fileLength = 36 + dataLength;
  final bytes = BytesBuilder(copy: false);

  void writeString(String value) {
    bytes.add(value.codeUnits);
  }

  void writeInt32(int value) {
    bytes.add([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  void writeInt16(int value) {
    bytes.add([value & 0xff, (value >> 8) & 0xff]);
  }

  writeString('RIFF');
  writeInt32(fileLength);
  writeString('WAVE');
  writeString('fmt ');
  writeInt32(16);
  writeInt16(1);
  writeInt16(channels);
  writeInt32(sampleRate);
  writeInt32(byteRate);
  writeInt16(blockAlign);
  writeInt16(bitsPerSample);
  writeString('data');
  writeInt32(dataLength);
  bytes.add(pcmBytes);
  return bytes.toBytes();
}
