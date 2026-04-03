# 0.0.9

- Added optional `externalAudioStream` parameter to `startListening()`, allowing callers to supply their own audio source (e.g. a VoIP call or a file) instead of the device microphone
- The stream must provide raw PCM audio: 16 kHz sample rate, mono channel, 16-bit little-endian — the same format the microphone produces
- When `externalAudioStream` is `null`, behaviour is identical to previous versions

# 0.0.8

- Added `LanguageUtils` class with `getSupportedLanguages()` and `maximizeLocale()` methods
- Language codes are now automatically sanitized to `languageCode-countryCode` format (e.g., "en" → "en-US")

# 0.0.7

- Updated screenshots

# 0.0.6
- It is now possible to use short-lived token instead of subscription key using the "authorizationToken" parameter

# 0.0.5
- Added support for Continuous or At-Start modes
- **BREAKING CHANGE** : the String parameter "language" is now a list of String named "languages" 

# 0.0.4
- Changed screenshots

# 0.0.3
- Added screenshots

# 0.0.2

- Minor updates to documentation

# 0.0.1

- Initial Version of the library
