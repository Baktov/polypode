# Importer ses personnages dans Polypode (`import_bnet.py`)

Polypode ne connaît un personnage qu'après sa première connexion avec l'addon. Pour composer des
équipes à l'avance, ce petit programme récupère **la liste de tous vos personnages** auprès de
Blizzard, et vous la collez ensuite dans Polypode avec la commande `/poly import` (ou le bouton
« Importer des personnages » des options de Polypode).

## Ce que fait le programme

1. Il ouvre votre navigateur sur la page de connexion **officielle** de Battle.net ; vous vous
   connectez et autorisez l'accès à vos personnages World of Warcraft.
2. Il demande à l'API de Blizzard la liste des personnages de **tous les comptes WoW** rattachés à
   ce compte Battle.net (nom, royaume, classe, niveau), ainsi que votre BattleTag.
3. Il retrouve à quel dossier `WTF\Account\<compte>` de votre installation correspond chaque compte
   WoW, et lit le roster de Polypode pour **ne garder que les personnages qu'il ne connaît pas
   encore**.
4. Il écrit le résultat dans `polypode_import.txt`, une ligne par personnage :

   ```text
   # Polypode /poly import — 2026-10-11 21:08 — 2 personnage(s)
   Mordsith-Elune;PALADIN;90;baktov;Exemple#1234
   Alacrité-Elune;MAGE;80;wow1;Exemple#1234
   ```

   (nom-royaume ; classe ; niveau ; compte WoW ; BattleTag). Les lignes qui commencent par `#`
   sont des commentaires.

