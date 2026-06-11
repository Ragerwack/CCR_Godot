extends Control
class_name ExpBarUI

var _bg: ColorRect        # 底层背景
var _fill_fg: ColorRect   # 前景填充条（深色底）
var _fill_bar: ColorRect  # 经验进度条（亮色）
var _glow: ColorRect      # 微光扫过层
var _label: Label         # 经验数值
var _glow_tween: Tween    # 微光动画（独立管理）
var _current_ratio: float = 0.0

const BAR_HEIGHT_RATIO: float = 0.024
const MIN_BAR_HEIGHT: int = 16
const MAX_BAR_HEIGHT: int = 24
const BAR_PADDING: int = 2
const GLOW_DURATION: float = 3.0        # 微光循环时间

func _ready() -> void:
	# 全宽底部锚定
	var vp = get_viewport_rect().size
	var bar_h = clampi(int(vp.y * BAR_HEIGHT_RATIO), MIN_BAR_HEIGHT, MAX_BAR_HEIGHT)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = -bar_h
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	setup_ui()
	_update_layout()
	_start_glow_animation()

	GameManager.player_data.changed.connect(_on_player_data_changed)
	# 显式监听同步完成信号，确保数据同步后经验条刷新
	GameManager.data_synced.connect(_on_data_synced)
	refresh()

func setup_ui() -> void:
	# ── 底层暗色背景 ──
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.05, 0.05, 0.08, 0.95)
	add_child(_bg)

	# ── 前景填充条（深色底，作为经验条的槽位） ──
	_fill_fg = ColorRect.new()
	_fill_fg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fill_fg.color = Color(0.12, 0.12, 0.18, 1.0)
	add_child(_fill_fg)

	# ── 经验进度条（紫色渐变，WoW 风格） ──
	_fill_bar = ColorRect.new()
	_fill_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 使用 shader material 做渐变，这里用纯色 + 后续 tween 模拟
	_fill_bar.color = Color(0.35, 0.15, 0.7, 1.0)  # 紫色
	add_child(_fill_bar)

	# ── 微光覆盖层 ──
	_glow = ColorRect.new()
	_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_glow.color = Color(1, 1, 1, 0)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	# ── 经验数值标签 ──
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1.0))  # 金色文字
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if _fill_fg == null or _fill_bar == null or _glow == null:
		return
	var inner_w = maxf(size.x - BAR_PADDING * 2.0, 0.0)
	var inner_h = maxf(size.y - BAR_PADDING * 2.0, 1.0)
	var inner_pos = Vector2(BAR_PADDING, BAR_PADDING)
	_fill_fg.position = inner_pos
	_fill_fg.size = Vector2(inner_w, inner_h)
	_fill_bar.position = inner_pos
	_fill_bar.size = Vector2(inner_w * _current_ratio, inner_h)
	_glow.position = inner_pos
	_glow.size = Vector2(inner_w, inner_h)

func _start_glow_animation() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_loops(0)  # 无限循环

	# 微光亮起 → 暗下去
	_glow_tween.tween_property(_glow, "color:a", 0.08, GLOW_DURATION * 0.5).from(0.0)
	_glow_tween.tween_property(_glow, "color:a", 0.0, GLOW_DURATION * 0.5)

func _on_player_data_changed() -> void:
	# 经验变化时带动画过渡
	var pd = GameManager.player_data
	var exp_in_level = pd.exp_in_level if "exp_in_level" in pd else GameManager.exp_in_level
	var exp_for_next = pd.exp_for_next if "exp_for_next" in pd else GameManager.exp_for_next
	# 回退方案：从 profile 的 exp 和 level 推算
	# 如果两种方式都没有，用 0/0 显示
	if exp_for_next <= 0:
		exp_for_next = 400

	var ratio = float(exp_in_level) / float(exp_for_next) if exp_for_next > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	_current_ratio = ratio

	var bar_width = _fill_fg.size.x * ratio
	var bar_tween = create_tween()
	bar_tween.tween_property(_fill_bar, "size:x", bar_width, 0.3).set_trans(Tween.TRANS_CUBIC)

	_label.text = "%d / %d" % [exp_in_level, exp_for_next]

	# 重新启动微光
	_start_glow_animation()

func _on_data_synced() -> void:
	# 数据同步完成后延迟一帧刷新，确保 player_data 已完全更新
	call_deferred("refresh")

func refresh() -> void:
	_on_player_data_changed()
