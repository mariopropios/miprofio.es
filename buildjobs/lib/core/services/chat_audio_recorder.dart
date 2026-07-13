import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/web_blob_bytes_reader.dart';

class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.durationSec,
  });

  final List<int> bytes;
  final String fileName;
  final String contentType;
  final int durationSec;
}

/// Grabación de audio para mensajes de voz del chat.
class ChatAudioRecorder {
  ChatAudioRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;

  Future<bool> hasPermission({bool request = false}) =>
      _recorder.hasPermission(request: request);

  Future<bool> requestPermission() => _recorder.hasPermission(request: true);

  Future<bool> get isRecording => _recorder.isRecording();

  Future<void> start() async {
    if (await _recorder.isRecording()) return;

    final config = RecordConfig(
      encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    if (kIsWeb) {
      await _recorder.start(config, path: '');
    } else {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(config, path: path);
    }

    _startedAt = DateTime.now();
  }

  Future<RecordedAudio?> stop() async {
    final outputPath = await _recorder.stop();
    final startedAt = _startedAt;
    _startedAt = null;
    if (outputPath == null || (outputPath.isEmpty && !kIsWeb)) return null;

    final durationSec = startedAt == null
        ? 1
        : DateTime.now().difference(startedAt).inSeconds.clamp(1, 599);

    final bytes = kIsWeb
        ? await readWebBlobBytes(outputPath)
        : await XFile(outputPath).readAsBytes();
    if (bytes.isEmpty) return null;

    if (kIsWeb) {
      return RecordedAudio(
        bytes: bytes,
        fileName: 'voice_$durationSec.wav',
        contentType: 'audio/wav',
        durationSec: durationSec,
      );
    }

    return RecordedAudio(
      bytes: bytes,
      fileName: 'voice_$durationSec.m4a',
      contentType: 'audio/mp4',
      durationSec: durationSec,
    );
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _startedAt = null;
  }

  Future<void> dispose() => _recorder.dispose();
}
