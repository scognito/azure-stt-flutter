// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/models/language_id_mode.dart';
import 'package:azure_stt_flutter/src/services/azure_stt_service.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';

export 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart' show TranscriptionState;
export 'package:azure_stt_flutter/src/models/language_id_mode.dart';

class AzureSpeechToText {
  late final TranscriptionCubit _transcriptionCubit;
  late final MicrophoneService _microphoneService;
  late final AzureSttService _azureSttService;

  AzureSpeechToText({
    required String subscriptionKey,
    required String region,
    List<String> languages = const [Constants.defaultLang],
    LanguageIdMode languageIdMode = .atStart,
    bool debug = false,
    Duration textClearTimeout = const Duration(seconds: 1),
  }) {
    _transcriptionCubit = TranscriptionCubit();
    _microphoneService = MicrophoneService();

    _azureSttService = AzureSttService(
      subscriptionKey: subscriptionKey,
      region: region,
      languages: languages,
      languageIdMode: languageIdMode,
      debug: debug,
      cubit: _transcriptionCubit,
      micService: _microphoneService,
      textClearTimeout: textClearTimeout,
    );
  }

  Stream<TranscriptionState> get transcriptionStateStream => _transcriptionCubit.stream;

  bool get isListening => _azureSttService.isListening();

  Future<void> startListening() async {
    await _azureSttService.startListening();
  }

  Future<void> stopListening() async {
    await _azureSttService.stopListening();
  }

  Future<void> dispose() async {
    await _microphoneService.dispose();
    _transcriptionCubit.close();
  }
}
