#!/usr/bin/env bash
# Stop: todo .dart creado o modificado SIN COMMITEAR en
# quebrado-app-flutter/lib/**/{models,services,viewmodels}/ (incl. lib/services y lib/viewmodels)
# necesita su test: el espejo test/<misma ruta>_test.dart o, al menos, un test que lo importe.
# Segunda vuelta (stop_hook_active: true): avisa sin bloquear (exit 1).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-json.sh"
read_hook_input
active="$(json_get stop_hook_active)"

missing=()
while IFS= read -r path; do
  [ -n "$path" ] || continue
  [ -f "$ROOT/$path" ] || continue
  inner="${path#quebrado-app-flutter/lib/}"
  mirror="test/${inner%.dart}_test.dart"
  [ -f "$APP/$mirror" ] && continue
  esc="$(printf '%s' "$inner" | sed 's/[.[\*^$/]/\\&/g')"
  if grep -rlE --include='*_test.dart' "package:quebrado_app_flutter/${esc}['\"]|lib/${esc}['\"]" "$APP/test" 2>/dev/null \
      | grep -qv 'all_imports_test.dart'; then
    continue
  fi
  missing+=("$path  →  quebrado-app-flutter/$mirror")
done < <(
  git -C "$ROOT" status --porcelain -uall 2>/dev/null \
    | grep -v '^ *D' \
    | sed -E 's/^.{3}//; s/.* -> //; s/^"(.*)"$/\1/' \
    | grep -E '^quebrado-app-flutter/lib/(.+/)?(models|services|viewmodels)/.+\.dart$' \
    | grep -vE '\.(g|freezed|mocks)\.dart$' \
    | sort -u
)

[ "${#missing[@]}" -eq 0 ] && exit 0
{
  echo "Hay archivos de models/services/viewmodels tocados sin su test espejo (ni un test que los importe):"
  printf '  - %s\n' "${missing[@]}"
  echo "Escribe el test (plantillas en la skill testing). No se da por terminado sin él."
} >&2
[ "$active" = "true" ] && exit 1
exit 2
