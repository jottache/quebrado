#!/usr/bin/env bash
# Responde "verde" si la puerta completa ya pasó con el contenido actual (huella),
# o "no verificado" si no. Lo usa el revisor para no repetir la suite.
# Salida: 0 verde, 1 no verificado.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOKS="$ROOT/.claude/hooks"
current="$(CLAUDE_PROJECT_DIR="$ROOT" "$HOOKS/lib-fingerprint.sh")"
if [ -f "$HOOKS/.last-green" ] && [ "$(cat "$HOOKS/.last-green")" = "$current" ]; then
  echo "verde"
  exit 0
fi
echo "no verificado"
exit 1
