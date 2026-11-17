#!/usr/bin/env bash
# Utilidades compartidas por los hooks de shell. Se carga con:  . "$(dirname "$0")/lib-json.sh"
# Lee el JSON que Claude Code pasa por stdin sin depender de jq (usa python3).

# Raíz del repo.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
APP="$ROOT/quebrado-app-flutter"

# Guarda stdin en HOOK_INPUT (llamar una sola vez).
read_hook_input() {
  HOOK_INPUT="$(cat)"
}

# json_get <ruta.con.puntos> → imprime el valor (vacío si no existe). Usa HOOK_INPUT.
json_get() {
  HOOK_INPUT="$HOOK_INPUT" python3 - "$1" <<'PY'
import json, os, sys
try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    data = {}
cur = data
for part in sys.argv[1].split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        cur = None
        break
if cur is None:
    print("")
elif isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur))
else:
    print(cur)
PY
}

# Ruta relativa a la raíz del repo.
rel_path() {
  case "$1" in
    "$ROOT"/*) printf '%s\n' "${1#"$ROOT"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}
