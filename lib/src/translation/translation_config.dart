import 'package:azure_stt_flutter/src/utils/language_utils.dart';

class TranslationConfig {
  final String fromLanguage;
  final List<String> toLanguages;
  final Duration textClearTimeout;

  final String sanitizedFromLanguage;
  final List<String> sanitizedToLanguages;

  TranslationConfig({
    required String fromLanguage,
    required List<String> toLanguages,
    this.textClearTimeout = const Duration(seconds: 1),
  }) : assert(toLanguages.isNotEmpty, 'toLanguages must not be empty'),
       fromLanguage = fromLanguage,
       toLanguages = List.unmodifiable(toLanguages),
       sanitizedFromLanguage = LanguageUtils.maximizeLocale(fromLanguage),
       sanitizedToLanguages = List.unmodifiable(toLanguages.map(LanguageUtils.maximizeLocale));
}
