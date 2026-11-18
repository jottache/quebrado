// Guardián de la spec 05: ningún valor de estilo escrito a mano en `lib/`.
//
// Cuenta, archivo por archivo, los valores de estilo sueltos:
//   - colores: `Color(0x…)` y `Colors.*` (salvo `Colors.transparent`)
//   - `fontSize:` con un número
//   - números distintos de 0 en `EdgeInsets.*(…)`
//   - separadores `SizedBox(height|width: n)` con n ≤ 32
//   - números en `BorderRadius.circular(…)` / `Radius.circular(…)`
//   - `size:` con un número dentro de `Icon(…)`
//   - `.withOpacity(`
// y los compara con la deuda de `no_hardcoded_styles_debt.txt`, que SOLO BAJA:
//   - si un archivo tiene MÁS que su deuda (o aparece uno nuevo) → falla;
//   - si tiene MENOS → falla también, para que se actualice la deuda
//     (así la lista nunca se queda vieja). Para actualizarla:
//       UPDATE_STYLE_DEBT=1 flutter test test/contract/no_hardcoded_styles_test.dart
//     que reescribe el archivo con los conteos actuales, pero se niega si
//     alguno subió.
// Al cerrar la spec 05 la deuda queda vacía.
//
// Fuera de alcance: los tokens (`lib/theme/`, `lib/*/theme/`,
// `rich_editor_colors.dart`) y las pantallas que la spec 02 reemplaza.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _debtPath = 'test/contract/no_hardcoded_styles_debt.txt';

const _excludedFiles = {
  'lib/screens/app_launcher_screen.dart',
  'lib/screens/launcher_action_hub_view.dart',
  'lib/widgets/desktop_command_center_view.dart',
  'lib/rich_editor/rich_editor_colors.dart',
};

bool _inScope(String rel) {
  if (!rel.endsWith('.dart')) return false;
  if (_excludedFiles.contains(rel)) return false;
  final parts = rel.split('/');
  // lib/theme/** y lib/<módulo>/theme/**
  if (parts.length > 2 && parts[1] == 'theme') return false;
  if (parts.length > 3 && parts[2] == 'theme') return false;
  return true;
}

// `\b` delante: `DiarioColors.x`, `AppColors.x`, `SuiteAppColors.x`… son tokens,
// no el `Colors.` de Material.
// También `Color.fromARGB(`/`Color.fromRGBO(` (colores escritos a mano por canal).
final _color = RegExp(
    r'\bColor\(0x|\bColor\.from(?:ARGB|RGBO)\(|\bColors\.(?!transparent\b)[a-zA-Z]');
final _fontSize = RegExp(r'fontSize:\s*\d');
final _opacity = RegExp(r'\.withOpacity\(');
final _radius = RegExp(r'\b(?:BorderRadius|Radius)\.circular\(\s*\d');
final _gap = RegExp(r'\bSizedBox\(\s*(?:height|width)\s*:\s*(\d+(?:\.\d+)?)\s*\)');
final _edgeCall =
    RegExp(r'\bEdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\(');
final _iconCall = RegExp(r'\bIcon\(');
final _nonZeroNum = RegExp(r'(?<![\w.])(?:[1-9]\d*(?:\.\d+)?|0\.\d*[1-9]\d*)(?![\w.])');
final _iconSize = RegExp(r'\bsize:\s*\d');

/// Texto entre el paréntesis que abre en [open] y su cierre.
String _argsFrom(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')') {
      depth--;
      if (depth == 0) return src.substring(open + 1, i);
    }
  }
  return '';
}

/// Quita comentarios de línea para no contar ejemplos en la documentación.
/// Solo corta en un `//` que no va precedido de `:` (para no tratar como
/// comentario el resto de una línea con una URL `https://…`).
String _stripComments(String src) =>
    src.split('\n').map((l) {
      final m = RegExp(r'(?<!:)//').firstMatch(l);
      return m == null ? l : l.substring(0, m.start);
    }).join('\n');

int countHardcoded(String source) {
  final src = _stripComments(source);
  var n = 0;
  n += _color.allMatches(src).length;
  n += _fontSize.allMatches(src).length;
  n += _opacity.allMatches(src).length;
  n += _radius.allMatches(src).length;
  n += _gap
      .allMatches(src)
      .where((m) => double.parse(m.group(1)!) <= 32 && double.parse(m.group(1)!) > 0)
      .length;
  for (final m in _edgeCall.allMatches(src)) {
    final args = _argsFrom(src, m.end - 1);
    // Solo números sueltos de primer nivel (no dentro de llamadas anidadas).
    final flat = args.replaceAll(RegExp(r'\([^()]*\)'), '');
    n += _nonZeroNum.allMatches(flat).length;
  }
  for (final m in _iconCall.allMatches(src)) {
    n += _iconSize.allMatches(_argsFrom(src, m.end - 1)).length;
  }
  return n;
}

