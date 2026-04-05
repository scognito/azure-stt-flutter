class Constants {
  static const packageName = 'azure-speech-flutter';
  static const defaultLang = 'en-US';

  static const int audioSampleRate = 16000;
  static const int audioChannels = 1;
  static const int audioBitsPerSample = 16;

  // Headers
  static const String authKey = 'Ocp-Apim-Subscription-Key';
  static const String authorization = 'Authorization';
  static const String connectionId = 'X-ConnectionId';
  static const String contentType = 'Content-Type';
  static const String path = 'Path';
  static const String language = 'Language';
  static const String format = 'Format';
  static const String userAgent = 'User-Agent';
  static const String requestId = 'X-RequestId';
  static const String requestTimestamp = 'X-Timestamp';
  static const String outputFormat = 'X-Microsoft-OutputFormat';
  static const String lidEnabled = 'lidEnabled';
}
