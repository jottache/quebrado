#!/usr/bin/env python3
"""PreToolUse (Bash): impide escribir o volcar código por terminal.

Código vigilado: archivos .dart y .sql y los directorios
quebrado-app-flutter/lib, quebrado-app-flutter/test y supabase (también lib/ y
test/ relativos, por si el comando corre dentro de la app).

Salida: 0 = permitido; 2 = bloqueado (el motivo va a stderr y lo lee el modelo).
Tests: python3 .claude/hooks/guard-bash.test.py
"""
import json
import re
import shlex
import sys

SCRATCH_PREFIXES = ("/private/tmp/claude-", "/tmp/claude-")
CODE_EXT = re.compile(r"\.(dart|sql)$")
CODE_DIR = re.compile(
    r"(^|/)quebrado-app-flutter/(lib|test)(/|$)|^(\./)?(lib|test)(/|$)|(^|/)supabase(/|$)"
)
# Referencia a código dentro de texto libre (scripts python/node, heredocs).
CODE_IN_TEXT = re.compile(
    r"[\w./*-]+\.(dart|sql)\b|quebrado-app-flutter/(lib|test)\b|(^|[\s'\"=(/])supabase/"
)

SEPARATORS = {";", "&&", "||", "&", "(", ")", "\n"}
REDIRECTS = {">", ">>", "&>", "&>>", ">|", ">&"}
WRAPPERS = {"sudo", "env", "command", "time", "nohup", "nice", "exec", "do", "then",
            "else", "{", "!", "builtin"}
DUMPERS = {"cat", "nl", "less", "more", "bat", "tac"}
INTERPRETERS = re.compile(r"^(python[\d.]*|node|ruby|deno|bun|php|osascript)$")

MSG_WRITE = (
    "Bloqueado: escritura a código por Bash ({}).\n"
    "Edita el código con Edit/Write (así se ven los cambios y corren los tests).\n"
    "Si es un falso positivo por texto (p. ej. un mensaje de commit que cita una ruta), "
    "usa `git commit -F <archivo>` o escribe el texto con Write."
)
MSG_DUMP = (
    "Bloqueado: volcado de código ({}).\n"
    "Usa Read con offset/limit o Grep; con Bash, filtra con `| grep`, `| head` o usa head/tail."
)


def is_scratch(path):
    return path.startswith(SCRATCH_PREFIXES)


def is_code(path):
    if not path or is_scratch(path):
        return False
    p = path.strip().rstrip(",")
    if p.startswith("./"):
        p = p[2:]
    return bool(CODE_EXT.search(p) or CODE_DIR.search(p))


def mentions_code(text):
    for m in CODE_IN_TEXT.finditer(text):
        token = m.group(0).strip(" '\"=(")
        if not is_scratch(token):
            # descarta coincidencias que son parte de una ruta del scratchpad
            start = m.start()
            prefix = text[max(0, start - 200):start]
            last_space = max(prefix.rfind(c) for c in " '\"=(\n\t")
            word = prefix[last_space + 1:] + m.group(0)
            if not is_scratch(word.strip(" '\"=(")):
                return True
    return False


HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1")


def split_heredocs(cmd):
    """Devuelve (comando sin cuerpos de heredoc, lista de cuerpos)."""
    lines = cmd.split("\n")
    out, bodies = [], []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        tags = [m.group(2) for m in HEREDOC.finditer(line)]
        i += 1
        for tag in tags:
            body = []
            while i < len(lines) and lines[i].strip() != tag:
                body.append(lines[i])
                i += 1
            i += 1  # salta la línea de cierre
            bodies.append("\n".join(body))
    return "\n".join(out), bodies


def tokenize(cmd):
    """Tokens con separadores y redirecciones como tokens propios."""
    tokens = []
    for line in cmd.split("\n"):
        try:
            lex = shlex.shlex(line, posix=True, punctuation_chars=";&|<>()")
            lex.whitespace_split = True
            lex.commenters = ""
            tokens.extend(list(lex))
        except ValueError:
            tokens.extend(re.split(r"\s+", line))
        tokens.append("\n")
    return [t for t in tokens if t != ""]


