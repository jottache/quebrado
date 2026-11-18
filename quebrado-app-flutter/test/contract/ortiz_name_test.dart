import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Spec 02, CA-11: ningún texto visible dice «Agente Ortiz»; la UI dice «Ortiz».
// Se buscan dentro de literales de texto (entre comillas) para no contar
// comentarios ni nombres de clases como `AgenteState`.
void main() {
  test('ningún texto de lib/ llama «Agente» a Ortiz', () {
    final pattern = RegExp(r'''['"][^'"\n]*(Agente Ortiz|del Agente|Agente IA)[^'"\n]*['"]''');
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = pattern.firstMatch(lines[i]);
        if (match != null) hits.add('${entity.path}:${i + 1}: ${match.group(0)}');
      }
    }

    expect(hits, isEmpty, reason: 'Usa «Ortiz» (CA-11):\n${hits.join('\n')}');
  });
}
