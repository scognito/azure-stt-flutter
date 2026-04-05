class AzureSpeechConfig {
  final String region;
  final String? subscriptionKey;
  final String? authorizationToken;

  const AzureSpeechConfig.subscriptionKey({required this.region, required String key})
    : subscriptionKey = key,
      authorizationToken = null;

  const AzureSpeechConfig.authorizationToken({required this.region, required String token})
    : authorizationToken = token,
      subscriptionKey = null;
}
