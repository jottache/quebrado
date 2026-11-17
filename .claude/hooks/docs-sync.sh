#!/usr/bin/env bash
# Stop: si cambió la configuración de la IA (CLAUDE.md, .claude/, .mcp.json) sin commitear y
# no cambió docs/orquestacion.md, bloquea UNA vez por estado de cambios pidiendo actualizar el
# inventario o justificar por qué no aplica. Si el estado no cambia, no vuelve a bloquear.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-json.sh"
read_hook_input
active="$(json_get stop_hook_active)"
STATE="$HERE/.last-report-docs-sync"

changed="$(git -C "$ROOT" status --porcelain -uall 2>/dev/null | sed -E 's/^.{3}//; s/.* -> //; s/^"(.*)"$/\1/')"
config="$(printf '%s\n' "$changed" \
  | grep -E '^(CLAUDE\.md|\.mcp\.json|\.claude/.+)$' \
  | grep -vE '^\.claude/hooks/\.last-(green|report)|^\.claude/settings\.local\.json$' \
  | sort -u)"
[ -n "$config" ] || exit 0
printf '%s\n' "$changed" | grep -qx 'docs/orquestacion.md' && exit 0
[ "$active" = "true" ] && exit 0

# Huella del estado actual (rutas + contenido) para no bloquear dos veces lo mismo.
state="$(cd "$ROOT" && printf '%s\n' "$config" | while IFS= read -r f; do
  printf '%s ' "$f"; [ -f "$f" ] && shasum "$f" | cut -d' ' -f1 || echo borrado; done | shasum | cut -d' ' -f1)"
if [ -f "$STATE" ] && [ "$(cat "$STATE")" = "$state" ]; then
  exit 0
fi
echo "$state" > "$STATE"
{
  echo "Cambió la configuración de la IA y no el inventario docs/orquestacion.md:"
  printf '%s\n' "$config" | sed 's/^/  - /'
  echo "Actualiza docs/orquestacion.md (agentes, skills, hooks) o justifica en tu respuesta por qué no aplica."
} >&2
exit 2
