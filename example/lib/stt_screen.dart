import 'package:azure_stt_flutter/azure_speech_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/azure_app_bar.dart';

class SttScreen extends StatelessWidget {
  final AzureSpeechToText sttService;
  final String selectedLanguage;
  final ValueChanged<String?> onLanguageChanged;

  const SttScreen({
    required this.sttService,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  static const _languages = {
    'en-US': 'English',
    'it': 'Italian',
    'nl-NL': 'Dutch',
    'es-ES': 'Spanish',
    'autodetect': 'At Start (IT, ES, NL, EN)',
    'continuous': 'Continuous (10 Languages)',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
          ),
        ),
        child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
          builder: (context, state) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    AzureAppBar(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLanguage,
                          dropdownColor: const Color(0xFF2E3192),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          onChanged: state.isListening
                              ? null
                              : onLanguageChanged,
                          items: _languages.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
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
                          if (sttService.isListening) {
                            sttService.stop();
                          } else {
                            sttService.start();
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
              ),
            );
          },
        ),
      ),
    );
  }
}
