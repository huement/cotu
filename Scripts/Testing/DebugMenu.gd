# res://Scripts/Testing/DebugMenu.gd
extends CanvasLayer
## Debug menu (autoload "DebugMenu"). Editor / debug builds only: in an exported release build it frees
## itself on start, so players never see it.
##
## Open / close: ` (backtick, TOGGLE_KEY). The game pauses while it's open. This is the ONE debug hotkey -
## the old BattleTest keys (B / N / H / V / L) are buttons in here now.
##   WORLD      jump to an overworld map, at any of its spawn / arrival markers
##   DUNGEONS   jump to any dungeon floor
##   CAVES      jump to any cave floor
##   LEVEL UP   level up one party member (or everyone) through the real level-up path
##   PARTY      full heal + revive, +1000 gold, give any item, set the time of day, save now
##   DISPLAY    preview the touch-screen HUD (MobileHUD) on desktop
##   BATTLE     BATTLE TEST ARENA (Scenes/Dungeons/BattleTestArena.tscn; any exit there returns you to
##              where you were - MapTransition.set_return_point), test encounters / end battle (Scripts/Testing/BattleTest.gd, node "BattleTester" in world.tscn),
##              Nine voice test; OPEN BATTLE TESTER appears once BattleTest.gd has open_debug_panel()
##
## Jumps use MapTransition.travel (same as a stone gate: swaps the map, places the party, autosaves).
## They need the game world (world.tscn) to be running - not available on the main menu or in battle.
## Add a map: put it in WORLD_MAPS / DUNGEON_FLOORS / CAVE_FLOORS. Dungeon / cave scenes that aren't
## listed are still picked up automatically from their folders (named after the file).

const TOGGLE_KEY: Key = KEY_QUOTELEFT
const ITEM_DIRS: Array[String] = [
	"res://Data/Items/Consumables/",
	"res://Data/Items/Equipment/",
	"res://Data/Items/Misc/",
	"res://Data/Items/Loot/",
]
const TIMES: Array[Array] = [["Dawn", 0.25], ["Noon", 0.5], ["Dusk", 0.75], ["Midnight", 0.0]]

const WORLD_MAPS: Array[Array] = [
	["Green Grove", "res://Scenes/GreenGrove.tscn"],
	["Fero Shaw", "res://Scenes/FeroShaw.tscn"],
	["Vero Wood", "res://Scenes/VeroWood.tscn"],
	["Gloom Reach", "res://Scenes/GloomReach.tscn"],
	["Broken Bone Marsh", "res://Scenes/BrokenBoneMarsh.tscn"],
	["Stone Trail", "res://Scenes/StoneTrail.tscn"],
]

const BATTLE_ARENA: String = "res://Scenes/Dungeons/BattleTestArena.tscn"
const DUNGEON_DIR: String = "res://Scenes/Dungeons/"
const DUNGEON_FLOORS: Array[Array] = [
	["Battle Test Arena", "res://Scenes/Dungeons/BattleTestArena.tscn"],
	["Fero Shaw Dungeon · Floor 1", "res://Scenes/Dungeons/FeroShawDungeon_Upper.tscn"],
	["Fero Shaw Dungeon · Floor 2 (boss)", "res://Scenes/Dungeons/FeroShawDungeon.tscn"],
	["Gloom Reach Dungeon · Floor 1", "res://Scenes/Dungeons/DungeonLevel1_Upper.tscn"],
	["Gloom Reach Dungeon · Floor 2 (boss)", "res://Scenes/Dungeons/DungeonLevel1.tscn"],
	["Dungeon Level 2", "res://Scenes/Dungeons/DungeonLevel2.tscn"],
	["Vero Wood Dungeon · Floor 1", "res://Scenes/Dungeons/VeroWoodDungeon_Upper.tscn"],
	["Vero Wood Dungeon · Floor 2 (boss)", "res://Scenes/Dungeons/VeroWoodDungeon.tscn"],
]

const CAVE_DIR: String = "res://Scenes/Caves/"
const CAVE_FLOORS: Array[Array] = [
	["Gloom Reach Cave · Floor 1", "res://Scenes/Caves/CaveLevel1.tscn"],
	["Gloom Reach Cave · Floor 2", "res://Scenes/Caves/CaveLevel2.tscn"],
	["Gloom Reach Cave · Floor 3", "res://Scenes/Caves/CaveLevel3.tscn"],
	["Broken Bone Marsh Cave", "res://Scenes/Caves/BrokenBoneMarshCave.tscn"],
	["Windmill Cellar · Floor 1", "res://Scenes/Caves/WindmillCave1.tscn"],
	["Windmill Cellar · Floor 2", "res://Scenes/Caves/WindmillCave2.tscn"],
]

