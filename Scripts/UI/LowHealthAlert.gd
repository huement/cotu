# res://Scripts/UI/LowHealthAlert.gd
class_name LowHealthAlert
extends Node
## "You're about to die" alert. Lives under the dungeon HUD (hud.gd adds it in _ready).
##
## While exploring (not in a battle, its victory screen, or a boss cutscene), if ANY living party
## member is below `critical_percent` of their max HP:
##   - the screen edge flashes red every `flash_interval` seconds,
##   - Audio/Player/heavy-breathing.mp3 loops,
##   - Nine says "warning-about-to-die" ONCE.
## When every living member is back at or above the threshold, everything stops.
##
## Nine's line re-arms (has_alerted_player_health_hud = false) when a battle starts or a party member
## takes damage, so the next time the party is left critical Nine warns again.
## Dead members (0 HP) don't count - this is about the ones still standing.

const BREATHING_PATH: String = "res://Audio/Player/heavy-breathing.mp3"
const NINE_CLIP: String = "warning-about-to-die"

## Below this percent of max HP a living member counts as "about to die".
@export_range(1.0, 50.0, 0.5) var critical_percent: float = 3.0
@export var flash_color: Color = Color(1.0, 0.05, 0.1, 0.85)
@export var flash_duration: float = 0.9
## Seconds between edge flashes.
@export var flash_interval: float = 1.6
@export_range(-40.0, 12.0, 0.5) var breathing_volume_db: float = -4.0
## Wait this long after the alert starts before Nine talks (lets the screen settle after a fight).
@export var nine_delay: float = 0.8
## How often the party is re-checked (seconds). Catches every way HP can change.
@export var check_interval: float = 0.25

## Nine has already warned about this low-health spell. Reset by a battle or by taking damage.
var has_alerted_player_health_hud: bool = false

var _active: bool = false
var _cutscene_running: bool = false
var _check_timer: float = 0.0
var _flash_timer: float = 0.0
var _nine_timer: float = -1.0
var _breathing: AudioStreamPlayer = null
var _breathing_fade: Tween = null
var _last_hp: Dictionary = {} # slot -> hp, to spot damage taken


func _ready() -> void:
	SignalBus.combat_started.connect(_on_combat_started)
	SignalBus.character_health_changed.connect(_on_character_health_changed)
	SignalBus.boss_cutscene_requested.connect(func(_id: String, _pos: Vector3, _end: Resource) -> void:
		_cutscene_running = true)
	SignalBus.boss_cutscene_finished.connect(func(_id: String) -> void:
		_cutscene_running = false)


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = check_interval
		_detect_damage()
		var should_alert: bool = _can_alert_now() and _party_is_critical()
		if should_alert and not _active:
			_start()
		elif not should_alert and _active:
			_stop()

	if not _active:
		return

	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = flash_interval
		SignalBus.edge_flash_requested.emit(flash_color, flash_duration)

	# Damage taken while already critical re-arms Nine: warn again.
	if not has_alerted_player_health_hud and _nine_timer < 0.0:
		_nine_timer = nine_delay
	if _nine_timer >= 0.0:
		_nine_timer -= delta
		if _nine_timer < 0.0 and not has_alerted_player_health_hud:
			has_alerted_player_health_hud = true
			SignalBus.nine_speak_requested.emit(NINE_CLIP)


# ==============================================================================
# Conditions
# ==============================================================================

func _can_alert_now() -> bool:
	if _cutscene_running:
		return false
	if GameState.current_mode != GameState.Mode.EXPLORING:
		return false
	return not GameState.is_battle_in_progress() # includes the victory / loot screen


## True when any living member is below critical_percent of their max HP.
func _party_is_critical() -> bool:
	for member: CatCharacter in _members():
		if member.current_hp > 0 and member.max_hp > 0 \
				and float(member.current_hp) / float(member.max_hp) * 100.0 < critical_percent:
			return true
	return false


func _members() -> Array[CatCharacter]:
	var out: Array[CatCharacter] = []
	if GameState.current_party == null:
		return out
	for slot: Variant in GameState.current_party.slots:
		var member: CatCharacter = slot as CatCharacter
		if member != null:
			out.append(member)
	return out


# ==============================================================================
# Re-arming Nine
# ==============================================================================

func _on_combat_started(_enemies: Variant, _party: Array, _facing: String) -> void:
	has_alerted_player_health_hud = false
	if _active:
		_stop() # the battle has its own feedback


func _on_character_health_changed(slot: int, current_hp: int) -> void:
	var before: int = int(_last_hp.get(slot, current_hp))
	if current_hp < before:
		has_alerted_player_health_hud = false
	_last_hp[slot] = current_hp


## Damage that doesn't go through character_health_changed (hazards, scripts) still re-arms Nine.
func _detect_damage() -> void:
	if GameState.current_party == null:
		return
	var slots: Array = GameState.current_party.slots
	for i: int in range(slots.size()):
		var member: CatCharacter = slots[i] as CatCharacter
		if member == null:
			continue
		var before: int = int(_last_hp.get(i, member.current_hp))
		if member.current_hp < before:
			has_alerted_player_health_hud = false
		_last_hp[i] = member.current_hp


# ==============================================================================
# On / off
# ==============================================================================

func _start() -> void:
	_active = true
	_flash_timer = 0.0 # first flash right away
	_nine_timer = nine_delay if not has_alerted_player_health_hud else -1.0
	_start_breathing()
	GameLogger.info("LowHealthAlert: party member below %.0f%% HP - alert on." % critical_percent)


func _stop() -> void:
	_active = false
	_nine_timer = -1.0
	_stop_breathing()
	GameLogger.info("LowHealthAlert: alert off.")


func _start_breathing() -> void:
	if not ResourceLoader.exists(BREATHING_PATH):
		push_warning("LowHealthAlert: %s not found (open the project in the editor so it imports)." % BREATHING_PATH)
		return
	if not is_instance_valid(_breathing):
		_breathing = AudioStreamPlayer.new()
		_breathing.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
		add_child(_breathing)
		var stream: AudioStream = (load(BREATHING_PATH) as AudioStream).duplicate()
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_breathing.stream = stream
		# Fallback loop in case the stream type doesn't loop on its own.
		_breathing.finished.connect(func() -> void:
			if _active and is_instance_valid(_breathing):
				_breathing.play())
	if is_instance_valid(_breathing_fade):
		_breathing_fade.kill()
	_breathing.volume_db = breathing_volume_db
	if not _breathing.playing:
		_breathing.play()


func _stop_breathing() -> void:
	if not is_instance_valid(_breathing) or not _breathing.playing:
		return
	var player: AudioStreamPlayer = _breathing
	_breathing_fade = create_tween()
	_breathing_fade.tween_property(player, "volume_db", -40.0, 0.8)
	_breathing_fade.tween_callback(func() -> void:
		if not _active and is_instance_valid(player):
			player.stop()
			player.volume_db = breathing_volume_db)
