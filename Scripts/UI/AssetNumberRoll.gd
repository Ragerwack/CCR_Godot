extends Control
class_name AssetNumberRoll

## 资产数字变化时使用的按位纵向滚动组件。
## 只有数值实际变化的数字列滚动；未变化数字和分隔符保持静止。

const ROLL_DURATION: float = 1.0
const FADED_ALPHA: float = 0.18
const TEXT_HORIZONTAL_PADDING: float = 6.0
const TEXT_VERTICAL_PADDING: float = 2.0
const CLIP_HORIZONTAL_BLEED: float = 2.0
const FONT_COLOR: Color = Color.BLACK

var _clip_host: Control
var _digits_row: HBoxContainer
var _roll_tween: Tween
var _display_text: String = ""
var _primary_value: int = 0
var _secondary_value: int = 0
var _has_value: bool = false
var _label_base_name: String = "AssetLabel"
var _font_size: int = 18
var _active_outgoing_labels: Array[Label] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

	# Godot 的 clip_contents 会同时裁剪横纵两个方向。滚动动画需要纵向裁剪，
	# 但横向边界必须略微外扩，否则字体的末位抗锯齿像素仍可能被切掉。
	_clip_host = Control.new()
	_clip_host.name = "NumberRollClipHost"
	_clip_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip_host.offset_left = -CLIP_HORIZONTAL_BLEED
	_clip_host.offset_right = CLIP_HORIZONTAL_BLEED
	_clip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_host.clip_contents = true
	add_child(_clip_host)

	_digits_row = HBoxContainer.new()
	_digits_row.name = "NumberRollDigitsRow"
	_digits_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_digits_row.offset_left = TEXT_HORIZONTAL_PADDING
	_digits_row.offset_right = -TEXT_HORIZONTAL_PADDING
	_digits_row.offset_top = TEXT_VERTICAL_PADDING
	_digits_row.offset_bottom = -TEXT_VERTICAL_PADDING
	_digits_row.alignment = BoxContainer.ALIGNMENT_END
	_digits_row.add_theme_constant_override("separation", 0)
	_digits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_host.add_child(_digits_row)

func configure(label_name: String, font_size: int) -> void:
	_label_base_name = label_name
	_font_size = font_size
	_rebuild_digits(_display_text, "", 0, false)

func get_current_digit_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for cell in _digits_row.get_children():
		var label := _find_digit_label(cell, "current")
		if label != null:
			labels.append(label)
	return labels

func get_display_text() -> String:
	return _display_text

func get_outgoing_digit_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for cell in _digits_row.get_children():
		var label := _find_digit_label(cell, "outgoing")
		if label != null:
			labels.append(label)
	return labels

func get_visible_outgoing_digit_count() -> int:
	var count := 0
	for label in get_outgoing_digit_labels():
		if label.visible:
			count += 1
	return count

func get_moving_current_digit_count() -> int:
	var count := 0
	for label in get_current_digit_labels():
		if absf(label.position.y) > 0.01:
			count += 1
	return count

func set_display(
		text: String,
		primary_value: int,
		secondary_value: int = 0,
		animate: bool = true
	) -> void:
	if not _has_value:
		_set_immediate(text, primary_value, secondary_value)
		return
	if text == _display_text:
		_primary_value = primary_value
		_secondary_value = secondary_value
		return

	var direction := _compare_values(primary_value, secondary_value)
	if not animate or direction == 0:
		_set_immediate(text, primary_value, secondary_value)
		return

	_stop_roll()
	var previous_text := _display_text
	_display_text = text
	_primary_value = primary_value
	_secondary_value = secondary_value

	_rebuild_digits(text, previous_text, direction, true)
	_start_roll(direction)

func _compare_values(primary_value: int, secondary_value: int) -> int:
	if primary_value != _primary_value:
		return 1 if primary_value > _primary_value else -1
	if secondary_value != _secondary_value:
		return 1 if secondary_value > _secondary_value else -1
	return 0

func _set_immediate(text: String, primary_value: int, secondary_value: int) -> void:
	_stop_roll()
	_display_text = text
	_primary_value = primary_value
	_secondary_value = secondary_value
	_has_value = true
	_rebuild_digits(text, "", 0, false)

