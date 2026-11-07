"""Fabrique le paquet CurseForge de Polypode : un seul ZIP avec tous les modules.

Sur CurseForge, Polypode a une seule page (un seul projet) : le fichier envoyé contient tous les
dossiers d'addon côte à côte (Polypode, Polypode_Data, Polypode_Histoire, Polypode_Histoire_Archive,
Polypode_Map...). Chaque module garde son dépôt git et ses versions : le paquet prend, pour chacun,
la **dernière version publiée sur GitHub** (étiquette v<version>), jamais les fichiers du disque ni
un travail non publié. Publier donc d'abord les modules modifiés avec publier_version.py.

    python tools/publier_paquet.py              # ZIP + notes de version, dans le dossier temporaire
    python tools/publier_paquet.py --noter      # une fois le ZIP envoyé sur CurseForge : noter le paquet

Version du paquet : la date du jour (2026.11.07 ; 2026.11.07.2 pour un deuxième paquet le même
jour), à saisir dans le champ « Display name » du fichier sur CurseForge. Le dernier paquet envoyé
est noté dans Publication/Curse/paquet.json (version et version de chaque module) : les notes de
version du paquet suivant reprennent les nouveautés de chaque module depuis ce paquet.
"""
import argparse
import datetime
import json
import os
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from publier_version import add_module, changes, git, last_release, toc_fields, version_tuple  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # ADDONS_POLYPODE
MODULES = ['Polypode', 'Polypode_Data', 'Polypode_Histoire', 'Polypode_Map', 'Polypode_Photo',
           'Polypode_Profil', 'Polypode_Suivi', 'Polypode_Teleport']
MANIFEST = os.path.join(ROOT, 'Publication', 'Curse', 'paquet.json')


def read_manifest():
    try:
        with open(MANIFEST, encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def pack_version(previous):
    """Date du jour, suffixée .2, .3... si un paquet a déjà été noté aujourd'hui."""
    today = datetime.date.today().strftime('%Y.%m.%d')
    if not previous or not previous['version'].startswith(today):
        return today
    rest = previous['version'][len(today):]
    return f'{today}.{int(rest[1:]) + 1 if rest else 2}'


def main():
    parser = argparse.ArgumentParser(description='Fabrique le ZIP CurseForge de Polypode (tous les modules).')
    parser.add_argument('--dossier', default=tempfile.gettempdir(), help='où écrire le ZIP et les notes')
    parser.add_argument('--noter', action='store_true',
                        help='noter ce paquet comme envoyé sur CurseForge (Publication/Curse/paquet.json)')
    args = parser.parse_args()

    previous = read_manifest()
    old_versions = previous['modules'] if previous else {}
    version = pack_version(previous)

    modules = {}  # nom -> (dépôt, étiquette)
    for name in MODULES:
        repo = os.path.join(ROOT, name)
        git(repo, 'fetch', '--quiet', '--tags')
        tag = last_release(repo)
        if not tag:
            sys.exit(f'{name} : aucune version publiée sur GitHub : lancer publier_version.py d\'abord.')
        local = toc_fields(repo, name)['Version']
        if version_tuple(local) > version_tuple(tag[1:]):
            print(f'Attention : {name} {local} n\'est pas publié sur GitHub : le paquet prend {tag}.')
        modules[name] = (repo, tag)

    current = {name: tag[1:] for name, (_, tag) in modules.items()}
    if current == old_versions:
        print(f'Attention : aucun module n\'a changé depuis le paquet {previous["version"]}.')

    zip_name = f'Polypode-{version}.zip'
    dest = os.path.join(args.dossier, zip_name)
    folders = []
    count = 0
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
        for name, (repo, tag) in modules.items():
            kept, nested = add_module(z, repo, name, tag)
            folders += [name, *nested]
            count += len(kept)
    print(f'{zip_name} : {count} fichiers, dossiers {", ".join(folders)}')

    # Notes de version (champ « Changelog » du fichier sur CurseForge, éditeur Markdown).
    lines = [f'**Polypode {version}**', '', '| Module | Version |', '| --- | --- |']
    for name, (repo, tag) in modules.items():
        title = toc_fields(repo, name, tag).get('Title', name)
        mark = ' (nouveau / new)' if previous and old_versions.get(name) != tag[1:] else ''
        lines.append(f'| {title} | {tag[1:]}{mark} |')
    for name, (repo, tag) in modules.items():
        since = old_versions.get(name)
        if not previous or since == tag[1:]:  # premier paquet : le tableau suffit
            continue
        news = changes(repo, since, tag)
        if news:
            title = toc_fields(repo, name, tag).get('Title', name)
            lines += ['', f'**{title}** ({f"depuis {since}" if since else "nouveau module"}) :', *news]
    lines += ['', '*English: full version history in French in each module\'s README on GitHub.*']
    notes = '\n'.join(lines) + '\n'
    notes_path = os.path.join(args.dossier, f'Polypode-{version}.notes.md')
    with open(notes_path, 'w', encoding='utf-8') as f:
        f.write(notes)
    print(f'ZIP : {dest}\nNotes : {notes_path}')

    if args.noter:
        with open(MANIFEST, 'w', encoding='utf-8', newline='\n') as f:
            json.dump({'version': version, 'date': datetime.date.today().isoformat(), 'modules': current},
                      f, ensure_ascii=False, indent=2)
            f.write('\n')
        print(f'Noté : paquet {version} dans {MANIFEST} (à committer dans C:\\PROJETS).')
    else:
        print('Une fois le ZIP envoyé sur CurseForge, relancer avec --noter.')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