def pipelines(tokens):
    """Lista de pipelines; cada pipeline es una lista de comandos (listas de tokens)."""
    result, pipe, cur = [], [], []
    for t in tokens:
        if t in SEPARATORS:
            if cur:
                pipe.append(cur)
            if pipe:
                result.append(pipe)
            pipe, cur = [], []
        elif t in ("|", "|&"):
            pipe.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        pipe.append(cur)
    if pipe:
        result.append(pipe)
    return result


def strip_redirects(cmd):
    """Separa (palabras, destinos de redirección de salida)."""
    words, targets = [], []
    i = 0
    while i < len(cmd):
        t = cmd[i]
        if t in REDIRECTS or t == "<" or t == "<<" or t == "<<<":
            nxt = cmd[i + 1] if i + 1 < len(cmd) else ""
            if t in REDIRECTS and not (t == ">&" and nxt.isdigit()) and nxt != "-":
                targets.append(nxt)
            i += 2
            continue
        if re.fullmatch(r"\d", t) and i + 1 < len(cmd) and cmd[i + 1] in REDIRECTS:
            i += 1  # descriptor (2>, 1>)
            continue
        words.append(t)
        i += 1
    return words, targets


def head_words(words):
    """Quita envoltorios (sudo, env, VAR=x, do…) y devuelve el comando real."""
    w = list(words)
    while w:
        first = w[0]
        if first in WRAPPERS or re.fullmatch(r"[A-Za-z_]\w*=.*", first):
            w = w[1:]
            # env -i / nice -n 5
            while w and w[0].startswith("-") and first in ("env", "nice", "sudo"):
                w = w[1:]
        else:
            break
    return w


def base(name):
    return name.rsplit("/", 1)[-1]


def args_of(words):
    return [a for a in words[1:] if not a.startswith("-")]


def dest_of(words):
    for i, a in enumerate(words):
        if a in ("-t", "--target-directory") and i + 1 < len(words):
            return words[i + 1]
        if a.startswith("--target-directory="):
            return a.split("=", 1)[1]
    args = args_of(words)
    return args[-1] if len(args) >= 2 else None


WRITE_CALLS = [
    re.compile(r"open\(\s*(['\"])([^'\"]+)\1\s*,\s*(['\"])[rbt]*[wax+]"),
    re.compile(r"Path\(\s*(['\"])([^'\"]+)\1\s*\)\s*\.\s*write_(?:text|bytes)\("),
    re.compile(r"writeFile(?:Sync)?\(\s*(['\"`])([^'\"`]+)\1"),
    re.compile(r"appendFile(?:Sync)?\(\s*(['\"`])([^'\"`]+)\1"),
]
DYNAMIC_WRITES = re.compile(
    r"open\([^)]*,\s*['\"][rbt]*[wax+]|\.write_(text|bytes)\(|writeFile|appendFile|"
    r"shutil\.(copy\w*|move)\(|os\.(rename|replace)\(|copyFileSync|renameSync"
)


def script_writes_code(text):
    """True si el texto de un script escribe a código."""
    literal_hit = False
    for rx in WRITE_CALLS:
        for m in rx.finditer(text):
            literal_hit = True
            if is_code(m.group(2)):
                return True
    if DYNAMIC_WRITES.search(text):
        # escrituras con destino no literal: si el script menciona código, se bloquea
        cleaned = text
        for rx in WRITE_CALLS:
            cleaned = rx.sub("", cleaned)
        if DYNAMIC_WRITES.search(cleaned) and mentions_code(text):
            return True
    return False


