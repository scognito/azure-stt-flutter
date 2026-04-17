import 'package:azure_stt_flutter/azure_speech_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'widgets/azure_app_bar.dart';

class TranslationScreen extends StatelessWidget {
  final AzureSpeechTranslation translationService;
  final String fromLanguage;
  final String toLanguage;
  final ValueChanged<String?> onFromLanguageChanged;
  final ValueChanged<String?> onToLanguageChanged;

  const TranslationScreen({
    required this.translationService,
    required this.fromLanguage,
    required this.toLanguage,
    required this.onFromLanguageChanged,
    required this.onToLanguageChanged,
  });

  static const _fromLanguages = {
    'en-US': 'English',
    'it-IT': 'Italian',
    'es-ES': 'Spanish',
    'fr-FR': 'French',
    'de-DE': 'German',
    'pt-PT': 'Portuguese',
    'nl-NL': 'Dutch',
    'uk-UA': 'Ukrainian',
  };

  static const _toLanguages = {
    'it': 'Italian',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'nl': 'Dutch',
    'uk': 'Ukrainian',
    'ja': 'Japanese',
    'zh-Hans': 'Chinese (Simplified)',
    'ar': 'Arabic',
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
        child: BlocBuilder<TranslationCubit, TranslationState>(
          builder: (context, state) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    AzureAppBar(),
                    _LanguageRow(
                      fromLanguage: fromLanguage,
                      toLanguage: toLanguage,
                      fromLanguages: _fromLanguages,
                      toLanguages: _toLanguages,
                      onFromChanged: state.isListening
                          ? null
                          : onFromLanguageChanged,
                      onToChanged: state.isListening
                          ? null
                          : onToLanguageChanged,
                    ),
                    Expanded(
                      child: state.recognizedText.isEmpty && !state.isListening
                          ? Center(
                              child: Text(
                                'Press the mic button to start\nlive translation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withAlpha(204),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            )
                          : _TranslationCards(
                              state: state,
                              toLanguage: toLanguage,
                            ),
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        child: Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: FloatingActionButton.large(
                        onPressed: () {
                          if (translationService.isListening) {
                            translationService.stop();
                          } else {
                            translationService.start();
                          }
                        },
                        backgroundColor: state.isListening
                            ? Colors.redAccent
                            : Colors.white,
                        foregroundColor: state.isListening
                            ? Colors.white
                            : Colors.blueAccent,
                        child: Icon(
                          state.isListening ? Icons.stop : Icons.translate,
                        ),
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

class _LanguageRow extends StatelessWidget {
  final String fromLanguage;
  final String toLanguage;
  final Map<String, String> fromLanguages;
  final Map<String, String> toLanguages;
  final ValueChanged<String?>? onFromChanged;
  final ValueChanged<String?>? onToChanged;

  const _LanguageRow({
    required this.fromLanguage,
    required this.toLanguage,
    required this.fromLanguages,
    required this.toLanguages,
    required this.onFromChanged,
    required this.onToChanged,
  });

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?>? onChanged,
    required String label,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(178),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF2E3192),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: onChanged,
                items: items.entries.map((e) {
                  return DropdownMenuItem<T>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _dropdown(
            value: fromLanguage,
            items: fromLanguages,
            onChanged: onFromChanged,
            label: 'FROM',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: Icon(
              Icons.arrow_forward,
              color: Colors.white.withAlpha(178),
              size: 20,
            ),
          ),
          _dropdown(
            value: toLanguage,
            items: toLanguages,
            onChanged: onToChanged,
            label: 'TO',
          ),
        ],
      ),
    );
  }
}

class _TranslationCards extends StatelessWidget {
  final TranslationState state;
  final String toLanguage;

  const _TranslationCards({required this.state, required this.toLanguage});

  @override
  Widget build(BuildContext context) {
    final translatedText =
        state.translations[toLanguage] ??
        state.translations.values.firstOrNull ??
        '';

    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(text: state.recognizedText, isSource: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Icon(
                Icons.keyboard_double_arrow_down_rounded,
                color: Colors.white.withAlpha(178),
                size: 28,
              ),
            ),
            _card(text: translatedText, isSource: false),
          ],
        ),
      ),
    );
  }

  Widget _card({required String text, required bool isSource}) {
    return AnimatedOpacity(
      opacity: text.isEmpty ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: isSource
              ? Colors.black.withAlpha(102)
              : Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSource
                ? Colors.white.withAlpha(40)
                : Colors.white.withAlpha(80),
            width: isSource ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: text.isEmpty
            ? Center(
                child: Text(
                  isSource ? 'Listening…' : 'Waiting for translation…',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSource ? 22 : 26,
                  fontWeight: isSource ? FontWeight.w400 : FontWeight.w600,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
      ),
    );
  }
}
