import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'transcription_state.dart';

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit() : super(const TranscriptionState());

  void setListening(bool listening) {
    emit(state.copyWith(isListening: listening));
  }

  void updateIntermediateText(String text, {String? language}) {
    emit(
      state.copyWith(
        intermediateText: text,
        finalizedText: [],
        text: text,
        detectedLanguage: _Value(language),
        error: const _Clear(),
      ),
    );
  }

  void addFinalizedText(String text, {String? language}) {
    if (text.isNotEmpty) {
      final updatedList = List.of(state.finalizedText)..add(text);
      emit(
        state.copyWith(
          finalizedText: updatedList,
          intermediateText: '',
          text: updatedList.join(),
          detectedLanguage: _Value(language),
          error: const _Clear(),
        ),
      );
    } else {
      emit(state.copyWith(intermediateText: '', text: ''));
    }
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
        intermediateText: '',
        finalizedText: [],
        text: '',
        detectedLanguage: const _Clear(),
        error: const _Clear(),
      ),
    );
  }
}
