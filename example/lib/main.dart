import 'dart:typed_data';

import 'package:azure_stt_flutter/azure_speech_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';

import 'stt_screen.dart';
import 'translation_screen.dart';
import 'tts_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azure Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AzureSpeechToTextExample(),
    );
  }
}

class AzureSpeechToTextExample extends StatefulWidget {
  const AzureSpeechToTextExample({super.key});

  @override
  State<AzureSpeechToTextExample> createState() =>
      _AzureSpeechToTextExampleState();
}

class _AzureSpeechToTextExampleState extends State<AzureSpeechToTextExample> {
  late AzureSpeechToText _sttService;
  late AzureTextToSpeech _ttsService;
  late AzureSpeechTranslation _translationService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _currentLanguage = 'en-US';
  String _translationFromLanguage = 'en-US';
  String _translationToLanguage = 'it';
  int _selectedIndex = 0;

  String get _region => dotenv.env['AZURE_REGION']!;
  String get _subscriptionKey => dotenv.env['AZURE_SUBSCRIPTION_KEY']!;

  @override
  void initState() {
    super.initState();
    _initAzureServices();
  }

  void _initAzureServices() {
    List<String> languages = [_currentLanguage];
    LanguageIdMode languageIdMode = LanguageIdMode.atStart;

    if (_currentLanguage == 'autodetect') {
      languages = ['it', 'es-ES', 'nl-NL', 'en-US'];
    } else if (_currentLanguage == 'continuous') {
      languages = [
        'en-US',
        'it-IT',
        'es-ES',
        'nl-NL',
        'mk-MK',
        'de-DE',
        'pt-PT',
        'nb-NO',
        'sv-SE',
        'uk-UA',
      ];
      languageIdMode = LanguageIdMode.continuous;
    }

    final config = AzureSpeechConfig.subscriptionKey(
      region: _region,
      key: _subscriptionKey,
    );

    _sttService = AzureSpeechToText(
      config: config,
      sttConfig: SpeechToTextConfig(
        languages: languages,
        languageIdMode: languageIdMode,
      ),
    );
    _ttsService = AzureTextToSpeech(config: config);
    _translationService = AzureSpeechTranslation(
      debug: true,
      config: config,
      translationConfig: TranslationConfig(
        fromLanguage: _translationFromLanguage,
        toLanguages: [_translationToLanguage],
      ),
    );
  }

  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage == null || newLanguage == _currentLanguage) return;
    _sttService.dispose();
    setState(() {
      _currentLanguage = newLanguage;
      _initAzureServices();
    });
  }

  void _onTranslationFromChanged(String? newLanguage) {
    if (newLanguage == null || newLanguage == _translationFromLanguage) return;
    _translationService.dispose();
    setState(() {
      _translationFromLanguage = newLanguage;
      _initAzureServices();
    });
  }

  void _onTranslationToChanged(String? newLanguage) {
    if (newLanguage == null || newLanguage == _translationToLanguage) return;
    _translationService.dispose();
    setState(() {
      _translationToLanguage = newLanguage;
      _initAzureServices();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _sttService.dispose();
    _translationService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      BlocProvider.value(
        value: _sttService.cubit,
        child: SttScreen(
          sttService: _sttService,
          selectedLanguage: _currentLanguage,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
      TtsScreen(ttsService: _ttsService, audioPlayer: _audioPlayer),
      BlocProvider.value(
        value: _translationService.cubit,
        child: TranslationScreen(
          translationService: _translationService,
          fromLanguage: _translationFromLanguage,
          toLanguage: _translationToLanguage,
          onFromLanguageChanged: _onTranslationFromChanged,
          onToLanguageChanged: _onTranslationToChanged,
        ),
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'STT'),
          BottomNavigationBarItem(icon: Icon(Icons.volume_up), label: 'TTS'),
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF2E3192),
      ),
    );
  }
}

class MyCustomSource extends StreamAudioSource {
  final List<int> _audioBytes;

  MyCustomSource(this._audioBytes) : super(tag: 'MyCustomSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _audioBytes.length;
    return StreamAudioResponse(
      sourceLength: _audioBytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/mpeg',
      stream: Stream.value(Uint8List.fromList(_audioBytes.sublist(start, end))),
    );
  }
}
