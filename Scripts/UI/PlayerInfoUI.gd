extends Control
class_name PlayerInfoUI

const AvatarCatalog = preload("res://Scripts/Data/AvatarCatalog.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

var _avatar_bg: ColorRect
var _avatar_image: TextureRect
var _id_label: Label
var _level_label: Label
var _combat_label: Label
var _stats_row: HBoxContainer
var _level_icon: TextureRect
var _combat_icon: TextureRect
var _avatar_size: float = 52.0
var _text_font_size: int = 18

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

	# ── 玩家昵称 ──
	_id_label = Label.new()
	_id_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_id_label.position = Vector2(0, 62)
	_id_label.size = Vector2(100, 20)
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_id_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
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
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1, 0.9))
	_stats_row.add_child(_level_label)

	_combat_icon = CCRVisualStyle.make_status_icon("status_combat_power", "CombatPowerIcon", 36.0)
	_stats_row.add_child(_combat_icon)
	_combat_label = Label.new()
	_combat_label.name = "CombatPowerLabel"
	_combat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_label.add_theme_color_override("font_color", Color(1, 0.6, 0.1, 0.9))
	_stats_row.add_child(_combat_label)

	_apply_text_style()
	_apply_avatar_layout()
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
	var line_height := maxf(float(_text_font_size + 6), 36.0)
	var label_y := avatar_top + _avatar_size + 8.0
	if _id_label:
		_id_label.position = Vector2(0, label_y)
		_id_label.size = Vector2(size.x, line_height)
	if _stats_row:
		_stats_row.position = Vector2(0, label_y + line_height)
		_stats_row.size = Vector2(size.x, line_height)

func _apply_text_style() -> void:
	for label in [_id_label, _level_label, _combat_label]:
		var typed_label := label as Label
		if typed_label != null:
			typed_label.add_theme_font_size_override("font_size", _text_font_size)

func _on_player_data_changed() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_avatar_image.texture = AvatarCatalog.get_texture(pd.avatar_id)
	_id_label.text = pd.nickname if pd.nickname != "" else Localization.t("ui.player.default_name")
	_level_label.text = Localization.t("ui.player.level_short", [pd.level])
	_combat_label.text = Localization.t("ui.player.combat_power_short", [pd.combat_power])
