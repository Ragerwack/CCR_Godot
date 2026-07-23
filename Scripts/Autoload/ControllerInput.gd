extends Node

signal controller_action_pressed(action_id: String)
signal bindings_changed()

const CONFIG_SECTION := "controller_input"
const CONFIG_BINDINGS_KEY := "bindings"
const CURSOR_TEXTURE_PATH := "res://Resources/UI/player_cursor.png"
const CURSOR_IMAGE_PATH := "res://Resources/UI/player_cursor_image.res"
const AXIS_PRESS_THRESHOLD := 0.55
const FOCUS_MOVE_THRESHOLD := 0.55
const FOCUS_MOVE_REPEAT_SECONDS := 0.18

const ACTION_DRAW_FREE := "ccr_draw_free"
const ACTION_DRAW_GEM := "ccr_draw_gem"
const ACTION_DRAW_GOLD := "ccr_draw_gold"
const ACTION_SYNTHESIZE := "ccr_action_synthesize"
const ACTION_STORE_VAULT := "ccr_action_store_vault"
const ACTION_DISCARD := "ccr_action_discard"
const ACTION_NAV_PREV := "ccr_nav_prev"
const ACTION_NAV_NEXT := "ccr_nav_next"
const ACTION_HAND_PAGE := "ccr_hand_page"
const ACTION_POINTER_PRIMARY := "ccr_pointer_primary"
const ACTION_POINTER_SECONDARY := "ccr_pointer_secondary"

const CUSTOM_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_IBEAM,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_CROSS,
	Input.CURSOR_WAIT,
	Input.CURSOR_BUSY,
	Input.CURSOR_DRAG,
	Input.CURSOR_CAN_DROP,
	Input.CURSOR_FORBIDDEN,
	Input.CURSOR_VSIZE,
	Input.CURSOR_HSIZE,
	Input.CURSOR_BDIAGSIZE,
	Input.CURSOR_FDIAGSIZE,
	Input.CURSOR_MOVE,
	Input.CURSOR_VSPLIT,
	Input.CURSOR_HSPLIT,
	Input.CURSOR_HELP,
]

const ACTION_ORDER := [
	ACTION_POINTER_PRIMARY,
	ACTION_POINTER_SECONDARY,
	ACTION_NAV_PREV,
	ACTION_NAV_NEXT,
	ACTION_HAND_PAGE,
	ACTION_DRAW_FREE,
	ACTION_SYNTHESIZE,
	ACTION_STORE_VAULT,
	ACTION_DISCARD,
	ACTION_DRAW_GEM,
	ACTION_DRAW_GOLD,
]

const ACTION_LABEL_KEYS := {
	ACTION_POINTER_PRIMARY: "ui.controller.action.pointer_primary",
	ACTION_POINTER_SECONDARY: "ui.controller.action.pointer_secondary",
	ACTION_NAV_PREV: "ui.controller.action.nav_prev",
	ACTION_NAV_NEXT: "ui.controller.action.nav_next",
	ACTION_HAND_PAGE: "ui.controller.action.hand_page",
	ACTION_DRAW_FREE: "ui.controller.action.draw_free",
	ACTION_SYNTHESIZE: "ui.controller.action.synthesize",
	ACTION_STORE_VAULT: "ui.controller.action.store_vault",
	ACTION_DISCARD: "ui.controller.action.discard",
	ACTION_DRAW_GEM: "ui.controller.action.draw_gem",
	ACTION_DRAW_GOLD: "ui.controller.action.draw_gold",
}

