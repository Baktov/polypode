"""Publie une version d'un module Polypode sur GitHub, avec un ZIP prêt à décompresser.

Le ZIP « Source code » que GitHub joint à chaque version contient un dossier nommé d'après le dépôt
et la version (« polypode-histoire-1.11.0 ») : il fallait le renommer pour que le jeu le charge.
Ce programme joint à la version un ZIP <Module>-<version>.zip qui contient directement le ou les
dossiers d'addon à leur nom exact (« Polypode_Histoire », et « Polypode_Histoire_Archive » sorti au
premier niveau : le jeu ne charge pas un addon rangé dans un autre), sans les fichiers de
développement.

    python tools/publier_version.py ..\\Polypode_Histoire            # publie
    python tools/publier_version.py ..\\Polypode_Histoire --essai    # ZIP seulement, sans publier

Contrôles : arbre de travail propre (fichiers suivis), HEAD poussé et à jour avec le dépôt distant,
étiquette v<version> du .toc encore libre. Le ZIP est fait depuis HEAD (git), pas depuis les
fichiers du disque. Notes de version : lignes de la section « Version » du README plus récentes
que la dernière version publiée. Nécessite git et gh (connecté).
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
import zipfile

# Fichiers de développement jamais livrés (nom de fichier, ou dossier de premier niveau avec /).
EXCLUDE_NAMES = {'CLAUDE.md', 'MODULES.md', '.gitignore', '.gitattributes', 'publier_version.py', 'check_locale.py'}
EXCLUDE_DIRS = {'Modele/', '.vscode/', '.kilo/'}
# Dossiers propres à un module : outils de développement (Polypode garde tools/ : import_bnet.py
# est présenté aux joueurs dans son README).
EXTRA_EXCLUDE_DIRS = {'Polypode_Photo': {'tools/'}}


def git(repo, *args, binary=False):
    out = subprocess.run(['git', '-C', repo, *args], check=True, capture_output=True)
    return out.stdout if binary else out.stdout.decode('utf-8').strip()


def version_tuple(text):
    return tuple(int(x) for x in text.split('.'))


def toc_fields(repo, name):
    text = git(repo, 'show', f'HEAD:{name}.toc')
    fields = {}
    for line in text.splitlines():
        m = re.match(r'##\s*([\w-]+)\s*:\s*(.*)', line)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    return fields


def last_release(repo):
    tags = [t for t in git(repo, 'tag', '--list', 'v*').split() if re.fullmatch(r'v\d+(\.\d+)*', t)]
    return max(tags, key=lambda t: version_tuple(t[1:]), default=None)


def changes(repo, since):
    """Lignes « `x.y.z` : ... » de la section Version du README, plus récentes que since."""
    readme = git(repo, 'show', 'HEAD:README.md')
    section = readme.split('\n## Version', 1)[1] if '\n## Version' in readme else ''
    lines = []
    for line in section.splitlines():
        if line.startswith('## '):
            break
        m = re.match(r'`(\d+(?:\.\d+)*)`\s*:', line)
        if m and (since is None or version_tuple(m.group(1)) > version_tuple(since)):
            lines.append(f'- {line}')
    return lines


def build_zip(repo, name, dest):
    """ZIP depuis HEAD : <name>/... et addons imbriqués (<sous-dossier>/<sous-dossier>.toc) au premier niveau."""
    files = git(repo, 'ls-files', '-z').split('\0')
    files = [f for f in files if f]
    nested = {f.split('/')[0] for f in files if re.fullmatch(r'([^/]+)/\1\.toc', f)}
    excluded_dirs = EXCLUDE_DIRS | EXTRA_EXCLUDE_DIRS.get(name, set())
    kept = []
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(files):
            if os.path.basename(f) in EXCLUDE_NAMES or any(f.startswith(d) for d in excluded_dirs):
                continue
            top = f.split('/')[0]
            target = f if top in nested else f'{name}/{f}'
            z.writestr(target, git(repo, 'show', f'HEAD:{f}', binary=True))
            kept.append(target)
    return kept, sorted(nested)


def main():
    parser = argparse.ArgumentParser(description='Publie une version d\'un module Polypode (release GitHub + ZIP).')
    parser.add_argument('module', help='dossier du module (ex. ..\\Polypode_Histoire)')
    parser.add_argument('--essai', action='store_true', help='construire le ZIP sans publier')
    parser.add_argument('--dossier', default=tempfile.gettempdir(), help='où écrire le ZIP')
    args = parser.parse_args()

    repo = os.path.abspath(args.module)
    name = os.path.basename(repo.rstrip('\\/'))
    toc = toc_fields(repo, name)
    version = toc['Version']
    title = toc.get('Title', name)
    tag = f'v{version}'

    if git(repo, 'status', '--porcelain', '--untracked-files=no'):
        sys.exit(f'{name} : modifications non commitées : committer d\'abord.')
    if not args.essai:
        git(repo, 'fetch', '--quiet', '--tags')
        if git(repo, 'rev-list', '--count', '@{u}..HEAD') != '0' or git(repo, 'rev-list', '--count', 'HEAD..@{u}') != '0':
            sys.exit(f'{name} : HEAD pas à jour avec le dépôt distant : pousser (ou tirer) d\'abord.')
    if tag in git(repo, 'tag', '--list', tag).split():
        sys.exit(f'{name} : la version {tag} est déjà publiée : changer ## Version du .toc d\'abord.')

    zip_name = f'{name}-{version}.zip'
    dest = os.path.join(args.dossier, zip_name)
    kept, nested = build_zip(repo, name, dest)
    folders = [name, *nested]
    print(f'{zip_name} : {len(kept)} fichiers, dossiers {", ".join(folders)}')

    previous = last_release(repo)
    deps = toc.get('Dependencies', '')
    lines = [
        f'**{title} {version}**',
        '',
        f'**Installation** : télécharger **{zip_name}** ci-dessous (pas « Source code »), puis le décompresser '
        'dans `World of Warcraft\\_retail_\\Interface\\AddOns\\` (WoW Forever : `_forever_` au lieu de `_retail_`). '
        f'Il contient directement {"le dossier" if len(folders) == 1 else "les dossiers"} '
        f'{", ".join(f"`{f}`" for f in folders)}, à garder tel{"" if len(folders) == 1 else "s"} quel{"" if len(folders) == 1 else "s"}.',
    ]
    if deps:
        lines += ['', f'Nécessite : {", ".join(f"**{d.strip()}**" for d in deps.split(","))} (même procédure).']
    news = changes(repo, previous[1:] if previous else None)
    if news:
        lines += ['', f'**Nouveautés depuis {previous}** :' if previous else '**Versions** :', *news]
    notes = '\n'.join(lines) + '\n'

    if args.essai:
        print(f'ZIP : {dest}\n--- notes ---\n{notes}')
        return
    head = git(repo, 'rev-parse', 'HEAD')
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.md', delete=False) as f:
        f.write(notes)
        notes_file = f.name
    try:
        remote = git(repo, 'remote', 'get-url', 'origin')
        slug = re.sub(r'(\.git)?$', '', remote.split('github.com/')[1])
        subprocess.run(['gh', 'release', 'create', tag, dest, '-R', slug, '--target', head,
                        '--title', f'{title} {version}', '--notes-file', notes_file], check=True)
    finally:
        os.unlink(notes_file)
    git(repo, 'fetch', '--quiet', '--tags')
    print(f'Publié : {title} {version} ({tag})')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
