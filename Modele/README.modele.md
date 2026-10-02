# Polypode Modele

(Présentation en deux phrases : ce que le module affiche ou fait, pour qui.) Addon compagnon de
[Polypode](https://github.com/Baktov/polypode), séparé : chargé ou non depuis la liste des AddOns
de WoW, par personnage.

Nécessite **Polypode 0.54.0** ou plus récent.

---

## Installation

1. Installer d'abord **Polypode** (dépendance obligatoire).
2. Placer le dossier `Polypode_Modele` dans `World of Warcraft/_retail_/Interface/AddOns/`
   (et, pour **WoW Forever**, dans `World of Warcraft/_classic_beta_/Interface/AddOns/`, par
   exemple par une jonction `mklink /J`).
3. Cocher « Polypode Modele » dans la liste des AddOns, **sur chaque personnage** dont vous
   voulez voir les informations : chacun envoie les siennes.

---

## Utilisation

Le bouton **Modele** (barre de titre de la fenêtre Polypode) ou `/poly modele` ouvre une fenêtre
qui liste les personnages du roster (personnage joué en tête) avec leur **zone actuelle** ;
l'infobulle donne la date de l'information d'un autre personnage. Échap ferme la fenêtre.

---

## Fonctionnement

- Le personnage joué est lu en direct. Les autres envoient leur zone par Polypode (message
  `MODELE`) à chaque connexion d'un de vos clients et à chaque changement de zone. Un personnage
  sans le module, ou pas encore vu, apparaît « pas d'infos ».
- Les informations sont **sauvegardées** (fichier de compte) avec leur date.
- Un personnage supprimé dans Polypode (Maj + clic) : ses informations sont oubliées.

---

## Options

Dans **Options → AddOns → Polypode → Modele** (réglage propre à chaque personnage) :

| Option | Défaut | Effet |
|---|---|---|
| Afficher le royaume | Non | Affiche le royaume à côté du nom de chaque personnage |

---

## Version

`1.0.0` : première version (zone actuelle de chaque personnage du roster).
