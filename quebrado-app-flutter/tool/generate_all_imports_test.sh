#!/usr/bin/env bash
# Genera test/all_imports_test.dart: importa TODO lib/ para que la cobertura cuente
# también los archivos que ningún test toca (si no, el % sale inflado).
#
# Se excluyen los archivos que solo compilan en web (importan dart:html,
# dart:js_interop, dart:js_util, dart:ui_web o package:web): la suite corre en la VM.
# El test generado se autoverifica: si se añaden o borran archivos en lib/, falla
# con "Lista desactualizada: ejecuta ./tool/generate_all_imports_test.sh".
#
# Uso (desde quebrado-app-flutter/):  ./tool/generate_all_imports_test.sh
#                                     ./tool/generate_all_imports_test.sh --check   # solo compara, no escribe
set -euo pipefail

cd "$(dirname "$0")/.."
TARGET="test/all_imports_test.dart"
case "${1:-}" in
  "") OUT="$TARGET" ;;
  --check) OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT ;;
  *) echo "Uso: $0 [--check]" >&2; exit 2 ;;
esac
WEB_ONLY_RE="^import '(dart:(html|js|js_interop|js_util|ui_web)|package:web/)"

files=()
while IFS= read -r f; do
  if grep -qE "$WEB_ONLY_RE" "$f"; then
    continue
  fi
  files+=("${f#lib/}")
done < <(find lib -name '*.dart' -type f | LC_ALL=C sort)

{
  echo "// GENERADO por tool/generate_all_imports_test.sh — no editar a mano."
  echo "// Importa todo lib/ (excepto archivos solo-web) para que la cobertura sea real."
  echo "// ignore_for_file: unused_import, directives_ordering"
  echo
  echo "import 'dart:io';"
  echo
  echo "import 'package:flutter_test/flutter_test.dart';"
  echo
  i=0
  for f in "${files[@]}"; do
    echo "import 'package:quebrado_app_flutter/$f' as i$i;"
    i=$((i + 1))
  done
  echo
  echo "const _importados = <String>["
  for f in "${files[@]}"; do
    echo "  '$f',"
  done
  echo "];"
  echo
  cat <<'DART'
final _soloWeb = RegExp(
  r"^import '(dart:(html|js|js_interop|js_util|ui_web)|package:web/)",
  multiLine: true,
);

void main() {
  test('importa todo lib/ (la lista generada está al día)', () {
    final actuales = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_soloWeb.hasMatch(f.readAsStringSync()))
        .map((f) => f.path.replaceAll(r'\', '/').substring('lib/'.length))
        .toSet();
    final generados = _importados.toSet();
    final nuevos = actuales.difference(generados);
    final borrados = generados.difference(actuales);
    if (nuevos.isNotEmpty || borrados.isNotEmpty) {
      fail('Lista desactualizada: ejecuta ./tool/generate_all_imports_test.sh\n'
          'Nuevos: $nuevos\nBorrados: $borrados');
    }
  });
}
DART
} > "$OUT"

if [ "$OUT" != "$TARGET" ]; then
  if cmp -s "$OUT" "$TARGET"; then
    echo "$TARGET está al día (${#files[@]} archivos de lib/)."
    exit 0
  fi
  echo "Lista desactualizada: ejecuta ./tool/generate_all_imports_test.sh" >&2
  exit 1
fi
echo "Generado $OUT con ${#files[@]} archivos de lib/."