const ALL_PARTY: int = 99

var _root: Control
var _status: Label
var _was_paused: bool = false
var _party_pick: OptionButton
var _open_level_screen: CheckBox
var _battle_box: VBoxContainer
var _open_tester_button: Button
var _item_pick: OptionButton
var _item_qty: SpinBox
var _mobile_toggle: CheckButton


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == TOGGLE_KEY:
		get_viewport().set_input_as_handled()
		toggle()
	elif key.keycode == KEY_ESCAPE and is_open():
		get_viewport().set_input_as_handled()
		close()


func is_open() -> bool:
	return is_instance_valid(_root) and _root.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh_party()
	var bt: Node = _battle_tester()
	_open_tester_button.visible = bt != null and bt.has_method(&"open_debug_panel")
	var hud: DungeonHUD = _hud()
	_mobile_toggle.disabled = hud == null or hud.mobile_hud == null
	_mobile_toggle.set_pressed_no_signal(hud != null and hud.mobile_hud != null and hud.mobile_hud.enabled)
	_set_status(_context_hint())
	_root.show()


func close() -> void:
	_root.hide()
	get_tree().paused = _was_paused


# ==============================================================================
# Jumps
# ==============================================================================
func _jump(scene_path: String, arrival: String) -> void:
	if scene_path == BATTLE_ARENA:
		_go_to_arena()
		return
	var problem: String = _jump_blocker()
	if not problem.is_empty():
		_set_status(problem, true)
		return
	MapTransition.clear_return_point()
	close()
	GameLogger.info("DebugMenu: jump to %s @ %s" % [scene_path, arrival])
	if not MapTransition.travel(get_tree(), scene_path, arrival):
		_set_status("Couldn't load %s" % scene_path, true)
		open()
		return
	SignalBus.show_toast.emit("DEBUG: %s · %s" % [scene_path.get_file().get_basename(), arrival], false)


## BATTLE TEST ARENA: remembers exactly where the party stands, goes to the arena (no autosave, so the
## save still points at where you were), and any exit in the arena brings the party back to that spot.
func _go_to_arena() -> void:
	var problem: String = _jump_blocker()
	if not problem.is_empty():
		_set_status(problem, true)
		return
	if MapTransition._current_map_path(get_tree()) == BATTLE_ARENA:
		_set_status("Already in the arena - use its stairs or exit to go back.", true)
		return
	var here: Dictionary = GameState.capture_location().duplicate()
	close()
	if not MapTransition._travel(get_tree(), BATTLE_ARENA, "SpawnPoint"):
		_set_status("Couldn't load %s" % BATTLE_ARENA, true)
		open()
		return
	MapTransition.set_return_point(BATTLE_ARENA, here)
	SignalBus.show_toast.emit("DEBUG: Battle Test Arena - leave by any exit to return to %s" % str(here.get("location_name", "where you were")), false)


func _jump_blocker() -> String:
	if get_tree().root.find_child("MapManager", true, false) == null:
		return "Start the game world first (jumps don't work from the main menu)."
	if SessionFlow.is_in_battle():
		return "Finish or end the battle first."
	return ""


func _context_hint() -> String:
	var blocker: String = _jump_blocker()
	if not blocker.is_empty():
		return blocker
	return "Now in: %s" % GameState.get_current_map_id()


