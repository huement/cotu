# Settings Menu Lite pour Godot 4 (version gratuite)

Menu de paramètres prêt à l'emploi, 100 % GDScript typé, sans aucun asset externe.

- **Audio** : volume par bus (Master, Musique, SFX), appliqué en direct.
- **Graphismes** : résolution, plein écran / fenêtré, VSync.
- **Sauvegarde automatique** : les paramètres sont rechargés et appliqués à chaque lancement du jeu depuis `user://settings.cfg`.
- Interface responsive (Control nodes natifs, `SIZE_EXPAND_FILL`), navigable à la souris, au clavier et à la manette.
- Interface en anglais avec **traduction française intégrée** (utilisée automatiquement pour les joueurs francophones).

Compatibilité : Godot **4.2 et versions suivantes**.

## Settings Menu PRO

La version payante **Settings Menu PRO** ajoute l'onglet **Contrôles** :

- réassignation des touches clavier, souris et manette (2 emplacements clavier/souris + 1 manette par action) ;
- détection des conflits avec choix « Échanger » ou « Remplacer » ;
- sauvegarde des touches personnalisées, API pour ajouter des actions depuis le code.

👉 https://exiforever.itch.io/settings-menu-pro

La mise à niveau est immédiate : remplacez le dossier `addons/settings_menu/` par celui de
Settings Menu PRO. Les réglages déjà sauvegardés par vos joueurs sont conservés.

---

## Installation (2 minutes)

1. Copiez le dossier `addons/settings_menu/` dans le dossier `addons/` de votre projet.
2. Ouvrez **Projet > Paramètres du projet > Plugins** et activez **Settings Menu Lite**.
   Le singleton `SettingsManager` est ajouté automatiquement aux autoloads.
3. (Recommandé) Dans le panneau **Audio** en bas de l'éditeur, créez les bus `Music` et `SFX`
   et assignez-les à vos `AudioStreamPlayer`. S'ils n'existent pas, l'addon les crée au lancement.

**Essayer tout de suite** : ouvrez `addons/settings_menu/demo/Demo.tscn` et lancez-la avec **F6**.

## Ouvrir le menu

```gdscript
const SETTINGS_MENU: PackedScene = preload("res://addons/settings_menu/SettingsMenu.tscn")

func _on_settings_button_pressed() -> void:
	var menu: Control = SETTINGS_MENU.instantiate()
	menu.free_on_close = true
	add_child(menu)
	menu.closed.connect(_on_settings_closed)
```

Vous pouvez aussi glisser `SettingsMenu.tscn` dans votre scène, le cacher, puis appeler `open()`.

### Options de la scène (Inspecteur)

| Option | Défaut | Effet |
| --- | --- | --- |
| `pause_game_while_open` | `false` | Met le jeu en pause tant que le menu est ouvert. |
| `free_on_close` | `false` | Libère le menu à la fermeture (sinon il est caché). |
| `revert_unsaved_on_close` | `true` | « Close » (« Fermer ») annule les modifications non sauvegardées. |
| `close_on_cancel` | `true` | Échap / bouton B ferme le menu. |

## Apparence

Le menu est entièrement stylé par un thème généré par code (aucune image ni police externe).
Dans l'Inspecteur de `SettingsMenu`, groupe **Appearance** :

| Option | Rôle |
| --- | --- |
| `color_preset` | Palette prête à l'emploi : Night (Nuit), Light (Clair), Ocean (Océan), **Candy** (Bonbon, par défaut), Dusk (Crépuscule), ou « Custom » pour utiliser les couleurs ci-dessous |
| `accent_color` | Couleur principale (onglet actif, bouton Save, curseurs, interrupteurs) |
| `panel_color` / `surface_color` | Fond de la fenêtre / fond des cartes |
| `text_color` / `muted_text_color` | Texte principal / texte secondaire |
| `on_accent_color` | Texte posé sur la couleur principale |
| `corner_radius` | Arrondi des angles |
| `max_panel_size` | Taille maximale du panneau (en dessous, il occupe 92 % de l'écran) |
| `animate` | Animations d'ouverture et de fermeture |
| `custom_theme` | Votre propre `Theme` : remplace entièrement le thème généré |

Par code : modifiez `color_preset` ou les couleurs, puis appelez `menu.apply_theme()`.

## Comportement des boutons

- Les réglages s'appliquent **immédiatement** pour que le joueur voie le résultat.
- **Sauvegarder** écrit tout dans `user://settings.cfg`.
- **Par défaut** restaure les valeurs du projet (à sauvegarder ensuite pour les conserver).
- **Fermer** ferme le menu ; les changements non sauvegardés sont annulés (réglable).

## Configuration

`Projet > Paramètres du projet > Settings Menu > audio/buses` : bus affichés dans l'onglet Audio
(par défaut `Master, Music, SFX`). Les valeurs par défaut sont celles de votre projet.
`settings_menu/localization/builtin_french` (activé par défaut) : traduction française intégrée ;
désactivez-la pour un jeu uniquement en anglais. Forcer une langue : `TranslationServer.set_locale("fr")`.

## API du singleton `SettingsManager`

```gdscript
SettingsManager.set_volume("Music", 0.5)       # 0.0 à 1.0
SettingsManager.set_resolution(Vector2i(1920, 1080))
SettingsManager.set_fullscreen(true)
SettingsManager.set_vsync(false)
SettingsManager.save_settings()
SettingsManager.reset_to_defaults()
```

Signaux : `settings_loaded`, `settings_saved`, `settings_reset`, `setting_changed(section, key, value)`.

## Licence

MIT (voir `LICENSE.txt`) : utilisable librement, y compris dans des jeux commerciaux.
