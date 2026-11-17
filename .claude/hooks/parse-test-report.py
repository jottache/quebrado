#!/usr/bin/env python3
"""Lee la salida de `flutter test --reporter json` y la compara con .claude/known-failures.

Uso: parse-test-report.py <reporte.jsonl> [--partial]

- Identificador de un test: `test/<ruta>_test.dart::<nombre completo con grupos>`.
- Fallo que NO está en la lista            → rojo (fallo nuevo).
- Fallo que está en la lista              → se informa como deuda (no bloquea).
- Test de la lista que ahora pasa         → rojo: hay que quitarlo (la lista solo baja).
- Entrada de la lista que no existe ya    → rojo: hay que quitarla (salvo --partial).
- Entrada con prefijo `~` (inestable)      → puede pasar o fallar sin poner la puerta en rojo.
- Test omitido (skip) que no está en .claude/known-skips → rojo (prohibido `skip`).
- Test de known-skips que ya no se omite   → rojo: hay que quitarlo (salvo --partial).
- Sin evento `done` (el runner murió a mitad) → rojo.
- `done.success == false` sin ningún fallo detectado (p. ej. error de carga) → rojo.
Con --partial (subconjunto de tests) solo cuenta lo que se ejecutó y lo que ahora
pasa se avisa sin bloquear.

Listas: $KNOWN_FAILURES_FILE o <raíz>/.claude/known-failures; $KNOWN_SKIPS_FILE o
<raíz>/.claude/known-skips (líneas `id`, comentarios #).
Salida: 0 verde, 1 rojo.
"""
import json
import os
import sys


def load_known(path):
    known = []
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                known.append(line)
    return known


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    partial = "--partial" in sys.argv
    if not args:
        print("uso: parse-test-report.py <reporte.jsonl> [--partial]", file=sys.stderr)
        return 2
    root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    app = os.path.join(root, "quebrado-app-flutter")
    known_path = os.environ.get("KNOWN_FAILURES_FILE") or os.path.join(root, ".claude", "known-failures")
    known = load_known(known_path)
    unstable = {k[1:].strip() for k in (known or []) if k.startswith("~")}
    if known is not None:
        known = [k[1:].strip() if k.startswith("~") else k for k in known]
    skips_path = os.environ.get("KNOWN_SKIPS_FILE") or os.path.join(root, ".claude", "known-skips")
    known_skips = set(load_known(skips_path) or [])

    suites, tests, results = {}, {}, {}
    errors = {}
    done_ok = None
    with open(args[0], encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            t = ev.get("type")
            if t == "suite":
                s = ev["suite"]
                path = s.get("path") or ""
                if path.startswith(app + os.sep):
                    path = path[len(app) + 1:]
                suites[s["id"]] = path
            elif t == "testStart":
                te = ev["test"]
                tests[te["id"]] = (te.get("suiteID"), te.get("name", ""))
            elif t == "print":
                msg = ev.get("message") or ""
                if "EXCEPTION CAUGHT" in msg:
                    lines = [l for l in msg.splitlines()[1:] if l.strip()]
                    if lines:
                        errors.setdefault(ev.get("testID"), []).append(" ".join(lines[:2])[:220])
            elif t == "error":
                first = (ev.get("error") or "").strip().splitlines()
                if first and not first[0].startswith("Test failed. See exception logs"):
                    errors.setdefault(ev.get("testID"), []).append(first[0][:220])
            elif t == "testDone":
                tid = ev["testID"]
                suite_id, name = tests.get(tid, (None, "?"))
                if ev.get("hidden") and ev.get("result") == "success":
                    continue  # "loading …" y similares
                if ev.get("skipped"):
                    results[tid] = "skip"
                else:
                    results[tid] = "ok" if ev.get("result") == "success" else "fail"
            elif t == "done":
                done_ok = ev.get("success")

    def ident(tid):
        suite_id, name = tests.get(tid, (None, "?"))
        return f"{suites.get(suite_id, '?')}::{name.strip()}"

    passed = {ident(t) for t, r in results.items() if r == "ok"}
    failed = {ident(t): t for t, r in results.items() if r == "fail"}
    skipped = {ident(t) for t, r in results.items() if r == "skip"}

    if not results:
        print("No se ejecutó ningún test (¿error de compilación?). Revisa la salida de flutter test.")
        return 1

    known_set = set(known or [])
    new_fail = sorted(f for f in failed if f not in known_set)
    debt = sorted(f for f in failed if f in known_set)
    now_pass = sorted(k for k in known_set if k in passed and k not in unstable)
    ran = passed | set(failed) | skipped
    stale = sorted(k for k in known_set if k not in ran) if not partial else []
    new_skips = sorted(s for s in skipped if s not in known_skips)
    stale_skips = sorted(k for k in known_skips if k not in skipped) if not partial else []

    print(f"Tests: {len(passed)} pasan, {len(failed)} fallan, {len(skipped)} omitidos.")
    if known is None:
        print(f"(sin lista de fallos conocidos: {known_path} no existe; todo fallo cuenta como nuevo)")
    red = False
    if done_ok is None:
        red = True
        print("El runner de tests terminó sin el evento final `done` (¿se cortó o lo mataron?): "
              "no se puede saber si corrieron todos los tests.")
    elif done_ok is False and not failed:
        red = True
        print("flutter test terminó con error pero ningún test falló (¿error de carga o compilación de un archivo?). "
              "Revisa la salida de flutter test.")
    if new_skips:
        red = True
        print(f"TESTS OMITIDOS NUEVOS ({len(new_skips)}): `skip` está prohibido (CLAUDE.md §6):")
        for s in new_skips:
            print(f"  - {s}")
    if stale_skips:
        red = True
        print("Tests de .claude/known-skips que ya no se omiten (o no existen): quítalos de la lista (solo baja):")
        for s in stale_skips:
            print(f"  - {s}")
    if new_fail:
        red = True
        print(f"FALLOS NUEVOS ({len(new_fail)}):")
        for f_ in new_fail:
            print(f"  - {f_}")
            for e in errors.get(failed[f_], [])[:2]:
                if e:
                    print(f"      {e}")
    if debt:
        print(f"Fallos conocidos (deuda en .claude/known-failures): {len(debt)}")
    flaky_ok = sorted(k for k in unstable if k in passed)
    if flaky_ok:
        print(f"Inestables de known-failures que esta vez pasaron (no bloquea): {len(flaky_ok)}")
    if now_pass:
        if partial:
            print("Estos tests de .claude/known-failures ahora pasan; quítalos de la lista (la lista solo baja):")
        else:
            red = True
            print("Tests de .claude/known-failures que AHORA PASAN: quítalos de la lista (la lista solo baja):")
        for k in now_pass:
            print(f"  - {k}")
    if stale:
        red = True
        print("Entradas de .claude/known-failures que ya no existen (test renombrado o borrado): quítalas:")
        for k in stale:
            print(f"  - {k}")
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main())
