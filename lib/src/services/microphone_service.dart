import 'dart:async';

import 'package:azure_stt_flutter/src/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class MicrophoneService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  Future<Stream<Uint8List>> start() async {
    if (!await _checkPermission()) {
      throw Exception('Microphone permission not granted');
    }

    const config = RecordConfig(
      encoder: .pcm16bits,
      sampleRate: Constants.audioSampleRate,
      numChannels: Constants.audioChannels,
    );

    debugPrint('Starting microphone stream (16kHz, mono, PCM16)...');

    final stream = await _audioRecorder.startStream(config);
    _isRecording = true;

    // Convert each chunk to Uint8List for binary-safe transmission.
    return stream;
  }

  Future<void> stop() async {
    if (!_isRecording) return;
    debugPrint('Stopping microphone stream');
    await _audioRecorder.stop();
    _isRecording = false;
  }

  Future<bool> _checkPermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) debugPrint('Microphone permission not granted.');
    return hasPermission;
  }

  Future<void> dispose() async {
    if (_isRecording) await stop();
    await _audioRecorder.dispose();
  }
}
