extends GutTest

func test_required_actions_exist() -> void:
    var required_actions: Array[StringName] = [
        &"move_forward",
        &"move_back",
        &"move_left",
        &"move_right",
        &"turn_left",
        &"turn_right",
        &"combat_attack",
        &"combat_defend",
        &"combat_use_item",
    ]

    for action in required_actions:
        assert_true(InputMap.has_action(action), "Missing InputMap action: %s" % [action])

func test_required_actions_have_at_least_one_binding() -> void:
    var required_actions: Array[StringName] = [
        &"move_forward",
        &"move_back",
        &"move_left",
        &"move_right",
        &"turn_left",
        &"turn_right",
        &"combat_attack",
        &"combat_defend",
        &"combat_use_item",
    ]

    for action in required_actions:
        var events := InputMap.action_get_events(action)
        assert_gt(events.size(), 0, "Action has no bindings: %s" % [action])
