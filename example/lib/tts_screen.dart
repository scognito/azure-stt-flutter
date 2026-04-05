import 'dart:typed_data';

import 'package:azure_stt_flutter/azure_speech_flutter.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'widgets/azure_app_bar.dart';

class TtsScreen extends StatefulWidget {
  final AzureTextToSpeech ttsService;
  final AudioPlayer audioPlayer;

  const TtsScreen({required this.ttsService, required this.audioPlayer});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  late TextEditingController _textEditingController;
  String _textToSpeak = 'Hello, this is a test of Azure Text-to-Speech.';
  TtsVoice? _selectedTtsVoice;
  List<TtsVoice> _availableTtsVoices = [];

  AudioPlayer get _audioPlayer => widget.audioPlayer;
  bool _isLoadingVoices = false;
  bool _isSynthesizing = false;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: _textToSpeak);
    _textEditingController.addListener(() {
      setState(() {
        _textToSpeak = _textEditingController.text;
      });
    });
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _isLoadingVoices = true;
    });
    try {
      final voices = await widget.ttsService.listVoices();
      setState(() {
        _availableTtsVoices = voices;
        _selectedTtsVoice = voices.firstWhere(
          (v) =>
              v.locale == 'en-US' &&
              v.gender == 'Female', // Default to a common voice
          orElse: () => voices.first,
        );
      });
    } catch (e) {
      debugPrint('Error loading voices: $e');
      // Optionally show an error message to the user
    } finally {
      setState(() {
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _synthesizeAndPlay() async {
    if (_selectedTtsVoice == null || _textToSpeak.isEmpty) {
      return;
    }

    setState(() {
      _isSynthesizing = true;
    });

    try {
      final audioBytes = await widget.ttsService.synthesize(
        TtsRequest(text: _textToSpeak, voice: _selectedTtsVoice!),
      );
      await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error synthesizing speech: $e');
      // Optionally show an error message to the user
    } finally {
      setState(() {
        _isSynthesizing = false;
      });
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AzureAppBar(),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _textEditingController,
                        style: const TextStyle(color: Colors.white),
                        textDirection: TextDirection.ltr,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Text to Speak',
                          labelStyle: TextStyle(
                            color: Colors.white.withAlpha(204),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(51),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isLoadingVoices
                          ? const CircularProgressIndicator()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<TtsVoice>(
                                  value: _selectedTtsVoice,
                                  dropdownColor: const Color(0xFF2E3192),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  onChanged: (TtsVoice? newValue) {
                                    setState(() {
                                      _selectedTtsVoice = newValue;
                                    });
                                  },
                                  items: _availableTtsVoices.map((voice) {
                                    return DropdownMenuItem<TtsVoice>(
                                      value: voice,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2.0,
                                          horizontal: 4.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${voice.localName} (${voice.gender})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text('[${voice.locale}]'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: FloatingActionButton.large(
                    onPressed: _isSynthesizing ? null : _synthesizeAndPlay,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    child: _isSynthesizing
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blueAccent,
                            ),
                          )
                        : const Icon(Icons.volume_up),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom AudioSource for just_audio to play in-memory audio bytes.
class MyCustomSource extends StreamAudioSource {
  final List<int> _audioBytes;

  MyCustomSource(this._audioBytes) : super(tag: 'MyCustomSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _audioBytes.length;
    return StreamAudioResponse(
      sourceLength: _audioBytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/mpeg',
      // Assuming MP3 format
      stream: Stream.value(Uint8List.fromList(_audioBytes.sublist(start, end))),
    );
  }
}
