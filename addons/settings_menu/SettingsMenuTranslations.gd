extends RefCounted
## Built-in French translation of the addon's texts.
##
## The addon is written in English. At startup, [code]SettingsManager[/code] registers
## this catalog with [TranslationServer], so players whose locale is French
## ([code]fr[/code], [code]fr_FR[/code], [code]fr_CA[/code]...) see the menu in French
## automatically. No .po/.csv import is needed.
##
## To disable it (English-only game), turn off the project setting
## [code]settings_menu/localization/builtin_french[/code].
## To add another language, create your own [Translation] (or CSV/PO file) using the
## English texts below as message IDs.

const LOCALE: String = "fr"

## English text -> French text.
const FR: Dictionary = {
	# --- Menu -----------------------------------------------------------------
	"Settings": "Paramètres",
	"Tune sound, display and controls to your liking.": "Réglez le son, l'affichage et les commandes à votre goût.",
	"Tune sound and display to your liking.": "Réglez le son et l'affichage à votre goût.",
	"Graphics": "Graphismes",
	"Controls": "Contrôles",
	"Resolution": "Résolution",
	"Window size in windowed mode.": "Taille de la fenêtre en mode fenêtré.",
	"Fullscreen": "Plein écran",
	"Switch between fullscreen and windowed.": "Basculer entre plein écran et fenêtré.",
	"Vertical Sync": "Synchronisation verticale",
	"VSync: removes screen tearing.": "VSync : supprime les déchirures d'image.",
	"Turn off fullscreen to choose the resolution.": "Désactivez le plein écran pour choisir la résolution.",
	"Defaults": "Par défaut",
	"Close": "Fermer",
	"Save": "Sauvegarder",
	"Settings saved.": "Paramètres sauvegardés.",
	"Error: could not save the settings.": "Erreur : impossible de sauvegarder les paramètres.",
	"Defaults restored. Click \"Save\" to keep them.": "Valeurs par défaut restaurées. Cliquez sur « Sauvegarder » pour les conserver.",
	"Unsaved changes.": "Modifications non sauvegardées.",
	# --- Controls tab -----------------------------------------------------------
	"Keyboard / Mouse": "Clavier / Souris",
	"Keyboard / Mouse %d": "Clavier / Souris %d",
	"Gamepad": "Manette",
	"Gamepad %d": "Manette %d",
	"No actions to configure. Add actions in Project > Project Settings > Input Map.":
		"Aucune action à configurer. Ajoutez des actions dans Projet > Paramètres du projet > Contrôles.",
	"Click a slot, then press the key you want. Esc: cancel. Right-click: clear.":
		"Cliquez sur une case puis appuyez sur la touche voulue. Échap : annuler. Clic droit : effacer.",
	"Click: rebind\nRight-click: clear": "Clic : réassigner\nClic droit : effacer",
	"Press a key…": "Appuyez sur une touche…",
	"Press a button…": "Appuyez sur un bouton…",
	"Waiting for input for \"%s\" (Esc to cancel).": "En attente d'une entrée pour « %s » (Échap pour annuler).",
	"Key Already in Use": "Touche déjà utilisée",
	"\"%s\" is already bound to \"%s\".\n\nSwap: \"%s\" gets the old key.\nReplace: \"%s\" loses this key.":
		"« %s » est déjà assigné à « %s ».\n\nÉchanger : « %s » récupère l'ancienne touche.\nRemplacer : « %s » perd cette touche.",
	"Swap": "Échanger",
	"Replace": "Remplacer",
	"Cancel": "Annuler",
	# --- Audio buses -------------------------------------------------------------
	"Master Volume": "Volume général",
	"Music": "Musique",
	"Sound Effects": "Effets sonores",
	# --- Keys ------------------------------------------------------------------------
	"Space": "Espace",
	"Enter": "Entrée",
	"Numpad Enter": "Entrée (pavé num.)",
	"Esc": "Échap",
	"Backspace": "Retour arrière",
	"Delete": "Suppr",
	"Insert": "Inser",
	"Shift": "Maj",
	"Caps Lock": "Verr. Maj",
	"Page Up": "Page préc.",
	"Page Down": "Page suiv.",
	"Home": "Début",
	"End": "Fin",
	# --- Mouse -----------------------------------------------------------------------
	"Left Click": "Clic gauche",
	"Right Click": "Clic droit",
	"Middle Click": "Clic milieu",
	"Wheel Up": "Molette haut",
	"Wheel Down": "Molette bas",
	"Wheel Left": "Molette gauche",
	"Wheel Right": "Molette droite",
	"Mouse 4": "Souris 4",
	"Mouse 5": "Souris 5",
	"Mouse %d": "Souris %d",
	# --- Gamepad ---------------------------------------------------------------------
	"A / Cross": "A / Croix",
	"B / Circle": "B / Rond",
	"X / Square": "X / Carré",
	"Select / Back": "Select / Retour",
	"Guide / Home": "Guide / Accueil",
	"D-Pad ↑": "Croix dir. ↑",
	"D-Pad ↓": "Croix dir. ↓",
	"D-Pad ←": "Croix dir. ←",
	"D-Pad →": "Croix dir. →",
	"Share / Capture": "Partage / Capture",
	"Paddle 1": "Palette 1",
	"Paddle 2": "Palette 2",
	"Paddle 3": "Palette 3",
	"Paddle 4": "Palette 4",
	"Touchpad": "Pavé tactile",
	"Button %d": "Bouton %d",
	"L Stick ←": "Stick G ←",
	"L Stick →": "Stick G →",
	"L Stick ↑": "Stick G ↑",
	"L Stick ↓": "Stick G ↓",
	"R Stick ←": "Stick D ←",
	"R Stick →": "Stick D →",
	"R Stick ↑": "Stick D ↑",
	"R Stick ↓": "Stick D ↓",
	"Axis %d %s": "Axe %d %s",
	# --- Colour presets ----------------------------------------------------------------
	"Night": "Nuit",
	"Light": "Clair",
	"Ocean": "Océan",
	"Candy": "Bonbon",
	"Dusk": "Crépuscule",
	"Custom": "Personnalisée",
	# --- Demo scene ----------------------------------------------------------------------
	"Settings Menu · Demo": "Settings Menu · Démo",
	"⚙  Settings": "⚙  Paramètres",
	"Move Left": "Aller à gauche",
	"Move Right": "Aller à droite",
	"Move Up": "Monter",
	"Move Down": "Descendre",
	"Jump": "Sauter",
	"Arrows / stick: move    ·    Space / A: jump    ·    Esc: settings":
		"Flèches / stick : déplacer    ·    Espace / A : sauter    ·    Échap : paramètres",
	"%s %s %s %s: move    ·    %s: jump    ·    Esc: settings":
		"%s %s %s %s : déplacer    ·    %s : sauter    ·    Échap : paramètres",
}

static var _registered: bool = false


## Registers the French catalog with [TranslationServer] (only once).
static func register() -> void:
	if _registered:
		return
	_registered = true
	var translation: Translation = Translation.new()
	translation.locale = LOCALE
	for message: String in FR:
		translation.add_message(StringName(message), StringName(String(FR[message])))
	TranslationServer.add_translation(translation)
