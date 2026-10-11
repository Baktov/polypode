#!/usr/bin/env python3
# Polypode : tools/import_bnet.py — liste des personnages d'un compte Battle.net pour /poly import
#
# Lit, par l'API Profile de Blizzard (/profile/user/wow), tous les personnages des comptes WoW
# rattachés à un compte Battle.net, relie chaque compte WoW à son dossier WTF/Account/<compte>
# (par les identifiants de character-list-order.txt) et écrit une ligne par personnage absent
# du roster de Polypode :
#     Nom-Royaume;CLASSE;niveau;compte;BattleTag
# Lecture seule : aucun fichier de WoW n'est modifié, le jeton OAuth n'est jamais enregistré.
# Bibliothèque standard de Python 3.8+ uniquement. Mode d'emploi : tools/IMPORT_BNET.md.

import argparse
import base64
import getpass
import http.server
import json
import os
import re
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from collections import Counter

OAUTH_HOST = "https://oauth.battle.net"
REGIONS = ("eu", "us", "kr", "tw")
# Espaces (namespaces) de l'API Profile, par version du jeu
NAMESPACES = {
    "retail": "profile-{region}",
    "classic": "profile-classic-{region}",
    "classic1x": "profile-classic1x-{region}",
}
# playable_class.id de l'API → classe telle que la donne UnitClass (2e résultat) dans le jeu
CLASS_TOKENS = {
    1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 6: "DEATHKNIGHT",
    7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 10: "MONK", 11: "DRUID", 12: "DEMONHUNTER",
    13: "EVOKER",
}
DEFAULT_PORT = 8765
HTTP_TIMEOUT = 30


def warn(message):
    """Messages de suivi sur la sortie d'erreur : la sortie standard reste aux lignes d'import."""
    print(message, file=sys.stderr)


class ScriptError(Exception):
    pass


# --------------------------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------------------------

def http_json(url, data=None, headers=None):
    """GET (ou POST si data) et décodage JSON ; renvoie (code HTTP, objet ou None)."""
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    request = urllib.request.Request(url, data=body, headers=headers or {})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        try:
            payload = json.loads(err.read().decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            payload = None
        return err.code, payload
    except urllib.error.URLError as err:
        raise ScriptError("Connexion impossible à {} : {}".format(url, err.reason))


# --------------------------------------------------------------------------------------------
# OAUTH : connexion de l'utilisateur dans son navigateur (authorization code flow)
# --------------------------------------------------------------------------------------------

class CallbackHandler(http.server.BaseHTTPRequestHandler):
    """Reçoit la redirection de Battle.net (?code=...&state=...) sur http://localhost:<port>/callback."""

    result = None

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/callback":
            self.send_response(404)
            self.end_headers()
            return
        CallbackHandler.result = dict(urllib.parse.parse_qsl(parsed.query))
        ok = "code" in CallbackHandler.result
        message = ("Connexion réussie : vous pouvez fermer cette page et revenir au script."
                   if ok else "Connexion refusée ou annulée : voir le message du script.")
        page = "<html><meta charset='utf-8'><body style='font-family:sans-serif'><p>{}</p></body></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.format(message).encode("utf-8"))

    def log_message(self, *args):
        pass  # pas de journal HTTP dans la console


def get_user_token(client_id, client_secret, port):
    redirect_uri = "http://localhost:{}/callback".format(port)
    state = secrets.token_urlsafe(16)
    query = urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "openid wow.profile",
        "state": state,
    })
    authorize_url = "{}/authorize?{}".format(OAUTH_HOST, query)

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), CallbackHandler)
    except OSError as err:
        raise ScriptError("Le port {} est occupé ({}) : choisir un autre port avec --port "
                          "(et l'ajouter aux redirections du client Battle.net).".format(port, err))
    server.timeout = 1
    CallbackHandler.result = None

    warn("Ouverture du navigateur pour la connexion Battle.net...")
    warn("Si rien ne s'ouvre, copier cette adresse dans le navigateur :\n  " + authorize_url)
    threading.Timer(0.5, webbrowser.open, args=(authorize_url,)).start()

    deadline = time.time() + 300
    while CallbackHandler.result is None and time.time() < deadline:
        server.handle_request()
    server.server_close()

    result = CallbackHandler.result
    if result is None:
        raise ScriptError("Pas de réponse de Battle.net en 5 minutes : relancer le script.")
    if result.get("state") != state:
        raise ScriptError("Réponse de Battle.net inattendue (state différent) : relancer le script.")
    if "code" not in result:
        raise ScriptError("Connexion refusée : {} {}".format(
            result.get("error", ""), result.get("error_description", "")).strip())

    basic = base64.b64encode("{}:{}".format(client_id, client_secret).encode()).decode()
    status, token = http_json(
        OAUTH_HOST + "/token",
        data={"grant_type": "authorization_code", "code": result["code"],
              "redirect_uri": redirect_uri},
        headers={"Authorization": "Basic " + basic})
    if status != 200 or not token or "access_token" not in token:
        detail = (token or {}).get("error_description") or (token or {}).get("error") or status
        raise ScriptError("Échange du code refusé par Battle.net ({}) : vérifier l'identifiant, "
                          "le secret et la redirection du client.".format(detail))
    return token["access_token"]


