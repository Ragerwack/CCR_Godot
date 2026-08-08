extends VScrollBar

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

# 最新垂直滚动条轨道原图为 68 x 438。页面可以只延长 NinePatch 中段，
# 但宽度、上下端帽与拨块均保持原始显示比例。
const CONTROL_SIZE := Vector2(68.0, 438.0)
# 轨道 PNG 左侧有 6px 透明留白。页面按玩家实际看见的轨道边缘对齐时，
# 必须从 Control 外框位置中扣除该留白，不能把透明像素当成滚动条左边缘。
const TRACK_VISUAL_LEFT_INSET: float = 6.0

var _scroll_container: ScrollContainer = null
var _source_scrollbar: VScrollBar = null
var _syncing: bool = false

func _ready() -> void:
	custom_minimum_size = CONTROL_SIZE
	size = CONTROL_SIZE
	CCRVisualStyle.apply_latest_vertical_scrollbar(self)
	# 样式函数只规定最小宽度；页面控件在这里恢复原始轨道长度。
	custom_minimum_size = CONTROL_SIZE
	size = CONTROL_SIZE
	value_changed.connect(_on_value_changed)
	_sync_from_source.call_deferred()

func bind_scroll_container(scroll_container: ScrollContainer) -> void:
	_scroll_container = scroll_container
	if _scroll_container == null:
		return
	# 保留 ScrollContainer 的滚轮、触控板和手柄滚动，只隐藏它自带的视觉条。
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_source_scrollbar = _scroll_container.get_v_scroll_bar()
	if _source_scrollbar == null:
		return
	if not _source_scrollbar.value_changed.is_connected(_on_source_value_changed):
		_source_scrollbar.value_changed.connect(_on_source_value_changed)
	if not _source_scrollbar.changed.is_connected(_sync_from_source):
		_source_scrollbar.changed.connect(_sync_from_source)
	_sync_from_source.call_deferred()

func _sync_from_source() -> void:
	if _source_scrollbar == null or not is_instance_valid(_source_scrollbar):
		return
	_syncing = true
	min_value = _source_scrollbar.min_value
	max_value = _source_scrollbar.max_value
	page = _source_scrollbar.page
	step = _source_scrollbar.step
	value = _source_scrollbar.value
	_syncing = false

func _on_source_value_changed(source_value: float) -> void:
	if _syncing:
		return
	_syncing = true
	value = source_value
	_syncing = false

func _on_value_changed(scroll_value: float) -> void:
	if _syncing or _scroll_container == null or not is_instance_valid(_scroll_container):
		return
	_syncing = true
	_scroll_container.scroll_vertical = maxi(0, int(roundf(scroll_value)))
	_syncing = false
