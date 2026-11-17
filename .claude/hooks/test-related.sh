#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): tras editar un .dart de lib/ o test/,
#   1) dart analyze <archivo>  (errores y warnings fallan; infos no)
#   2) sus tests: si es un test, ese test; si es lib/a/b.dart, su espejo test/a/b_test.dart
#      o, si no hay espejo, hasta 3 tests que lo importen. Los fallos listados en
#      .claude/known-failures no bloquean.
# .sql y demás: nada (el SQL lo revisa el revisor).  Salida: 0 ok, 2 fallo (resumen a stderr).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-json.sh"
read_hook_input
file="$(json_get tool_input.file_path)"
[ -n "$file" ] || exit 0
case "$file" in /*) ;; *) file="$ROOT/$file" ;; esac
rel="$(rel_path "$file")"

case "$rel" in
  quebrado-app-flutter/lib/*.dart|quebrado-app-flutter/test/*.dart) ;;
  *) exit 0 ;;
esac
case "$rel" in
  *.g.dart|*.freezed.dart|*.mocks.dart|*/all_imports_test.dart) exit 0 ;;
esac
[ -f "$file" ] || exit 0

export CLAUDE_PROJECT_DIR="$ROOT"
app_rel="${rel#quebrado-app-flutter/}"   # lib/a/b.dart o test/a/b_test.dart
cd "$APP" || exit 0
TMP="$(mktemp -d "${TMPDIR:-/tmp}/test-related.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
problems=""

# 1. Análisis del archivo
if ! dart analyze "$app_rel" > "$TMP/analyze.txt" 2>&1; then
  problems+="dart analyze $app_rel:"$'\n'
  problems+="$(grep -E '^\s*(error|warning) ' "$TMP/analyze.txt" | head -20)"$'\n'
fi

# 2. Tests relacionados
tests=()
note=""
case "$app_rel" in
  test/*_test.dart)
    tests=("$app_rel")
    ;;
  test/*)
    # helper de tests: tests que lo importan por nombre de archivo
    name="$(basename "$app_rel")"
    while IFS= read -r t; do tests+=("$t"); done < <(
      grep -rlF --include='*_test.dart' "$name" test | grep -v 'all_imports_test.dart' | sort | head -3)
    ;;
  lib/*)
    inner="${app_rel#lib/}"
    mirror="test/${inner%.dart}_test.dart"
    if [ -f "$mirror" ]; then
      tests=("$mirror")
    else
      esc="$(printf '%s' "$inner" | sed 's/[.[\*^$/]/\\&/g')"
      while IFS= read -r t; do tests+=("$t"); done < <(
        grep -rlE --include='*_test.dart' "package:quebrado_app_flutter/${esc}['\"]|lib/${esc}['\"]" test \
          | grep -v 'all_imports_test.dart' | sort | head -3)
      if [ "${#tests[@]}" -eq 0 ]; then
        note="Aviso: $app_rel no tiene test espejo ($mirror) ni tests que lo importen."
      fi
    fi
    ;;
esac

if [ "${#tests[@]}" -gt 0 ]; then
  flutter test --reporter json "${tests[@]}" > "$TMP/report.jsonl" 2> "$TMP/stderr.txt"
  if ! python3 "$HERE/parse-test-report.py" "$TMP/report.jsonl" --partial > "$TMP/tests.txt" 2>&1; then
    problems+="flutter test ${tests[*]}:"$'\n'"$(cat "$TMP/tests.txt")"$'\n'
    problems+="$(grep -vE 'Resolving dependencies|Downloading packages|Got dependencies|newer versions|flutter pub outdated|^\s*$' "$TMP/stderr.txt" | head -15)"$'\n'
  else
    summary="$(head -1 "$TMP/tests.txt")"
  fi
fi

if [ -n "$problems" ]; then
  {
    echo "test-related: hay problemas tras editar $app_rel"
    printf '%s' "$problems"
    [ -n "$note" ] && echo "$note"
  } >&2
  exit 2
fi
echo "test-related: $app_rel → analyze OK${summary:+; ${tests[*]} → $summary}"
[ -n "$note" ] && echo "$note"
exit 0
