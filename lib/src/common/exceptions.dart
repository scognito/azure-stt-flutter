import 'package:http/http.dart' as http;

class AzureSpeechException implements Exception {
  final int statusCode;
  final String body;

  AzureSpeechException(this.statusCode, this.body);

  @override
  String toString() => 'AzureSpeechException($statusCode): $body';
}

class AzureTtsException extends AzureSpeechException {
  AzureTtsException(http.Response res) : super(res.statusCode, res.body);
}

class InvalidOperationError implements Exception {
  final String message;

  const InvalidOperationError(this.message);

  @override
  String toString() => 'InvalidOperationError: $message';
}

class ArgumentNullError implements Exception {
  final String message;

  const ArgumentNullError(this.message);

  @override
  String toString() => 'ArgumentNullError: Argument not found: $message';
}
