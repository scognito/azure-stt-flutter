/// Flutter package for real-time Speech-to-Text and Text-to-Speech using Microsoft Azure Cognitive Services.
///
/// This library provides a reactive, stream-based API for speech recognition
/// and text synthesis with support for multiple languages and automatic language detection.
library azure_stt_flutter;

export 'package:azure_stt_flutter/src/common/exceptions.dart'
    show AzureSpeechException, AzureTtsException;
export 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
export 'package:azure_stt_flutter/src/config/speech_to_text_config.dart';
export 'package:azure_stt_flutter/src/config/tts_models.dart';

export 'package:azure_stt_flutter/src/stt/azure_speech_to_text.dart';
export 'package:azure_stt_flutter/src/tts/azure_text_to_speech.dart';

export 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart'
    show TranscriptionCubit, TranscriptionState;
export 'package:azure_stt_flutter/src/utils/language_utils.dart' show LanguageUtils;
