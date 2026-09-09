extends Node

## Runtime input bootstrap.
## We intentionally rebuild these actions every launch so stale Godot
## InputMap bindings cannot survive between project revisions.

func _ready() -> void:
    _set_action("move_forward", [KEY_W, KEY_UP])
    _set_action("move_back", [KEY_S, KEY_DOWN])
    _set_action("move_left", [KEY_A, KEY_LEFT])
    _set_action("move_right", [KEY_D, KEY_RIGHT])
    _set_action("jump", [KEY_SPACE])
    _set_action("sprint", [KEY_SHIFT])
    _set_action("flight_boost", [KEY_SHIFT])
    _set_action("flight_down", [KEY_CTRL])
    _set_action("super_jump", [KEY_R])
    _set_action("toggle_camera", [KEY_V])
    _set_action("attack", [MOUSE_BUTTON_LEFT])
    _set_action("block", [MOUSE_BUTTON_RIGHT])
    _set_action("dodge", [KEY_Q])
    _set_action("ability_flight", [KEY_F])
    _set_action("ability_teleport", [KEY_T])
    _set_action("ability_size_down", [KEY_Z])
    _set_action("ability_size_up", [KEY_X])
    _set_action("portal_use", [KEY_E])
    _set_action("energy_blast", [KEY_C])
    _set_action("ground_slam", [KEY_G])

func _set_action(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    else:
        InputMap.action_erase_events(action)

    for key in keys:
        var ev: InputEvent
        if key >= MOUSE_BUTTON_LEFT and key <= MOUSE_BUTTON_XBUTTON2:
            var mouse := InputEventMouseButton.new()
            mouse.button_index = key
            ev = mouse
        else:
            var keyboard := InputEventKey.new()
            keyboard.physical_keycode = key
            ev = keyboard
        InputMap.action_add_event(action, ev)
