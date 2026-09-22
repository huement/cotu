# res://Core/AudioManager.gd
extends Node

@export var sfx_pool_size: int = 16
@export var sfx_3d_pool_size: int = 8
@export var base_audio_dir: String = "res://Audio/"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _sfx_index: int = 0
var _sfx_3d_index: int = 0

var _ambient_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer

# Enemy Ambient Loop Registry (EnemyType String -> AudioStreamPlayer)
var _active_enemy_loops: Dictionary = {}
var _is_in_combat: bool = false
var _current_bgm_request: Variant = null


func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = &"UI" if AudioServer.get_bus_index("UI") != -1 else &"Master"
	add_child(_ui_player)
	
	_initialize_audio_channels()
	
	var bus: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(bus):
		if bus.has_signal(&"combat_started") and not bus.combat_started.is_connected(_on_combat_started):
			bus.combat_started.connect(_on_combat_started)
		if bus.has_signal(&"combat_ended") and not bus.combat_ended.is_connected(_on_combat_ended):
			bus.combat_ended.connect(_on_combat_ended)
		if bus.has_signal(&"spell_vfx_requested") and not bus.spell_vfx_requested.is_connected(_on_spell_vfx_requested):
			bus.spell_vfx_requested.connect(_on_spell_vfx_requested)


