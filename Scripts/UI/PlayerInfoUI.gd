extends Control
class_name PlayerInfoUI

signal avatar_pressed()

const AvatarCatalog = preload("res://Scripts/Data/AvatarCatalog.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const AssetNumberRollScript = preload("res://Scripts/UI/AssetNumberRoll.gd")
const STAT_FLIP_DURATION := 1.0

var _avatar_bg: ColorRect
var _avatar_image: TextureRect
var _avatar_button: Button
var _id_label: Label
var _level_number
var _combat_number
var _level_label_host: Control
var _combat_label_host: Control
var _stats_row: HBoxContainer
var _level_icon: TextureRect
var _combat_icon: TextureRect
var _avatar_size: float = 52.0
var _text_font_size: int = 18
var _avatar_career_enabled: bool = false

func set_avatar_career_enabled(enabled: bool) -> void:
	_avatar_career_enabled = enabled
	if is_node_ready():
		_apply_avatar_interaction()

func configure_avatar_size(target_height: float) -> void:
	_avatar_size = maxf(52.0, target_height)
	if is_node_ready():
		_apply_avatar_layout()

func configure_text_font_size(font_size: int) -> void:
	_text_font_size = maxi(10, font_size)
	if is_node_ready():
		_apply_text_style()
		_apply_avatar_layout()

func _ready() -> void:
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

func setup_ui() -> void:
	# ── 玩家头像 ──
	_avatar_bg = ColorRect.new()
	_avatar_bg.name = "AvatarHost"
	_avatar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_avatar_bg.position = Vector2(0, 4)
	_avatar_bg.size = Vector2(52, 52)
	_avatar_bg.color = Color(1, 1, 1, 0)
	_avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avatar_bg)

	_avatar_image = TextureRect.new()
	_avatar_image.name = "AvatarImage"
	_avatar_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_image.offset_left = 3
	_avatar_image.offset_top = 3
	_avatar_image.offset_right = -3
	_avatar_image.offset_bottom = -3
	_avatar_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_bg.add_child(_avatar_image)

	_avatar_button = Button.new()
	_avatar_button.name = "PlayerAvatarButton"
	_avatar_button.flat = true
	_avatar_button.focus_mode = Control.FOCUS_NONE
	_avatar_button.pressed.connect(_on_avatar_button_pressed)
	add_child(_avatar_button)

	# ── 玩家昵称 ──
	_id_label = Label.new()
	_id_label.name = "PlayerIdLabel"
	_id_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_id_label.position = Vector2(0, 62)
	_id_label.size = Vector2(100, 20)
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_id_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(_id_label)

	# ── 等级与收藏战力 ──
	_stats_row = HBoxContainer.new()
	_stats_row.name = "PlayerStatsRow"
	_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats_row.add_theme_constant_override("separation", 2)
	_stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_row)

	_level_icon = CCRVisualStyle.make_status_icon("status_level", "LevelIcon", 36.0)
	_stats_row.add_child(_level_icon)
	_level_label_host = _make_stat_label_host("LevelLabelHost")
	_stats_row.add_child(_level_label_host)
	_level_number = _make_stat_number_roll("LevelNumberRoll", "LevelLabel")
	_level_label_host.add_child(_level_number)

	_combat_icon = CCRVisualStyle.make_status_icon("status_combat_power", "CombatPowerIcon", 36.0)
	_stats_row.add_child(_combat_icon)
	_combat_label_host = _make_stat_label_host("CombatPowerLabelHost")
	_stats_row.add_child(_combat_label_host)
	_combat_number = _make_stat_number_roll("CombatPowerNumberRoll", "CombatPowerLabel")
	_combat_label_host.add_child(_combat_number)

	_level_label_host.resized.connect(_layout_stat_label_host.bind(_level_label_host, _level_number))
	_combat_label_host.resized.connect(_layout_stat_label_host.bind(_combat_label_host, _combat_number))

	_apply_text_style()
	_apply_avatar_layout()
	_apply_avatar_interaction()
	refresh()

