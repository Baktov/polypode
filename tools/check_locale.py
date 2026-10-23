"""Contrôle des traductions d'un module Polypode (voir MODULES.md, « Langues »).

    python Polypode\\tools\\check_locale.py <dossier du module>      # depuis ADDONS_POLYPODE

Lit les .lua du module (hors Locales/) et les tables de Locales/*.lua, puis signale :
- les clés L["..."] du code sans traduction dans une langue (enUS obligatoire) ;
- les traductions dont la clé n'est plus utilisée dans le code ;
- les traductions dont les spécificateurs de format (%s, %d, %%...) diffèrent de la clé (ordre compris) ;
- les textes français restés hors de L[...] (accents ou plusieurs mots ; hors P.Debug, commentaires
  et fichiers marqués « -- check_locale: noms propres ») : liste à relire, tous ne sont pas des
  textes affichés.
Code de sortie 1 s'il manque une traduction anglaise ou si un format diffère.
"""
import pathlib
import re
import sys

ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
FORMAT = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[a-zA-Z%]")
FRENCH = re.compile(r"[àâçéèêëîïôûùœÀÂÇÉÈÊ]")


def tokens(text):
    """Jetons (type, valeur, ligne) : "str", "name" ou "op" ; commentaires ignorés."""
    i, line, n = 0, 1, len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c.isspace():
            i += 1
        elif text.startswith("--", i):
            block = re.match(r"--\[(=*)\[", text[i:])
            if block:
                end = text.find("]" + block.group(1) + "]", i)
                end = n if end < 0 else end + len(block.group(1)) + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            line += text.count("\n", i, end)
            i = end
        elif c in "\"'":
            j, value = i + 1, []
            while j < n and text[j] != c:
                if text[j] == "\\" and j + 1 < n:
                    value.append(ESCAPES.get(text[j + 1], text[j + 1]))
                    j += 2
                else:
                    value.append(text[j])
                    j += 1
            yield "str", "".join(value), line
            line += text.count("\n", i, j)
            i = j + 1
        elif text.startswith("[[", i) or re.match(r"\[=+\[", text[i:]):
            level = re.match(r"\[(=*)\[", text[i:]).group(1)
            end = text.find("]" + level + "]", i)
            end = n if end < 0 else end
            yield "str", text[i + len(level) + 2:end], line
            line += text.count("\n", i, end)
            i = end + len(level) + 2
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", text[i:])
            yield "name", m.group(0), line
            i += len(m.group(0))
        elif text.startswith("..", i):
            yield "op", "..", line
            i += 2
        else:
            yield "op", c, line
            i += 1


def scan_code(path):
    """Clés L[...] (clé → [lignes]) et littéraux hors L[...] (ligne, texte, sur une ligne P.Debug)."""
    toks = list(tokens(path.read_text(encoding="utf-8")))
    keys, loose, debug_lines = {}, [], set()
    for k, (kind, value, line) in enumerate(toks):
        if kind == "name" and value == "Debug" and k and toks[k - 1][1] == ".":
            depth, j = 0, k + 1
            while j < len(toks):
                if toks[j][1] == "(":
                    depth += 1
                elif toks[j][1] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                debug_lines.update(range(line, toks[j][2] + 1))
                j += 1
    k = 0
    while k < len(toks):
        kind, value, line = toks[k]
        if kind == "name" and value == "L" and k + 2 < len(toks) and toks[k + 1][1] == "[" and toks[k + 2][0] == "str":
            parts, j = [toks[k + 2][1]], k + 3
            while j + 1 < len(toks) and toks[j][1] == ".." and toks[j + 1][0] == "str":
                parts.append(toks[j + 1][1])
                j += 2
            if toks[j][1] == "]":
                keys.setdefault("".join(parts), []).append(line)
                k = j + 1
                continue
        if kind == "str":
            loose.append((line, value, line in debug_lines))
        k += 1
    return keys, loose


def scan_locale(path):
    """Traductions d'un fichier de langue : clé → texte."""
    toks = list(tokens(path.read_text(encoding="utf-8")))
    table = {}
    for k in range(len(toks) - 4):
        if toks[k][1] == "[" and toks[k + 1][0] == "str" and toks[k + 2][1] == "]" and toks[k + 3][1] == "=" \
                and toks[k + 4][0] == "str":
            table[toks[k + 1][1]] = toks[k + 4][1]
    return table


def main(module):
    module = pathlib.Path(module)
    used, suspects = {}, []
    for path in sorted(module.rglob("*.lua")):
        rel = path.relative_to(module)
        if rel.parts[0] in ("Locales", "Modele", "tools") or ".kilo" in rel.parts:
            continue
        keys, loose = scan_code(path)
        for key, lines in keys.items():
            used.setdefault(key, []).extend(f"{rel}:{line}" for line in lines)
        # Fichier de noms propres (lieux...) traduits autrement que par L[...] : pas à relire.
        if "-- check_locale: noms propres" in path.read_text(encoding="utf-8"):
            continue
        for line, value, in_debug in loose:
            if not in_debug and (FRENCH.search(value) or re.search(r"[a-z]{2,} [a-z]{2,} [a-z]{2,}", value)):
                suspects.append(f"{rel}:{line}: {value[:100]!r}")

    locales = {p.stem: scan_locale(p) for p in sorted((module / "Locales").glob("*.lua"))}
    errors = 0
    if "enUS" not in locales:
        print("Locales/enUS.lua manquant")
        errors += 1
    for name, table in locales.items():
        missing = [k for k in used if k not in table]
        unused = [k for k in table if k not in used]
        # Même suite de formats, dans le même ordre : string.format de Lua est positionnel. Formats
        # de date() (%H, %m ou %Y, inconnus de string.format) : mêmes éléments, ordre libre
        # (jour/mois selon la langue).
        def is_date(key):
            return any(code in key for code in ("%H", "%m", "%Y"))
        bad_format = [k for k, v in table.items()
                      if (sorted(FORMAT.findall(k)) != sorted(FORMAT.findall(v)) if is_date(k)
                          else FORMAT.findall(k) != FORMAT.findall(v))]
        print(f"== {name} : {len(table)} traductions, {len(missing)} manquantes, {len(unused)} inutilisées, "
              f"{len(bad_format)} formats différents")
        for k in missing:
            print(f"  manquante : {k!r} ({used[k][0]})")
        for k in unused:
            print(f"  inutilisée : {k!r}")
        for k in bad_format:
            print(f"  format : {k!r} -> {table[k]!r}")
        if name == "enUS":
            errors += len(missing)
        errors += len(bad_format)
    print(f"== {len(used)} clés dans le code ; {len(suspects)} textes hors L[...] à relire")
    for s in suspects:
        print("  " + s)
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
