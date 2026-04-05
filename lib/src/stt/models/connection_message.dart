import 'dart:convert';
import 'dart:typed_data';

import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:uuid/uuid.dart';

enum MessageType { text, binary }

class ConnectionMessage {
  static final _uuid = Uuid();

  final MessageType _messageType;
  final Map<String, dynamic> _headers;
  final MessageBody? _body;
  final String _id;
  final int _size;

  ConnectionMessage(
    this._messageType,
    MessageBody? body, {
    Map<String, dynamic>? headers,
    String? id,
  }) : _body = body,
       _headers = headers ?? {},
       _id = id ?? _uuid.v4().replaceAll('-', ''),
       _size = _calculateSize(body) {
    if (_messageType == MessageType.text && body != null && body is! TextMessageBody) {
      throw InvalidOperationError('Payload must be String (MessageType.text)');
    }

    if (_messageType == MessageType.binary && body != null && body is! BinaryMessageBody) {
      throw InvalidOperationError('Payload must be Uint8List (MessageType.binary)');
    }
  }

  static int _calculateSize(MessageBody? body) {
    if (body == null) return 0;

    return switch (body) {
      TextMessageBody(:final content) => utf8.encode(content).length,
      BinaryMessageBody(:final content) => content.lengthInBytes,
    };
  }

  MessageType get messageType => _messageType;

  Map<String, dynamic> get headers => Map.unmodifiable(_headers);

  MessageBody? get body => _body;

  String get textBody {
    if (_messageType == .binary) {
      throw InvalidOperationError('Not supported for message type binary');
    }
    return (_body as TextMessageBody).content;
  }

  Uint8List get binaryBody {
    if (_messageType == .text) {
      throw InvalidOperationError('Not supported for message type text');
    }
    return (_body as BinaryMessageBody).content;
  }

  String get id => _id;

  int get size => _size;
}

sealed class MessageBody {
  const MessageBody();
}

class TextMessageBody extends MessageBody {
  final String content;

  const TextMessageBody(this.content);
}

class BinaryMessageBody extends MessageBody {
  final Uint8List content;

  const BinaryMessageBody(this.content);
}