func _stop_roll() -> void:
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = null
	for label in _active_outgoing_labels:
		if is_instance_valid(label):
			label.hide()
	_active_outgoing_labels.clear()
	_reset_visible_digit_labels()

func _reset_visible_digit_labels() -> void:
	if _digits_row == null:
		return
	for cell in _digits_row.get_children():
		if cell is Control:
			for child in cell.get_children():
				if child is Label:
					child.position.y = 0.0
					child.modulate.a = 1.0

func _rebuild_digits(new_text: String, old_text: String, direction: int, animate: bool) -> void:
	for child in _digits_row.get_children():
		_digits_row.remove_child(child)
		child.queue_free()
	_active_outgoing_labels.clear()

	var aligned_chars := _align_display_chars(new_text, old_text)
	var old_chars: Array[String] = aligned_chars[0]
	var new_chars: Array[String] = aligned_chars[1]
	var cell_count := maxi(old_chars.size(), new_chars.size())
	var max_cell_height := 0.0
	var total_width := 0.0
	var first_current_label: Label = null
	var first_outgoing_label: Label = null

	for index in range(cell_count):
		var old_char := old_chars[index] if index < old_chars.size() else ""
		var new_char := new_chars[index] if index < new_chars.size() else ""
		var should_roll := animate and old_char != "" and new_char != "" and old_char != new_char and _is_digit(old_char) and _is_digit(new_char)
		var cell := _make_digit_cell(index, new_char, old_char, should_roll)
		_digits_row.add_child(cell)
		_update_digit_cell_size(cell)

		var current_label := _find_digit_label(cell, "current")
		var outgoing_label := _find_digit_label(cell, "outgoing")
		if first_current_label == null and current_label != null:
			first_current_label = current_label
		if first_outgoing_label == null and outgoing_label != null:
			first_outgoing_label = outgoing_label

		total_width += cell.custom_minimum_size.x
		max_cell_height = maxf(max_cell_height, cell.custom_minimum_size.y)

		if should_roll and current_label != null and outgoing_label != null:
			current_label.position.y = max_cell_height * float(direction)
			current_label.modulate.a = FADED_ALPHA
			outgoing_label.position.y = 0.0
			outgoing_label.modulate.a = 1.0
			outgoing_label.show()
			_active_outgoing_labels.append(outgoing_label)

	if first_current_label != null:
		first_current_label.name = _label_base_name
	if first_outgoing_label != null:
		first_outgoing_label.name = _label_base_name.trim_suffix("Label") + "OutgoingLabel"

	custom_minimum_size = Vector2(
		ceilf(total_width + TEXT_HORIZONTAL_PADDING * 2.0),
		ceilf(max_cell_height + TEXT_VERTICAL_PADDING * 2.0)
	)

func _make_digit_cell(index: int, new_char: String, old_char: String, should_roll: bool) -> Control:
	var cell := Control.new()
	cell.name = "DigitCell%d" % index
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.clip_contents = should_roll

	var current_label := _make_digit_label("CurrentDigit", new_char)
	var outgoing_label := _make_digit_label("OutgoingDigit", old_char)
	outgoing_label.hide()
	cell.add_child(outgoing_label)
	cell.add_child(current_label)

	current_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	outgoing_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	return cell

func _update_digit_cell_size(cell: Control) -> void:
	var current_label := _find_digit_label(cell, "current")
	var outgoing_label := _find_digit_label(cell, "outgoing")
	var width := maxf(
		_measure_label_width(current_label) if current_label != null else 0.0,
		_measure_label_width(outgoing_label) if outgoing_label != null else 0.0
	)
	var height := maxf(
		_measure_label_height(current_label) if current_label != null else 0.0,
		_measure_label_height(outgoing_label) if outgoing_label != null else 0.0
	)
	cell.custom_minimum_size = Vector2(ceilf(width), ceilf(height))
	cell.size = cell.custom_minimum_size

func _make_digit_label(label_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.set_meta("asset_digit_role", "outgoing" if label_name == "OutgoingDigit" else "current")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _font_size)
	label.add_theme_color_override("font_color", FONT_COLOR)
	return label