def check(cmd):
    """Devuelve el motivo del bloqueo o None."""
    if not cmd.strip():
        return None
    structural, bodies = split_heredocs(cmd)
    tokens = tokenize(structural)
    pipes = pipelines(tokens)
    all_words = [t for t in tokens if t not in SEPARATORS and t not in ("|", "|&")]
    any_code_token = any(is_code(t) for t in all_words) or mentions_code(cmd)

    # Bucles for … do cat (volcado en lote)
    if re.search(r"\bdo\s+(cat|nl|less|more|bat)\b", structural) and any_code_token \
            and not re.search(r"\bdone\s*\|", structural):
        return MSG_DUMP.format("bucle con cat")

    for pipe in pipes:
        for idx, raw in enumerate(pipe):
            words, targets = strip_redirects(raw)
            for tgt in targets:
                if is_code(tgt):
                    return MSG_WRITE.format(f"redirección hacia {tgt}")
            w = head_words(words)
            if not w:
                continue
            name = base(w[0])

            # sed/perl -i en cualquier posición (xargs, find -exec, env…)
            for j, tok in enumerate(words):
                b = base(tok)
                if b in ("sed", "gsed", "perl"):
                    rest = words[j + 1:]
                    inplace = any(
                        re.fullmatch(r"-[a-zA-Z]*i.*", a) and not a.startswith("--")
                        or a.startswith("--in-place")
                        for a in rest
                        if a.startswith("-")
                    )
                    if b == "perl":
                        inplace = any(re.fullmatch(r"-[a-zA-Z]*i\S*", a) for a in rest)
                    if inplace and any_code_token:
                        return MSG_WRITE.format(f"{b} -i")

            if name == "tee":
                if any(is_code(a) for a in args_of(w)):
                    return MSG_WRITE.format("tee hacia código")

            if name in ("cp", "mv", "install", "rsync", "ln"):
                dest = dest_of(w)
                if dest and is_code(dest):
                    return MSG_WRITE.format(f"{name} con destino {dest}")

            if name == "git" and len(w) > 1:
                sub = w[1]
                if sub == "mv":
                    dest = dest_of(w[1:])
                    if dest and is_code(dest):
                        return MSG_WRITE.format(f"git mv con destino {dest}")
                if sub == "apply" and "--check" not in w:
                    return MSG_WRITE.format("git apply (usa --check para probar)")

            if name == "patch" and "--dry-run" not in w:
                return MSG_WRITE.format("patch")

            if name in ("dart", "flutter") and len(w) > 1:
                sub = w[1]
                if sub == "format":
                    safe = (
                        "--set-exit-if-changed" in w
                        or "--output=none" in w
                        or "-onone" in w
                        or any(
                            w[k] in ("--output", "-o") and k + 1 < len(w) and w[k + 1] == "none"
                            for k in range(len(w))
                        )
                    )
                    if not safe:
                        return MSG_WRITE.format(
                            f"{name} format (usa --output none o --set-exit-if-changed)")
                if sub == "fix" and "--apply" in w:
                    return MSG_WRITE.format("dart fix --apply")

            # intérpretes con código en línea o heredoc
            if INTERPRETERS.match(name):
                inline = " ".join(w[1:])
                text = inline + "\n" + "\n".join(bodies)
                if script_writes_code(text):
                    return MSG_WRITE.format(f"script {name} que escribe código")

            # volcados: cat/nl/less/more de código sin pipe que filtre
            if name in DUMPERS and len(pipe) == 1:
                if any(is_code(a) for a in args_of(w)):
                    return MSG_DUMP.format(f"{name} de código")
            if name in ("sed", "gsed") and len(pipe) == 1:
                has_n = any(re.fullmatch(r"-[a-zA-Z]*n[a-zA-Z]*", a) for a in w[1:])
                if has_n and any(is_code(a) for a in args_of(w)[1:]):
                    return MSG_DUMP.format("sed -n de código")
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    cmd = (data.get("tool_input") or {}).get("command") or ""
    reason = check(cmd)
    if reason:
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
