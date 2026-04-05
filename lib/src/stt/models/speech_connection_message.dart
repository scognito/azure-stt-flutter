import 'package:azure_stt_flutter/src/common/exceptions.dart';
import 'package:azure_stt_flutter/src/constants.dart';
import 'package:azure_stt_flutter/src/stt/models/connection_message.dart';

class SpeechConnectionMessage extends ConnectionMessage {
  final String _path;
  final String _requestId;
  final String _contentType;

  SpeechConnectionMessage(
    MessageType messageType,
    String path,
    String requestId,
    String contentType,
    MessageBody body,
  ) : _path = path,
      _requestId = requestId,
      _contentType = contentType,
      super(messageType, body, headers: _buildHeaders(path, requestId, contentType)) {
    if (path.isEmpty) throw ArgumentNullError('path');
    if (requestId.isEmpty) throw ArgumentNullError('requestId');
  }

  static Map<String, dynamic> _buildHeaders(String path, String requestId, String contentType) {
    final Map<String, dynamic> headers = {};

    headers[Constants.path] = path;
    headers[Constants.requestId] = requestId;
    headers[Constants.requestTimestamp] = DateTime.now().toUtc().toIso8601String();

    if (contentType.isNotEmpty) {
      headers[Constants.contentType] = contentType;
    }

    return headers;
  }

  String get path => _path;

  String get requestId => _requestId;

  String get contentType => _contentType;
}