def get_battletag(access_token):
    status, info = http_json(OAUTH_HOST + "/userinfo",
                             headers={"Authorization": "Bearer " + access_token})
    if status == 200 and info:
        return info.get("battletag") or ""
    warn("BattleTag illisible (code {}) : les lignes n'auront pas de BattleTag.".format(status))
    return ""


def get_account_profile(access_token, region, namespace, locale):
    """Profil du compte (/profile/user/wow) ; renvoie (code HTTP, objet)."""
    query = urllib.parse.urlencode({"namespace": namespace, "locale": locale})
    url = "https://{}.api.blizzard.com/profile/user/wow?{}".format(region, query)
    return http_json(url, headers={"Authorization": "Bearer " + access_token})


# --------------------------------------------------------------------------------------------
# LECTURE DE SAVEDVARIABLES (sous-ensemble de Lua écrit par WoW : tables, chaînes, nombres)
# --------------------------------------------------------------------------------------------

LUA_TOKEN = re.compile(r"""
    \s+ | --\[\[.*?\]\] | --[^\n]* |
    (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*') |
    (?P<num>-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+)) |
    (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
    (?P<sym>[{}\[\]=,;])
""", re.VERBOSE | re.DOTALL)

LUA_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n",
               "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def lua_unescape(raw):
    def repl(match):
        text = match.group(1)
        if text.isdigit():
            return chr(int(text))
        return LUA_ESCAPES.get(text, text)
    return re.sub(r"\\(\d{1,3}|.)", repl, raw[1:-1], flags=re.DOTALL)


def lua_tokens(text):
    pos = 0
    tokens = []
    while pos < len(text):
        match = LUA_TOKEN.match(text, pos)
        if not match:
            raise ValueError("caractère inattendu à la position {}".format(pos))
        pos = match.end()
        kind = match.lastgroup
        if kind == "str":
            tokens.append(("val", lua_unescape(match.group(kind))))
        elif kind == "num":
            value = match.group(kind)
            tokens.append(("val", int(value, 0) if re.fullmatch(r"-?(0[xX][0-9a-fA-F]+|\d+)", value)
                           else float(value)))
        elif kind == "name":
            word = match.group(kind)
            consts = {"true": True, "false": False, "nil": None}
            tokens.append(("val", consts[word]) if word in consts else ("name", word))
        elif kind == "sym":
            tokens.append(("sym", match.group(kind)))
    return tokens


def parse_saved_variables(text):
    """Renvoie {nom de variable: valeur} ; les tables Lua deviennent des dict."""
    tokens = lua_tokens(text)
    index = 0

    def peek():
        return tokens[index] if index < len(tokens) else (None, None)

    def take(expected=None):
        nonlocal index
        token = peek()
        if expected and token != expected:
            raise ValueError("attendu {} et trouvé {}".format(expected, token))
        index += 1
        return token

    def value():
        kind, val = peek()
        if (kind, val) == ("sym", "{"):
            return table()
        if kind == "val":
            take()
            return val
        raise ValueError("valeur attendue, trouvé {}".format((kind, val)))

    def table():
        take(("sym", "{"))
        result = {}
        position = 1
        while peek() != ("sym", "}"):
            if peek() == ("sym", "["):
                take()
                key = value()
                take(("sym", "]"))
                take(("sym", "="))
                result[key] = value()
            elif peek()[0] == "name" and tokens[index + 1] == ("sym", "="):
                key = take()[1]
                take()
                result[key] = value()
            else:
                result[position] = value()
                position += 1
            if peek() in (("sym", ","), ("sym", ";")):
                take()
        take(("sym", "}"))
        return result

    variables = {}
    while index < len(tokens):
        name = take()
        if name[0] != "name":
            raise ValueError("nom de variable attendu, trouvé {}".format(name))
        take(("sym", "="))
        variables[name[1]] = value()
    return variables


