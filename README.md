# Azure STT Flutter

A Flutter package for real-time Speech-to-Text (transcription) using Microsoft Azure Cognitive Services. This library provides a reactive, stream-based API built to easily integrate speech recognition into your Flutter applications.

## Features

*   **Real-time Transcription**: Receive intermediate results (hypothesis) and finalized text as the user speaks.
*   **Cross-Platform**: Supports Mobile (iOS, Android), Desktop (macOS, Windows, Linux), and Web.
*   **Auto-Silence Timeout**: Automatically clears the text after a configurable period of silence.
*   **Multi-Language & LID**: Supports single-language recognition and multi-language identification (LID).

## Language Identification (LID) Modes

The library supports three main ways to handle spoken languages. Choosing the right mode is critical for performance and accuracy.

### 1. Single Language (Fastest)
This is the **recommended mode for fastest subtitles and real-time feedback**. The engine doesn't spend time identifying the language; it starts transcribing immediately using the provided locale.

**How to use:** Provide only one language in the list.
```dart
// Using Subscription Key (Long-lived)
final azureStt = AzureSpeechToText(
  subscriptionKey: 'YOUR_AZURE_KEY',
  region: 'westeurope',
  languages: ['en-US'],
);

// Optional custom endpoint
final azureSttCustom = AzureSpeechToText(
  subscriptionKey: 'YOUR_AZURE_KEY',
  region: 'westeurope',
  customEndpoint: 'https://stt.your-domain.com',
  languages: ['en-US'],
);

// OR Using Authorization Token (Short-lived)
final azureStt = AzureSpeechToText(
  authorizationToken: 'YOUR_BACKEND_GENERATED_TOKEN',
  region: 'westeurope',
  languages: ['en-US'],
);
```

### 2. At-Start Detection
The service identifies the language(s) talked at the beginning of the audio and then transcribes using that language for the rest of the session. It supports up to **4 candidate languages**.

**Note**: The first few seconds of audio are used for identification, which might introduce a slight initial delay in transcription.

**How to use:** Provide up to 4 languages and set `languageIdMode` to 'AtStart' (default).
```dart
final azureStt = AzureSpeechToText(
  subscriptionKey: '...',
  region: '...',
  languages: ['en-US', 'it-IT', 'es-ES', 'fr-FR'],
  languageIdMode: .atStart, // Default
);
```

### 3. Continuous Detection
The service continuously monitors the audio and can switch the transcription language mid-stream if the speaker changes. It supports up to **10 candidate languages**.

**Note**: This mode is the most flexible but requires the service to constantly evaluate the language, which is best for multi-lingual conversations.

**How to use:** Provide up to 10 languages and set `languageIdMode` to 'Continuous'.
```dart
final azureStt = AzureSpeechToText(
  subscriptionKey: '...',
  region: '...',
  languages: ['en-US', 'it-IT', 'es-ES', 'de-DE', 'pt-PT', 'nb-NO', 'sv-SE', 'uk-UA'],
  languageIdMode: .continuous,
);
```

## Example app

An example app is included in the package:

<p>
  <img src="https://raw.githubusercontent.com/scognito/azure-stt-flutter/main/screenshots/image-01.jpg" width="300">
  <img src="https://raw.githubusercontent.com/scognito/azure-stt-flutter/main/screenshots/image-02.jpg" width="300">
</p>

## Getting Started

### 1. Permissions

**Android**

Add the microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS**

Add the microphone usage description to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for speech recognition.</string>
```

**macOS**

Add the microphone entitlement to `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

## Usage

### Initialization

Initialize the `AzureSpeechToText` instance. 

```dart
final azureStt = AzureSpeechToText(
  subscriptionKey: 'YOUR_AZURE_KEY', // Or authorizationToken: '...'
  region: 'westeurope',
  languages: ['en-US'],
  textClearTimeout: const Duration(seconds: 2),
);
```

### Listening to Updates

The library exposes a `transcriptionStateStream` which emits `TranscriptionState` updates. When using LID, the `detectedLanguage` field will contain the identified locale.

```dart
StreamBuilder<TranscriptionState>(
  stream: azureStt.transcriptionStateStream,
  builder: (context, snapshot) {
    final state = snapshot.data;
    if (state == null) return SizedBox();

    return Column(
      children: [
        if (state.detectedLanguage != null)
          Text('Language: ${state.detectedLanguage}'),
        // Combined text (finalized + intermediate)
        Text(state.text),

        // Or access them separately
        // Text(state.intermediateText), // Changing hypothesis
        // Text(state.finalizedText.join(' ')), // Confirmed sentences
      ],
    );
  },
)
```

### Controls

```dart
// Start listening
await azureStt.startListening()

// Stop listening
azureStt.stopListening()

// Check if listening
azureStt.isListening()

// Dispose when done
azureStt.dispose()
```

## Architecture

The library is built using the **BLoC/Cubit** pattern to manage the state of the transcription.

### TranscriptionCubit
The central state manager. It processes events from the Azure Service and emits `TranscriptionState`.

### TranscriptionState
An immutable object containing:
*   **`intermediateText`**: The real-time, changing text (hypothesis) that Azure sends while you are speaking.
*   **`finalizedText`**: A list of completed sentences (phrases) that Azure has confirmed.
*   **`text`**: A helper field that combines finalized and intermediate text for easier display.
*   **`detectedLanguage`**: The BCP-47 locale detected by the service (when using LID).
*   **`isListening`**: A boolean indicating if the microphone is active.

## Authentication

The library handles authentication differently depending on the platform due to browser limitations.

### Mobile & Desktop
*   **Mechanism**: The library uses the Subscription Key to get a short-lived **Access Token** from Azure.
*   **Connection**: It connects to the Azure WebSocket URL, passing this token in the **HTTP Authorization Header** (`Authorization: Bearer <token>`). This is the standard, secure way.

### Web
*   **Limitation**: Standard browser WebSocket APIs do not allow setting custom HTTP headers during the handshake.
*   **Solution**: The library passes authentication via URL Query Parameters.
*   **Security**: For Web, it is **strongly recommended** to use `authorizationToken` instead of `subscriptionKey`. You should generate these short-lived tokens on your backend to avoid exposing your permanent key in the browser URL.

### Short lived token creation example
```
curl -v -X POST \
"https://eastus.api.cognitive.microsoft.com/sts/v1.0/issueToken" \
-H "Content-type: application/x-www-form-urlencoded" \
-H "Content-Length: 0" \
-H "Ocp-Apim-Subscription-Key: YourSpeechResourceKey"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
