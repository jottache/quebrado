#!/usr/bin/env python3
"""Casos de guard-rls.py. Uso: python3 .claude/hooks/guard-rls.test.py
Los JWT y claves de prueba se generan aquí (firma falsa) para no escribir secretos literales."""
import base64
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("guard_rls", os.path.join(HERE, "guard-rls.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def b64(obj):
    return base64.urlsafe_b64encode(json.dumps(obj).encode()).decode().rstrip("=")


def jwt(role):
    return f"{b64({'alg': 'HS256', 'typ': 'JWT'})}.{b64({'iss': 'supabase', 'role': role})}.firmafalsa"


SERVICE_JWT = jwt("service_" + "role")
ANON_JWT = jwt("anon")
GKEY = "AIza" + "Sy" + "A" * 33
SR = "service_" + "role"

MIG = "supabase/017_presupuestos.sql"
POL = "CREATE POLICY \"x\" ON t FOR ALL USING (auth.uid() = user_id);"

BLOCK, ALLOW = True, False
CASES = [
    # políticas: solo en migraciones
    (MIG, POL, ALLOW),
    (MIG, "drop policy if exists \"x\" on t;", ALLOW),
    (MIG, "ALTER POLICY \"x\" ON t USING (true);", ALLOW),
    (MIG, "CREATE POLICY \"x\" ON t FOR ALL USING (true) WITH CHECK (true);", ALLOW),
    (MIG, "ALTER TABLE t ENABLE ROW LEVEL SECURITY;", ALLOW),
    (MIG, "ALTER TABLE t FORCE ROW LEVEL SECURITY;", ALLOW),
    (MIG, "ALTER TABLE t DISABLE ROW LEVEL SECURITY;", BLOCK),
    (MIG, "alter table t no force row level security;", BLOCK),
    ("supabase/seed.sql", POL, BLOCK),
    ("supabase/scripts/arreglo.sql", "drop policy x on t;", BLOCK),
    ("supabase/arreglo.sql", "ALTER TABLE t DISABLE ROW LEVEL SECURITY;", BLOCK),
    ("supabase/17_mal_numerada.sql", POL, BLOCK),
    ("quebrado-app-flutter/lib/services/supabase_service.dart", f"await client.rpc('{POL}');", BLOCK),
    ("supabase/import_backup.py", "cur.execute('CREATE POLICY x ON t')", BLOCK),
    ("docs/security/audit-2026-11-17.md", POL, ALLOW),
    ("CLAUDE.md", "Nunca DISABLE ROW LEVEL SECURITY", ALLOW),
    ("quebrado-app-flutter/lib/a.dart", "// política de cancelación", ALLOW),
    # service_role dentro de la app
    ("quebrado-app-flutter/lib/services/supabase_config.dart", f"const k = '{SR}';", BLOCK),
    ("quebrado-app-flutter/.env", "SUPABASE_SERVICE_ROLE_KEY=x", BLOCK),
    ("quebrado-app-flutter/.env", f"SUPABASE_ANON_KEY={SERVICE_JWT}", BLOCK),
    ("quebrado-app-flutter/web/index.html", f"<script>const k='{SERVICE_JWT}'</script>", BLOCK),
    ("quebrado-app-flutter/lib/a.dart", f"const k = '{ANON_JWT}';", ALLOW),
    ("quebrado-app-flutter/.env", f"SUPABASE_ANON_KEY={ANON_JWT}", ALLOW),
    (MIG, f"GRANT EXECUTE ON FUNCTION f() TO anon, authenticated, {SR};", ALLOW),
    ("supabase/import_backup.py", f"KEY = os.environ['SUPABASE_{SR.upper()}_KEY']", ALLOW),
    # claves de Google/Gemini
    ("quebrado-app-flutter/lib/agente/services/gemini_config.dart", f"const k = '{GKEY}';", BLOCK),
    ("quebrado-app-flutter/.env.example", f"GEMINI_API_KEY={GKEY}", BLOCK),
    ("docs/notas.md", f"clave {GKEY}", BLOCK),
    ("quebrado-app-flutter/.env", f"GEMINI_API_KEY={GKEY}", ALLOW),
    ("quebrado-app-flutter/.env.example", "GEMINI_API_KEY=tu-gemini-api-key-aqui", ALLOW),
    ("quebrado-app-flutter/lib/a.dart", "final k = dotenv.env['GEMINI_API_KEY'];", ALLOW),
    # vacío
    ("quebrado-app-flutter/lib/a.dart", "", ALLOW),
]


def run_hook(payload):
    env = dict(os.environ, CLAUDE_PROJECT_DIR="/repo")
    p = subprocess.run([sys.executable, os.path.join(HERE, "guard-rls.py")],
                       input=json.dumps(payload), capture_output=True, text=True, env=env)
    return p.returncode


def main():
    fails = 0
    for path, text, expected in CASES:
        got = guard.check(path, text) is not None
        if got != expected:
            fails += 1
            print(f"FALLO: esperado {'BLOQUEA' if expected else 'PERMITE'}: {path}: {text[:60]!r}")
    # extremo a extremo con las tres formas de entrada
    e2e = [
        ({"tool_input": {"file_path": "/repo/supabase/seed.sql", "content": POL}}, 2),
        ({"tool_input": {"file_path": "/repo/supabase/seed.sql", "old_string": POL,
                         "new_string": "-- nada"}}, 0),
        ({"tool_input": {"file_path": "/repo/supabase/seed.sql", "old_string": "a",
                         "new_string": POL, "replace_all": True}}, 2),
        ({"tool_input": {"file_path": "/repo/quebrado-app-flutter/lib/a.dart",
                         "edits": [{"old_string": "a", "new_string": "b"},
                                   {"old_string": "c", "new_string": f"'{SR}'"}]}}, 2),
        ({"tool_input": {"file_path": f"/repo/{MIG}", "content": POL}}, 0),
    ]
    for payload, code in e2e:
        rc = run_hook(payload)
        if rc != code:
            fails += 1
            print(f"FALLO e2e: {json.dumps(payload)[:90]} salió {rc}, esperado {code}")
    total = len(CASES) + len(e2e)
    print(f"guard-rls: {total} casos, {fails} fallos")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
