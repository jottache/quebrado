import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  static final SpeechRecognitionService instance = SpeechRecognitionService._internal();
  SpeechRecognitionService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  String _currentLocaleId = 'es_ES';

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized;

  /// Inicializa el motor de reconocimiento de voz
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('SpeechRecognitionService error: ${errorNotification.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('SpeechRecognitionService status: $status');
        },
      );

      if (_isInitialized) {
        final locales = await _speechToText.locales();
        final esLocale = locales.firstWhere(
          (loc) => loc.localeId.startsWith('es'),
          orElse: () => locales.isNotEmpty ? locales.first : LocaleName('es_ES', 'Español'),
        );
        _currentLocaleId = esLocale.localeId;
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('Error inicializando SpeechRecognitionService: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Inicia la escucha activa y llama a [onResult] cada vez que se detectan palabras
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    VoidCallback? onDone,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult && onDone != null) {
            onDone();
          }
        },
        localeId: _currentLocaleId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );
      return true;
    } catch (e) {
      debugPrint('Error en startListening: $e');
      return false;
    }
  }

  /// Detiene la escucha
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Error en stopListening: $e');
    }
  }

  /// Cancela la escucha activa
  Future<void> cancelListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (e) {
      debugPrint('Error en cancelListening: $e');
    }
  }
}
