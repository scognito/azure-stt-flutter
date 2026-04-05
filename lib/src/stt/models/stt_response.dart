import 'package:flutter/cupertino.dart';

abstract class STTResponse {
  final String path;
  final String text;
  final String? language;

  const STTResponse({required this.path, required this.text, this.language});
}

class SpeechHypothesis extends STTResponse {
  SpeechHypothesis({required super.text, super.language}) : super(path: 'speech.hypothesis');

  factory SpeechHypothesis.fromJson(Map<String, dynamic> json) {
    return SpeechHypothesis(
      text: json['Text'] ?? '',
      language: json['PrimaryLanguage']?['Language'] as String?,
    );
  }
}

class SpeechPhrase extends STTResponse {
  final String recognitionStatus;

  SpeechPhrase({required super.text, required this.recognitionStatus, super.language})
    : super(path: 'speech.phrase');

  factory SpeechPhrase.fromJson(Map<String, dynamic> json) {
    return SpeechPhrase(
      text: json['DisplayText'] ?? '',
      recognitionStatus: json['RecognitionStatus'] ?? 'Error',
      language: json['PrimaryLanguage']?['Language'] as String?,
    );
  }
}

STTResponse? parseAzureResponse(String path, Map<String, dynamic> json) {
  try {
    if (path == 'speech.hypothesis') {
      return SpeechHypothesis.fromJson(json);
    }
    if (path == 'speech.phrase') {
      return SpeechPhrase.fromJson(json);
    }
  } catch (e) {
    debugPrint("Error parsing Azure response: $e");
  }
  return null;
}