func _measure_label_width(label: Label) -> float:
	return label.get_combined_minimum_size().x if label.text != "" else 0.0

func _measure_label_height(label: Label) -> float:
	if label.text != "":
		return label.get_combined_minimum_size().y
	label.text = "0"
	var height := label.get_combined_minimum_size().y
	label.text = ""
	return height

func _start_roll(direction: int) -> void:
	if _active_outgoing_labels.is_empty():
		_finish_roll()
		return

	_roll_tween = create_tween().set_parallel(true)
	_roll_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for outgoing_label in _active_outgoing_labels:
		if not is_instance_valid(outgoing_label):
			continue
		var cell := outgoing_label.get_parent() as Control
		var current_label := _find_digit_label(cell, "current")
		var travel := maxf(cell.custom_minimum_size.y, 1.0)
		_roll_tween.tween_property(outgoing_label, "position:y", -travel * float(direction), ROLL_DURATION)
		_roll_tween.tween_property(outgoing_label, "modulate:a", FADED_ALPHA, ROLL_DURATION)
		if current_label != null:
			current_label.position.y = travel * float(direction)
			current_label.modulate.a = FADED_ALPHA
			_roll_tween.tween_property(current_label, "position:y", 0.0, ROLL_DURATION)
			_roll_tween.tween_property(current_label, "modulate:a", 1.0, ROLL_DURATION)
	_roll_tween.chain().tween_callback(_finish_roll)

func _finish_roll() -> void:
	_roll_tween = null
	for label in _active_outgoing_labels:
		if is_instance_valid(label):
			label.hide()
	_active_outgoing_labels.clear()
	_reset_visible_digit_labels()

func _align_display_chars(new_text: String, old_text: String) -> Array[Array]:
	if new_text.find("/") == -1 and old_text.find("/") == -1:
		var pure_aligned := _right_align_chars(_chars(new_text), _chars(old_text))
		return [pure_aligned[0], pure_aligned[1]]

	var new_parts := _split_once(new_text, "/")
	var old_parts := _split_once(old_text, "/")
	var new_left := _chars(new_parts[0] if new_parts.size() > 0 else "")
	var new_right := _chars(new_parts[1] if new_parts.size() > 1 else "")
	var old_left := _chars(old_parts[0] if old_parts.size() > 0 else "")
	var old_right := _chars(old_parts[1] if old_parts.size() > 1 else "")
	var aligned_left := _right_align_chars(new_left, old_left)
	var aligned_right := _right_align_chars(new_right, old_right)
	var old_result: Array[String] = aligned_left[0]
	var new_result: Array[String] = aligned_left[1]
	old_result.append("/")
	new_result.append("/")
	old_result.append_array(aligned_right[0])
	new_result.append_array(aligned_right[1])
	return [old_result, new_result]

func _right_align_chars(new_chars: Array[String], old_chars: Array[String]) -> Array[Array]:
	var width := maxi(new_chars.size(), old_chars.size())
	var old_result: Array[String] = []
	var new_result: Array[String] = []
	for index in range(width):
		var old_index := index - (width - old_chars.size())
		var new_index := index - (width - new_chars.size())
		old_result.append(old_chars[old_index] if old_index >= 0 else "")
		new_result.append(new_chars[new_index] if new_index >= 0 else "")
	return [old_result, new_result]

func _split_once(text: String, delimiter: String) -> Array[String]:
	var delimiter_index := text.find(delimiter)
	if delimiter_index < 0:
		return [text, ""]
	return [
		text.substr(0, delimiter_index),
		text.substr(delimiter_index + delimiter.length()),
	]

func _chars(text: String) -> Array[String]:
	var result: Array[String] = []
	for index in range(text.length()):
		result.append(text.substr(index, 1))
	return result

func _is_digit(value: String) -> bool:
	return value.length() == 1 and value >= "0" and value <= "9"

func _find_digit_label(cell: Node, role: String) -> Label:
	for child in cell.get_children():
		if child is Label and str(child.get_meta("asset_digit_role", "")) == role:
			return child
	return null
