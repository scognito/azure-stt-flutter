import 'dart:async';

import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/config/speech_to_text_config.dart';
import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/stt/azure_stt_service.dart';

class AzureSpeechToText {
  final AzureSpeechConfig config;
  final SpeechToTextConfig sttConfig;

  final TranscriptionCubit _cubit;
  final MicrophoneService _microphone;
  late final AzureSttService _service;

  AzureSpeechToText({required this.config, SpeechToTextConfig? sttConfig})
    : sttConfig = sttConfig ?? SpeechToTextConfig(),
      _cubit = TranscriptionCubit(),
      _microphone = MicrophoneService() {
    _service = AzureSttService(
      config: config,
      sttConfig: this.sttConfig,
      cubit: _cubit,
      micService: _microphone,
    );
  }

  Stream<TranscriptionState> get stream => _cubit.stream;

  bool get isListening => _service.isListening();

  Future<void> start() {
    return _service.startListening();
  }

  Future<void> startWithConfig(SpeechToTextConfig config) {
    return _service.startListening(sttConfig: config);
  }

  Future<void> stop() {
    return _service.stopListening();
  }

  Future<void> dispose() async {
    await _microphone.dispose();
    await _cubit.close();
  }

  TranscriptionCubit get cubit => _cubit;
}
