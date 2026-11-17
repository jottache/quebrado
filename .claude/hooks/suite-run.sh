#!/usr/bin/env bash
# LA PUERTA: flutter analyze (0 errores, 0 warnings) → flutter test --coverage
# (comparado con .claude/known-failures) → cobertura contra .claude/coverage-threshold.
#
# Uso:  .claude/hooks/suite-run.sh                 # puerta completa; si pasa, registra la huella
#       .claude/hooks/suite-run.sh test/a_test.dart # subconjunto: no mide cobertura ni registra huella
# Salida: 0 verde, 1 rojo. Informe completo en .claude/hooks/.last-report.txt
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export CLAUDE_PROJECT_DIR="$ROOT"
HOOKS="$ROOT/.claude/hooks"
APP="$ROOT/quebrado-app-flutter"
REPORT="$HOOKS/.last-report.txt"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/suite-run.XXXXXX")"
LOCK="$HOOKS/.suite-lock"
trap 'rm -rf "$TMP"' EXIT

# Cerrojo: dos puertas a la vez comparten coverage/lcov.info, .last-report*, .last-green
# y la SQLite de tests. Se espera hasta 10 min; un cerrojo de un proceso muerto se limpia.
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  holder="$(cat "$LOCK/pid" 2>/dev/null)"
  dead=""
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
    dead=1                                   # el dueño ya no existe
  elif [ -z "$holder" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    dead=1                                   # sin pid desde hace >1 min: murió entre mkdir y echo
  fi
  if [ -n "$dead" ]; then
    # mv es atómico: si otro proceso ya lo limpió (y quizá tomó el cerrojo), este mv falla y no borra nada suyo.
    [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$holder" ] && mv "$LOCK" "$LOCK.dead.$$" 2>/dev/null \
      && rm -rf "$LOCK.dead.$$"
    continue
  fi
  if [ "$waited" -ge 600 ]; then
    echo "PUERTA ROJA: otra ejecución de la puerta (pid ${holder:-?}) lleva más de 10 min; si no hay ninguna, borra $LOCK."
    exit 1
  fi
  [ "$waited" -eq 0 ] && echo "Esperando a otra ejecución de la puerta (pid ${holder:-?})…"
  sleep 5; waited=$((waited + 5))
done
echo $$ > "$LOCK/pid"
trap 'rm -rf "$TMP" "$LOCK"' EXIT

FINGERPRINT="$("$HOOKS/lib-fingerprint.sh")"
: > "$REPORT"
say() { echo "$*" | tee -a "$REPORT"; }

cd "$APP" || { echo "No existe $APP"; exit 1; }
start=$(date +%s)

# 1. Análisis estático
if ! flutter analyze --no-fatal-infos > "$TMP/analyze.txt" 2>&1; then
  say "PUERTA ROJA: flutter analyze tiene errores o warnings:"
  grep -E '^\s*(error|warning) •' "$TMP/analyze.txt" | head -40 | tee -a "$REPORT"
  grep -qE '^\s*(error|warning) •' "$TMP/analyze.txt" || tail -20 "$TMP/analyze.txt" | tee -a "$REPORT"
  exit 1
fi
say "analyze → 0 errores, 0 warnings"

# 2. Tests
PARTIAL=""
if [ "$#" -gt 0 ]; then
  PARTIAL="--partial"
  flutter test --reporter json "$@" > "$TMP/report.jsonl" 2> "$TMP/test-stderr.txt"
else
  rm -f coverage/lcov.info  # que nunca se mida un lcov viejo
  flutter test --coverage --reporter json > "$TMP/report.jsonl" 2> "$TMP/test-stderr.txt"
fi
cp "$TMP/report.jsonl" "$HOOKS/.last-report.jsonl" 2>/dev/null
if ! python3 "$HOOKS/parse-test-report.py" "$TMP/report.jsonl" $PARTIAL > "$TMP/tests.txt" 2>&1; then
  say "PUERTA ROJA: tests"
  tee -a "$REPORT" < "$TMP/tests.txt"
  grep -vE 'Resolving dependencies|Downloading packages|Got dependencies|newer versions|flutter pub outdated|^\s*$' \
    "$TMP/test-stderr.txt" | head -20 | tee -a "$REPORT"
  exit 1
fi
tee -a "$REPORT" < "$TMP/tests.txt"

if [ -n "$PARTIAL" ]; then
  say "Subconjunto verde (sin cobertura ni huella) en $(( $(date +%s) - start )) s."
  exit 0
fi

# 3. Cobertura
if ! "$HOOKS/check-coverage.sh" > "$TMP/cov.txt" 2>&1; then
  say "PUERTA ROJA: cobertura"
  tee -a "$REPORT" < "$TMP/cov.txt"
  exit 1
fi
tee -a "$REPORT" < "$TMP/cov.txt"

echo "$FINGERPRINT" > "$HOOKS/.last-green"
say "PUERTA VERDE en $(( $(date +%s) - start )) s (huella registrada)."
exit 0
