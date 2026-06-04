extends Control
class_name PlayerInfoUI

var _avatar_bg: ColorRect
var _id_label: Label
var _level_label: Label
var _combat_label: Label

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

	var avatar_inner = ColorRect.new()
	avatar_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_inner.position = Vector2(3, 3)
	avatar_inner.size = Vector2(-6, -6)
	avatar_inner.color = Color(0.3, 0.3, 0.4, 1.0)
	_avatar_bg.add_child(avatar_inner)

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

	refresh()

func _on_player_data_changed() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_id_label.text = pd.nickname if pd.nickname != "" else "玩家"
	_level_label.text = "Lv.%d" % pd.level
	_combat_label.text = "⚔ %d" % pd.combat_power
