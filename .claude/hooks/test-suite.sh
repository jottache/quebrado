#!/usr/bin/env bash
# Stop: corre la puerta completa (suite-run.sh) salvo que el contenido no haya cambiado
# desde la última vez en verde (huella → ~1 s). Si está en rojo, el turno no termina.
# Segunda vuelta (stop_hook_active: true): avisa sin bloquear (exit 1) para no entrar en bucle.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-json.sh"
read_hook_input
active="$(json_get stop_hook_active)"
export CLAUDE_PROJECT_DIR="$ROOT"

if "$HERE/suite-green.sh" > /dev/null 2>&1; then
  exit 0
fi

if out="$("$HERE/suite-run.sh" 2>&1)"; then
  exit 0
fi

{
  echo "La suite no está en verde: el trabajo no se puede dar por terminado."
  echo "$out" | grep -v '^analyze → ' | tail -40
  echo "Informe completo: .claude/hooks/.last-report.txt · Repetir: .claude/hooks/suite-run.sh"
} >&2
if [ "$active" = "true" ]; then
  exit 1
fi
exit 2
