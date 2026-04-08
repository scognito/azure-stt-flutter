// ignore_for_file: prefer-match-file-name, unused-code

/// Flutter package for real-time Speech-to-Text using Microsoft Azure Cognitive Services.
///
/// This library provides a reactive, stream-based API for speech recognition
/// with support for multiple languages and automatic language detection.
library azure_stt_flutter;

import 'dart:async';
import 'dart:typed_data';

import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/services/azure_stt_service.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/utils/language_utils.dart';

export 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart' show TranscriptionState;
export 'package:azure_stt_flutter/src/utils/language_utils.dart' show LanguageUtils;

/// Main class for Azure Speech-to-Text functionality.
///
/// This class provides real-time speech recognition using Azure Cognitive Services.
/// It supports multiple languages, automatic language detection, and streams
/// transcription results through a reactive API.
class AzureSpeechToText {
  late final TranscriptionCubit _transcriptionCubit;
  late final MicrophoneService _microphoneService;
  late final AzureSttService _azureSttService;

  /// Creates an instance of [AzureSpeechToText].
  ///
  /// Either [subscriptionKey] or [authorizationToken] must be provided for authentication.
  ///
  /// Parameters:
  /// - [subscriptionKey]: Azure Speech Services subscription key
  /// - [authorizationToken]: Azure authorization token (alternative to subscription key)
  /// - [region]: Azure region (e.g., 'westeurope', 'eastus')
  /// - [languages]: List of language codes (e.g., ['en-US', 'it-IT']). Defaults to ['en-US']
  /// - [languageIdMode]: Language detection mode (atStart or continuous). Defaults to atStart
  /// - [debug]: Enable debug logging. Defaults to false
  /// - [textClearTimeout]: Duration before clearing intermediate text. Defaults to 1 second
  /// - [customEndpoint]: Optional full Azure Speech endpoint URL. When provided, it
  ///   overrides the default region-based websocket endpoint.
  AzureSpeechToText({
    String? subscriptionKey,
    String? authorizationToken,
    required String region,
    String? customEndpoint,
    List<String> languages = const [Constants.defaultLang],
    LanguageIdMode languageIdMode = .atStart,
    bool debug = false,
    Duration textClearTimeout = const Duration(seconds: 1),
  }) {
    assert(
      (subscriptionKey != null && authorizationToken == null) ||
          (subscriptionKey == null && authorizationToken != null),
      'Either subscriptionKey or authorizationToken must be provided',
    );
    _transcriptionCubit = TranscriptionCubit();
    _microphoneService = MicrophoneService();

    // The Speech SDK only accepts languages in the format languageCode-regionCode
    // If the user specify only the language code, we try to guess the most common region code
    final sanitizedLanguages = languages.map(LanguageUtils.maximizeLocale).toList();

    _azureSttService = AzureSttService(
      subscriptionKey: subscriptionKey,
      authorizationToken: authorizationToken,
      region: region,
      customEndpoint: customEndpoint,
      languages: sanitizedLanguages,
      languageIdMode: languageIdMode,
      debug: debug,
      cubit: _transcriptionCubit,
      micService: _microphoneService,
      textClearTimeout: textClearTimeout,
    );
  }

  /// Stream of transcription state updates.
  ///
  /// Listen to this stream to receive real-time transcription results,
  /// including intermediate and finalized text.
  Stream<TranscriptionState> get transcriptionStateStream => _transcriptionCubit.stream;

  /// Returns whether the service is currently listening for speech.
  bool get isListening => _azureSttService.isListening();

  /// Starts the speech recognition session.
  ///
  /// Opens a WebSocket connection to Azure Speech Services and begins
  /// capturing audio. Transcription results are emitted through
  /// [transcriptionStateStream].
  ///
  /// By default, audio is captured from the device microphone. You can instead
  /// provide an [externalAudioStream] to supply your own audio source — for
  /// example, audio coming from a VoIP call or a file.
  ///
  /// The stream must emit [Uint8List] chunks of raw PCM audio formatted as:
  /// 16 kHz sample rate, mono channel, 16-bit little-endian samples.
  /// This matches exactly the format that the microphone produces and that the
  /// WAV header sent to Azure declares.
  ///
  /// If [externalAudioStream] is `null`, the device microphone is used as normal.
  ///
  Future<void> startListening({Stream<Uint8List>? externalAudioStream}) async {
    await _azureSttService.startListening(externalAudioStream: externalAudioStream);
  }

  /// Stops listening for speech input.
  ///
  /// Closes the WebSocket connection and stops audio capture.
  Future<void> stopListening() async {
    await _azureSttService.stopListening();
  }

  /// Disposes of resources used by this instance.
  ///
  /// Call this method when you no longer need the speech recognition service
  /// to release microphone and other resources.
  Future<void> dispose() async {
    await _microphoneService.dispose();
    _transcriptionCubit.close();
  }
}

enum LanguageIdMode { atStart, continuous }
