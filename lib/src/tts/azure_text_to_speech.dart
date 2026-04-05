import 'dart:convert';

import 'package:azure_stt_flutter/src/common/auth_headers.dart';
import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/config/tts_models.dart';
import 'package:http/http.dart' as http;

class AzureTextToSpeech {
  final AzureSpeechConfig config;

  const AzureTextToSpeech({required this.config});

  Future<List<TtsVoice>> listVoices() async {
    final url = Uri.parse(
      'https://${config.region}.tts.speech.microsoft.com/cognitiveservices/voices/list',
    );

    final response = await http.get(url, headers: buildAuthHeaders(config));

    if (response.statusCode != 200) {
      throw AzureTtsException(response);
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((e) => TtsVoice.fromJson(e)).toList();
  }

  Future<List<int>> synthesize(TtsRequest request) async {
    final url = Uri.parse('https://${config.region}.tts.speech.microsoft.com/cognitiveservices/v1');

    final response = await http.post(
      url,
      headers: {
        ...buildAuthHeaders(config),
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': request.outputFormat.value,
      },
      body: utf8.encode(request.toSsml()),
    );

    if (response.statusCode != 200) {
      throw AzureTtsException(response);
    }

    return response.bodyBytes;
  }
}
