import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/agente/services/gemini_service.dart';
import 'package:quebrado_app_flutter/agente/services/suite_rag_service.dart';

/// RAG sin estados ni datos: solo da una foto de contexto fija.
class _FakeRag extends Fake implements SuiteRagService {
  @override
  String generateLiveContextSnapshot() => 'CONTEXTO DE PRUEBA';
}

// Spec 02, CA-11 y PQ-02 (decisión de la persona del 2026-11-18): el agente
// se llama «Ortiz» y así se presenta.
void main() {
  test('la instrucción de sistema presenta al asistente como Ortiz', () {
    final instruction = GeminiService(ragService: _FakeRag()).debugSystemInstruction();

    expect(instruction, startsWith('Eres Ortiz,'));
    expect(instruction, contains('Si te preguntan cómo te llamas, eres Ortiz.'));
    expect(instruction, contains('CONTEXTO DE PRUEBA'));
  });
}