func _apply_avatar_layout() -> void:
	if _avatar_bg == null or _avatar_image == null:
		return
	var avatar_top := maxf(4.0, (size.x - _avatar_size) * 0.5)
	_avatar_bg.position = Vector2((size.x - _avatar_size) * 0.5, avatar_top)
	_avatar_bg.size = Vector2(_avatar_size, _avatar_size)
	_avatar_image.offset_left = 0
	_avatar_image.offset_top = 0
	_avatar_image.offset_right = 0
	_avatar_image.offset_bottom = 0
	if _avatar_button:
		_avatar_button.position = _avatar_bg.position
		_avatar_button.size = _avatar_bg.size
	var line_height := maxf(float(_text_font_size + 6), 36.0)
	var label_y := avatar_top + _avatar_size + 8.0
	if _id_label:
		_id_label.position = Vector2(0, label_y)
		_id_label.size = Vector2(size.x, line_height)
	if _stats_row:
		_stats_row.position = Vector2(0, label_y + line_height)
		_stats_row.size = Vector2(size.x, line_height)

func _apply_text_style() -> void:
	for label in [_id_label]:
		var typed_label := label as Label
		if typed_label != null:
			typed_label.add_theme_font_size_override("font_size", _text_font_size)
	for number in [_level_number, _combat_number]:
		if number != null:
			number.configure(_stat_number_label_name(number), _text_font_size)
	if _level_label_host != null and _level_number != null:
		_update_stat_label_host_width(_level_label_host, _level_number)
	if _combat_label_host != null and _combat_number != null:
		_update_stat_label_host_width(_combat_label_host, _combat_number)

func _on_player_data_changed() -> void:
	refresh()

func _on_avatar_button_pressed() -> void:
	if _avatar_career_enabled:
		avatar_pressed.emit()

func _apply_avatar_interaction() -> void:
	if _avatar_button == null:
		return
	_avatar_button.disabled = not _avatar_career_enabled
	_avatar_button.mouse_filter = Control.MOUSE_FILTER_STOP if _avatar_career_enabled else Control.MOUSE_FILTER_IGNORE
	_avatar_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _avatar_career_enabled else Control.CURSOR_ARROW
	_avatar_button.tooltip_text = Localization.t("ui.career.avatar_tooltip") if _avatar_career_enabled else ""

func refresh() -> void:
	var pd = GameManager.player_data
	_avatar_image.texture = AvatarCatalog.get_texture(pd.avatar_id)
	_apply_avatar_interaction()
	_id_label.text = pd.nickname if pd.nickname != "" else Localization.t("ui.player.default_name")
	_set_stat_number(_level_label_host, _level_number, pd.level, Localization.t("ui.player.level_short", [pd.level]))
	_set_stat_number(_combat_label_host, _combat_number, pd.combat_power, Localization.t("ui.player.combat_power_short", [pd.combat_power]))

func _make_stat_label_host(host_name: String) -> Control:
	var host := Control.new()
	host.name = host_name
	host.clip_contents = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = Vector2(18.0, 36.0)
	return host

func _make_stat_number_roll(node_name: String, label_name: String):
	var number := AssetNumberRollScript.new()
	number.name = node_name
	number.configure(label_name, _text_font_size)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.set_meta("ccr_stat_label_name", label_name)
	return number

func _stat_number_label_name(number) -> String:
	if number == null:
		return "PlayerStatLabel"
	return str(number.get_meta("ccr_stat_label_name", "PlayerStatLabel"))

func _set_stat_number(host: Control, number, value: int, display_text: String) -> void:
	if host == null or number == null:
		return
	number.set_display(display_text, value, 0, is_visible_in_tree())
	_update_stat_label_host_width(host, number)
	_layout_stat_label_host(host, number)

func _update_stat_label_host_width(host: Control, number) -> void:
	if host == null or number == null:
		return
	host.custom_minimum_size = Vector2(
		maxf(18.0, ceilf(number.custom_minimum_size.x) + 2.0),
		maxf(maxf(36.0, float(_text_font_size + 6)), ceilf(number.custom_minimum_size.y))
	)

func _layout_stat_label_host(host: Control, number) -> void:
	if host == null or number == null:
		return
	var number_height := maxf(1.0, number.custom_minimum_size.y)
	number.size = Vector2(maxf(host.size.x, host.custom_minimum_size.x), number_height)
	number.position = Vector2(0.0, maxf(0.0, (host.size.y - number_height) * 0.5))
