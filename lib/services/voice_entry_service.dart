import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceCaptureResult {
  const VoiceCaptureResult({
    required this.audioPath,
    required this.audioDurationMs,
    required this.transcript,
  });

  final String audioPath;
  final int audioDurationMs;
  final String transcript;
}

class VoiceEntryService {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();

  bool _capturing = false;
  bool _paused = false;

  Future<bool> startCapture({
    void Function(String transcript)? onTranscript,
  }) async {
    if (_capturing) {
      return true;
    }

    final hasMicPermission = await _recorder.hasPermission();
    if (!hasMicPermission) {
      return false;
    }

    final audioPath = await _buildAudioPath();

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: audioPath,
      );
    } catch (_) {
      _capturing = false;
      return false;
    }

    _stopwatch
      ..reset()
      ..start();

    _capturing = true;
    _paused = false;
    return true;
  }

  Future<bool> pauseCapture() async {
    if (!_capturing || _paused) {
      return false;
    }

    try {
      await _recorder.pause();
      _stopwatch.stop();
      _paused = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resumeCapture() async {
    if (!_capturing || !_paused) {
      return false;
    }

    try {
      await _recorder.resume();
      _stopwatch.start();
      _paused = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<VoiceCaptureResult?> stopCapture() async {
    if (!_capturing) {
      return null;
    }

    String? audioPath;
    try {
      audioPath = await _recorder.stop();
    } catch (_) {
      audioPath = null;
    }

    _stopwatch.stop();
    _capturing = false;
  _paused = false;

    if (audioPath == null || audioPath.trim().isEmpty) {
      return null;
    }

    return VoiceCaptureResult(
      audioPath: audioPath,
      audioDurationMs: _stopwatch.elapsedMilliseconds,
      transcript: '',
    );
  }

  Future<void> cancelCapture() async {
    if (!_capturing) {
      return;
    }

    String? audioPath;
    try {
      audioPath = await _recorder.stop();
    } catch (_) {
      audioPath = null;
    }

    _stopwatch.stop();
    _capturing = false;
    _paused = false;

    if (audioPath != null) {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String> _buildAudioPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}${Platform.pathSeparator}entry_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final id = DateTime.now().microsecondsSinceEpoch;
    return '${audioDir.path}${Platform.pathSeparator}entry_$id.m4a';
  }

  Future<void> dispose() async {
    if (_capturing) {
      await cancelCapture();
    }
    await _recorder.dispose();
  }
}
