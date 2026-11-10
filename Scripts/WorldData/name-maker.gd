class_name NameGenerator
extends RefCounted

const MAX_LETTERS: int = 10

# Base names: Roman names, classical Latin stems, and cyberpunk tech terms
const BASE_NAMES: Array[String] = [
	# Roman / Classical
	"Maximus", "Titus", "Caius", "Nero", "Felix", "Cato", 
	"Aurel", "Varro", "Remus", "Decim", "Cass", "Juno", 
	"Livia", "Brutus", "Vesper", "Sever", "Castor", "Marius",
	# Cyberpunk / Tech
	"Pixel", "Vector", "Cipher", "Neon", "Proxy", "Glitch", 
	"Cobalt", "Static", "Vertex", "Pulse", "Servo", "Matrix",
	"Kilo", "Chrono", "Vex", "Rift", "Flux", "Zero"
]

# Short titles/modifiers (2 to 4 letters) that sit before or after a base
const MODIFIERS: Array[String] = [
	# Roman honorifics & Latin roots
	"Rex", "Lux", "Pax", "Dux", "Lex", "Sol", "Vox", "IX", "IV", "VII",
	# Cyber & Futuristic terms
	"Neu", "Neo", "Hex", "Syn", "Arc", "Bit", "Core", "Net", "Mod", "Dot"
]

## Generates a compliant name fitting the letter count limit.
static func generate() -> String:
	for _attempt in range(25):
		var candidate: String = _roll_candidate()
		
		# Count only letters (excluding spaces and hyphens)
		var letter_count: int = candidate.replace(" ", "").replace("-", "").length()
		if letter_count <= MAX_LETTERS:
			return candidate
			
	# Fallback if random combinations exceed the limit repeatedly
	return BASE_NAMES.pick_random()

static func _roll_candidate() -> String:
	var base: String = BASE_NAMES.pick_random()
	var mod: String = MODIFIERS.pick_random()
	
	# Structure types:
	# 0 = Single Word (e.g., "Maximus", "Cipher")
	# 1 = Mod + Base  (e.g., "Neo Titus", "Syn Varo")
	# 2 = Base + Mod  (e.g., "Maximus Rex", "Pixel Neu")
	match randi() % 3:
		0:
			return base
		1:
			return "%s %s" % [mod, base]
		2:
			return "%s %s" % [base, mod]
			
	return base