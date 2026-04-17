part of 'translation_cubit.dart';

sealed class _Nullable<T> {
  const _Nullable();
}

final class _Clear<T> extends _Nullable<T> {
  const _Clear();
}

final class _Value<T> extends _Nullable<T> {
  final T? value;
  const _Value(this.value);
}

@immutable
final class TranslationState extends Equatable {
  final String recognizedText;
  final Map<String, String> translations;
  final bool isListening;
  final String? detectedLanguage;
  final String? error;

  const TranslationState({
    this.recognizedText = '',
    this.translations = const {},
    this.isListening = false,
    this.detectedLanguage,
    this.error,
  });

  TranslationState copyWith({
    String? recognizedText,
    Map<String, String>? translations,
    bool? isListening,
    _Nullable<String>? detectedLanguage,
    _Nullable<String>? error,
  }) {
    return TranslationState(
      recognizedText: recognizedText ?? this.recognizedText,
      translations: translations ?? this.translations,
      isListening: isListening ?? this.isListening,
      detectedLanguage: switch (detectedLanguage) {
        _Clear() => null,
        _Value(:final value) => value,
        null => this.detectedLanguage,
      },
      error: switch (error) {
        _Clear() => null,
        _Value(:final value) => value,
        null => this.error,
      },
    );
  }

  @override
  List<Object?> get props => [recognizedText, translations, isListening, detectedLanguage, error];
}
