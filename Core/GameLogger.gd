# res://Core/GameLogger.gd
extends Node

## Universal Logging System for Claws of the Undying
## Handles categorized, color-coded logging with a single master toggle switch.

# ==============================================================================
# 1. MASTER TOGGLES & CONFIGURATION
# ==============================================================================
## Master switch to turn ALL console logging on or off globally.
@export var is_logging_enabled: bool = true

## Category-specific toggles for granular control
@export var log_combat_events: bool = true
@export var log_movement_events: bool = true
@export var log_ui_events: bool = false
@export var log_system_events: bool = true

## Channel Category Enums
enum Channel { SYSTEM, COMBAT, NAVIGATION, UI, WARNING, ERROR }

# ==============================================================================
# 2. LOGGING PUBLIC API
# ==============================================================================

## Log combat actions (e.g., attacks, damage, turns, status effects)
func combat(message: String) -> void:
	if not is_logging_enabled or not log_combat_events:
		return
	_dispatch_log("⚔️ [COMBAT]", message, "cyan")

## Log player/party movement and dungeon exploration
func nav(message: String) -> void:
	if not is_logging_enabled or not log_movement_events:
		return
	_dispatch_log("🧭 [NAV]", message, "green")

## Log UI interactions, popups, and button pushes
func ui(message: String) -> void:
	if not is_logging_enabled or not log_ui_events:
		return
	_dispatch_log("🖥️ [UI]", message, "magenta")

## Log general system events (init, battle start, scene transitions)
func info(message: String) -> void:
	if not is_logging_enabled or not log_system_events:
		return
	_dispatch_log("⚙️ [SYSTEM]", message, "gray")

## Log non-fatal warnings
func warn(message: String) -> void:
	if not is_logging_enabled:
		return
	_dispatch_log("⚠️ [WARN]", message, "yellow")

## Log critical system errors
func error(message: String) -> void:
	_dispatch_log("💥 [ERROR]", message, "red")

# ==============================================================================
# 3. INTERNAL DISPATCH & SIGNAL ROUTING
# ==============================================================================

func _dispatch_log(prefix: String, message: String, color_name: String) -> void:
	var formatted_time: String = Time.get_time_string_from_system()
	var full_text: String = "[%s] %s %s" % [formatted_time, prefix, message]

	# 1. Console Rich Output (Colorized in Godot Editor Output Dock)
	print_rich("[color=%s]%s[/color]" % [color_name, full_text])

	# 2. Route to SignalBus for In-Game Combat Log UI windows
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("log_message_emitted"):
		sb.emit_signal("log_message_emitted", full_text, color_name)
