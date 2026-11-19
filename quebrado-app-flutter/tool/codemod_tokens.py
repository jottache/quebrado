#!/usr/bin/env python3
"""Codemod de la spec 05: cambia valores de estilo escritos a mano por tokens.

Solo hace reemplazos MECÁNICOS y seguros, donde el argumento es un número
literal suelto:

  fontSize: 13                     -> fontSize: OrtizFontSize.body
  EdgeInsets.all(16)               -> EdgeInsets.all(OrtizSpace.lg)
  EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                                   -> ...(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm)
  EdgeInsets.only / fromLTRB / EdgeInsetsDirectional.*  (igual, argumento a argumento)
  SizedBox(height: 8) / SizedBox(width: 12)   (separadores, ≤ 32)
  BorderRadius.circular(14) / Radius.circular(14)  -> OrtizRadius.block
  .withOpacity(x)                  -> .withValues(alpha: x)

Lo que NO toca (lo resuelven los agentes, porque depende del contexto):
colores (`Colors.*`, `Color(0x…)`), números > 32 en márgenes, tamaños en
expresiones (`12 * k`, ternarios), tamaños de icono y dimensiones de layout.

Redondeo al token más cercano (decisión de la spec 05); en empate, al menor.
Añade los imports `package:quebrado_app_flutter/theme/…` que falten.

Uso (desde quebrado-app-flutter/):
  python3 tool/codemod_tokens.py            # simulación: informe, no escribe
  python3 tool/codemod_tokens.py --apply    # escribe los cambios
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

# Fuera de alcance: el design system y las pantallas que la spec 02 reemplaza.
EXCLUDE_DIRS = {"theme"}
EXCLUDE_FILES = {
    "lib/screens/app_launcher_screen.dart",
    "lib/screens/launcher_action_hub_view.dart",
    "lib/widgets/desktop_command_center_view.dart",
    "lib/rich_editor/rich_editor_colors.dart",
}

PKG = "package:quebrado_app_flutter/theme/"
IMPORT_OF = {
    "OrtizSpace": PKG + "ortiz_space.dart",
    "OrtizRadius": PKG + "ortiz_space.dart",
    "OrtizFontSize": PKG + "ortiz_type.dart",
}

SPACE = [(2, "xxs"), (4, "xs"), (8, "sm"), (12, "md"), (16, "lg"), (20, "xl"), (24, "xxl"), (32, "xxxl")]
RADIUS = [(8, "chip"), (12, "field"), (16, "block"), (20, "dialog"), (22, "sheet")]
FONT = [(11, "caption"), (12, "bodySm"), (14, "body"), (16, "titleSm"), (18, "title"), (24, "display"), (32, "displayLg")]

NUM = r"\d+(?:\.\d+)?"


def nearest(value, scale):
    """Token más cercano; en empate, el MENOR (así ninguna pantalla crece y no
    aparecen desbordes nuevos: con empate al mayor, 6→8, 10→12 y 13→14
    desbordaban filas en los widget tests)."""
    best = None
    for v, name in scale:
        d = abs(value - v)
        if best is None or d < best[0] or (d == best[0] and v < best[1]):
            best = (d, v, name)
    return best[2]


def space_token(n):
    if n == 0 or n > 32:
        return None  # 0 no es un estilo; > 32 es layout: lo deciden los agentes
    return "OrtizSpace." + nearest(n, SPACE)


def radius_token(n):
    if n >= 30:
        return "OrtizRadius.pill"
    return "OrtizRadius." + nearest(n, RADIUS)


def font_token(n):
    # < 10 px: vistas densas (calendarios, badges) → `micro` (9). Subirlos a 11
    # desbordaba celdas del calendario semanal.
    if n < 10:
        return "OrtizFontSize.micro"
    return "OrtizFontSize." + nearest(n, FONT)


def split_top_level(args):
    """Parte una lista de argumentos por comas de primer nivel."""
    parts, depth, cur = [], 0, ""
    for ch in args:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return parts


def match_paren(text, open_idx):
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


ARG_NUM = re.compile(r"^(\s*)(?:(\w+)(\s*:\s*))?(" + NUM + r")(\s*)$")


def rewrite_call_args(text, call_re, token_fn, counter, key):
    """Reemplaza argumentos numéricos sueltos dentro de llamadas que casan con call_re."""
    out, pos = [], 0
    for m in call_re.finditer(text):
        open_idx = m.end() - 1
        close_idx = match_paren(text, open_idx)
        if close_idx < 0 or open_idx < pos:
            continue
        args = text[open_idx + 1:close_idx]
        new_parts = []
        changed = False
        for part in split_top_level(args):
            am = ARG_NUM.match(part)
            if am:
                tok = token_fn(float(am.group(4)))
                if tok:
                    name = (am.group(2) or "") + (am.group(3) or "")
                    part = f"{am.group(1)}{name}{tok}{am.group(5)}"
                    changed = True
                    counter[key] = counter.get(key, 0) + 1
            new_parts.append(part)
        if changed:
            out.append(text[pos:open_idx + 1])
            out.append(",".join(new_parts))
            pos = close_idx
    out.append(text[pos:])
    return "".join(out)


EDGE_RE = re.compile(r"\bEdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\(")
RADIUS_RE = re.compile(r"\b(?:BorderRadius|Radius)\.circular\(")
SIZEDBOX_RE = re.compile(r"\bSizedBox\(\s*(height|width)\s*:\s*(" + NUM + r")\s*\)")
FONT_RE = re.compile(r"\bfontSize\s*:\s*(" + NUM + r")(?=\s*[,)\n])")
OPACITY_RE = re.compile(r"\.withOpacity\(")


def transform(text, counter):
    text = rewrite_call_args(text, EDGE_RE, space_token, counter, "EdgeInsets")
    text = rewrite_call_args(text, RADIUS_RE, radius_token, counter, "radio")

    def sized(m):
        tok = space_token(float(m.group(2)))
        if not tok:
            return m.group(0)
        counter["SizedBox"] = counter.get("SizedBox", 0) + 1
        return f"SizedBox({m.group(1)}: {tok})"

    text = SIZEDBOX_RE.sub(sized, text)

    def font(m):
        counter["fontSize"] = counter.get("fontSize", 0) + 1
        return "fontSize: " + font_token(float(m.group(1)))

    text = FONT_RE.sub(font, text)

    n_op = len(OPACITY_RE.findall(text))
    if n_op:
        counter["withOpacity"] = counter.get("withOpacity", 0) + n_op
        text = OPACITY_RE.sub(".withValues(alpha: ", text)
    return text


IMPORT_LINE = re.compile(r"^import\s+['\"][^'\"]+['\"][^;]*;\s*$", re.M)


def ensure_imports(text):
    needed = sorted({uri for cls, uri in IMPORT_OF.items() if re.search(r"\b" + cls + r"\.", text)})
    missing = []
    for uri in needed:
        fname = uri.rsplit("/", 1)[1]
        # Ya importado (por paquete o por ruta relativa).
        if re.search(r"import\s+['\"][^'\"]*" + re.escape(fname) + r"['\"]", text):
            continue
        missing.append(f"import '{uri}';")
    if not missing:
        return text
    last = None
    for m in IMPORT_LINE.finditer(text):
        last = m
    block = "\n".join(missing)
    if last:
        return text[: last.end()] + "\n" + block + text[last.end():]
    return block + "\n" + text


def files():
    for p in sorted(LIB.rglob("*.dart")):
        rel = p.relative_to(ROOT).as_posix()
        if rel in EXCLUDE_FILES:
            continue
        if any(part in EXCLUDE_DIRS for part in p.relative_to(LIB).parts[:-1]):
            continue
        if p.name.endswith("_colors.dart"):
            continue
        yield p, rel


def main():
    apply = "--apply" in sys.argv
    total, touched = {}, 0
    for path, rel in files():
        original = path.read_text(encoding="utf-8")
        counter = {}
        new = transform(original, counter)
        if new == original:
            continue
        new = ensure_imports(new)
        touched += 1
        for k, v in counter.items():
            total[k] = total.get(k, 0) + v
        print(f"{rel}: " + ", ".join(f"{k} {v}" for k, v in sorted(counter.items())))
        if apply:
            path.write_text(new, encoding="utf-8")
    print("-" * 60)
    print(f"Archivos {'modificados' if apply else 'a modificar'}: {touched}")
    for k, v in sorted(total.items()):
        print(f"  {k}: {v}")
    print(f"  TOTAL: {sum(total.values())}")
    if not apply:
        print("Simulación: no se escribió nada. Usa --apply para escribir.")


if __name__ == "__main__":
    main()
