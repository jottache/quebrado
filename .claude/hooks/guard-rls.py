#!/usr/bin/env python3
"""PreToolUse (Edit|Write|MultiEdit): reglas de seguridad de datos.

Mira solo el texto NUEVO (Write: content; Edit: new_string; MultiEdit: edits[].new_string).

1. Políticas RLS solo en migraciones `supabase/NNN_slug.sql`: bloquea
   CREATE/ALTER/DROP POLICY y DISABLE / NO FORCE ROW LEVEL SECURITY en código
   (.sql que no es migración, .dart, scripts).
2. Dentro de migraciones bloquea DISABLE ROW LEVEL SECURITY y NO FORCE ROW LEVEL SECURITY.
3. Dentro de quebrado-app-flutter/ (incl. .env*, web/) bloquea `service_role`,
   `SERVICE_ROLE_KEY` o un JWT cuyo payload diga "role":"service_role": todo lo
   que hay en la app (incluido el .env, que va como asset) es público.
4. En cualquier archivo bloquea una clave literal de Google/Gemini (AIza…), salvo en `.env`.

No bloquea `USING (true)`: las políticas permisivas actuales son deuda conocida
(docs/pendientes.md) y las revisan el revisor y security-auditor.

Salida: 0 = permitido; 2 = bloqueado (motivo en stderr).
Tests: python3 .claude/hooks/guard-rls.test.py
"""
import base64
import json
import os
import re
import sys

MIGRATION = re.compile(r"^supabase/\d{3}_[\w.-]+\.sql$")
POLICY = re.compile(r"\b(CREATE|ALTER|DROP)\s+POLICY\b", re.I)
RLS_OFF = re.compile(
    r"\bDISABLE\s+ROW\s+LEVEL\s+SECURITY\b|\bNO\s+FORCE\s+ROW\s+LEVEL\s+SECURITY\b", re.I
)
SERVICE = re.compile(r"service_role|SERVICE_ROLE_KEY", re.I)
JWT = re.compile(r"eyJ[A-Za-z0-9_-]+\.(eyJ[A-Za-z0-9_-]+)\.[A-Za-z0-9_-]*")
GOOGLE_KEY = re.compile(r"AIza[0-9A-Za-z_\-]{35}")
CODE_EXT = (".sql", ".dart", ".py", ".sh", ".js", ".ts", ".mjs", ".cjs")


def new_text(data):
    ti = data.get("tool_input") or {}
    parts = []
    for key in ("content", "new_string"):
        if isinstance(ti.get(key), str):
            parts.append(ti[key])
    for e in ti.get("edits") or []:
        if isinstance(e, dict) and isinstance(e.get("new_string"), str):
            parts.append(e["new_string"])
    return "\n".join(parts)


def rel(path, root):
    path = os.path.normpath(path)
    root = os.path.normpath(root)
    if path.startswith(root + os.sep):
        return path[len(root) + 1:]
    return path


def jwt_is_service(text):
    for m in JWT.finditer(text):
        payload = m.group(1)
        try:
            raw = base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
            claims = json.loads(raw)
        except Exception:
            continue
        if isinstance(claims, dict) and claims.get("role") == "service_role":
            return True
    return False


def check(rel_path, text):
    """Devuelve el motivo del bloqueo o None."""
    if not text:
        return None
    rp = rel_path.replace("\\", "/")
    name = rp.rsplit("/", 1)[-1]
    is_migration = bool(MIGRATION.match(rp))
    in_claude = rp.startswith(".claude/")
    is_code = rp.endswith(CODE_EXT) and not in_claude

    if is_migration:
        if RLS_OFF.search(text):
            return ("Bloqueado: desactivar RLS (DISABLE / NO FORCE ROW LEVEL SECURITY) en una "
                    "migración. Todas las tablas llevan RLS activo; ajusta las políticas.")
    elif is_code and (POLICY.search(text) or RLS_OFF.search(text)):
        return ("Bloqueado: políticas RLS fuera de una migración. Las políticas se crean "
                "solo en una migración nueva `supabase/NNN_slug.sql` (la app y otros "
                "archivos nunca crean, cambian ni desactivan políticas).")

    if rp.startswith("quebrado-app-flutter/"):
        if SERVICE.search(text) or jwt_is_service(text):
            return ("Bloqueado: clave service_role dentro de la app. Todo lo que hay en "
                    "quebrado-app-flutter/ (incluido el .env, que se empaqueta como asset en "
                    "web) es público. La app solo usa la anon key.")

    allowed_env = name.startswith(".env") and "example" not in name
    if GOOGLE_KEY.search(text) and not allowed_env:
        return ("Bloqueado: clave literal de Google/Gemini (AIza…). Las claves van solo en "
                "`.env` (gitignored); en el código se leen con flutter_dotenv. Ojo: en web "
                "el .env se publica, ver docs/pendientes.md.")
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    path = (data.get("tool_input") or {}).get("file_path") or ""
    reason = check(rel(path, root), new_text(data))
    if reason:
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