# --------------------------------------------------------------------------------------------
# DOSSIER DE WOW : comptes, roster de Polypode, langue
# --------------------------------------------------------------------------------------------

def find_wow_dir(explicit):
    """Dossier de la version du jeu (celui qui contient WTF) : donné, ou cherché depuis le script
    (installé dans Interface/AddOns/Polypode/tools) puis depuis le dossier courant."""
    if explicit:
        if not os.path.isdir(os.path.join(explicit, "WTF")):
            raise ScriptError("Pas de dossier WTF dans {}.".format(explicit))
        return explicit
    for start in (os.path.dirname(os.path.abspath(__file__)), os.getcwd()):
        folder = start
        while True:
            if os.path.isdir(os.path.join(folder, "WTF", "Account")):
                return folder
            parent = os.path.dirname(folder)
            if parent == folder:
                break
            folder = parent
    return None


def account_dirs(wow_dir):
    """Dossiers de comptes WoW (WTF/Account/<compte>), une seule fois chacun (liens résolus)."""
    root = os.path.join(wow_dir, "WTF", "Account")
    seen = set()
    result = []
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if name == "SavedVariables" or not os.path.isdir(path):
            continue
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        result.append((name, path))
    return result


def read_character_ids(account_path):
    """Identifiants des personnages du compte (partie hexadécimale de Player-<serveur>-<id>)."""
    path = os.path.join(account_path, "character-list-order.txt")
    ids = set()
    if os.path.isfile(path):
        with open(path, encoding="utf-8", errors="replace") as handle:
            for match in re.finditer(r"\b\d+-([0-9A-Fa-f]{6,})\b", handle.read()):
                ids.add(int(match.group(1), 16))
    return ids


def read_polypode(accounts):
    """Roster (toutes entrées, retirées comprises) et comptes nommés, réunis sur tous les comptes."""
    roster = {}
    labels = {}
    for name, path in accounts:
        file_path = os.path.join(path, "SavedVariables", "Polypode.lua")
        if not os.path.isfile(file_path):
            continue
        try:
            with open(file_path, encoding="utf-8", errors="replace") as handle:
                db = parse_saved_variables(handle.read()).get("PolypodeDB") or {}
        except ValueError as err:
            warn("Roster de {} illisible ({}) : ignoré.".format(name, err))
            continue
        for key, entry in (db.get("roster") or {}).items():
            if isinstance(entry, dict):
                known = roster.get(key)
                # l'entrée la plus récente l'emporte (retrait compris)
                if known is None or (entry.get("updated") or 0) > (known.get("updated") or 0):
                    roster[key] = entry
        for key, label in (db.get("accountLabels") or {}).items():
            if isinstance(label, dict) and label.get("label"):
                known = labels.get(key)
                if known is None or (label.get("updated") or 0) > (known.get("updated") or 0):
                    labels[key] = label
    return roster, {key: label["label"] for key, label in labels.items()}


def read_locale(wow_dir):
    """Langue du client (SET textLocale "frFR" → fr_FR), pour des noms de royaume identiques au jeu."""
    path = os.path.join(wow_dir, "WTF", "Config.wtf") if wow_dir else None
    if path and os.path.isfile(path):
        with open(path, encoding="utf-8", errors="replace") as handle:
            match = re.search(r'SET textLocale "([a-z]{2})([A-Z]{2})"', handle.read())
            if match:
                return "{}_{}".format(match.group(1), match.group(2))
    return None


# --------------------------------------------------------------------------------------------
# TRAITEMENT
# --------------------------------------------------------------------------------------------

def text_field(value):
    """Champ de l'API : texte (avec locale) ou dict de traductions (sans)."""
    if isinstance(value, dict):
        return value.get("fr_FR") or value.get("en_US") or next(iter(value.values()), "")
    return value or ""


