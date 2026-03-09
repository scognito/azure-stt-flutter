import 'package:azure_stt_flutter/src/cubit/transcription_cubit.dart';
import 'package:azure_stt_flutter/src/services/azure_stt_service.dart';
import 'package:azure_stt_flutter/src/services/microphone_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMicrophoneService extends Mock implements MicrophoneService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AzureSttService Validation', () {
    final cubit = TranscriptionCubit();
    final micService = MockMicrophoneService();

    test('AtStart mode with 4 languages should succeed', () {
      final service = AzureSttService(
        subscriptionKey: 'key',
        region: 'region',
        languages: ['en-US', 'es-ES', 'fr-FR', 'de-DE'],
        languageIdMode: .atStart,
        cubit: cubit,
        micService: micService,
      );

      expect(service, isA<AzureSttService>());
    });

    test('AtStart mode with 5 languages should fail', () {
      expect(
        () => AzureSttService(
          subscriptionKey: 'key',
          region: 'region',
          languages: ['en-US', 'es-ES', 'fr-FR', 'de-DE', 'it-IT'],
          languageIdMode: .atStart,
          cubit: cubit,
          micService: micService,
        ),
        throwsAssertionError,
      );
    });

    test('DetectContinuous mode with 10 languages should succeed', () {
      final service = AzureSttService(
        subscriptionKey: 'key',
        region: 'region',
        languages: List.generate(10, (i) => 'lang-$i'),
        languageIdMode: .detectContinuous,
        cubit: cubit,
        micService: micService,
      );

      expect(service, isA<AzureSttService>());
    });

    test('DetectContinuous mode with 11 languages should fail', () {
      expect(
        () => AzureSttService(
          subscriptionKey: 'key',
          region: 'region',
          languages: List.generate(11, (i) => 'lang-$i'),
          languageIdMode: .detectContinuous,
          cubit: cubit,
          micService: micService,
        ),
        throwsAssertionError,
      );
    });
  });
}