func _initialize_audio_channels() -> void:
	for i in range(sfx_pool_size):
		var asp := AudioStreamPlayer.new()
		asp.name = "SFXPlayer_%d" % i
		asp.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(asp)
		_sfx_pool.append(asp)

	for i in range(sfx_3d_pool_size):
		var asp3d := AudioStreamPlayer3D.new()
		asp3d.name = "SFX3DPlayer_%d" % i
		asp3d.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		asp3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		asp3d.unit_size = 2.0
		asp3d.max_distance = 12.0
		add_child(asp3d)
		_sfx_3d_pool.append(asp3d)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = &"Ambient" if AudioServer.get_bus_index("Ambient") != -1 else &"Master"
	add_child(_ambient_player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = &"Music" if AudioServer.get_bus_index("Music") != -1 else &"Master"
	add_child(_bgm_player)

	# Auto-loop any track played on the BGM player
	_bgm_player.finished.connect(_bgm_player.play)


# ==============================================================================
# 0. BGM & AMBIENT MUSIC MANAGEMENT
# ==============================================================================
## Plays a dedicated background music track from a file path or AudioStream.
func play_bgm(stream_or_file_name: Variant, update_saved_request: bool = true) -> void:
	if update_saved_request:
		_current_bgm_request = stream_or_file_name

	var stream: AudioStream = null

	if stream_or_file_name is AudioStream:
		stream = stream_or_file_name
	elif stream_or_file_name is String:
		var raw_path: String = (stream_or_file_name as String).strip_edges()
		if raw_path.is_empty():
			return

		var clean_rel_path: String = raw_path.get_basename() + ".mp3"
		
		# Build potential paths to resolve relative subfolders (e.g. "Environment/" or "Music/")
		var candidate_paths: Array[String] = []
		if raw_path.begins_with("res://"):
			candidate_paths.append(raw_path)
		else:
			candidate_paths.append(base_audio_dir.path_join(clean_rel_path))
			candidate_paths.append(base_audio_dir.path_join("Music").path_join(clean_rel_path.get_file()))
			candidate_paths.append(base_audio_dir.path_join("Environment").path_join(clean_rel_path.get_file()))

		var found_path: String = ""
		for path in candidate_paths:
			if ResourceLoader.exists(path):
				found_path = path
				break

		if not found_path.is_empty():
			stream = load(found_path) as AudioStream
		else:
			push_error("AudioManager: Could not locate BGM audio file for '%s'. Checked candidate paths: %s" % [stream_or_file_name, candidate_paths])
			return

	if is_instance_valid(stream):
		if _bgm_player.stream != stream or not _bgm_player.is_playing():
			_bgm_player.stream = stream
			_bgm_player.play()
			GameLogger.combat("BGM playing successfully: %s" % stream.resource_path)


## Stops the currently playing background music.
func stop_bgm() -> void:
	if is_instance_valid(_bgm_player) and _bgm_player.is_playing():
		_bgm_player.stop()


## Plays looping ambient environmental audio (e.g., "ghost", "dungeon_wind") without touching BGM.
func play_level_sound(sound_name: String) -> void:
	var clean_name: String = sound_name.get_basename()
	var file_path: String = base_audio_dir.path_join("Environment").path_join(clean_name + ".mp3")

	if ResourceLoader.exists(file_path):
		var stream: AudioStream = load(file_path) as AudioStream
		if is_instance_valid(stream) and _ambient_player.stream != stream:
			_ambient_player.stream = stream
			_ambient_player.play()


## Stops active environmental ambient audio.
func stop_level_sound() -> void:
	if is_instance_valid(_ambient_player) and _ambient_player.is_playing():
		_ambient_player.stop()


# ==============================================================================
# 1. WEAPONS & COMBAT SFX
# ==============================================================================
func play_attack_sound(weapon_type: String) -> void:
	var type_upper: String = weapon_type.to_upper()
	var filename: String = "physical.mp3"

	if "BLADE" in type_upper or "SLASH" in type_upper or "SWORD" in type_upper:
		var blade_files: Array[String] = ["blade.mp3", "blade-2.mp3"]
		filename = blade_files.pick_random()
	elif "BASH" in type_upper or "STAFF" in type_upper or "BLUDGEON" in type_upper:
		filename = "bash.mp3"
	elif "RANGED" in type_upper or "BOW" in type_upper or "SHOOT" in type_upper:
		filename = "ranged.mp3"
	elif "UNARMED" in type_upper or "PUNCH" in type_upper or "KICK" in type_upper:
		filename = "unarmed.mp3"
	elif "PLASMA" in type_upper:
		filename = "plasma.mp3"

	var full_path: String = base_audio_dir.path_join("Attacks").path_join(filename)
	_play_stream_from_path(full_path)


func play_player_damage() -> void:
	_play_from_folder("Player/", "damage")


func play_victory_sound() -> void:
	_play_from_folder("Environment/", "win-battle")


func play_turn_around_sound() -> void:
	_play_from_folder("Player/", "whoosh")


# ==============================================================================
# 2. ENEMY & DEATH SFX
# ==============================================================================
## Plays enemy death SFX matching "<enemy_type>_death.mp3" (e.g., "zombie_death.mp3"), falling back to "death.mp3"
func play_enemy_death_sound(enemy_type: String = "") -> void:
	var key: String = enemy_type.to_lower().strip_edges()
	var file_name: String = "death"

	if not key.is_empty() and _has_file("Enemies/", key + "_death"):
		file_name = key + "_death"

	_play_from_folder("Enemies/", file_name)


func play_3d_enemy_sound(sound_name: String, world_pos: Vector3) -> void:
	var file_path: String = base_audio_dir.path_join("Enemies").path_join(sound_name.to_lower() + ".mp3")
	if ResourceLoader.exists(file_path):
		var stream: AudioStream = load(file_path) as AudioStream
		if is_instance_valid(stream):
			var player3d := _get_next_3d_player()
			player3d.global_position = world_pos
			player3d.stream = stream
			player3d.play()


func play_enemy_sound(enemy_sound_file_name: String) -> void:
	var clean_name: String = enemy_sound_file_name.get_basename()
	if clean_name.is_empty():
		clean_name = "skeleton_footstep"

	var full_path: String = base_audio_dir.path_join("Enemies").path_join(clean_name + ".mp3")
	if not ResourceLoader.exists(full_path):
		full_path = base_audio_dir.path_join("Enemies").path_join("skeleton_footstep.mp3")

	_play_stream_from_path(full_path)


# ==============================================================================
# BATTLE MUSIC OVERRIDES
# ==============================================================================
func play_battle_music() -> void:
	# Pass false so _current_bgm_request is not overwritten
	play_bgm("Environment/dungeon-battle", false)


func stop_battle_music() -> void:
	stop_bgm()


# ==============================================================================
# COMBAT SIGNAL CALLBACKS
# ==============================================================================
func _on_combat_started(_enemy_data_or_group: Variant, _player_party: Array, _enemy_facing: String) -> void:
	_is_in_combat = true
	stop_all_enemy_loops()
	play_battle_music()


func _on_combat_ended(victory: bool) -> void:
	_is_in_combat = false
	stop_battle_music()
	if victory:
		play_victory_sound()
		
	# Delay restarting standard level BGM slightly to allow victory fanfare to play out
	await get_tree().create_timer(3.0).timeout
	
	# Resume standard level background music
	if _current_bgm_request != null:
		play_bgm(_current_bgm_request)


# ==============================================================================
# 3. MOVEMENT & PROXIMITY ALERTS
# ==============================================================================
func play_walking_sound(floor_type: String = "dungeon") -> void:
	var key: String = "footsteps_" + floor_type.to_lower()
	_play_from_folder("Player/", key)


func play_proximity_clicker(tier: int) -> void:
	var file_name: String = "monster_clicker" if tier == 1 else "monster_clicker-closer"
	_play_from_folder("Player/", file_name)


# ==============================================================================
# 4. ENVIRONMENT & ITEMS SFX
# ==============================================================================
func play_mask_sound(mask_type: String = "bad") -> void:
	var file_name: String = "mask-" + mask_type.to_lower()
	_play_from_folder("Items/", file_name)


func play_magic_sound(element_name: String) -> void:
	_play_from_folder("Magic/", element_name.to_lower())


func play_ui_sound(ui_sound_file_name: String) -> void:
	var clean_name: String = ui_sound_file_name.get_basename()
	if clean_name.is_empty():
		clean_name = "button-press"

	var full_path: String = base_audio_dir.path_join("UI").path_join(clean_name + ".mp3")
	if not ResourceLoader.exists(full_path):
		full_path = base_audio_dir.path_join("UI").path_join("button-press.mp3")

	if ResourceLoader.exists(full_path):
		var stream: AudioStream = load(full_path) as AudioStream
		if is_instance_valid(stream):
			_ui_player.stream = stream
			_ui_player.play()


func play_button_press() -> void:
	_play_from_folder("UI/", "button-press")


func play_search_sound() -> void:
	_play_from_folder("Player/", "search")


func play_potion_sound() -> void:
	_play_from_folder("Player/", "use-potion")


func play_environment(sound_name: String) -> void:
	var clean_name: String = sound_name.get_basename()
	if clean_name.is_empty():
		return

	var full_path: String = base_audio_dir.path_join("Environment").path_join(clean_name + ".mp3")
	if not ResourceLoader.exists(full_path):
		push_warning("AudioManager: Environmental sound not found at path: " + full_path)
		return

	_play_stream_from_path(full_path)


# ==============================================================================
# INTERNAL ROUTING HELPERS
# ==============================================================================
func _has_file(subfolder: String, base_name: String) -> bool:
	return ResourceLoader.exists(base_audio_dir + subfolder + base_name + ".mp3")


func _play_stream_from_path(full_path: String) -> void:
	if not ResourceLoader.exists(full_path):
		return
	var stream: AudioStream = load(full_path) as AudioStream
	if is_instance_valid(stream):
		var player := _get_next_sfx_player()
		player.stream = stream
		player.play()


func _play_from_folder(subfolder: String, base_name: String) -> void:
	var matching_streams: Array[AudioStream] = []
	var folder_path: String = base_audio_dir + subfolder + base_name

	if ResourceLoader.exists(folder_path + ".mp3"):
		var single_stream: AudioStream = load(folder_path + ".mp3") as AudioStream
		matching_streams.append(single_stream)

	var idx: int = 2
	while ResourceLoader.exists("%s-%d.mp3" % [folder_path, idx]):
		var var_stream: AudioStream = load("%s-%d.mp3" % [folder_path, idx]) as AudioStream
		matching_streams.append(var_stream)
		idx += 1

	if not matching_streams.is_empty():
		var chosen: AudioStream = matching_streams[randi() % matching_streams.size()]
		var player := _get_next_sfx_player()
		player.stream = chosen
		player.play()


func _get_next_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	return player


func _get_next_3d_player() -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = _sfx_3d_pool[_sfx_3d_index]
	_sfx_3d_index = (_sfx_3d_index + 1) % _sfx_3d_pool.size()
	return player


# ==============================================================================
# ENEMY AMBIENT LOOP MANAGEMENT
# ==============================================================================
func sync_nearby_enemy_loops(nearby_types: Array[String]) -> void:
	if _is_in_combat:
		stop_all_enemy_loops()
		return

	var active_keys: Array = _active_enemy_loops.keys()
	for enemy_type in active_keys:
		if not nearby_types.has(enemy_type):
			_stop_enemy_loop(enemy_type)

	for enemy_type in nearby_types:
		if not _active_enemy_loops.has(enemy_type):
			_start_enemy_loop(enemy_type)


func _start_enemy_loop(enemy_type: String) -> void:
	var key: String = enemy_type.to_lower()
	var possible_paths: Array[String] = [
		base_audio_dir + "Enemies/" + key + "_walking.mp3",
		base_audio_dir + "Enemies/" + key + "_shuffle.mp3"
	]

	var file_path: String = ""
	for path in possible_paths:
		if ResourceLoader.exists(path):
			file_path = path
			break

	if file_path.is_empty():
		return

	var stream: AudioStream = load(file_path) as AudioStream
	if not is_instance_valid(stream):
		return

	var asp := AudioStreamPlayer.new()
	asp.name = "EnemyLoop_" + key
	asp.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	asp.stream = stream
	add_child(asp)
	asp.play()

	_active_enemy_loops[key] = asp


func _stop_enemy_loop(enemy_type: String) -> void:
	var key: String = enemy_type.to_lower()
	if _active_enemy_loops.has(key):
		var asp: AudioStreamPlayer = _active_enemy_loops[key] as AudioStreamPlayer
		if is_instance_valid(asp):
			asp.stop()
			asp.queue_free()
		_active_enemy_loops.erase(key)


func stop_all_enemy_loops() -> void:
	var active_keys: Array = _active_enemy_loops.keys()
	for key in active_keys:
		_stop_enemy_loop(str(key))


# ==============================================================================
# MAGIC SPELL & SKILL AUDIO ROUTING
# ==============================================================================
func _on_spell_vfx_requested(anim_name: String, _element: Variant = null) -> void:
	play_spell_sound(anim_name)


func play_spell_sound(anim_name: String) -> void:
	var key: String = anim_name.to_lower().strip_edges()
	if key.is_empty() or key == "none":
		return

	var candidate_files: Array[String] = _find_magic_audio_candidates(key)

	if candidate_files.is_empty():
		var magic_keywords: Array[String] = ["air", "bolt", "dark", "earth", "fire", "life", "light", "smoke", "water"]
		for kw in magic_keywords:
			if kw in key:
				candidate_files = _find_magic_audio_candidates(kw)
				if not candidate_files.is_empty():
					break

	if candidate_files.is_empty():
		return

	var chosen_path: String = candidate_files.pick_random()
	_play_stream_from_path(chosen_path)


func _find_magic_audio_candidates(base_key: String) -> Array[String]:
	var candidates: Array[String] = []
	var path_stem: String = base_audio_dir + "Magic/" + base_key

	if ResourceLoader.exists(path_stem + ".mp3"):
		candidates.append(path_stem + ".mp3")

	var i: int = 2
	while ResourceLoader.exists("%s-%d.mp3" % [path_stem, i]):
		candidates.append("%s-%d.mp3" % [path_stem, i])
		i += 1

	return candidates


func play_skill_sound(skill_name: String) -> void:
	var key: String = skill_name.to_lower().strip_edges().replace(" ", "-").replace("_", "-")
	if key.is_empty():
		return

	var file_path: String = base_audio_dir + "Skills/" + key + ".mp3"
	if not ResourceLoader.exists(file_path):
		file_path = base_audio_dir + "Skills/default.mp3"

	_play_stream_from_path(file_path)
