# Game Menu Kit Lite pour Godot 4 (édition gratuite)

Un menu principal et un menu d'options animés, prêts à l'emploi. 100 % GDScript typé, aucun
fichier image ou son : le fond est un shader, les sons sont générés par le code.

- **Style Néon** : fond synthwave, titre lumineux, boutons et panneaux animés.
- **Menu principal** : titre ou logo, Nouvelle partie, Options, Quitter avec confirmation et
  écran d'au revoir.
- **Options** : Vidéo (mode d'affichage, résolution, VSync, limite d'images, qualité, échelle de
  rendu, anticrénelage, luminosité, compteur FPS) et Audio (5 volumes, sons au survol, couper le
  son en arrière-plan), appliqués en direct et enregistrés tout seuls. Ajoutez vos réglages.
- Sons d'interface doux (3 packs), navigation souris, clavier et manette.
- Interface en anglais avec **traduction française intégrée**.

Compatibilité : Godot **4.2 et plus** (testé avec 4.2 et 4.3).

*English version: see `README.md`.*

## Game Menu Kit PRO

L'édition payante ajoute 3 styles (Grimoire, Pop, Verre), 4 onglets d'options (Jeu, Caméra,
Commandes avec réassignation des touches, Accessibilité), les emplacements de sauvegarde avec
capture d'écran, Continuer / Charger, un menu pause et un écran de chargement.

👉 https://exiforever.itch.io/game-menu-kit-pro

Le passage est immédiat : remplacez le dossier `addons/game_menu_kit/`. Les réglages de vos
joueurs sont conservés.

---

## Installation (2 minutes)

1. Copiez le dossier `addons/game_menu_kit/` dans le dossier `addons/` de votre projet.
2. Ouvrez **Projet > Paramètres du projet > Plugins** et activez **Game Menu Kit Lite**.
   L'autoload `MenuKit` est ajouté automatiquement.

**Essayez tout de suite** : ouvrez `addons/game_menu_kit/demo/demo.tscn` et lancez-la avec
**F6**. Le dossier `demo/` peut être supprimé sans risque.

## Menu principal

1. Créez votre scène titre et ajoutez-y `addons/game_menu_kit/main_menu.tscn`.
2. Dans l'Inspecteur : `kicker` (petite ligne au-dessus du titre), `title_lines` (une ou deux
   lignes) ou `logo`, `footer_text`, et `new_game_scene` (la scène lancée par **Nouvelle partie**).

`confirm_quit` demande confirmation avant de quitter. Signaux : `new_game_requested`,
`quit_requested` (s'il est connecté, le jeu ne quitte plus tout seul).

Depuis votre code :

```gdscript
MenuKit.change_scene("res://levels/level_2.tscn")
MenuKit.go_to_main_menu()
MenuKit.quit_game()  # écran d'au revoir, puis quitte
```

## Réglages

```gdscript
var vsync: bool = MenuKit.settings.get_value("video/vsync")
MenuKit.setting_changed.connect(func(key: String, value: Variant) -> void:
	print(key, " = ", value))
MenuKit.settings.hide("video/render_scale")
MenuKit.settings.add_toggle("video/film_grain", "Film grain", true)
MenuKit.settings.add_range("audio/ambience", "Ambience", 80.0, 0.0, 100.0, 1.0, "%")
```

Les valeurs sont enregistrées dans `user://menu_kit_settings.cfg`. Les bus audio `Music`, `SFX`,
`Voice` et `UI` sont créés s'ils n'existent pas dans votre projet.

Pour changer les couleurs ou les polices : **Système de fichiers > clic droit > Nouvelle
ressource > MenuKitStyleNeon**, modifiez-la dans l'Inspecteur, puis mettez le chemin du `.tres`
dans **Paramètres du projet > Menu Kit > Style**.

## Paramètres du projet (Projet > Paramètres du projet > Menu Kit)

| Paramètre | Défaut | Effet |
| --- | --- | --- |
| Style | `neon` | `neon` ou le chemin de votre `.tres`. |
| Sounds > Pack | `soft` | `soft`, `felt`, `minimal` (sans son au survol) ou `off`. |
| Localization > Builtin French | activé | Textes en français pour les joueurs francophones. |
| Scenes > Main Menu | vide | Scène ouverte par `MenuKit.go_to_main_menu()` (trouvée automatiquement). |

## Licence

MIT, voir `LICENSE.txt`. Polices : SIL Open Font License (voir `fonts/OFL-*.txt`).
