extends RefCounted
## French texts of the demo game (the kit's own texts are already translated).

const FR: Dictionary = {
	"Sector 7 // online": "Secteur 7 // en ligne",
	"Sector 7 · Orbital Dock": "Secteur 7 · Quai orbital",
	"Sector 7 · Neon Market": "Secteur 7 · Marché néon",
	"Sector 7 · Data Core": "Secteur 7 · Noyau de données",
	"Data shards": "Fragments",
	"All shards recovered": "Tous les fragments récupérés",
	"move": "bouger",
	"boost": "turbo",
	"pause": "pause",
	"Move": "Bouger",
	"Boost": "Turbo",
	"Interact": "Interagir",
	"Map": "Carte",
	"Pause": "Pause",
	"Move up": "Monter",
	"Move down": "Descendre",
	"Move left": "Aller à gauche",
	"Move right": "Aller à droite",
	"Tip: dashing through a laser grid costs half your shield, not all of it.":
		"Astuce : traverser une grille laser coûte la moitié du bouclier, pas tout.",
	"Tip: hold boost to cross a sector in a few seconds.":
		"Astuce : maintenez le turbo pour traverser un secteur en quelques secondes.",
	"Tip: the pause menu saves a screenshot with your game.":
		"Astuce : le menu pause enregistre une capture d'écran avec votre partie.",
}

static var _registered: bool = false


static func register() -> void:
	if _registered:
		return
	_registered = true
	var translation: Translation = Translation.new()
	translation.locale = "fr"
	for message: String in FR:
		translation.add_message(StringName(message), StringName(String(FR[message])))
	TranslationServer.add_translation(translation)
