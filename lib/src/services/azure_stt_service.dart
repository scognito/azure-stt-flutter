import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/models/azure_response.dart';
import 'package:azure_stt_flutter/src/models/connection_message.dart';
import 'package:azure_stt_flutter/src/models/speech_connection_message.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:azure_stt_flutter/src/web_socket/web_socket_service_stub.dart'
    if (dart.library.io) 'package:azure_stt_flutter/src/web_socket/web_socket_service_mobile.dart'
    if (dart.library.html) 'package:azure_stt_flutter/src/web_socket/web_socket_service_web.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AzureSttService {
  final String _subscriptionKey;
  final String _region;
  final List<String> _languages;
  final bool _debug;
  final TranscriptionCubit _cubit;
  final MicrophoneService _micService;

  final crlf = '\r\n';

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  StreamSubscription<Uint8List>? _micSubscription;
  final _uuid = Uuid();
  final Duration? _textClearTimeout;
  Timer? _textClearTimer;

  AzureSttService({
    required String subscriptionKey,
    required String region,
    List<String> languages = const [Constants.defaultLang],
    bool debug = false,
    required TranscriptionCubit cubit,
    required MicrophoneService micService,
    Duration? textClearTimeout,
  }) : _subscriptionKey = subscriptionKey,
       _region = region,
       _languages = languages,
       _cubit = cubit,
       _debug = debug,
       _micService = micService,
       _textClearTimeout = textClearTimeout;

  Future<String?> _getAuthToken() async {
    final uri = Uri.parse('https://$_region.api.cognitive.microsoft.com/sts/v1.0/issueToken');
    try {
      final response = await http.post(uri, headers: {Constants.authKey: _subscriptionKey});
      if (response.statusCode == 200) return response.body;
      debugPrint('Auth token failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Auth token exception: $e');
      return null;
    }
  }

  Future<void> startListening() async {
    _cubit.reset();
    _cubit.setListening(true);

    final requestId = _uuid.v4().replaceAll('-', '').toUpperCase();

    try {
      if (kIsWeb) {
        // For web, we pass the subscription key as a query parameter
        // as browsers don't allow setting the Ocp-Apim-Subscription-Key header.
        final uri = Uri.parse('wss://$_region.stt.speech.microsoft.com/stt/speech/universal/v2')
            .replace(
              queryParameters: {
                Constants.language: _languages.first,
                Constants.format: 'simple',
                Constants.authKey: _subscriptionKey,
                Constants.connectionId: requestId,
              },
            );

        _channel = getWebSocketService().connect(uri);
      } else {
        // For mobile and desktop, we get a short-lived auth token
        final token = await _getAuthToken();
        if (token == null) {
          _cubit.setListening(false);
          return;
        }

        final uri = Uri.parse(
          'wss://$_region.stt.speech.microsoft.com/stt/speech/universal/v2?language=${_languages.first}&format=simple',
        );

        _channel = getWebSocketService().connect(
          uri,
          headers: {Constants.authorization: 'Bearer $token'},
        );
      }

      _socketSubscription = _channel!.stream.listen(
        _handleIncoming,
        onError: (err) {
          if (err is WebSocketChannelException) {
            debugPrint('WebSocket error: ${err.message}');
          } else {
            debugPrint('WebSocket error: $err');
          }
          stopListening();
        },
        onDone: () {
          String wsStatus = _channel?.closeCode != null
              ? 'with code ${_channel?.closeCode ?? '-'}, reason ${_channel?.closeReason ?? '-'}'
              : 'successfully';

          debugPrint('WebSocket closed $wsStatus');
          _cubit.setListening(false);
        },
        cancelOnError: true,
      );

      _sendSpeechConfig(requestId);
      _sendSpeechContext(requestId);

      final wavHeader = _getWavHeader();
      final wavHeaderMessage = SpeechConnectionMessage(
        .binary,
        'audio',
        requestId,
        'audio/x-wav',
        BinaryMessageBody(wavHeader),
      );
      _channel?.sink.add(serializeBinaryConnectionMessage(wavHeaderMessage));
      if (_debug) {
        debugPrint('>>> SENT WAV Header (${wavHeader.length} bytes)');
      }

      final micStream = await _micService.start();

      _micSubscription = micStream.listen(
        (Uint8List audioChunk) {
          if (audioChunk.isEmpty) return;

          final audioChunkMessage = SpeechConnectionMessage(
            .binary,
            'audio',
            requestId,
            'audio/x-wav',
            BinaryMessageBody(audioChunk),
          );
          _channel?.sink.add(serializeBinaryConnectionMessage(audioChunkMessage));
          if (_debug) {
            debugPrint('>>> SENT Audio Chunk (${audioChunk.length} bytes)');
          }
        },
        onError: (e) {
          debugPrint('Mic error: $e');
          stopListening();
        },
        onDone: () {
          debugPrint('Mic stream done; sending end-of-stream.');
          // Send an empty audio message to signal the end of the stream
          final endStreamMessage = SpeechConnectionMessage(
            .binary,
            'audio',
            requestId,
            'audio/x-wav',
            BinaryMessageBody(Uint8List(0)),
          );
          _channel?.sink.add(serializeBinaryConnectionMessage(endStreamMessage));
        },
      );
    } catch (e) {
      debugPrint('startListening exception: $e');
      stopListening();
    }
  }

  Future<void> stopListening() async {
    try {
      await _micService.stop();
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _channel?.sink.close();
      _channel = null;
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      _textClearTimer?.cancel();
      _textClearTimer = null;
    } catch (e) {
      debugPrint('Error stopping: $e');
    } finally {
      _cubit.setListening(false);
    }
  }

  bool isListening() => _cubit.isListening;

  void sendSpeechMessage(SpeechConnectionMessage message, WebSocketChannel channel) {
    if (message.messageType == .binary) {
      final payload = serializeBinaryConnectionMessage(message);
      channel.sink.add(payload);
      if (_debug) {
        debugPrint('>>> SENT SpeechConnectionMessage BINARY (${payload.length} bytes)');
      }
    } else {
      final StringBuffer headerBuilder = StringBuffer();
      for (final entry in message.headers.entries) {
        headerBuilder.write('${entry.key}: ${entry.value}$crlf');
      }
      headerBuilder.write(crlf);
      headerBuilder.write(message.textBody);

      channel.sink.add(headerBuilder.toString());
      if (_debug) {
        debugPrint('>>> SENT SpeechConnectionMessage TEXT');
      }
    }
  }

  Uint8List serializeBinaryConnectionMessage(SpeechConnectionMessage message) {
    if (message.messageType != .binary) {
      throw Exception('Binary serialization is only for MessageType.Binary');
    }

    // 1. Build the header string
    final headerBuilder = StringBuffer();
    final allHeaders = {...message.headers};

    // Get the binary content from BinaryMessageBody
    final binaryContent = message.binaryBody;

    // The service requires Content-Length in the header for binary messages.
    if (binaryContent.isNotEmpty) {
      allHeaders['Content-Length'] = binaryContent.lengthInBytes.toString();
    }

    for (final entry in allHeaders.entries) {
      headerBuilder.write('${entry.key}:${entry.value}$crlf');
    }

    final headerBytes = utf8.encode(headerBuilder.toString());
    final headerLength = headerBytes.length;

    // 2. Create the 2-byte header length prefix (Big-Endian)
    final lengthData = ByteData(2);
    lengthData.setUint16(0, headerLength, .big); // MUST be 2 bytes, Big-Endian

    // 3. Assemble the full payload: [2-byte length] + [header] + [body]
    final fullPayload = BytesBuilder();
    fullPayload.add(lengthData.buffer.asUint8List());
    fullPayload.add(headerBytes);
    if (message.binaryBody.isNotEmpty) {
      fullPayload.add(message.binaryBody);
    }

    return fullPayload.toBytes();
  }

  void _sendTextFrame(String path, String requestId, Map<String, Object?> payload) {
    if (_channel == null) return;

    final bodyContent = jsonEncode(payload);

    final message = SpeechConnectionMessage(
      .text,
      path,
      requestId,
      'application/json; charset=utf-8',
      TextMessageBody(bodyContent),
    );

    sendSpeechMessage(message, _channel!);
  }

  void _sendSpeechConfig(String requestId) {
    final payload = {
      "recognition": "conversation",
      "context": {
        "system": {"name": "FlutterSDK", "version": "1.0.0"},
        "os": kIsWeb
            ? null
            : {"platform": "Flutter", "name": "Dart/Flutter Client", "version": "1.0"},
        "audio": {
          "source": {
            "bitspersample": 16,
            "channelcount": 1,
            "samplerate": 16000,
            "type": "Microphones", // o "Microphone"
            "connectivity": "Unknown",
            "manufacturer": "Flutter",
            "model": "MicService",
          },
        },
      },
    };
    _sendTextFrame('speech.config', requestId, payload);
  }

  void _sendSpeechContext(String requestId) {
    final payload = {
      "phraseDetection": {"mode": "Conversation"},
      "languageId": {
        "mode": _languages.length > 1 ? "DetectContinuous" : "AtStart",
        "languages": _languages,
      },
    };
    _sendTextFrame('speech.context', requestId, payload);
  }

  void _handleIncoming(Object? raw) {
    try {
      if (_debug) {
        debugPrint(
          '<<< RECEIVED: ${raw is String ? raw : (raw is List ? 'binary ${raw.length} bytes' : 'unknown')}',
        );
      }

      if (raw is String) {
        final parsed = _parseTextFrame(raw);
        final path = parsed.headers[Constants.path];

        if (path != null && parsed.body != null && parsed.body!.isNotEmpty) {
          _processJsonResponse(path, parsed.body!);
        } else {
          debugPrint('Text frame with no body or path: headers=${parsed.headers}');
        }
      } else if (raw is List<int>) {
        // Binary frame from server (rare for Azure responses). Convert to bytes and try to decode as text.
        final asString = utf8.decode(raw);
        final parsed = _parseTextFrame(asString);
        final path = parsed.headers[Constants.path];
        if (path != null && parsed.body != null) {
          _processJsonResponse(path, parsed.body!);
        }
      } else {
        debugPrint('Unknown frame type: ${raw.runtimeType}');
      }
    } catch (e, s) {
      debugPrint('HandleIncoming exception: $e\n$s');
    }
  }

  void _processJsonResponse(String path, String jsonBody) {
    try {
      final trimmed = jsonBody.trim();
      if (trimmed.isEmpty) {
        _cubit.reset();
        return;
      }
      final map = jsonDecode(trimmed);

      final response = parseAzureResponse(path, map);
      if (response is SpeechHypothesis) {
        _cubit.updateIntermediateText(response.text);
        _resetClearTimer();
      } else if (response is SpeechPhrase) {
        _cubit.addFinalizedText(response.text);
        _resetClearTimer();
      } else {
        // other events (e.g. recognition started/ended)
        debugPrint('Azure event: ${map['type'] ?? map}');
      }
    } catch (e) {
      debugPrint('processJsonResponse failed: $e; body: $jsonBody');
    }
  }

  _ParsedFrame _parseTextFrame(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final parts = normalized.split('\n\n');
    if (parts.length >= 2) {
      // ignore: avoid-unsafe-collection-methods
      final headerLines = parts[0].split('\n');
      final headers = <String, String>{};
      for (var line in headerLines) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          final k = line.substring(0, idx).trim();
          final v = line.substring(idx + 1).trim();
          headers[k] = v;
        }
      }
      final body = parts.sublist(1).join('\n\n');
      return _ParsedFrame(headers: headers, body: body);
    }
    // no headers? treat whole as body
    return _ParsedFrame(headers: {}, body: raw);
  }

  Uint8List _getWavHeader() {
    // Data for 16kHz, 16-bit, mono
    final sampleRate = 16000;
    final channels = 1;
    final bitsPerSample = 16;
    final byteRate = (sampleRate * channels * bitsPerSample) ~/ 8;

    // Using ByteData for managing endianness (little-endian)
    final buffer = Uint8List(44);
    final view = ByteData.view(buffer.buffer);

    // "RIFF"
    buffer.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
    // File size (set 0 for streaming)
    view.setUint32(4, 0, .little);
    // "WAVE"
    buffer.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]);
    // "fmt " chunk
    buffer.setRange(12, 16, [0x66, 0x6D, 0x74, 0x20]);
    // fmt chunk size (16 for PCM)
    view.setUint32(16, 16, .little);
    // Audio format (1 for PCM)
    view.setUint16(20, 1, .little);
    // Num channels
    view.setUint16(22, channels, .little);
    // Sample rate
    view.setUint32(24, sampleRate, .little);
    // Byte rate
    view.setUint32(28, byteRate, .little);
    // Block align
    view.setUint16(32, (channels * bitsPerSample) ~/ 8, .little);
    // Bits per sample
    view.setUint16(34, bitsPerSample, .little);
    // "data" chunk
    buffer.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]);
    // Data size (set 0 for streaming)
    view.setUint32(40, 0, .little);

    return buffer;
  }

  void _resetClearTimer() {
    if (_textClearTimeout == null) return;

    _textClearTimer?.cancel();
    _textClearTimer = Timer(_textClearTimeout, () {
      _cubit.clearText();
    });
  }
}

class _ParsedFrame {
  final Map<String, String> headers;
  final String? body;

  const _ParsedFrame({required this.headers, this.body});
}