Map<String, int> _currentCounts() {
  final counts = <String, int>{};
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.path.replaceAll('\\', '/');
    if (!_inScope(rel)) continue;
    final c = countHardcoded(e.readAsStringSync());
    if (c > 0) counts[rel] = c;
  }
  return counts;
}

Map<String, int> _readDebt() {
  final f = File(_debtPath);
  if (!f.existsSync()) return {};
  final debt = <String, int>{};
  for (final line in f.readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final parts = t.split(RegExp(r'\s+'));
    debt[parts[0]] = int.parse(parts[1]);
  }
  return debt;
}

void main() {
  group('countHardcoded', () {
    test('cuenta cada tipo de valor suelto', () {
      const src = '''
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0));
        Text('a', style: TextStyle(fontSize: 13, color: Color(0xFF112233)));
        SizedBox(height: 8); SizedBox(width: 120);
        BorderRadius.circular(14); x.withOpacity(0.5);
        Icon(Icons.add, size: 18, color: Colors.transparent);
      ''';
      // Colors.white, Color(0x, fontSize, 12, SizedBox 8, circular, withOpacity, size
      expect(countHardcoded(src), 8);
    });

    test('cuenta colores por canal y no se salta lo que sigue a una URL', () {
      const src = '''
        final a = Color.fromARGB(255, 1, 2, 3); final b = Color.fromRGBO(1, 2, 3, 1);
        launch('https://x.y'); final c = Colors.red;
      ''';
      expect(countHardcoded(src), 3);
    });

    test('los tokens y los comentarios no cuentan', () {
      const src = '''
        // Antes: EdgeInsets.all(16), Colors.white
        Container(padding: const EdgeInsets.all(OrtizSpace.lg), color: OrtizPalette.bg);
        Text('a', style: TextStyle(fontSize: OrtizFontSize.body));
        SizedBox(height: OrtizSpace.sm); EdgeInsets.zero; EdgeInsets.all(0);
        Icon(Icons.add, size: OrtizIconSize.md); BorderRadius.circular(OrtizRadius.chip);
        Container(color: DiarioColors.primary); Text('x', style: TextStyle(color: AppColors.primary));
        final c = SuiteAppColors.diarioTint; final h = HabitosColors.amber;
      ''';
      expect(countHardcoded(src), 0);
    });
  });

  test('ningún valor de estilo escrito a mano nuevo en lib/ (deuda que solo baja)', () {
    final current = _currentCounts();
    final debt = _readDebt();

    final subieron = <String>[];
    final bajaron = <String>[];
    for (final e in current.entries) {
      final d = debt[e.key] ?? 0;
      if (e.value > d) subieron.add('${e.key}: ${e.value} (deuda $d)');
    }
    for (final e in debt.entries) {
      final c = current[e.key] ?? 0;
      if (c < e.value) bajaron.add('${e.key}: $c (deuda ${e.value})');
    }

    if (Platform.environment['UPDATE_STYLE_DEBT'] == '1') {
      // La primera vez (sin archivo de deuda) se registra la deuda de partida.
      if (File(_debtPath).existsSync()) {
        expect(subieron, isEmpty,
            reason: 'No se actualiza la deuda si algún archivo subió:\n${subieron.join('\n')}');
      }
      final keys = current.keys.toList()..sort();
      final total = current.values.fold<int>(0, (a, b) => a + b);
      File(_debtPath).writeAsStringSync([
        '# Deuda de valores de estilo escritos a mano (spec 05). SOLO BAJA.',
        '# Generado por test/contract/no_hardcoded_styles_test.dart con UPDATE_STYLE_DEBT=1.',
        '# Total: $total en ${keys.length} archivos.',
        for (final k in keys) '$k ${current[k]}',
        '',
      ].join('\n'));
      return;
    }

    expect(subieron, isEmpty,
        reason: 'Valores de estilo escritos a mano nuevos (usa los tokens de lib/theme/, '
            'skill ortiz-dark-ui):\n${subieron.join('\n')}');
    expect(bajaron, isEmpty,
        reason: 'Bajó la deuda: actualízala con '
            'UPDATE_STYLE_DEBT=1 flutter test test/contract/no_hardcoded_styles_test.dart\n'
            '${bajaron.join('\n')}');
  });
}
