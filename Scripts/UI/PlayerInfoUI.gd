extends Control
class_name PlayerInfoUI

const AvatarCatalog = preload("res://Scripts/Data/AvatarCatalog.gd")

var _avatar_bg: ColorRect
var _avatar_image: TextureRect
var _id_label: Label
var _level_label: Label
var _combat_label: Label
var _avatar_size: float = 52.0

func configure_avatar_size(target_height: float) -> void:
	_avatar_size = maxf(52.0, target_height)
	if is_node_ready():
		_apply_avatar_layout()

func _ready() -> void:
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

func setup_ui() -> void:
	# ── 头像（金色边框圆形示意） ──
	_avatar_bg = ColorRect.new()
	_avatar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_avatar_bg.position = Vector2(0, 4)
	_avatar_bg.size = Vector2(52, 52)
	_avatar_bg.color = Color(1, 0.84, 0, 1)  # 金色边框
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
	_id_label.add_theme_font_size_override("font_size", 13)
	_id_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(_id_label)

	# ── 等级 ──
	_level_label = Label.new()
	_level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_level_label.position = Vector2(0, 84)
	_level_label.size = Vector2(100, 20)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1, 0.9))
	add_child(_level_label)

	# ── 战力 ──
	_combat_label = Label.new()
	_combat_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combat_label.position = Vector2(0, 106)
	_combat_label.size = Vector2(100, 24)
	_combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_label.add_theme_font_size_override("font_size", 12)
	_combat_label.add_theme_color_override("font_color", Color(1, 0.6, 0.1, 0.9))
	add_child(_combat_label)

	_apply_avatar_layout()
	refresh()

func _apply_avatar_layout() -> void:
	if _avatar_bg == null or _avatar_image == null:
		return
	var border := maxf(3.0, roundf(_avatar_size * 0.055))
	_avatar_bg.position = Vector2((size.x - _avatar_size) * 0.5, 4)
	_avatar_bg.size = Vector2(_avatar_size, _avatar_size)
	_avatar_image.offset_left = border
	_avatar_image.offset_top = border
	_avatar_image.offset_right = -border
	_avatar_image.offset_bottom = -border
	var label_y := 10.0 + _avatar_size
	if _id_label:
		_id_label.position = Vector2(0, label_y)
		_id_label.size = Vector2(size.x, 20)
	if _level_label:
		_level_label.position = Vector2(0, label_y + 22)
		_level_label.size = Vector2(size.x, 20)
	if _combat_label:
		_combat_label.position = Vector2(0, label_y + 44)
		_combat_label.size = Vector2(size.x, 24)

func _on_player_data_changed() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_avatar_image.texture = AvatarCatalog.get_texture(pd.avatar_id)
	_id_label.text = pd.nickname if pd.nickname != "" else Localization.t("ui.player.default_name")
	_level_label.text = "Lv.%d" % pd.level
	_combat_label.text = "⚔ %d" % pd.combat_power