def collect_characters(profile):
    """Liste de (index du compte WoW, numéro du compte WoW, personnage normalisé)."""
    result = []
    for number, account in enumerate(profile.get("wow_accounts") or [], start=1):
        for char in account.get("characters") or []:
            class_info = char.get("playable_class") or {}
            realm = char.get("realm") or {}
            result.append((number, account.get("id"), {
                "id": char.get("id"),
                "name": text_field(char.get("name")),
                "realm": text_field(realm.get("name")) or realm.get("slug", ""),
                "class": CLASS_TOKENS.get(class_info.get("id"), ""),
                "level": char.get("level") or "",
            }))
    return result


def match_accounts(profile, accounts):
    """Compte WoW (numéro d'ordre) → (dossier, nb d'identifiants communs, nb de personnages)."""
    folder_ids = [(name, read_character_ids(path)) for name, path in accounts]
    matches = {}
    for number, account in enumerate(profile.get("wow_accounts") or [], start=1):
        ids = {char.get("id") for char in account.get("characters") or []}
        best = None
        for name, known in folder_ids:
            common = len(ids & known)
            if common and (best is None or common > best[1]):
                best = (name, common, len(ids))
        matches[number] = best
    return matches


def account_names(characters, matches, labels):
    """Nom de chaque compte WoW : compte déjà nommé dans Polypode (le plus fréquent parmi ses
    personnages), sinon nom du dossier WTF, sinon « Compte N »."""
    names = {}
    for number in sorted({c[0] for c in characters} | set(matches)):
        counts = Counter(labels[key] for n, _, char in characters if n == number
                         for key in [char_key(char)] if key in labels)
        if counts:
            names[number] = counts.most_common(1)[0][0]
        elif matches.get(number):
            names[number] = matches[number][0]
        else:
            names[number] = "Compte {}".format(number)
    return names


def char_key(char):
    return "{}-{}".format(char["name"], char["realm"])


def clean(value):
    return str(value).replace(";", ",").replace("\n", " ").strip()


def print_check(characters, matches, names, roster):
    warn("")
    warn("Comptes WoW renvoyés par l'API et dossier WTF correspondant :")
    for number in sorted(names):
        match = matches.get(number)
        found = ("dossier {} ({} identifiants sur {} en commun)".format(*match) if match
                 else "aucun dossier trouvé (identifiants différents ou dossier WTF absent)")
        warn("  Compte {} -> nom « {} » : {}".format(number, names[number], found))
    warn("")
    warn("Personnages (identifiant de l'API = identifiant hexadécimal de character-list-order.txt) :")
    for number, _, char in sorted(characters, key=lambda c: (c[0], char_key(c[2]))):
        entry = roster.get(char_key(char))
        state = "nouveau" if entry is None else (
            "retiré du roster" if entry.get("removed") else "dans le roster")
        warn("  [{}] {:<28} id {:>10} = {:08X}  {:<12} niv. {:<3} {}".format(
            names[number], char_key(char), char["id"] or 0, char["id"] or 0,
            char["class"] or "?", char["level"], state))


