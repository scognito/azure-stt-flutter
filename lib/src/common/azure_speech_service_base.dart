// ignore_for_file: avoid-unsafe-collection-methods

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:azure_stt_flutter/src/config/azure_speech_config.dart';
import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/stt/models/connection_message.dart';
import 'package:azure_stt_flutter/src/stt/models/speech_connection_message.dart';
import 'package:azure_stt_flutter/src/web_socket/web_socket_service_stub.dart'
    if (dart.library.io) 'package:azure_stt_flutter/src/web_socket/web_socket_service_mobile.dart'
    if (dart.library.html) 'package:azure_stt_flutter/src/web_socket/web_socket_service_web.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AzureSpeechServiceBase {
  final AzureSpeechConfig config;
  final bool debug;
  final MicrophoneService micService;

  final String crlf = '\r\n';
  final _uuid = Uuid();

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  StreamSubscription<Uint8List>? _micSubscription;

  AzureSpeechServiceBase({required this.config, required this.micService, this.debug = false});

  Future<String> _getAuthToken() async {
    final subscriptionKey = config.subscriptionKey!;
    final uri = Uri.parse(
      'https://${config.region}.api.cognitive.microsoft.com/sts/v1.0/issueToken',
    );
    try {
      final response = await http.post(uri, headers: {Constants.authKey: subscriptionKey});
      if (response.statusCode == 200) return response.body;
      throw AzureSpeechException(response.statusCode, response.body);
    } catch (e) {
      if (e is AzureSpeechException) rethrow;
      throw AzureSpeechException(0, e.toString());
    }
  }

  String newRequestId() => _uuid.v4().replaceAll('-', '').toUpperCase();

  Future<void> openSession({
    required String requestId,
    required Uri Function(Map<String, String> queryParams) buildUri,
    required Map<String, String> baseQueryParams,
    required void Function(Object?) onMessage,
    required void Function(String) onError,
    required void Function() onDone,
  }) async {
    final queryParams = {...baseQueryParams, Constants.connectionId: requestId};

    if (kIsWeb) {
      if (config.subscriptionKey != null) {
        queryParams[Constants.authKey] = config.subscriptionKey!;
      } else {
        queryParams[Constants.authorization] = 'Bearer ${config.authorizationToken}';
      }
      final uri = buildUri(queryParams);
      debugPrint('>>> CONNECTING WebSocket: $uri');
      _channel = getWebSocketService().connect(uri);
    } else {
      final token = config.subscriptionKey != null
          ? await _getAuthToken()
          : config.authorizationToken!;

      final uri = buildUri(queryParams);
      debugPrint('>>> CONNECTING WebSocket: $uri');
      _channel = getWebSocketService().connect(
        uri,
        headers: {Constants.authorization: 'Bearer $token'},
      );
    }

    _socketSubscription = _channel!.stream.listen(
      onMessage,
      onError: (err) {
        final message = err is WebSocketChannelException
            ? 'WebSocket error: ${err.message}'
            : 'WebSocket error: $err';
        debugPrint(message);
        onError(message);
        stopSession();
      },
      onDone: () {
        final code = _channel?.closeCode;
        debugPrint(
          code != null
              ? 'WebSocket closed with code $code, reason ${_channel?.closeReason}'
              : 'WebSocket closed successfully',
        );
        onDone();
      },
      cancelOnError: true,
    );
  }

  Future<void> startAudioStream({
    required String requestId,
    required Stream<Uint8List>? externalAudioStream,
    required void Function(String) onError,
  }) async {
    sendWavHeader(requestId);

    final audioStream = externalAudioStream ?? await micService.start();

    _micSubscription = audioStream.listen(
      (Uint8List audioChunk) {
        if (audioChunk.isEmpty) return;
        sendBinaryAudio(requestId, audioChunk);
        if (debug) debugPrint('>>> SENT Audio Chunk (${audioChunk.length} bytes)');
      },
      onError: (e) {
        final message = 'Microphone error: $e';
        debugPrint(message);
        onError(message);
        stopSession();
      },
      onDone: () {
        debugPrint('Mic stream done; sending end-of-stream.');
        sendBinaryAudio(requestId, Uint8List(0));
      },
    );
  }

  Future<void> stopSession() async {
    try {
      await micService.stop();
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _channel?.sink.close();
      _channel = null;
      await _socketSubscription?.cancel();
      _socketSubscription = null;
    } catch (e) {
      debugPrint('Error stopping session: $e');
    }
  }

  void sendWavHeader(String requestId) {
    final msg = SpeechConnectionMessage(
      MessageType.binary,
      'audio',
      requestId,
      'audio/x-wav',
      BinaryMessageBody(_getWavHeader()),
    );
    _channel?.sink.add(_serializeBinaryConnectionMessage(msg));
  }

  void sendBinaryAudio(String requestId, Uint8List bytes) {
    final msg = SpeechConnectionMessage(
      MessageType.binary,
      'audio',
      requestId,
      'audio/x-wav',
      BinaryMessageBody(bytes),
    );
    _channel?.sink.add(_serializeBinaryConnectionMessage(msg));
  }

  void sendTextFrame(String path, String requestId, Map<String, Object?> payload) {
    if (_channel == null) return;
    final msg = SpeechConnectionMessage(
      MessageType.text,
      path,
      requestId,
      'application/json; charset=utf-8',
      TextMessageBody(jsonEncode(payload)),
    );
    _sendSpeechMessage(msg, _channel!);
  }

  void sendSpeechConfig(String requestId) {
    sendTextFrame('speech.config', requestId, {
      'recognition': 'conversation',
      'context': {
        'system': {'name': 'FlutterSDK', 'version': '1.0.0'},
        'os': kIsWeb
            ? null
            : {'platform': 'Flutter', 'name': 'Dart/Flutter Client', 'version': '1.0'},
        'audio': {
          'source': {
            'bitspersample': Constants.audioBitsPerSample,
            'channelcount': Constants.audioChannels,
            'samplerate': Constants.audioSampleRate,
            'type': 'Microphones',
            'connectivity': 'Unknown',
            'manufacturer': 'Flutter',
            'model': 'MicService',
          },
        },
      },
    });
  }

  ParsedFrame parseTextFrame(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final parts = normalized.split('\n\n');
    if (parts.length >= 2) {
      final headers = <String, String>{};
      for (final line in parts.first.split('\n')) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
        }
      }
      return ParsedFrame(headers: headers, body: parts.sublist(1).join('\n\n'));
    }
    return ParsedFrame(headers: {}, body: raw);
  }

  void _sendSpeechMessage(SpeechConnectionMessage message, WebSocketChannel channel) {
    if (message.messageType == MessageType.binary) {
      final payload = _serializeBinaryConnectionMessage(message);
      channel.sink.add(payload);
      if (debug) debugPrint('>>> SENT BINARY (${payload.length} bytes)');
    } else {
      final sb = StringBuffer();
      for (final entry in message.headers.entries) {
        sb.write('${entry.key}: ${entry.value}$crlf');
      }
      sb.write(crlf);
      sb.write(message.textBody);
      channel.sink.add(sb.toString());
      if (debug) debugPrint('>>> SENT TEXT path=${message.headers[Constants.path]}');
    }
  }

  Uint8List _serializeBinaryConnectionMessage(SpeechConnectionMessage message) {
    if (message.messageType != MessageType.binary) {
      throw Exception('Binary serialization is only for MessageType.binary');
    }

    final headerBuilder = StringBuffer();
    final allHeaders = {...message.headers};
    final binaryContent = message.binaryBody;

    if (binaryContent.isNotEmpty) {
      allHeaders['Content-Length'] = binaryContent.lengthInBytes.toString();
    }

    for (final entry in allHeaders.entries) {
      headerBuilder.write('${entry.key}:${entry.value}$crlf');
    }

    final headerBytes = utf8.encode(headerBuilder.toString());
    final lengthData = ByteData(2)..setUint16(0, headerBytes.length, Endian.big);

    final fullPayload = BytesBuilder()
      ..add(lengthData.buffer.asUint8List())
      ..add(headerBytes);
    if (binaryContent.isNotEmpty) fullPayload.add(binaryContent);

    return fullPayload.toBytes();
  }

  Uint8List _getWavHeader() {
    const sampleRate = Constants.audioSampleRate;
    const channels = Constants.audioChannels;
    const bitsPerSample = Constants.audioBitsPerSample;
    const byteRate = (sampleRate * channels * bitsPerSample) ~/ 8;

    final buffer = Uint8List(44);
    final view = ByteData.view(buffer.buffer);

    buffer.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // RIFF
    view.setUint32(4, 0, Endian.little); // file size (streaming = 0)
    buffer.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // WAVE
    buffer.setRange(12, 16, [0x66, 0x6D, 0x74, 0x20]); // fmt
    view.setUint32(16, 16, Endian.little); // fmt chunk size
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, (channels * bitsPerSample) ~/ 8, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);
    buffer.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // data
    view.setUint32(40, 0, Endian.little); // data size (streaming = 0)

    return buffer;
  }

  bool get isSessionActive => _channel != null;
}

class ParsedFrame {
  final Map<String, String> headers;
  final String body;

  const ParsedFrame({required this.headers, required this.body});
}
