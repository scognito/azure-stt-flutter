part of 'transcription_cubit.dart';

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
final class TranscriptionState extends Equatable {
  final String intermediateText;
  final List<String> finalizedText;
  final String text;
  final bool isListening;
  final String? detectedLanguage;
  final String? error;

  const TranscriptionState({
    this.intermediateText = '',
    this.finalizedText = const [],
    this.text = '',
    this.isListening = false,
    this.detectedLanguage,
    this.error,
  });

  TranscriptionState copyWith({
    String? intermediateText,
    List<String>? finalizedText,
    String? text,
    bool? isListening,
    _Nullable<String>? detectedLanguage,
    _Nullable<String>? error,
  }) {
    return TranscriptionState(
      intermediateText: intermediateText ?? this.intermediateText,
      finalizedText: finalizedText ?? this.finalizedText,
      text: text ?? this.text,
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
  List<Object?> get props => [
    intermediateText,
    finalizedText,
    text,
    isListening,
    detectedLanguage,
    error,
  ];
}
