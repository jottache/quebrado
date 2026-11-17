#!/usr/bin/env bash
# Compara la cobertura de líneas de quebrado-app-flutter/lib (coverage/lcov.info, solo SF:lib/…)
# con el umbral de .claude/coverage-threshold. El umbral solo sube; nunca se baja.
# Salida: 0 ok (o sin umbral todavía), 1 bajo el umbral o sin lcov.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LCOV="${1:-$ROOT/quebrado-app-flutter/coverage/lcov.info}"
THRESHOLD_FILE="$ROOT/.claude/coverage-threshold"

if [ ! -f "$THRESHOLD_FILE" ]; then
  echo "Cobertura: sin umbral (.claude/coverage-threshold no existe); no se comprueba."
  exit 0
fi
if [ ! -f "$LCOV" ]; then
  echo "Cobertura: no existe $LCOV (corre flutter test --coverage)."
  exit 1
fi
LCOV="$LCOV" THRESHOLD_FILE="$THRESHOLD_FILE" python3 - <<'PY'
import os, re, sys
thr = None
for line in open(os.environ["THRESHOLD_FILE"], encoding="utf-8"):
    line = line.split("#", 1)[0].strip()
    m = re.search(r"\d+(\.\d+)?", line)
    if m:
        thr = float(m.group(0)); break
if thr is None:
    print("Cobertura: .claude/coverage-threshold no tiene un número; no se comprueba.")
    sys.exit(0)
lf = lh = 0
take = False
for line in open(os.environ["LCOV"], encoding="utf-8"):
    if line.startswith("SF:"):
        sf = line[3:].strip().replace("\\", "/")
        take = sf.startswith("lib/") or "/quebrado-app-flutter/lib/" in sf
    elif take and line.startswith("LF:"):
        lf += int(line[3:])
    elif take and line.startswith("LH:"):
        lh += int(line[3:])
pct = 100.0 * lh / lf if lf else 0.0
if pct + 1e-9 < thr:
    print(f"Cobertura: {pct:.2f}% ({lh}/{lf} líneas de lib/) BAJO el umbral {thr}%. "
          "Añade tests; el umbral no se baja.")
    sys.exit(1)
print(f"Cobertura: {pct:.2f}% ({lh}/{lf} líneas de lib/) ≥ umbral {thr}%.")
PY
