import 'package:equatable/equatable.dart';

class TtsRequest extends Equatable {
  final String text;
  final TtsVoice voice;
  final AudioOutputFormat outputFormat;

  const TtsRequest({
    required this.text,
    required this.voice,
    this.outputFormat = AudioOutputFormat.audio16khz128kbitrateMonoMp3,
  });

  String toSsml() {
    return '''
<speak version='1.0' xml:lang='${voice.locale}'>
    <voice xml:lang='${voice.locale}' xml:gender='${voice.gender}' name='${voice.name}'>
        $text
    </voice>
</speak>
''';
  }

  @override
  List<Object?> get props => [text, voice, outputFormat];
}

enum AudioOutputFormat {
  /// Raw 8khz 8bit mono mulaw
  raw8khz8bitMonoMulaw('raw-8khz-8bit-mono-mulaw'),

  /// Raw 8khz 8bit mono pcm
  raw8khz8bitMonoPcm('raw-8khz-8bit-mono-pcm'),

  /// Raw 16khz 16bit mono pcm
  raw16khz16bitMonoPcm('raw-16khz-16bit-mono-pcm'),

  /// Riff 8khz 8bit mono mulaw
  riff8khz8bitMonoMulaw('riff-8khz-8bit-mono-mulaw'),

  /// Riff 8khz 8bit mono pcm
  riff8khz8bitMonoPcm('riff-8khz-8bit-mono-pcm'),

  /// Riff 16khz 16bit mono pcm
  riff16khz16bitMonoPcm('riff-16khz-16bit-mono-pcm'),

  /// Audio 16khz 128kbitrate mono mp3
  audio16khz128kbitrateMonoMp3('audio-16khz-128kbitrate-mono-mp3'),

  /// Audio 16khz 64kbitrate mono mp3
  audio16khz64kbitrateMonoMp3('audio-16khz-64kbitrate-mono-mp3'),

  /// Audio 16khz 32kbitrate mono mp3
  audio16khz32kbitrateMonoMp3('audio-16khz-32kbitrate-mono-mp3'),

  /// Audio 24khz 160kbitrate mono mp3
  audio24khz160kbitrateMonoMp3('audio-24khz-160kbitrate-mono-mp3'),

  /// Audio 24khz 96kbitrate mono mp3
  audio24khz96kbitrateMonoMp3('audio-24khz-96kbitrate-mono-mp3'),

  /// Audio 24khz 48kbitrate mono mp3
  audio24khz48kbitrateMonoMp3('audio-24khz-48kbitrate-mono-mp3'),

  /// Audio 48khz 192kbitrate mono mp3
  audio48khz192kbitrateMonoMp3('audio-48khz-192kbitrate-mono-mp3'),

  /// Audio 48khz 128kbitrate mono mp3
  audio48khz128kbitrateMonoMp3('audio-48khz-128kbitrate-mono-mp3'),

  /// Audio 48khz 96kbitrate mono mp3
  audio48khz96kbitrateMonoMp3('audio-48khz-96kbitrate-mono-mp3'),

  /// Ogg 16khz 16bit mono opus
  ogg16khz16bitMonOpus('ogg-16khz-16bit-mono-opus'),

  /// Ogg 24khz 16bit mono opus
  ogg24khz16bitMonOpus('ogg-24khz-16bit-mono-opus'),

  /// Ogg 48khz 16bit mono opus
  ogg48khz16bitMonOpus('ogg-48khz-16bit-mono-opus'),

  /// Webm 16khz 16bit mono opus
  webm16khz16bitMonOpus('webm-16khz-16bit-mono-opus'),

  /// Webm 24khz 16bit mono opus
  webm24khz16bitMonOpus('webm-24khz-16bit-mono-opus'),

  /// Webm 48khz 16bit mono opus
  webm48khz16bitMonOpus('webm-48khz-16bit-mono-opus');

  final String value;

  const AudioOutputFormat(this.value);
}

class TtsVoice extends Equatable {
  final String name;
  final String locale;
  final String localeName;
  final String localName;
  final String gender;
  final String? description;

  const TtsVoice({
    required this.name,
    required this.locale,
    required this.localeName,
    required this.localName,
    required this.gender,
    this.description,
  });

  factory TtsVoice.fromJson(Map<String, dynamic> json) {
    return TtsVoice(
      name: json['ShortName'] as String,
      locale: json['Locale'] as String,
      localeName: json['LocaleName'] as String,
      localName: json['LocalName'] as String,
      gender: json['Gender'] as String,
      description: json['DisplayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'locale': locale,
      'gender': gender,
      'description': description,
      'localeName': localeName,
      'localName': localName,
    };
  }

  @override
  List<Object?> get props => [name, locale, localName, localeName, gender, description];
}
