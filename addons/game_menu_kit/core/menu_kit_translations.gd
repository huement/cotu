extends RefCounted
## Built-in French translation of the kit's texts.
##
## The kit is written in English. At startup, the MenuKit autoload registers this
## catalog with [TranslationServer], so players whose language is French see the
## menus in French (and "Français" appears in the Language setting). No .po/.csv
## import is needed. To turn it off (English-only game), untick the project setting
## [code]menu_kit/localization/builtin_french[/code]. To add a language, create your
## own [Translation] (CSV or PO) using the English texts below as message ids.

const LOCALE: String = "fr"

## English text -> French text.
const FR: Dictionary = {
	# --- Main menu -----------------------------------------------------------
	"Continue": "Continuer",
	"New Game": "Nouvelle partie",
	"Load Game": "Charger",
	"Options": "Options",
	"Quit": "Quitter",
	"Quit game?": "Quitter le jeu ?",
	"Anything since your last save will be lost.": "Tout ce qui s'est passé depuis la dernière sauvegarde sera perdu.",
	"Stay": "Rester",
	"See you soon": "À bientôt",
	"Signal lost": "Signal perdu",
	"Farewell, traveller": "Adieu, voyageur",
	"Bye bye!": "À plus !",
	"Loading!": "Chargement !",
	# --- Save slots ----------------------------------------------------------
	"Save Game": "Sauvegarder",
	"Slot %d": "Emplacement %d",
	"Empty slot": "Emplacement vide",
	"Nothing saved here yet": "Rien n'est encore sauvegardé ici",
	"Saved game": "Partie sauvegardée",
	"Load this save?": "Charger cette sauvegarde ?",
	"Load": "Charger",
	"Overwrite this save?": "Écraser cette sauvegarde ?",
	"The older save in this slot will be replaced.": "L'ancienne sauvegarde de cet emplacement sera remplacée.",
	"Overwrite": "Écraser",
	"Erase": "Effacer",
	"Erase this save?": "Effacer cette sauvegarde ?",
	"This cannot be undone.": "Impossible de revenir en arrière.",
	# --- Pause menu and loading ----------------------------------------------
	"Paused": "Pause",
	"Resume": "Reprendre",
	"Main Menu": "Menu principal",
	"Return to the main menu?": "Revenir au menu principal ?",
	"Play time": "Temps de jeu",
	"Loading": "Chargement",
	# --- Options menu --------------------------------------------------------
	"Back": "Retour",
	"Reset": "Réinitialiser",
	"Cancel": "Annuler",
	"Reset settings?": "Réinitialiser les réglages ?",
	"Every setting of the \"%s\" tab goes back to its default value.":
		"Tous les réglages de l'onglet « %s » reprennent leur valeur par défaut.",
	"On": "Activé",
	"Off": "Désactivé",
	# --- Tabs ----------------------------------------------------------------
	"Game": "Jeu",
	"Camera": "Caméra",
	"Video": "Vidéo",
	"Audio": "Audio",
	"Controls": "Commandes",
	"Accessibility": "Accessibilité",
	# --- Game ----------------------------------------------------------------
	"Difficulty": "Difficulté",
	"Story": "Histoire",
	"Normal": "Normal",
	"Hard": "Difficile",
	"Language": "Langue",
	"Subtitles": "Sous-titres",
	"Subtitle size": "Taille des sous-titres",
	"Small": "Petits",
	"Medium": "Moyens",
	"Large": "Grands",
	"Tutorial hints": "Astuces du tutoriel",
	"Autosave": "Sauvegarde auto",
	"Every 5 min": "Toutes les 5 min",
	"Every 10 min": "Toutes les 10 min",
	# --- Camera --------------------------------------------------------------
	"Field of view": "Champ de vision",
	"Mouse sensitivity": "Sensibilité souris",
	"Stick sensitivity": "Sensibilité stick",
	"Invert Y axis": "Inverser l'axe Y",
	"Camera shake": "Tremblements caméra",
	"Head bob": "Balancement de tête",
	"Motion blur": "Flou de mouvement",
	# --- Video ---------------------------------------------------------------
	"Display": "Affichage",
	"Window": "Fenêtre",
	"Borderless": "Sans bordure",
	"Fullscreen": "Plein écran",
	"Resolution": "Résolution",
	"VSync": "VSync",
	"Frame rate limit": "Limite d'images/s",
	"Unlimited": "Illimitée",
	"Quality": "Qualité",
	"Low": "Basse",
	"Mid": "Moyenne",
	"High": "Haute",
	"Ultra": "Ultra",
	"Render scale": "Échelle de rendu",
	"Anti-aliasing": "Anticrénelage",
	"Brightness": "Luminosité",
	"Show FPS": "Afficher les FPS",
	# --- Audio ---------------------------------------------------------------
	"Master": "Général",
	"Music": "Musique",
	"Effects": "Effets",
	"Voices": "Voix",
	"Interface": "Interface",
	"Hover sounds": "Sons de survol",
	"Mute in background": "Couper en arrière-plan",
	# --- Controls ------------------------------------------------------------
	"Action": "Action",
	"Keyboard / Mouse": "Clavier / Souris",
	"Gamepad": "Manette",
	"Press a key…": "Appuyez sur une touche…",
	"Press a button…": "Appuyez sur un bouton…",
	"Already in use": "Déjà utilisée",
	"\"%s\" is already used by \"%s\".\nSwap: \"%s\" gets the old key. Replace: \"%s\" loses it.":
		"« %s » est déjà utilisée par « %s ».\nÉchanger : « %s » récupère l'ancienne touche. Remplacer : « %s » la perd.",
	"Swap": "Échanger",
	"Replace": "Remplacer",
	"Controller vibration": "Vibrations de la manette",
	"Stick dead zone": "Zone morte du stick",
	"Aim mode": "Mode de visée",
	"Hold": "Maintenir",
	"Toggle": "Basculer",
	# --- Accessibility -------------------------------------------------------
	"Colorblind mode": "Mode daltonien",
	"Protanopia": "Protanopie",
	"Deuteranopia": "Deutéranopie",
	"Tritanopia": "Tritanopie",
	"Text size": "Taille du texte",
	"Reduce flashing": "Réduire les flashs",
	"High-contrast HUD": "HUD à fort contraste",
	"Read menus aloud": "Lire les menus à voix haute",
	# --- Keys ----------------------------------------------------------------
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
	# --- Mouse ---------------------------------------------------------------
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
	# --- Gamepad -------------------------------------------------------------
	"A / Cross": "A / Croix",
	"B / Circle": "B / Rond",
	"X / Square": "X / Carré",
	"Select / Back": "Select / Retour",
	"Guide / Home": "Guide / Accueil",
	"D-Pad ↑": "Croix ↑",
	"D-Pad ↓": "Croix ↓",
	"D-Pad ←": "Croix ←",
	"D-Pad →": "Croix →",
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
