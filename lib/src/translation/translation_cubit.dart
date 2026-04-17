import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'translation_state.dart';

class TranslationCubit extends Cubit<TranslationState> {
  TranslationCubit() : super(const TranslationState());

  void setListening(bool listening) {
    emit(state.copyWith(isListening: listening));
  }

  void updateIntermediate({
    required String recognizedText,
    required Map<String, String> translations,
    String? detectedLanguage,
  }) {
    emit(
      state.copyWith(
        recognizedText: recognizedText,
        translations: translations,
        detectedLanguage: _Value(detectedLanguage),
        error: const _Clear(),
        isListening: true,
      ),
    );
  }

  void addFinalized({
    required String recognizedText,
    required Map<String, String> translations,
    String? detectedLanguage,
  }) {
    emit(
      state.copyWith(
        recognizedText: recognizedText,
        translations: translations,
        detectedLanguage: _Value(detectedLanguage),
        error: const _Clear(),
        isListening: true,
      ),
    );
  }

  void emitError(String message) {
    emit(state.copyWith(isListening: false, error: _Value(message)));
  }

  bool get isListening => state.isListening;

  void reset() {
    clearText();
    emit(state.copyWith(isListening: false));
  }

  void clearText() {
    emit(
      state.copyWith(
        recognizedText: '',
        translations: {},
        detectedLanguage: const _Clear(),
        error: const _Clear(),
      ),
    );
  }
}
