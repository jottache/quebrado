#!/usr/bin/env bash
# Imprime la huella (sha256) del CONTENIDO de todo lo que afecta a la puerta:
# lib, test, tool, *.dart sueltos de la app, pubspec.yaml/.lock, analysis_options.yaml,
# supabase/*.sql, DATABASE_MODELS.md, umbral de cobertura, listas de fallos y omitidos
# conocidos y los scripts de la puerta. Cambiar docs/ no invalida la huella.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
KNOWN="${KNOWN_FAILURES_FILE:-$ROOT/.claude/known-failures}"
SKIPS="${KNOWN_SKIPS_FILE:-$ROOT/.claude/known-skips}"
ROOT="$ROOT" KNOWN="$KNOWN" SKIPS="$SKIPS" python3 - <<'PY'
import hashlib, os, glob
root = os.environ["ROOT"]
app = os.path.join(root, "quebrado-app-flutter")
files = []
for d in ("lib", "test", "tool"):
    for dp, dn, fn in os.walk(os.path.join(app, d)):
        dn[:] = sorted(x for x in dn if not x.startswith("."))
        files += [os.path.join(dp, f) for f in fn if f != ".DS_Store"]
files += glob.glob(os.path.join(app, "*.dart"))
files += [os.path.join(app, f) for f in ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml")]
files += glob.glob(os.path.join(root, "supabase", "*.sql"))
files += [os.path.join(root, "DATABASE_MODELS.md"),
          os.path.join(root, ".claude", "coverage-threshold"),
          os.environ["SKIPS"],
          os.environ["KNOWN"]]
hooks = os.path.join(root, ".claude", "hooks")
files += [os.path.join(hooks, f) for f in ("suite-run.sh", "parse-test-report.py",
                                           "check-coverage.sh", "lib-fingerprint.sh")]
h = hashlib.sha256()
for f in sorted(set(files)):
    h.update(os.path.relpath(f, root).encode() + b"\0")
    if os.path.isfile(f):
        with open(f, "rb") as fh:
            h.update(hashlib.sha256(fh.read()).digest())
    else:
        h.update(b"<ausente>")
print(h.hexdigest())
PY
