import 'dart:async';
import 'dart:convert';
import 'package:azure_stt_flutter/src/common/azure_speech_service_base.dart';
import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/config/speech_to_text_config.dart';
import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/stt/models/stt_response.dart';
import 'package:flutter/foundation.dart';

class AzureSttService extends AzureSpeechServiceBase {
  final SpeechToTextConfig _sttConfig;
  final TranscriptionCubit _cubit;

  Timer? _textClearTimer;

  AzureSttService({
    required AzureSpeechConfig config,
    SpeechToTextConfig? sttConfig,
    bool debug = false,
    required TranscriptionCubit cubit,
    required MicrophoneService micService,
  }) : _sttConfig = sttConfig ?? SpeechToTextConfig(),
       _cubit = cubit,
       super(config: config, micService: micService, debug: debug);

  Future<void> startListening({
    Stream<List<int>>? externalAudioStream,
    SpeechToTextConfig? sttConfig,
  }) async {
    if (_cubit.isListening) return;

    _cubit.reset();
    _cubit.setListening(true);

    final currentConfig = sttConfig ?? _sttConfig;
    final requestId = newRequestId();

    try {
      final isLidEnabled = currentConfig.languages.length > 1;
      final baseParams = <String, String>{Constants.format: 'simple'};

      if (isLidEnabled) {
        baseParams[Constants.lidEnabled] = 'true';
      } else {
        baseParams[Constants.language] = currentConfig.sanitizedLanguages.isNotEmpty
            ? currentConfig.sanitizedLanguages.first
            : Constants.defaultLang;
      }

      await openSession(
        requestId: requestId,
        buildUri: (params) => Uri.parse(
          'wss://${config.region}.stt.speech.microsoft.com/stt/speech/universal/v2',
        ).replace(queryParameters: params),
        baseQueryParams: baseParams,
        onMessage: _handleIncoming,
        onError: (msg) {
          _cubit.emitError(msg);
        },
        onDone: () => _cubit.setListening(false),
      );

      sendSpeechConfig(requestId);
      _sendSpeechContext(requestId, currentConfig);
      _resetClearTimer(currentConfig);

      await startAudioStream(
        requestId: requestId,
        externalAudioStream: externalAudioStream?.cast(),
        onError: (msg) => _cubit.emitError(msg),
      );
    } catch (e) {
      final message = e is AzureSpeechException ? e.toString() : 'Failed to start listening: $e';
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

  void _sendSpeechContext(String requestId, SpeechToTextConfig config) {
    final Map<String, dynamic> payload = {
      'phraseDetection': {'mode': 'Conversation'},
    };

    if (config.languages.length > 1) {
      payload['languageId'] = {
        'languages': config.sanitizedLanguages,
        'mode': config.languageIdMode == LanguageIdMode.continuous
            ? 'DetectContinuous'
            : 'DetectAtAudioStart',
        'onSuccess': {'action': 'Recognize'},
        'onUnknown': {'action': 'None'},
        'priority': 'PrioritizeLatency',
      };
    }

    sendTextFrame('speech.context', requestId, payload);
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
      final response = parseAzureResponse(path, map);
      if (response is SpeechHypothesis) {
        _cubit.updateIntermediateText(response.text, language: response.language);
        _resetClearTimer(_sttConfig);
      } else if (response is SpeechPhrase) {
        _cubit.addFinalizedText(response.text, language: response.language);
        _resetClearTimer(_sttConfig);
      } else if (debug) {
        debugPrint('Azure event: ${map['type'] ?? map}');
      }
    } catch (e) {
      debugPrint('processResponse failed: $e; body: $jsonBody');
    }
  }

  void _resetClearTimer(SpeechToTextConfig config) {
    _textClearTimer?.cancel();
    _textClearTimer = Timer(config.textClearTimeout, _cubit.clearText);
  }
}
