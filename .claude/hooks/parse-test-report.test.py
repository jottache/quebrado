#!/usr/bin/env python3
"""Tests de parse-test-report.py con informes JSON sintéticos.

Uso: python3 .claude/hooks/parse-test-report.test.py   (imprime nº de casos y fallos)
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PARSER = os.path.join(HERE, "parse-test-report.py")
APP = "/repo/quebrado-app-flutter"


def report(tests, done=True, success=None):
    """tests: lista de (archivo, nombre, resultado) con resultado ok|fail|skip."""
    evs = [{"type": "suite", "suite": {"id": 1, "path": f"{APP}/test/a_test.dart"}},
           {"type": "suite", "suite": {"id": 2, "path": f"{APP}/test/b_test.dart"}}]
    any_fail = False
    for i, (suite, name, res) in enumerate(tests, start=10):
        evs.append({"type": "testStart", "test": {"id": i, "suiteID": suite, "name": name}})
        if res == "fail":
            any_fail = True
            evs.append({"type": "error", "testID": i, "error": "Expected: 1\n  Actual: 2"})
        evs.append({"type": "testDone", "testID": i, "hidden": False,
                    "skipped": res == "skip", "result": "error" if res == "fail" else "success"})
    if done:
        evs.append({"type": "done", "success": (not any_fail) if success is None else success})
    return "\n".join(json.dumps(e) for e in evs) + "\n"


def run(rep, known="", skips="", partial=False):
    with tempfile.TemporaryDirectory() as d:
        paths = {}
        for name, content in (("r.jsonl", rep), ("known", known), ("skips", skips)):
            paths[name] = os.path.join(d, name)
            with open(paths[name], "w", encoding="utf-8") as f:
                f.write(content)
        env = dict(os.environ, CLAUDE_PROJECT_DIR="/repo",
                   KNOWN_FAILURES_FILE=paths["known"], KNOWN_SKIPS_FILE=paths["skips"])
        args = [sys.executable, PARSER, paths["r.jsonl"]] + (["--partial"] if partial else [])
        p = subprocess.run(args, env=env, capture_output=True, text=True)
        return p.returncode, p.stdout


A_OK = (1, "g suma", "ok")
A_FAIL = (1, "g resta", "fail")
B_SKIP = (2, "omitido", "skip")
KF = "test/a_test.dart::g resta\n"
KS = "test/b_test.dart::omitido\n"

CASES = [
    # (descripción, informe, known, skips, partial, salida esperada, texto esperado)
    ("todo verde", report([A_OK]), "", "", False, 0, "1 pasan"),
    ("fallo nuevo → rojo", report([A_OK, A_FAIL]), "", "", False, 1, "FALLOS NUEVOS"),
    ("fallo conocido → verde", report([A_OK, A_FAIL]), KF, "", False, 0, "deuda"),
    ("conocido que ahora pasa → rojo", report([(1, "g resta", "ok")]), KF, "", False, 1, "AHORA PASAN"),
    ("conocido que ahora pasa en parcial → verde", report([(1, "g resta", "ok")]), KF, "", True, 0, "quítalos"),
    ("inestable que pasa → verde", report([(1, "g resta", "ok")]), "~" + KF, "", False, 0, "Inestables"),
    ("inestable que falla → verde", report([A_FAIL]), "~" + KF, "", False, 0, "deuda"),
    ("entrada que ya no existe → rojo", report([A_OK]), KF, "", False, 1, "ya no existen"),
    ("sin evento done → rojo", report([A_OK], done=False), "", "", False, 1, "sin el evento final"),
    ("done fallido sin fallos → rojo", report([A_OK], success=False), "", "", False, 1, "error de carga"),
    ("skip nuevo → rojo", report([A_OK, B_SKIP]), "", "", False, 1, "OMITIDOS NUEVOS"),
    ("skip nuevo en parcial → rojo", report([A_OK, B_SKIP]), "", "", True, 1, "OMITIDOS NUEVOS"),
    ("skip conocido → verde", report([A_OK, B_SKIP]), "", KS, False, 0, "1 omitidos"),
    ("skip conocido que ya corre → rojo", report([A_OK, (2, "omitido", "ok")]), "", KS, False, 1, "ya no se omiten"),
    ("informe vacío → rojo", "", "", "", False, 1, "ningún test"),
    ("fallo de carga oculto → rojo", report([A_OK]).replace(
        '{"type": "done"',
        json.dumps({"type": "testStart", "test": {"id": 99, "suiteID": 2, "name": "loading test/b_test.dart"}})
        + "\n" + json.dumps({"type": "testDone", "testID": 99, "hidden": True, "skipped": False, "result": "error"})
        + '\n{"type": "done"'), "", "", False, 1, "FALLOS NUEVOS"),
]


def main():
    fails = 0
    for desc, rep, known, skips, partial, want_code, want_text in CASES:
        code, out = run(rep, known, skips, partial)
        if code != want_code or want_text not in out:
            fails += 1
            print(f"FALLA: {desc}: salida={code} (esperada {want_code})\n{out}")
    print(f"parse-test-report: {len(CASES)} casos, {fails} fallos")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