## Spawn / arrival markers in a scene, read from the .tscn text (debug builds run from the project folder).
## "SpawnPoint" first when it exists.
static func markers_in(scene_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var f: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if f == null:
		return ["SpawnPoint"]
	var rx := RegEx.new()
	rx.compile("\\[node name=\"([^\"]+)\"")
	for m: RegExMatch in rx.search_all(f.get_as_text()):
		var n: String = m.get_string(1)
		if (n.begins_with("SpawnPoint") or n.ends_with("Arrival")) and not found.has(n):
			found.append(n)
	if found.has("SpawnPoint"):
		found.remove_at(found.find("SpawnPoint"))
		found.insert(0, "SpawnPoint")
	if found.is_empty():
		found.append("SpawnPoint")
	return found


## Listed entries + any other .tscn in `dir` (so new floors show up without editing this file).
static func with_unlisted(listed: Array[Array], dir: String) -> Array[Array]:
	var result: Array[Array] = listed.duplicate()
	var known: PackedStringArray = []
	for e: Array in listed:
		known.append(str(e[1]))
	for file: String in _scene_files(dir):
		var path: String = dir + file
		if not known.has(path):
			result.append([file.get_basename().capitalize(), path])
	var existing: Array[Array] = []
	for e: Array in result:
		if ResourceLoader.exists(str(e[1])):
			existing.append(e)
	return existing


static func _scene_files(dir: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for f: String in ResourceLoader.list_directory(dir):
		var clean: String = f.trim_suffix(".remap")
		if clean.ends_with(".tscn") and not names.has(clean):
			names.append(clean)
	names.sort()
	return names


# ==============================================================================
# Party
# ==============================================================================
func _refresh_party() -> void:
	_party_pick.clear()
	var slots: Array = _party_slots()
	for i: int in slots.size():
		var cat: CatCharacter = slots[i] as CatCharacter
		if cat != null:
			_party_pick.add_item("%s  ·  %s  ·  Lv %d" % [cat.name, AbilityRules.class_name_of(cat), cat.level], i)
	if _party_pick.item_count > 0:
		_party_pick.add_item("Whole party", ALL_PARTY)
	_party_pick.disabled = _party_pick.item_count == 0


func _party_slots() -> Array:
	if GameState.current_party == null:
		return []
	return GameState.current_party.slots


func _on_level_up_pressed() -> void:
	if _party_pick.item_count == 0:
		_set_status("No party loaded.", true)
		return
	var picked: int = _party_pick.get_selected_id()
	var slots: Array = _party_slots()
	var leveled: Array[CatCharacter] = []
	for i: int in slots.size():
		var cat: CatCharacter = slots[i] as CatCharacter
		if cat == null or (picked != ALL_PARTY and picked != i):
			continue
		if level_up_once(cat):
			leveled.append(cat)
			SignalBus.character_health_changed.emit(i, cat.current_hp)
			SignalBus.character_mana_changed.emit(i, cat.current_energy, cat.max_energy)
	if leveled.is_empty():
		_set_status("Already at max level.", true)
		return
	var names: PackedStringArray = []
	for cat: CatCharacter in leveled:
		names.append("%s → Lv %d" % [cat.name, cat.level])
	_set_status("Leveled up: " + ", ".join(names))
	var keep: int = _party_pick.selected
	_refresh_party()
	_party_pick.select(keep)
	if _open_level_screen.button_pressed and leveled.size() == 1:
		close()
		SignalBus.level_up_screen_requested.emit(leveled[0])


## One real level-up (the same path as earning the XP in battle): class auto gains, level points,
## a pending level-up dice roll, spellbook opening, full HP / MP. Returns false at max level.
static func level_up_once(cat: CatCharacter) -> bool:
	if cat.level >= cat.get_max_level():
		return false
	var needed: int = maxi(1, cat.get_required_xp_for_level(cat.level) - cat.current_xp)
	return cat.add_xp(needed)


# ==============================================================================
# Party tools
# ==============================================================================
func _heal_party() -> void:
	var slots: Array = _party_slots()
	var n: int = 0
	for i: int in slots.size():
		var cat: CatCharacter = slots[i] as CatCharacter
		if cat == null:
			continue
		cat._calculate_vitals()
		cat.current_hp = cat.max_hp
		cat.stats.health = cat.max_hp
		cat.current_energy = cat.max_energy
		SignalBus.character_health_changed.emit(i, cat.current_hp)
		SignalBus.character_mana_changed.emit(i, cat.current_energy, cat.max_energy)
		n += 1
	_set_status("Healed %d cats to full HP / MP." % n if n > 0 else "No party loaded.", n == 0)


func _give_item() -> void:
	if _item_pick.selected < 0 or GameState.inventory == null:
		_set_status("No item / pack.", true)
		return
	var item: ItemData = load(str(_item_pick.get_item_metadata(_item_pick.selected))) as ItemData
	var qty: int = int(_item_qty.value)
	if GameState.inventory.add_item(item, qty):
		_set_status("Gave %d x %s" % [qty, item.item_name])
	else:
		_set_status("Pack is full.", true)


func _set_time(t: float, label: String) -> void:
	GameState.world_time = t # the map's DayNightCycle follows it as soon as the game unpauses
	_set_status("Time set to %s." % label)


## Every ItemData .tres in ITEM_DIRS, sorted by file name.
static func all_item_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for dir: String in ITEM_DIRS:
		for f: String in AbilityLibrary.list_resource_files(dir):
			paths.append(dir + f)
	return paths


func _hud() -> DungeonHUD:
	return get_tree().root.find_child("HUD", true, false) as DungeonHUD


# ==============================================================================
# Battle tester (BattleTest.gd)
# ==============================================================================
func _battle_tester() -> Node:
	return get_tree().root.find_child("BattleTester", true, false)


## Calls `method` on the BattleTester node if it has it.
## BattleTest.gd can add an `open_debug_panel()` method; when it exists the menu shows an
## OPEN BATTLE TESTER button that calls it.
func _call_battle_tester(method: StringName) -> void:
	var bt: Node = _battle_tester()
	if bt == null or not bt.has_method(method):
		_set_status("BattleTester node / %s() not found (it lives in world.tscn)." % method, true)
		return
	close()
	bt.call(method)


## Stops the running battle like a retreat (no victory screen / rewards), so you're straight back to exploring.
func _end_battle() -> void:
	if not bool(CombatManager.get("is_combat_active")):
		_set_status("No battle running.", true)
		return
	close()
	SignalBus.combat_ended.emit(false)


# ==============================================================================
# UI
# ==============================================================================
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CreationUI.glass_panel(CreationUI.YELLOW))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = -16
	_root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title: Label = CreationUI.title("DEBUG", 22, CreationUI.YELLOW)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x: Button = CreationUI.small_button("CLOSE  [ ` ]", CreationUI.GREY)
	x.pressed.connect(close)
	head.add_child(x)
	_status = CreationUI.wrap(CreationUI.body("", 12, Color(CreationUI.WHITE, 0.6)))
	col.add_child(_status)

	_add_jump_section(col, "WORLD", WORLD_MAPS)
	_add_jump_section(col, "DUNGEONS", with_unlisted(DUNGEON_FLOORS, DUNGEON_DIR))
	_add_jump_section(col, "CAVES", with_unlisted(CAVE_FLOORS, CAVE_DIR))

	# Party
	col.add_child(_section_title("LEVEL UP"))
	_party_pick = _option()
	col.add_child(_party_pick)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_open_level_screen = CheckBox.new()
	_open_level_screen.text = "Open level-up screen"
	_open_level_screen.button_pressed = true
	_open_level_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_level_screen.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	_open_level_screen.add_theme_font_size_override("font_size", 12)
	row.add_child(_open_level_screen)
	var lvl: Button = CreationUI.small_button("LEVEL UP", CreationUI.GREEN)
	lvl.custom_minimum_size = Vector2(120, 32)
	lvl.pressed.connect(_on_level_up_pressed)
	row.add_child(lvl)

	# Party tools
	col.add_child(_section_title("PARTY"))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	col.add_child(tools)
	tools.add_child(_tool_button("HEAL + REVIVE", CreationUI.GREEN, _heal_party))
	tools.add_child(_tool_button("+1000 GOLD", CreationUI.YELLOW, func() -> void:
		GameState.add_gold(1000)
		_set_status("Gold: %d" % GameState.party_gold)))
	tools.add_child(_tool_button("SAVE NOW", CreationUI.GREY, func() -> void:
		var problem: String = _jump_blocker()
		if not problem.is_empty():
			_set_status(problem, true)
			return
		GameState.save_game()
		_set_status("Saved: %s" % GameState.get_current_map_id())))
	var give := HBoxContainer.new()
	give.add_theme_constant_override("separation", 6)
	col.add_child(give)
	_item_pick = _option()
	_item_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for path: String in all_item_paths():
		var item: ItemData = load(path) as ItemData
		if item != null:
			_item_pick.add_item(item.item_name)
			_item_pick.set_item_metadata(_item_pick.item_count - 1, path)
	give.add_child(_item_pick)
	_item_qty = SpinBox.new()
	_item_qty.min_value = 1
	_item_qty.max_value = 99
	_item_qty.value = 1
	_item_qty.custom_minimum_size = Vector2(70, 32)
	give.add_child(_item_qty)
	give.add_child(_tool_button("GIVE", CreationUI.GREEN, _give_item))
	var times := HBoxContainer.new()
	times.add_theme_constant_override("separation", 6)
	col.add_child(times)
	for t: Array in TIMES:
		times.add_child(_tool_button(str(t[0]).to_upper(), CreationUI.GREY, _set_time.bind(float(t[1]), str(t[0]))))

	# Display
	col.add_child(_section_title("DISPLAY"))
	_mobile_toggle = CheckButton.new()
	_mobile_toggle.text = "Mobile HUD (touch layout + D-pad)"
	_mobile_toggle.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	_mobile_toggle.add_theme_font_size_override("font_size", 12)
	_mobile_toggle.toggled.connect(func(on: bool) -> void:
		var hud: DungeonHUD = _hud()
		if hud == null or hud.mobile_hud == null:
			_set_status("Start the game world first.", true)
			return
		hud.mobile_hud.set_enabled(on)
		_set_status("Mobile HUD %s (mouse acts as a finger on the D-pad)." % ("on" if on else "off")))
	col.add_child(_mobile_toggle)

	# Battle (BattleTest.gd on the BattleTester node)
	col.add_child(_section_title("BATTLE"))
	_battle_box = VBoxContainer.new()
	_battle_box.add_theme_constant_override("separation", 6)
	col.add_child(_battle_box)
	var arena: Button = CreationUI.small_button("BATTLE TEST ARENA", CreationUI.PINK)
	arena.custom_minimum_size = Vector2(0, 38)
	arena.tooltip_text = "Go to the arena; any exit there brings you back to where you were."
	arena.pressed.connect(_go_to_arena)
	_battle_box.add_child(arena)
	_open_tester_button = CreationUI.small_button("OPEN BATTLE TESTER", CreationUI.PINK)
	_open_tester_button.pressed.connect(_call_battle_tester.bind(&"open_debug_panel"))
	_battle_box.add_child(_open_tester_button)
	var fights := HBoxContainer.new()
	fights.add_theme_constant_override("separation", 6)
	_battle_box.add_child(fights)
	fights.add_child(_tool_button("MIXED FIGHT", CreationUI.PINK, _call_battle_tester.bind(&"_toggle_combat_encounter")))
	fights.add_child(_tool_button("GHOST FIGHT", CreationUI.PINK, _call_battle_tester.bind(&"_trigger_ghost_encounter")))
	fights.add_child(_tool_button("END BATTLE", CreationUI.RED, _end_battle))
	_battle_box.add_child(_tool_button("NINE VOICE TEST", CreationUI.GREY, _call_battle_tester.bind(&"_test_nine_hud")))


func _tool_button(text: String, accent: Color, action: Callable) -> Button:
	var b: Button = CreationUI.small_button(text, accent)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(action)
	return b


func _add_jump_section(parent: VBoxContainer, heading: String, entries: Array[Array]) -> void:
	parent.add_child(_section_title(heading))
	var scene_pick: OptionButton = _option()
	for i: int in entries.size():
		scene_pick.add_item(str(entries[i][0]), i)
		scene_pick.set_item_metadata(i, str(entries[i][1]))
	parent.add_child(scene_pick)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var arrival_pick: OptionButton = _option()
	arrival_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(arrival_pick)
	var go: Button = CreationUI.small_button("JUMP", CreationUI.GREEN)
	go.custom_minimum_size = Vector2(90, 32)
	row.add_child(go)

	var fill_arrivals: Callable = func(idx: int) -> void:
		arrival_pick.clear()
		if idx < 0:
			return
		for marker: String in markers_in(str(scene_pick.get_item_metadata(idx))):
			arrival_pick.add_item(marker)
	scene_pick.item_selected.connect(fill_arrivals)
	if scene_pick.item_count > 0:
		fill_arrivals.call(0)
	go.pressed.connect(func() -> void:
		if scene_pick.selected < 0:
			return
		var arrival: String = arrival_pick.get_item_text(arrival_pick.selected) if arrival_pick.selected >= 0 else "SpawnPoint"
		_jump(str(scene_pick.get_item_metadata(scene_pick.selected)), arrival))


func _section_title(text: String) -> Label:
	var l: Label = CreationUI.title(text, 14, Color(CreationUI.WHITE, 0.55))
	return l


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0, 32)
	o.add_theme_font_override("font", ShardsMenuStyle.BODY_FONT)
	o.add_theme_font_size_override("font_size", 13)
	o.fit_to_longest_item = false
	return o


func _set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", CreationUI.RED if is_error else Color(CreationUI.WHITE, 0.6))
