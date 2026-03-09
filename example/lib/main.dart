import 'dart:async';

import 'package:azure_stt_flutter/azure_stt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AzureSpeechToText? _azureSpeechToText;
  String _currentLanguage = 'en-US';

  @override
  void initState() {
    super.initState();
    _initAzureStt();
  }

  void _initAzureStt() {
    _azureSpeechToText?.dispose();
    _azureSpeechToText = AzureSpeechToText(
      subscriptionKey: dotenv.env['AZURE_SUBSCRIPTION_KEY']!,
      region: dotenv.env['AZURE_REGION']!,
      languages: [_currentLanguage],
      debug: true,
    );
  }

  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _currentLanguage) {
      setState(() {
        _currentLanguage = newLanguage;
        _initAzureStt();
      });
    }
  }

  @override
  void dispose() {
    _azureSpeechToText?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider<AzureSpeechToText>.value(
      value: _azureSpeechToText!,
      child: MaterialApp(
        title: 'Azure STT Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: TranscriptionPage(
          selectedLanguage: _currentLanguage,
          onLanguageChanged: _onLanguageChanged,
        ),
      ),
    );
  }
}

class TranscriptionPage extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;

  const TranscriptionPage({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  static const _languages = {
    'en-US': 'English',
    'it-IT': 'Italian',
    'nl-NL': 'Dutch',
    'es-ES': 'Spanish',
    'mk-MK': 'Macedonian',
  };

  @override
  Widget build(BuildContext context) {
    final azureStt = Provider.of<AzureSpeechToText>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          ),
        ),
        child: StreamBuilder<TranscriptionState>(
          stream: azureStt.transcriptionStateStream,
          initialData: const TranscriptionState(),
          builder: (context, snapshot) {
            final state = snapshot.data!;
            return SafeArea(
              child: Column(
                children: [
                  _buildAppBar(state.isListening),
                  Expanded(
                    child: Stack(
                      children: [
                        if (state.text.isEmpty && !state.isListening)
                          Center(
                            child: Text(
                              'Press the mic button to start\nreal-time transcription.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withAlpha(204),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        if (state.text.isNotEmpty)
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(153),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(51),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(51),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  state.text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: FloatingActionButton.large(
                      onPressed: () {
                        if (state.isListening) {
                          azureStt.stopListening();
                        } else {
                          azureStt.startListening();
                        }
                      },
                      backgroundColor: state.isListening
                          ? Colors.redAccent
                          : Colors.white,
                      foregroundColor: state.isListening
                          ? Colors.white
                          : Colors.blueAccent,
                      child: Icon(state.isListening ? Icons.stop : Icons.mic),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isListening) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Azure STT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedLanguage,
                dropdownColor: const Color(0xFF2E3192),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onChanged: isListening ? null : onLanguageChanged,
                items: _languages.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