**Ce qu'il ne fait pas** : il ne modifie aucun fichier de World of Warcraft, n'enregistre ni votre
mot de passe (il n'y a pas accès : la connexion se fait sur le site de Blizzard) ni le jeton
d'accès, qui reste en mémoire le temps du programme. Il n'envoie rien ailleurs qu'à Blizzard.

**Nom des comptes WoW** : l'API ne donne pas le nom des comptes WoW, seulement un numéro. Le
programme reprend le nom que vous avez déjà donné au compte dans Polypode (réglage « Compte WoW de
ce personnage »), sinon le nom du dossier `WTF\Account\...`, sinon « Compte 1 », « Compte 2 »...
Deux comptes WoW n'ont jamais le même nom : si des personnages de deux comptes WoW différents
sont rangés sous le même nom dans Polypode, ce nom reste au compte qui en a le plus, l'autre prend le
nom de son dossier, et le programme signale les personnages à ranger à nouveau dans Polypode.

## Prérequis

- **Python 3.8 ou plus récent** : <https://www.python.org/downloads/> (sous Windows, cocher « Add
  python.exe to PATH » à l'installation). Aucune autre bibliothèque n'est nécessaire.
- **Un compte Battle.net avec l'authentificateur activé**, exigé par Blizzard pour créer un client
  développeur.
- **Polypode 2.3.0 ou plus récent** installé (le programme est livré dans son dossier `tools`).

## Étape 1 : créer un client Battle.net (une seule fois)

1. Aller sur <https://develop.battle.net/access/clients> et se connecter.
2. **Create Client** :
   - *Client Name* : au choix (ex. « Polypode import ») ;
   - *Redirect URLs* : `http://localhost:8765/callback` (exactement) ;
   - *Service URL* : peut rester vide ou recevoir `http://localhost` ;
   - *Intended Use* : « Import de mes personnages dans un addon WoW » ;
   - valider.
3. Noter le **Client ID** et le **Client Secret** affichés. Le secret est personnel : ne pas le
   partager.

## Étape 2 : lancer le programme

Ouvrir un terminal (PowerShell sous Windows) dans le dossier du programme :

```powershell
cd "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Polypode\tools"
```

(adapter le chemin à votre installation). Puis, **d'abord une vérification** :

```powershell
python import_bnet.py --check
```

Le programme demande le Client ID et le Client Secret (le secret ne s'affiche pas à la saisie),
ouvre le navigateur pour la connexion, puis affiche chaque compte WoW avec le dossier trouvé et la
liste des personnages. Vérifier que les comptes et les personnages sont les bons, puis :

```powershell
python import_bnet.py
```

Pour ne pas retaper le Client ID et le secret à chaque fois, les mettre dans des variables
d'environnement de la session :

```powershell
$env:BNET_CLIENT_ID = "votre client id"
$env:BNET_CLIENT_SECRET = "votre client secret"
```

Le dossier du jeu est trouvé seul quand le programme est dans `Interface\AddOns\Polypode\tools`,
sinon par l'emplacement de Retail que Battle.net inscrit dans Windows. Pour une autre version
(Classic) ou une installation déplacée, l'indiquer avec `--wow-dir` (le dossier qui contient
`WTF`, par exemple `--wow-dir "D:\Jeux\World of Warcraft\_classic_era_"`).

## Étape 3 : importer dans le jeu

1. Ouvrir `polypode_import.txt` (créé dans le dossier courant), tout sélectionner (Ctrl+A) et
   copier (Ctrl+C).
2. Dans le jeu : `/poly import`, ou Options → AddOns → Polypode → « Importer des personnages ».
3. Coller (Ctrl+V) dans la fenêtre et valider. Polypode indique les personnages ajoutés, ceux
   déjà connus et les lignes refusées. Les personnages ajoutés sont partagés avec vos autres
   fenêtres Polypode et rangés dans leur compte.

Un personnage importé apparaît dans « Personnages disponibles » sans être connecté ; sa première
connexion complète le reste (nom de famille sur WoW Forever, compte Battle.net exact...).

## Relancer le programme

Le programme peut être relancé autant de fois que nécessaire (après la création de nouveaux
personnages, par exemple) : il ne sort que les personnages **absents** du roster de Polypode. Les
personnages que vous avez retirés de Polypode ne sont pas proposés à nouveau.

Polypode n'écrit son roster sur le disque qu'à la déconnexion ou au `/reload` : un import tout
récent peut donc ressortir. Ce n'est pas grave, `/poly import` ignore les personnages qu'il connaît
déjà ; coller deux fois la même liste ne crée aucun doublon.

## Options

| Option | Rôle |
| --- | --- |
| `--check` | affiche les comptes, leur dossier et les personnages, sans écrire de fichier |
| `--region eu` | région du compte : `eu` (défaut), `us`, `kr`, `tw` (la Chine n'est pas prise en charge) |
| `--namespace retail` | version du jeu : `retail` (défaut), `classic` (Classic actuel : Cataclysm, Mists...), `classic1x` (Classic Era), ou un espace complet de l'API |
| `--probe` | essaie chaque version du jeu et indique combien de personnages chacune renvoie |
| `--all` | sort aussi les personnages déjà dans le roster |
| `--wow-dir DOSSIER` | dossier du jeu (celui qui contient `WTF`) : `_retail_`, `_classic_`, `_classic_era_`... |
| `--locale fr_FR` | langue des noms de royaume ; défaut : celle du jeu (`WTF\Config.wtf`) |
| `--output FICHIER` | fichier produit (défaut `polypode_import.txt`) ; `-` pour l'afficher à l'écran |
| `--port 8765` | port local de la redirection ; s'il change, changer aussi la *Redirect URL* du client |
| `--save-json FICHIER` | enregistre la réponse brute de Blizzard (pour signaler un problème) |
| `--from-json FICHIER` | relit une réponse enregistrée, sans se connecter |

## Versions du jeu couvertes

- **Retail** : oui (défaut).
- **WoW Classic** : oui, avec `--namespace classic` ou `--namespace classic1x` et `--wow-dir`
  pointant sur le dossier `_classic_` ou `_classic_era_`. La répartition des serveurs récents
  (Anniversary, Hardcore...) n'est pas documentée par Blizzard : `--probe` indique quelle version
  répond.
- **WoW Forever** : pas encore, Blizzard n'a publié aucun espace d'API pour Forever.

## Problèmes courants

| Message ou symptôme | Cause et solution |
| --- | --- |
| Battle.net affiche « invalid redirect_uri » | la *Redirect URL* du client n'est pas exactement `http://localhost:8765/callback` (ou le port a changé) |
| « Échange du code refusé » | Client ID ou secret erroné : les recopier depuis develop.battle.net |
| « Le port 8765 est occupé » | lancer avec `--port 8766` et ajouter `http://localhost:8766/callback` au client |
| « code 404 » | aucun personnage dans cette région ou cette version du jeu : vérifier `--region` et `--namespace` (ou `--probe`) |
| « code 403 » | autorisation refusée : relancer et accepter l'accès aux personnages World of Warcraft |
| des personnages manquent | Blizzard peut omettre des personnages inactifs depuis longtemps : les connecter une fois, puis relancer le programme (ou les laisser s'ajouter seuls à leur connexion avec Polypode) |
| un compte est nommé « Compte 2 » | aucun dossier `WTF\Account\...` ne lui correspond (`--wow-dir` ?) : le renommer ensuite dans Polypode |
| les accents s'affichent mal dans le terminal | affichage seulement : le fichier produit est correct (UTF-8) |