const DEFAULT_BINDINGS := {
	ACTION_POINTER_PRIMARY: "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT,
	ACTION_POINTER_SECONDARY: "button:%d" % JOY_BUTTON_RIGHT_SHOULDER,
	ACTION_NAV_PREV: "button:%d" % JOY_BUTTON_LEFT_SHOULDER,
	ACTION_NAV_NEXT: "button:%d" % JOY_BUTTON_RIGHT_SHOULDER,
	# 手牌翻页不区分上下方向，右摇杆上下任一方向都会翻到下一页。
	ACTION_HAND_PAGE: "axis_any:%d" % JOY_AXIS_RIGHT_Y,
	ACTION_DRAW_FREE: "button:%d" % JOY_BUTTON_A,
	ACTION_SYNTHESIZE: "button:%d" % JOY_BUTTON_X,
	ACTION_STORE_VAULT: "button:%d" % JOY_BUTTON_Y,
	ACTION_DISCARD: "button:%d" % JOY_BUTTON_B,
	ACTION_DRAW_GEM: "button:%d" % JOY_BUTTON_DPAD_UP,
	ACTION_DRAW_GOLD: "button:%d" % JOY_BUTTON_DPAD_DOWN,
}

const BINDING_OPTIONS := [
	{"id": "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT, "label_key": "ui.controller.binding.r2"},
	{"id": "axis:%d:1" % JOY_AXIS_TRIGGER_LEFT, "label_key": "ui.controller.binding.l2"},
	{"id": "button:%d" % JOY_BUTTON_RIGHT_SHOULDER, "label_key": "ui.controller.binding.r1"},
	{"id": "button:%d" % JOY_BUTTON_LEFT_SHOULDER, "label_key": "ui.controller.binding.l1"},
	{"id": "button:%d" % JOY_BUTTON_A, "label_key": "ui.controller.binding.a"},
	{"id": "button:%d" % JOY_BUTTON_B, "label_key": "ui.controller.binding.b"},
	{"id": "button:%d" % JOY_BUTTON_X, "label_key": "ui.controller.binding.x"},
	{"id": "button:%d" % JOY_BUTTON_Y, "label_key": "ui.controller.binding.y"},
	{"id": "button:%d" % JOY_BUTTON_DPAD_UP, "label_key": "ui.controller.binding.dpad_up"},
	{"id": "button:%d" % JOY_BUTTON_DPAD_DOWN, "label_key": "ui.controller.binding.dpad_down"},
	{"id": "button:%d" % JOY_BUTTON_DPAD_LEFT, "label_key": "ui.controller.binding.dpad_left"},
	{"id": "button:%d" % JOY_BUTTON_DPAD_RIGHT, "label_key": "ui.controller.binding.dpad_right"},
	{"id": "button:%d" % JOY_BUTTON_LEFT_STICK, "label_key": "ui.controller.binding.left_stick"},
	{"id": "button:%d" % JOY_BUTTON_RIGHT_STICK, "label_key": "ui.controller.binding.right_stick"},
	{"id": "axis_any:%d" % JOY_AXIS_RIGHT_Y, "label_key": "ui.controller.binding.right_stick_vertical"},
]

var _bindings: Dictionary = {}
var _cursor_hidden_by_controller: bool = false
var _focus_move_cooldown: float = 0.0
var _last_focus_direction: Vector2 = Vector2.ZERO
var _primary_mouse_down: bool = false
var _secondary_mouse_down: bool = false

func _ready() -> void:
	_apply_custom_cursor()
	_load_bindings()
	_apply_input_map()
	set_process(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_show_cursor()
		return
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if button_event.pressed:
			_hide_cursor_for_controller()
		return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= AXIS_PRESS_THRESHOLD:
			_hide_cursor_for_controller()

func _process(delta: float) -> void:
	_focus_move_cooldown = maxf(0.0, _focus_move_cooldown - delta)
	_handle_left_stick_focus()
	_handle_pointer_action(ACTION_POINTER_PRIMARY, MOUSE_BUTTON_LEFT)
	_handle_pointer_action(ACTION_POINTER_SECONDARY, MOUSE_BUTTON_RIGHT)
	for action_id in ACTION_ORDER:
		if action_id == ACTION_POINTER_PRIMARY or action_id == ACTION_POINTER_SECONDARY:
			continue
		if Input.is_action_just_pressed(action_id):
			controller_action_pressed.emit(action_id)

func get_action_ids() -> Array:
	return ACTION_ORDER.duplicate()

func get_action_label_key(action_id: String) -> String:
	return str(ACTION_LABEL_KEYS.get(action_id, action_id))

func get_binding(action_id: String) -> String:
	return str(_bindings.get(action_id, DEFAULT_BINDINGS.get(action_id, "")))

func get_binding_options() -> Array:
	return BINDING_OPTIONS.duplicate(true)

func get_binding_label(binding_id: String) -> String:
	for option in BINDING_OPTIONS:
		if str(option.get("id", "")) == binding_id:
			return Localization.t(str(option.get("label_key", "")))
	return binding_id

func set_binding(action_id: String, binding_id: String) -> void:
	if action_id not in ACTION_ORDER:
		return
	if not _is_known_binding(binding_id):
		return
	_bindings[action_id] = binding_id
	Config.set_value(CONFIG_SECTION, CONFIG_BINDINGS_KEY, _bindings)
	_apply_input_map()
	bindings_changed.emit()

func reset_bindings() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate()
	Config.set_value(CONFIG_SECTION, CONFIG_BINDINGS_KEY, _bindings)
	_apply_input_map()
	bindings_changed.emit()

func activate_focused_control() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return _activate_control(focus_owner)

func focus_first_available() -> void:
	var candidates := _collect_focus_candidates()
	if candidates.is_empty():
		return
	var first := candidates[0] as Control
	first.grab_focus()

func _apply_custom_cursor() -> void:
	var cursor_texture := _load_cursor_texture()
	if cursor_texture != null:
		for cursor_shape in CUSTOM_CURSOR_SHAPES:
			Input.set_custom_mouse_cursor(cursor_texture, cursor_shape, Vector2.ZERO)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _load_cursor_texture() -> Texture2D:
	var image := load(CURSOR_IMAGE_PATH) as Image
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	var imported_texture := load(CURSOR_TEXTURE_PATH)
	return imported_texture as Texture2D

func _load_bindings() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate()
	var saved = Config.get_value(CONFIG_SECTION, CONFIG_BINDINGS_KEY, {})
	if saved is Dictionary:
		for action_id in ACTION_ORDER:
			var binding_id := str(saved.get(action_id, ""))
			if _is_known_binding(binding_id):
				_bindings[action_id] = binding_id

func _apply_input_map() -> void:
	for action_id in ACTION_ORDER:
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id, 0.5)
		InputMap.action_erase_events(action_id)
		for event in _binding_to_events(get_binding(action_id)):
			InputMap.action_add_event(action_id, event)

func _binding_to_events(binding_id: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var parts := binding_id.split(":", false)
	if parts.size() < 2:
		return events
	match parts[0]:
		"button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(parts[1])
			events.append(event)
		"axis":
			if parts.size() < 3:
				return events
			var event := InputEventJoypadMotion.new()
			event.axis = int(parts[1])
			event.axis_value = float(parts[2])
			events.append(event)
		"axis_any":
			# Godot 的 axis_value 带方向；同一动作注册正反两个事件即可响应摇杆上下。
			for direction in [-1.0, 1.0]:
				var event := InputEventJoypadMotion.new()
				event.axis = int(parts[1])
				event.axis_value = direction
				events.append(event)
	return events

func _is_known_binding(binding_id: String) -> bool:
	for option in BINDING_OPTIONS:
		if str(option.get("id", "")) == binding_id:
			return true
	return false

func _show_cursor() -> void:
	if _cursor_hidden_by_controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_cursor_hidden_by_controller = false

func _hide_cursor_for_controller() -> void:
	if not _cursor_hidden_by_controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_cursor_hidden_by_controller = true

func _handle_pointer_action(action_id: String, mouse_button: MouseButton) -> void:
	if Input.is_action_just_pressed(action_id):
		if _cursor_hidden_by_controller:
			if mouse_button == MOUSE_BUTTON_LEFT:
				activate_focused_control()
			return
		_emit_mouse_button(mouse_button, true)
		if mouse_button == MOUSE_BUTTON_LEFT:
			_primary_mouse_down = true
		else:
			_secondary_mouse_down = true
	if Input.is_action_just_released(action_id):
		if mouse_button == MOUSE_BUTTON_LEFT and not _primary_mouse_down:
			return
		if mouse_button == MOUSE_BUTTON_RIGHT and not _secondary_mouse_down:
			return
		_emit_mouse_button(mouse_button, false)
		if mouse_button == MOUSE_BUTTON_LEFT:
			_primary_mouse_down = false
		else:
			_secondary_mouse_down = false

func _emit_mouse_button(mouse_button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = mouse_button
	event.pressed = pressed
	event.position = get_viewport().get_mouse_position()
	event.global_position = event.position
	Input.parse_input_event(event)

func _handle_left_stick_focus() -> void:
	var axis := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if axis.length() < FOCUS_MOVE_THRESHOLD:
		_last_focus_direction = Vector2.ZERO
		return
	var direction := Vector2.ZERO
	if absf(axis.x) > absf(axis.y):
		direction.x = signf(axis.x)
	else:
		direction.y = signf(axis.y)
	if direction == Vector2.ZERO:
		return
	if _focus_move_cooldown > 0.0 and direction == _last_focus_direction:
		return
	_move_focus(direction)
	_last_focus_direction = direction
	_focus_move_cooldown = FOCUS_MOVE_REPEAT_SECONDS

func _move_focus(direction: Vector2) -> void:
	var candidates := _collect_focus_candidates()
	if candidates.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner() as Control
	if current == null or not candidates.has(current):
		(candidates[0] as Control).grab_focus()
		return
	var current_center := current.get_global_rect().get_center()
	var best: Control = null
	var best_score := INF
	for candidate in candidates:
		var control := candidate as Control
		if control == current:
			continue
		var delta := control.get_global_rect().get_center() - current_center
		var forward := delta.dot(direction)
		if forward <= 1.0:
			continue
		var perpendicular := absf(delta.cross(direction))
		var score := forward + perpendicular * 2.2
		if score < best_score:
			best_score = score
			best = control
	if best == null:
		best = _next_linear_candidate(candidates, current, direction)
	if best != null:
		best.grab_focus()

func _next_linear_candidate(candidates: Array, current: Control, direction: Vector2) -> Control:
	var index := candidates.find(current)
	if index < 0:
		return candidates[0] as Control
	var step := 1 if direction.x >= 0.0 or direction.y >= 0.0 else -1
	var next_index := wrapi(index + step, 0, candidates.size())
	return candidates[next_index] as Control

func _collect_focus_candidates() -> Array:
	var result: Array = []
	_collect_focus_candidates_recursive(get_tree().root, result)
	result.sort_custom(func(a, b):
		var ar := (a as Control).get_global_rect()
		var br := (b as Control).get_global_rect()
		if absf(ar.position.y - br.position.y) > 8.0:
			return ar.position.y < br.position.y
		return ar.position.x < br.position.x
	)
	return result

func _collect_focus_candidates_recursive(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if _is_focus_candidate(control):
				result.append(control)
		_collect_focus_candidates_recursive(child, result)

func _is_focus_candidate(control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	if control.get_global_rect().size.x <= 4.0 or control.get_global_rect().size.y <= 4.0:
		return false
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is OptionButton or control is HSlider:
		return true
	if control is CardSlotUI:
		return (control as CardSlotUI).is_controller_focusable()
	return false

func _activate_control(control: Control) -> bool:
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control is CardSlotUI:
		(control as CardSlotUI).controller_activate()
		return true
	if control is BaseButton:
		var button := control as BaseButton
		if button.disabled:
			return false
		button.emit_signal("pressed")
		return true
	if control is OptionButton:
		(control as OptionButton).show_popup()
		return true
	return false
