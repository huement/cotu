# res://Scripts/Utilities/level_default_starters.gd
# One-shot: godot --path . --headless -s Scripts/Utilities/level_default_starters.gd
extends SceneTree

const SAVE_PATH: String = "res://Data/default_save.tres"
const TARGET_LEVEL: int = 5
const FIGHTER_CLASSES: Array[String] = ["Spartan", "Crusader", "Ghostblade", "Ronin", "Amazon"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		push_error("Missing default save at %s" % SAVE_PATH)
		quit(1)
		return

	var save: SaveGame = load(SAVE_PATH) as SaveGame
	if not is_instance_valid(save) or not is_instance_valid(save.party):
		push_error("Failed to load SaveGame party from %s" % SAVE_PATH)
		quit(1)
		return

	# Re-load authored L1 baselines from git if this file was already leveled.
	# We treat current level > 1 as "already processed" and abort unless forced.
	var already_leveled: bool = false
	for slot_variant: Variant in save.party.slots:
		var probe: CatCharacter = slot_variant as CatCharacter
		if is_instance_valid(probe) and probe.level >= TARGET_LEVEL:
			already_leveled = true
			break

	if already_leveled:
		print("level_default_starters: party already at level %d — restoring L1 baselines first is required." % TARGET_LEVEL)
		print("Re-read from the pre-level tres values embedded below and re-apply.")
		_restore_level_one_baselines(save)

	for slot_variant: Variant in save.party.slots:
		var cat: CatCharacter = slot_variant as CatCharacter
		if not is_instance_valid(cat):
			continue
		_level_cat_to_target(cat)

	var err: Error = ResourceSaver.save(save, SAVE_PATH)
	if err != OK:
		push_error("ResourceSaver failed (%s) writing %s" % [error_string(err), SAVE_PATH])
		quit(1)
		return

	print("level_default_starters: wrote leveled starters to %s" % SAVE_PATH)
	quit(0)


## Authored L1 values from the original default_save (before this utility ran).
func _restore_level_one_baselines(save: SaveGame) -> void:
	var baselines: Dictionary = {
		"Commander Whiskers": {
			"level": 1, "current_xp": 0, "max_xp": 1000,
			"strength": 14, "intelligence": 8, "piety": 8, "vitality": 25,
			"dexterity": 8, "speed": 8, "personality": 8,
			"current_energy": 16, "max_energy": 16,
		},
		"Sir Clawslot": {
			"level": 1, "current_xp": 0, "max_xp": 1000,
			"strength": 13, "intelligence": 8, "piety": 8, "vitality": 22,
			"dexterity": 8, "speed": 12, "personality": 8,
			"current_energy": 16, "max_energy": 16,
		},
		"Baron Von Hiss": {
			"level": 1, "current_xp": 0, "max_xp": 1000,
			"strength": 10, "intelligence": 8, "piety": 8, "vitality": 20,
			"dexterity": 12, "speed": 14, "personality": 8,
			"current_energy": 16, "max_energy": 16,
		},
		"Sage Psych-Meow": {
			"level": 1, "current_xp": 0, "max_xp": 1000,
			"strength": 8, "intelligence": 15, "piety": 15, "vitality": 15,
			"dexterity": 8, "speed": 11, "personality": 8,
			"current_energy": 30, "max_energy": 30,
		},
	}

	for slot_variant: Variant in save.party.slots:
		var cat: CatCharacter = slot_variant as CatCharacter
		if not is_instance_valid(cat):
			continue
		if not baselines.has(cat.name):
			continue
		var data: Dictionary = baselines[cat.name] as Dictionary
		for key: String in data.keys():
			cat.set(key, data[key])
		_seed_vitals_from_attributes(cat)


func _level_cat_to_target(cat: CatCharacter) -> void:
	# Keep authored attributes; only seed vitals so LevelManager HP/MP math has a real baseline.
	_seed_vitals_from_attributes(cat)

	var options: Dictionary = {
		"stat_points": _stat_distribution_for(cat),
		"notify_ui": false,
		"persist_save": false,
	}
	while int(cat.level) < TARGET_LEVEL:
		LevelManager.level_player(cat, options)

	print(
		"  %s => L%d | STR %d INT %d PIE %d VIT %d DEX %d SPD %d | HP %d/%d | EN %d/%d | XP %d/%d"
		% [
			cat.name,
			cat.level,
			cat.strength,
			cat.intelligence,
			cat.piety,
			cat.vitality,
			cat.dexterity,
			cat.speed,
			cat.current_hp,
			cat.max_hp,
			cat.current_energy,
			cat.max_energy,
			cat.current_xp,
			cat.max_xp,
		]
	)


func _seed_vitals_from_attributes(cat: CatCharacter) -> void:
	var prof_name: String = ""
	if is_instance_valid(cat.profession) and "profession_name" in cat.profession:
		prof_name = str(cat.profession.get("profession_name"))

	var max_hp: int = cat.vitality * 2
	if prof_name in ["Spartan", "Crusader", "Amazon"]:
		max_hp = cat.vitality * 3

	cat.max_hp = max_hp
	cat.current_hp = max_hp
	# Energy stays as authored max_energy unless it was never set.
	if cat.max_energy <= 0:
		cat.max_energy = cat.intelligence + cat.piety
	cat.current_energy = cat.max_energy


func _stat_distribution_for(cat: CatCharacter) -> Dictionary:
	var prof_name: String = ""
	if is_instance_valid(cat.profession) and "profession_name" in cat.profession:
		prof_name = str(cat.profession.get("profession_name"))

	var is_fighter: bool = false
	for f_class: String in FIGHTER_CLASSES:
		if prof_name.nocasecmp_to(f_class) == 0:
			is_fighter = true
			break

	if is_fighter:
		return {"strength": 2, "vitality": 1, "dexterity": 1, "speed": 1}
	return {"intelligence": 2, "piety": 1, "vitality": 1, "speed": 1}
