#!/usr/bin/env python3
"""Casos de guard-bash.py. Uso: python3 .claude/hooks/guard-bash.test.py
Cada regla nueva del guard lleva aquí al menos un caso positivo y uno negativo."""
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("guard_bash", os.path.join(HERE, "guard-bash.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

S = "/private/tmp/claude-501/proyecto/sesion/scratchpad"
L = "quebrado-app-flutter/lib/quebrado/models/account.dart"
T = "quebrado-app-flutter/test/multi_book_test.dart"
SQL = "supabase/016_notas_documento_enriquecido.sql"

BLOCK, ALLOW = True, False
CASES = [
    # --- redirecciones ---
    (f"echo hola > {L}", BLOCK),
    (f"echo hola >> {L}", BLOCK),
    (f"echo hola 1> {L}", BLOCK),
    (f"echo hola &> {L}", BLOCK),
    (f"echo hola >& {L}", BLOCK),
    (f"echo hola 2> {SQL}", BLOCK),
    (f"cat <<'EOF' > {L}\nvoid main() {{}}\nEOF", BLOCK),
    ("echo x > supabase/017_nueva.sql", BLOCK),
    ("echo x > lib/main.dart", BLOCK),
    ("echo x > quebrado-app-flutter/test/", BLOCK),
    ("echo hola > docs/notas.md", ALLOW),
    (f"flutter analyze > {S}/analyze.txt 2>&1", ALLOW),
    (f"echo x > {S}/borrador.dart", ALLOW),
    ("ls 2>/dev/null", ALLOW),
    ("cmd 2>&1 | tail -5", ALLOW),
    # --- tee ---
    (f"echo x | tee {L}", BLOCK),
    (f"echo x | tee -a {SQL}", BLOCK),
    (f"echo x | tee {S}/log.txt", ALLOW),
    # --- sed / perl -i ---
    (f"sed -i '' 's/a/b/' {L}", BLOCK),
    (f"sed -i.bak 's/a/b/' {L}", BLOCK),
    (f"sed -e 's/a/b/' -i {SQL}", BLOCK),
    (f"find quebrado-app-flutter/lib -name '*.dart' | xargs sed -i '' 's/a/b/'", BLOCK),
    ("find quebrado-app-flutter/lib -name '*.dart' -exec sed -i '' 's/a/b/' {} +", BLOCK),
    (f"env LC_ALL=C sed -i '' 's/a/b/' {L}", BLOCK),
    (f"perl -pi -e 's/a/b/' {L}", BLOCK),
    (f"perl -i -pe 's/a/b/' {SQL}", BLOCK),
    ("sed -i '' 's/a/b/' README.md", ALLOW),
    (f"sed 's/a/b/' {L} | head", ALLOW),
    # --- cp / mv / git mv / install / rsync ---
    (f"cp {S}/account.dart {L}", BLOCK),
    (f"cp {S}/x.sql supabase/", BLOCK),
    (f"mv viejo.dart {L}", BLOCK),
    (f"git mv {L} quebrado-app-flutter/lib/quebrado/models/cuenta.dart", BLOCK),
    (f"install -m 644 a.txt {L}", BLOCK),
    (f"rsync -a {S}/lib/ quebrado-app-flutter/lib/", BLOCK),
    (f"cp -t quebrado-app-flutter/lib {S}/a.dart", BLOCK),
    (f"cp {L} {S}/copia.dart", ALLOW),
    ("cp README.md docs/README.md", ALLOW),
    ("mv docs/a.md docs/b.md", ALLOW),
    # --- git apply / patch ---
    (f"git apply {S}/cambio.patch", BLOCK),
    (f"git apply --check {S}/cambio.patch", ALLOW),
    (f"patch -p1 < {S}/cambio.patch", BLOCK),
    (f"patch --dry-run -p1 < {S}/cambio.patch", ALLOW),
    # --- formateadores ---
    ("dart format quebrado-app-flutter/lib", BLOCK),
    (f"cd quebrado-app-flutter && dart format lib/main.dart", BLOCK),
    ("dart format --output none --set-exit-if-changed quebrado-app-flutter/lib", ALLOW),
    ("dart format --output=none quebrado-app-flutter/lib", ALLOW),
    ("dart format --set-exit-if-changed lib", ALLOW),
    ("dart fix --apply", BLOCK),
    ("dart fix --dry-run", ALLOW),
    # --- intérpretes ---
    (f"python3 -c \"open('{L}','w').write('x')\"", BLOCK),
    (f"python3 - <<'EOF'\nfrom pathlib import Path\nPath('{SQL}').write_text('x')\nEOF", BLOCK),
    (f"python3 - <<'EOF'\nimport glob\nfor p in glob.glob('quebrado-app-flutter/lib/**/*.dart'):\n    open(p,'w').write('')\nEOF", BLOCK),
    (f"node -e \"require('fs').writeFileSync('{L}', 'x')\"", BLOCK),
    (f"python3 -c \"print(open('{L}').read()[:100])\"", ALLOW),
    (f"python3 - <<'EOF'\nopen('{S}/out.txt','w').write(open('{L}').read()[:10])\nEOF", ALLOW),
    ("python3 -c \"import json; print(1)\"", ALLOW),
    ("python3 .claude/hooks/guard-bash.test.py", ALLOW),
    # --- volcados ---
    (f"cat {L}", BLOCK),
    (f"nl {SQL}", BLOCK),
    (f"less {L}", BLOCK),
    (f"more {T}", BLOCK),
    (f"sed -n '1,200p' {L}", BLOCK),
    ("for f in quebrado-app-flutter/lib/quebrado/models/*.dart; do cat $f; done", BLOCK),
    (f"cat {L} | grep class", ALLOW),
    (f"sed -n 1,200p {L} | head -150", ALLOW),
    ("for f in quebrado-app-flutter/lib/*.dart; do cat $f; done | wc -l", ALLOW),
    ("cat README.md", ALLOW),
    ("cat pubspec.yaml && cat .env.example", ALLOW),
    (f"cat {S}/test.txt", ALLOW),
    (f"head -50 {L}", ALLOW),
    (f"tail -20 {SQL}", ALLOW),
    # --- permitidos habituales ---
    (f"grep -n 'class' {L}", ALLOW),
    (f"wc -l {L}", ALLOW),
    ("git diff -- quebrado-app-flutter/lib", ALLOW),
    ("git status --porcelain && git log --oneline | head", ALLOW),
    ("cd quebrado-app-flutter && flutter analyze --no-fatal-infos", ALLOW),
    (f"cd quebrado-app-flutter && flutter test {T}", ALLOW),
    (f"dart analyze {L}", ALLOW),
    ("git commit -F /private/tmp/claude-501/x/msg.txt", ALLOW),
    ("", ALLOW),
]


def run_hook(cmd):
    p = subprocess.run(
        [sys.executable, os.path.join(HERE, "guard-bash.py")],
        input=json.dumps({"tool_input": {"command": cmd}}),
        capture_output=True, text=True,
    )
    return p.returncode


def main():
    fails = 0
    for cmd, expected in CASES:
        got = guard.check(cmd) is not None
        if got != expected:
            fails += 1
            print(f"FALLO: esperado {'BLOQUEA' if expected else 'PERMITE'}: {cmd!r}")
    # extremo a extremo: el hook real sale con 2 / 0
    e2e = [(f"echo x > {L}", 2), ("cat README.md", 0), ("no es json", None)]
    for cmd, code in e2e[:2]:
        rc = run_hook(cmd)
        if rc != code:
            fails += 1
            print(f"FALLO e2e: {cmd!r} salió {rc}, esperado {code}")
    p = subprocess.run([sys.executable, os.path.join(HERE, "guard-bash.py")],
                       input="no es json", capture_output=True, text=True)
    if p.returncode != 0:
        fails += 1
        print("FALLO e2e: JSON inválido debería permitir (exit 0)")
    total = len(CASES) + 3
    print(f"guard-bash: {total} casos, {fails} fallos")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
