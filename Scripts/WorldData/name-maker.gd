class_name NameGenerator
extends RefCounted

const MAX_LETTERS: int = 10

# Base names: kept between 3–7 letters so they reliably pair with modifiers
const BASE_NAMES: Array[String] = [
	# Roman / Classical / Mythic (60)
	"Maximus", "Titus", "Caius", "Nero", "Felix", "Cato",
	"Aurel", "Varro", "Remus", "Decim", "Cass", "Juno",
	"Livia", "Brutus", "Vesper", "Sever", "Castor", "Marius",
	"Lucius", "Marcus", "Gaius", "Odo", "Sulla", "Drusus",
	"Magnus", "Julius", "Rufus", "Flavia", "Octav", "Valen",
	"Corvus", "Lucan", "Sabin", "Tiber", "Aegis", "Apollo",
	"Mars", "Nova", "Orion", "Atlas", "Janus", "Rhea",
	"Vesta", "Ceres", "Diana", "Pluto", "Vulcan", "Zephyr",
	"Solis", "Eris", "Ferrum", "Aether", "Umbra", "Luxor",
	"Regis", "Taurus", "Aquila", "Lupus", "Ursus", "Nyx",
	"Johny", "Fortune", "Thirteen", "Zaphod", "Aleister",
	"Violet", "Violent", "Vile", "Viper", "Eva",

	# Cyberpunk / Tech / Sci-Fi (76)
	"Pixel", "Vector", "Cipher", "Neon", "Glitch",
	"Cobalt", "Kilo", "Chrono", "Vex", "Flux", "Zero",
	"Cortex", "Helix", "Prism", "Quasar",
	"Data", "Byte", "Node", "Link", "Volt", "Prime", "Spark",
	"Echo", "Ghost", "Shade", "Trace", "Breach", "Crash", "Null",
	"Void", "Apex", "Nadir", "Onyx", "Chrome", "Yella",
	"Ion", "Zak", "Nano", "Giga", "Tera", "Cyber", "Synth",
	"Codec", "Sector", "Socket", "Paco", "Daisy"
]

# Short titles, prefixes, numerals, and tags (1 to 4 characters)
const MODIFIERS: Array[String] = [
	# Roman honorifics, Latin roots & numerals (41)
	"Rex", "Lux", "Pax", "Dux", "Lex", "Sol", "Vox", "Nox",
	"Max", "Imp", "Cent", "Leg", "Sen", "Prae", "Trib", "Cons",
	"Dom", "Magn", "Ver", "Ult", "Prim", "Sec", "Tert", "Dec",
	"Aug", "Cael", "Ign", "Fer", "Aur",
	"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII",

	# Cyber, tech & designation codes (41)
	"Neu", "Neo", "Hex", "Syn", "Arc", "Bit", "SIR",
	"MD", "Dot", "Doc", "ESQ", "88", "Mog", "Ram", "Null",
  "CELL", "Lord", "Cryo", "Pyro", "Aero", "Geo", "Exo",
	"Sub", "Pro", "Count", "Dev", "Dark", "Trip", "Chip", "Max",
	"Luc", "Zero", "One", "Z", "K9", "V2", "01", "13", "99", "X2",
	"Lil", "NBA", "KID", "Kat", "OTF", "Wiz"
]


## Generates a compliant name fitting the letter count limit.
## Optionally pass an array of existing names to avoid duplicates.
static func generate(exclude: Array[String] = []) -> String:
	for _attempt in range(25):
		var candidate: String = _roll_candidate()
		if not candidate in exclude:
			return candidate
			
	return _roll_candidate()


static func _roll_candidate() -> String:
	var base: String = BASE_NAMES.pick_random()
	var remaining: int = MAX_LETTERS - base.length()
	
	# ~30% chance for a clean single-word name, or if no room remains for a modifier
	if remaining < 1 or randf() < 0.30:
		return base
	
	# Filter modifiers that strictly fit within the remaining character budget
	var valid_mods: Array[String] = []
	for mod in MODIFIERS:
		if mod.length() <= remaining:
			valid_mods.append(mod)
			
	if valid_mods.is_empty():
		return base
		
	var chosen_mod: String = valid_mods.pick_random()
	var sep: String = "-" if randf() < 0.40 else " "
	
	# 50/50 split between Prefix (e.g., "Neo Titus", "Syn-Vex") and Suffix (e.g., "Cato-IX", "Maximus Rex")
	if randf() < 0.50:
		return "%s%s%s" % [chosen_mod, sep, base]
	else:
		return "%s%s%s" % [base, sep, chosen_mod]