def main():
    parser = argparse.ArgumentParser(
        description="Liste les personnages d'un compte Battle.net pour la commande /poly import de "
                    "Polypode (voir tools/IMPORT_BNET.md).")
    parser.add_argument("--region", default="eu", choices=REGIONS,
                        help="région du compte (défaut : eu)")
    parser.add_argument("--namespace", default="retail",
                        help="version du jeu : retail (défaut), classic, classic1x, ou espace "
                             "complet (ex. profile-classic-eu)")
    parser.add_argument("--probe", action="store_true",
                        help="essaie chaque version du jeu et indique celles qui répondent")
    parser.add_argument("--check", action="store_true",
                        help="affiche la correspondance personnage / dossier de compte, sans lignes d'import")
    parser.add_argument("--all", action="store_true",
                        help="sort aussi les personnages déjà dans le roster de Polypode")
    parser.add_argument("--wow-dir",
                        help="dossier de la version du jeu, celui qui contient WTF (ex. "
                             "\"C:\\Program Files (x86)\\World of Warcraft\\_retail_\") ; "
                             "trouvé seul si le script est dans Interface\\AddOns\\Polypode\\tools")
    parser.add_argument("--locale", help="langue des noms (ex. fr_FR) ; défaut : celle du jeu")
    parser.add_argument("--output", default="polypode_import.txt",
                        help="fichier des lignes à coller dans /poly import (défaut : "
                             "polypode_import.txt ; « - » pour l'écran)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT,
                        help="port local de la redirection (défaut : {})".format(DEFAULT_PORT))
    parser.add_argument("--save-json", help="enregistre la réponse brute de l'API dans ce fichier")
    parser.add_argument("--from-json",
                        help="utilise une réponse enregistrée (--save-json) au lieu de se connecter")
    # console Windows : un caractère qu'elle ne sait pas afficher est remplacé, sans erreur
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    args = parser.parse_args()

    wow_dir = find_wow_dir(args.wow_dir)
    accounts = account_dirs(wow_dir) if wow_dir else []
    if wow_dir:
        warn("Dossier du jeu : {} ({} dossiers de comptes)".format(wow_dir, len(accounts)))
    else:
        warn("Dossier du jeu introuvable (option --wow-dir) : comptes numérotés, roster non lu.")
    locale = args.locale or read_locale(wow_dir) or "en_US"
    roster, labels = read_polypode(accounts)

    battletag = ""
    if args.from_json:
        with open(args.from_json, encoding="utf-8") as handle:
            saved = json.load(handle)
        profile, battletag = saved.get("profile", saved), saved.get("battletag", "")
    else:
        client_id = os.environ.get("BNET_CLIENT_ID") or input("Identifiant du client Battle.net : ").strip()
        client_secret = os.environ.get("BNET_CLIENT_SECRET") or getpass.getpass(
            "Secret du client Battle.net (non affiché) : ").strip()
        if not client_id or not client_secret:
            raise ScriptError("Identifiant et secret du client Battle.net nécessaires.")
        token = get_user_token(client_id, client_secret, args.port)
        battletag = get_battletag(token)

        if args.probe:
            warn("")
            for label, pattern in NAMESPACES.items():
                namespace = pattern.format(region=args.region)
                status, data = get_account_profile(token, args.region, namespace, locale)
                count = sum(len(a.get("characters") or []) for a in (data or {}).get("wow_accounts") or [])
                result = ("{} personnage(s)".format(count) if status == 200
                          else "pas de réponse (code {})".format(status))
                warn("  {:<10} {:<24} {}".format(label, namespace, result))
            return 0

        namespace = NAMESPACES.get(args.namespace, args.namespace).format(region=args.region)
        status, profile = get_account_profile(token, args.region, namespace, locale)
        if status != 200 or not profile:
            hint = {401: "jeton refusé", 403: "accès refusé (droit wow.profile ?)",
                    404: "aucun personnage pour cette version du jeu ou cette région"}.get(status, "")
            raise ScriptError("API Blizzard : code {} {} (espace {}).".format(status, hint, namespace))
        if args.save_json:
            with open(args.save_json, "w", encoding="utf-8") as handle:
                json.dump({"battletag": battletag, "profile": profile}, handle,
                          ensure_ascii=False, indent=1)
            warn("Réponse brute enregistrée dans {}.".format(args.save_json))

    characters = collect_characters(profile)
    matches = match_accounts(profile, accounts)
    names = account_names(characters, matches, labels)
    warn("{} compte(s) WoW, {} personnage(s){}.".format(
        len(names), len(characters), " — BattleTag " + battletag if battletag else ""))

    if args.check:
        print_check(characters, matches, names, roster)
        return 0

    lines = []
    known = 0
    for number, _, char in sorted(characters, key=lambda c: (c[0], char_key(c[2]))):
        if char_key(char) in roster:
            known += 1
            if not args.all:
                continue
        lines.append(";".join(clean(v) for v in (
            char_key(char), char["class"], char["level"], names[number], battletag)))

    header = "# Polypode /poly import — {} — {} personnage(s)".format(
        time.strftime("%Y-%m-%d %H:%M"), len(lines))
    text = "\n".join([header] + lines) + "\n"
    if args.output == "-":
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
        warn("Lignes écrites dans {} : ouvrir le fichier, tout copier (Ctrl+A, Ctrl+C) et coller "
             "dans /poly import.".format(os.path.abspath(args.output)))
    warn("{} nouveau(x), {} déjà dans le roster{}.".format(
        len(characters) - known, known, " (sortis aussi : --all)" if args.all else " (ignorés)"))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ScriptError as err:
        warn("Erreur : {}".format(err))
        sys.exit(1)
    except KeyboardInterrupt:
        warn("Interrompu.")
        sys.exit(1)
