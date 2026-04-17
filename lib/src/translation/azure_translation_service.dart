import 'dart:async';
import 'dart:convert';

import 'package:azure_stt_flutter/src/common/azure_speech_service_base.dart';
import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/translation/translation_config.dart';
import 'package:azure_stt_flutter/src/translation/translation_cubit.dart';
import 'package:flutter/foundation.dart';

class AzureTranslationService extends AzureSpeechServiceBase {
  final TranslationConfig _translationConfig;
  final TranslationCubit _cubit;

  Timer? _textClearTimer;

  AzureTranslationService({
    required AzureSpeechConfig config,
    required TranslationConfig translationConfig,
    required TranslationCubit cubit,
    required MicrophoneService micService,
    bool debug = false,
  }) : _translationConfig = translationConfig,
       _cubit = cubit,
       super(config: config, micService: micService, debug: debug);

  Future<void> startListening({Stream<List<int>>? externalAudioStream}) async {
    if (_cubit.isListening) return;

    _cubit.reset();
    _cubit.setListening(true);

    final requestId = newRequestId();

    try {
      await openSession(
        requestId: requestId,
        buildUri: (params) {
          final allParams = <String, List<String>>{
            for (final e in params.entries) e.key: [e.value],
            'to': _translationConfig.toLanguages,
          };
          return Uri(
            scheme: 'wss',
            host: '${config.region}.stt.speech.microsoft.com',
            path: '/speech/universal/v2',
            queryParameters: allParams,
          );
        },
        baseQueryParams: {
          Constants.format: 'simple',
          'from': _translationConfig.sanitizedFromLanguage,
        },
        onMessage: _handleIncoming,
        onError: (msg) => _cubit.emitError(msg),
        onDone: () => _cubit.setListening(false),
      );

      sendSpeechConfig(requestId);
      _sendTranslationContext(requestId);
      _resetClearTimer();

      await startAudioStream(
        requestId: requestId,
        externalAudioStream: externalAudioStream?.cast(),
        onError: (msg) => _cubit.emitError(msg),
      );
    } catch (e) {
      final message = e is AzureSpeechException ? e.toString() : 'Failed to start translation: $e';
      debugPrint(message);
      _cubit.emitError(message);
      await stopListening();
    }
  }

  Future<void> stopListening() async {
    _textClearTimer?.cancel();
    _textClearTimer = null;
    await stopSession();
    _cubit.setListening(false);
  }

  bool isListening() => _cubit.isListening;

  void _sendTranslationContext(String requestId) {
    sendTextFrame('speech.context', requestId, {
      'phraseDetection': {'mode': 'Conversation'},
    });
  }

  void _handleIncoming(Object? raw) {
    try {
      if (debug) {
        debugPrint(
          '<<< RECEIVED: ${raw is String ? raw : (raw is List ? 'binary ${raw.length} bytes' : 'unknown')}',
        );
      }
      if (raw is String) {
        final parsed = parseTextFrame(raw);
        final path = parsed.headers[Constants.path];
        if (path != null && parsed.body.isNotEmpty) {
          _processResponse(path, parsed.body);
        }
      } else if (raw is List<int>) {
        final parsed = parseTextFrame(utf8.decode(raw));
        final path = parsed.headers[Constants.path];
        if (path != null) _processResponse(path, parsed.body);
      }
    } catch (e, s) {
      debugPrint('HandleIncoming exception: $e\n$s');
    }
  }

  void _processResponse(String path, String jsonBody) {
    try {
      final trimmed = jsonBody.trim();
      if (trimmed.isEmpty) {
        _cubit.reset();
        return;
      }

      final map = jsonDecode(trimmed) as Map<String, dynamic>;

      switch (path.toLowerCase()) {
        case 'speech.hypothesis':
          final recognized = map['Text'] as String? ?? '';
          final translations = _parseTranslations(map);
          final language = _parsePrimaryLanguage(map);
          _cubit.updateIntermediate(
            recognizedText: recognized,
            translations: translations,
            detectedLanguage: language,
          );
          _resetClearTimer();

        case 'speech.phrase':
          final status = map['RecognitionStatus'] as String? ?? '';
          if (status == 'Success') {
            final recognized = map['DisplayText'] as String? ?? '';
            final translations = _parseTranslations(map);
            final language = _parsePrimaryLanguage(map);
            _cubit.addFinalized(
              recognizedText: recognized,
              translations: translations,
              detectedLanguage: language,
            );
            _resetClearTimer();
          }

        default:
          if (debug) debugPrint('Azure translation event: $path — ${map['type'] ?? ''}');
      }
    } catch (e) {
      debugPrint('processResponse failed: $e; body: $jsonBody');
    }
  }

  Map<String, String> _parseTranslations(Map<String, dynamic> map) {
    final translationBlock = map['Translation'] as Map<String, dynamic>?;
    return _parseTranslationsFromBlock(translationBlock);
  }

  Map<String, String> _parseTranslationsFromBlock(Map<String, dynamic>? block) {
    if (block == null) return {};
    final list = block['Translations'] as List<dynamic>?;
    if (list == null) return {};
    return {
      for (final entry in list)
        (entry['Language'] as String? ?? ''): (entry['Text'] as String? ?? ''),
    };
  }

  String? _parsePrimaryLanguage(Map<String, dynamic> map) {
    return (map['PrimaryLanguage'] as Map<String, dynamic>?)?['Language'] as String?;
  }

  void _resetClearTimer() {
    _textClearTimer?.cancel();
    _textClearTimer = Timer(_translationConfig.textClearTimeout, _cubit.clearText);
  }
}
