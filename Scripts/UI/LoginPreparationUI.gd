extends Control
class_name LoginPreparationUI

signal retry_requested()
signal back_requested()

const STATUS_PENDING := "pending"
const STATUS_RUNNING := "running"
const STATUS_SUCCESS := "success"
const STATUS_FAILED := "failed"

var _panel: Panel = null
var _title_label: Label = null
var _current_label: Label = null
var _steps_box: VBoxContainer = null
var _hint_label: Label = null
var _retry_button: Button = null
var _back_button: Button = null
var _rows: Dictionary = {}
var _step_labels: Dictionary = {}
var _setup_done: bool = false

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	if _setup_done:
		return
	_setup_done = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = Panel.new()
	_panel.size = Vector2(520, 500)
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(28, 24)
	vbox.size = Vector2(464, 452)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = Localization.t("ui.login.prepare.title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)

	_current_label = Label.new()
	_current_label.text = Localization.t("ui.login.prepare.waiting")
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 1.0))
	vbox.add_child(_current_label)

	_steps_box = VBoxContainer.new()
	_steps_box.custom_minimum_size = Vector2(0, 300)
	_steps_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_steps_box)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55, 1.0))
	_hint_label.visible = false
	vbox.add_child(_hint_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	_retry_button = Button.new()
	_retry_button.text = Localization.t("ui.login.prepare.retry")
	_retry_button.visible = false
	_retry_button.pressed.connect(func(): retry_requested.emit())
	buttons.add_child(_retry_button)

	_back_button = Button.new()
	_back_button.text = Localization.t("ui.login.prepare.back")
	_back_button.visible = false
	_back_button.pressed.connect(func(): back_requested.emit())
	buttons.add_child(_back_button)

func set_steps(steps: Array[Dictionary]) -> void:
	if _steps_box == null:
		_setup_ui()
	_rows.clear()
	_step_labels.clear()
	for child in _steps_box.get_children():
		_steps_box.remove_child(child)
		child.queue_free()

	for step in steps:
		var id := str(step.get("id", ""))
		var label := str(step.get("label", id))
		_step_labels[id] = label

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 30)
		row.add_theme_constant_override("separation", 10)

		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(64, 0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(status_label)

		var name_label := Label.new()
		name_label.text = label
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var time_label := Label.new()
		time_label.custom_minimum_size = Vector2(88, 0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)

		_steps_box.add_child(row)
		_rows[id] = {
			"status": status_label,
			"name": name_label,
			"time": time_label,
		}
		set_step(id, STATUS_PENDING)

	_hint_label.visible = false
	_retry_button.visible = false
	_back_button.visible = false
	set_current(Localization.t("ui.login.prepare.waiting"))

func set_current(text: String) -> void:
	if _current_label != null:
		_current_label.text = text

func set_step(id: String, status: String, elapsed_ms: int = -1, detail: String = "") -> void:
	if not _rows.has(id):
		return
	var row: Dictionary = _rows[id]
	var status_label := row["status"] as Label
	var name_label := row["name"] as Label
	var time_label := row["time"] as Label

	status_label.text = _status_text(status)
	status_label.add_theme_color_override("font_color", _status_color(status))
	name_label.add_theme_color_override("font_color", _status_color(status))

	var base_label := str(_step_labels.get(id, id))
	name_label.text = base_label if detail == "" else base_label + " - " + detail
	time_label.text = "" if elapsed_ms < 0 else str(elapsed_ms) + " ms"

func show_failure(message: String) -> void:
	_hint_label.text = message
	_hint_label.visible = true
	_retry_button.visible = true
	_back_button.visible = true
	set_current(Localization.t("ui.login.prepare.failed"))

func show_success() -> void:
	_hint_label.visible = false
	_retry_button.visible = false
	_back_button.visible = false
	set_current(Localization.t("ui.login.prepare.done"))

func _status_text(status: String) -> String:
	match status:
		STATUS_RUNNING:
			return Localization.t("ui.login.prepare.status.running")
		STATUS_SUCCESS:
			return Localization.t("ui.login.prepare.status.success")
		STATUS_FAILED:
			return Localization.t("ui.login.prepare.status.failed")
	return Localization.t("ui.login.prepare.status.pending")

func _status_color(status: String) -> Color:
	match status:
		STATUS_RUNNING:
			return Color(0.45, 0.75, 1.0, 1.0)
		STATUS_SUCCESS:
			return Color(0.45, 0.95, 0.55, 1.0)
		STATUS_FAILED:
			return Color(1.0, 0.38, 0.32, 1.0)
	return Color(0.75, 0.75, 0.78, 1.0)
