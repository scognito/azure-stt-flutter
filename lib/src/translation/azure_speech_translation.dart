import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/translation/azure_translation_service.dart';
import 'package:azure_stt_flutter/src/translation/translation_config.dart';
import 'package:azure_stt_flutter/src/translation/translation_cubit.dart';

class AzureSpeechTranslation {
  final AzureSpeechConfig config;
  final TranslationConfig translationConfig;

  final TranslationCubit _cubit;
  final MicrophoneService _microphone;
  late final AzureTranslationService _service;

  AzureSpeechTranslation({
    required this.config,
    required this.translationConfig,
    bool debug = false,
  }) : _cubit = TranslationCubit(),
       _microphone = MicrophoneService() {
    _service = AzureTranslationService(
      config: config,
      translationConfig: translationConfig,
      cubit: _cubit,
      micService: _microphone,
      debug: debug,
    );
  }

  Stream<TranslationState> get stream => _cubit.stream;

  bool get isListening => _service.isListening();

  TranslationCubit get cubit => _cubit;

  Future<void> start() => _service.startListening();

  Future<void> stop() => _service.stopListening();

  Future<void> dispose() async {
    await _microphone.dispose();
    await _cubit.close();
  }
}
