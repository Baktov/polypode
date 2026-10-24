# Polypode Template

*Version française : [README.md](README.md)*

(Two-sentence overview: what the module shows or does, and for whom.) Separate companion addon of
[Polypode](https://github.com/Baktov/polypode): enabled or not in the WoW AddOns list, per
character.

Requires **Polypode 0.54.0** or later.

> **Languages**: French, English, German, Spanish, Italian and Brazilian Portuguese, following the
> language chosen in Polypode (option "Langue / Language"). The translations were made with the help
> of Claude, Anthropic's AI: feedback from native speakers is very welcome
> ([GitHub issue](https://github.com/Baktov/polypode-modele/issues)).

---

## Installation

1. Install **Polypode** first (required dependency).
2. Put the `Polypode_Modele` folder in `World of Warcraft/_retail_/Interface/AddOns/`
   (and, for **WoW Forever**, in `World of Warcraft/_forever_/Interface/AddOns/`).
3. Enable "Polypode Template" in the AddOns list **on each character** whose information you want
   to see: each one sends its own.

---

## Usage

The **Template** button (title bar of the Polypode window) or `/poly modele` (alias
`/poly template`) opens a window listing the roster characters (current character first) with their
**current zone**; the tooltip gives the date of another character's information. Escape closes the
window.

---

## How it works

- The current character is read live. The others send their zone through Polypode (`MODELE`
  message) whenever one of your clients logs in and on every zone change. A character without the
  module, or not seen yet, shows "no info".
- The information is **saved** (account file) with its date.
- A character deleted in Polypode (Shift + click): its information is forgotten.

---

## Options

In **Options > AddOns > Polypode > Template** (setting specific to each character):

| Option | Default | Effect |
|---|---|---|
| Show the realm | No | Shows the realm next to the name of each character |

---

## Versions

The full version history is in the [French README](README.md#version).
