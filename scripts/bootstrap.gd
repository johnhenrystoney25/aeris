extends Node

func _ready() -> void:
    _ensure_action("move_forward", [KEY_W, KEY_UP])
    _ensure_action("move_back", [KEY_S, KEY_DOWN])
    _ensure_action("move_left", [KEY_A, KEY_LEFT])
    _ensure_action("move_right", [KEY_D, KEY_RIGHT])
    _ensure_action("jump", [KEY_SPACE])
    _ensure_action("sprint", [KEY_SHIFT])
    _ensure_action("flight_boost", [KEY_SHIFT])
    _ensure_action("flight_down", [KEY_CTRL])
    _ensure_action("super_jump", [KEY_R])
    _ensure_action("toggle_camera", [KEY_V])
    _ensure_action("attack", [MOUSE_BUTTON_LEFT])
    _ensure_action("block", [MOUSE_BUTTON_RIGHT])
    _ensure_action("dodge", [KEY_Q])
    _ensure_action("ability_flight", [KEY_F])
    _ensure_action("ability_teleport", [KEY_T])
    _ensure_action("ability_size_down", [KEY_Z])
    _ensure_action("ability_size_up", [KEY_X])
    _ensure_action("portal_use", [KEY_E])
    _ensure_action("energy_blast", [KEY_C])
    _ensure_action("ground_slam", [KEY_G])

func _ensure_action(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
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
        var exists := false
        for existing in InputMap.action_get_events(action):
            if existing.as_text() == ev.as_text():
                exists = true
                break
        if not exists:
            InputMap.action_add_event(action, ev)
