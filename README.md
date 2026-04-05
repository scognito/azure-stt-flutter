# Azure Speech Flutter

A Flutter package for real-time **Speech-to-Text** (STT) and **Text-to-Speech** (TTS) using Microsoft Azure Cognitive Services. No Azure SDK binary dependency: it communicates directly with the Azure WebSocket/REST APIs.

*   **STT**: Stream-based real-time transcription with intermediate (hypothesis) and finalized results, multi-language identification (LID), and auto-silence timeout.
*   **TTS**: Synthesize text to audio bytes using any Azure Neural voice, with configurable output format.
*   **Cross-platform**: Mobile (iOS, Android), Desktop (macOS, Windows, Linux), and Web.

## Example app

<p>
  <img src="https://raw.githubusercontent.com/scognito/azure-stt-flutter/main/screenshots/image-01.jpg" width="300">
  <img src="https://raw.githubusercontent.com/scognito/azure-stt-flutter/main/screenshots/image-02.jpg" width="300">
</p>

---

## Getting Started

### Installation

```dart
import 'package:azure_stt_flutter/azure_speech_flutter.dart';
```

### Authentication

Both STT and TTS use the same `AzureSpeechConfig`. You must provide exactly one credential:

```dart
// Option A: Subscription Key
final config = AzureSpeechConfig.subscriptionKey(
  region: 'westeurope', // or other supported region
  key: 'YOUR_AZURE_KEY',
);

// Option B: Short-lived Authorization Token (recommended for Web)
final config = AzureSpeechConfig.authorizationToken(
  region: 'westeurope', // or other supported region
  token: 'YOUR_BACKEND_GENERATED_TOKEN',
);
```

**Web security note**: Browser WebSocket APIs cannot set custom HTTP headers. On Web, auth is passed as a URL query parameter. Always use `authorizationToken` (generated server-side) on Web: never expose `subscriptionKey` in the browser URL.

To generate a short-lived token:
```sh
curl -X POST \
  "https://westeurope.api.cognitive.microsoft.com/sts/v1.0/issueToken" \
  -H "Content-Length: 0" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY"
```

---

## Speech-to-Text (STT)

### Permissions

STT requires microphone access. TTS does not.

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for speech recognition.</string>
```

**macOS** — `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

### Basic usage

```dart
final azureStt = AzureSpeechToText(
  config: AzureSpeechConfig.subscriptionKey(
    region: 'westeurope', // or other supported region
    key: 'YOUR_AZURE_KEY',
  ),
  sttConfig: SpeechToTextConfig(
    languages: ['en-US'],
    textClearTimeout: const Duration(seconds: 2),
  ),
);

// Start / stop
await azureStt.start();
await azureStt.stop();

// Check state
azureStt.isListening;

// Dispose when done
await azureStt.dispose();
```

### Listening to transcription updates

`azureStt.stream` emits `TranscriptionState` on every change:

```dart
StreamBuilder<TranscriptionState>(
  stream: azureStt.stream,
  builder: (context, snapshot) {
    final state = snapshot.data ?? const TranscriptionState();

    if (state.error != null) return Text('Error: ${state.error}');

    return Column(
      children: [
        if (state.detectedLanguage != null)
          Text('Detected: ${state.detectedLanguage}'),
        // Combined text (finalized + intermediate)
        Text(state.text),
        // state.intermediateText // live hypothesis (no punctuation)
        // state.finalizedText   // list of confirmed sentences
        // state.isListening     // mic active
      ],
    );
  },
)
```

### Using the BLoC cubit

`AzureSpeechToText` owns a `TranscriptionCubit`. Provide it higher in the widget tree to avoid rebuilding the whole subtree:

```dart
BlocProvider.value(
  value: azureStt.cubit,
  child: MyWidget(),
)

// Then in a descendant:
BlocBuilder<TranscriptionCubit, TranscriptionState>(
  builder: (context, state) => Text(state.text),
)
```

### Language Identification (LID)

The number of languages you provide determines the mode automatically:

|  Mode | Languages count |
|---|-----------------|
|Single language (fastest) | 1               |
| At-Start LID | 1 - 4           |
| Continuous LID | 1 - 10          |

Bare language codes are expanded automatically (`"it"` → `"it-IT"`).

```dart
// Single language: fastest, no identification overhead
SpeechToTextConfig(languages: ['en-US'])

// At-Start: identifies once at the beginning of the session
SpeechToTextConfig(
  languages: ['en-US', 'it', 'es-ES', 'fr-FR'],
  languageIdMode: .atStart, // default
)

// Continuous: re-identifies throughout the session, up to 10 languages
SpeechToTextConfig(
  languages: ['en-US', 'it-IT', 'es-ES', 'de-DE', 'pt-PT', 'nb-NO', 'sv-SE', 'uk-UA'],
  languageIdMode: .continuous,
)
```

### External audio stream

To bypass the microphone (e.g. VoIP or file audio), inject your own stream. It must emit raw PCM: 16 kHz, mono, 16-bit little-endian.

```dart
await azureStt.start(); // uses mic by default
// or pass an external stream via the service layer (see AzureSttService.startListening)
```

---

## Text-to-Speech (TTS)

No microphone permissions required.

### Basic usage

```dart
final azureTts = AzureTextToSpeech(
  config: AzureSpeechConfig.subscriptionKey(
    region: 'westeurope', // or other supported region
    key: 'YOUR_AZURE_KEY',
  ),
);

// 1. Fetch available voices
final voices = await azureTts.listVoices();

// 2. Pick a voice
final voice = voices.firstWhere(
  (v) => v.locale == 'en-US' && v.gender == 'Female',
  orElse: () => voices.first,
);

// 3. Synthesize: returns raw audio bytes
final audioBytes = await azureTts.synthesize(
  TtsRequest(
    text: 'Hello from Azure Speech Flutter!',
    voice: voice,
    outputFormat: .audio16khz128kbitrateMonoMp3, // default
  ),
);
```

### Output formats

`AudioOutputFormat` covers MP3, PCM, mulaw, Opus, and WebM at various sample rates and bitrates. The default is `audio16khz128kbitrateMonoMp3`.

### Playing the audio

The package returns raw bytes. Plug them into any audio player. Example with [`just_audio`](https://pub.dev/packages/just_audio):

```dart
class _BytesAudioSource extends StreamAudioSource {
  final List<int> bytes;
  _BytesAudioSource(this.bytes) : super(tag: 'tts');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/mpeg',
      stream: Stream.value(Uint8List.fromList(bytes.sublist(start, end))),
    );
  }
}

final player = AudioPlayer();
await player.setAudioSource(_BytesAudioSource(audioBytes));
await player.play();
```

### Voice metadata

Each `TtsVoice` exposes:

| Field | Description |
|---|---|
| `name` | Azure short name (e.g. `en-US-JennyNeural`) |
| `locale` | BCP-47 locale (e.g. `en-US`) |
| `localeName` | Locale display name (e.g. `English (United States)`) |
| `localName` | Voice display name in its own language |
| `gender` | `"Male"` or `"Female"` |

---

## License

MIT. See [LICENSE](LICENSE).
