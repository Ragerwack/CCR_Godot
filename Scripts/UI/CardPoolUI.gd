extends Control
class_name CardPoolUI

signal card_clicked(card: CardInfo)
signal card_double_clicked(card: CardInfo, slot_index: int)
signal card_dragged(card: CardInfo, from_slot: int)

@export var pool_name: String = "card_pool"
@export var columns: int = 8
@export var rows: int = 2

var slot_count: int = 16  # 8×2 固定
var slots: Array[CardSlotUI] = []

func _ready() -> void:
	setup_ui()
	# 先读取已有数据（解决竞态：信号发出后才创建本控件）
	if CardPoolSystem.current_pool.size() > 0:
		_refresh_display(CardPoolSystem.current_pool)
	# 再连接信号，保证后续更新也能收到
	CardPoolSystem.pool_updated.connect(_on_pool_updated)
	CardPoolSystem.pool_filled.connect(_on_pool_filled)

	# 监听拖拽结束 → 刷新 UI
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func setup_ui() -> void:
	# ── 卡槽网格（8×2 = 16 固定） ──
	_create_slot_grid()

	# ── 右侧刷新按钮列（垂直居中） ──
	_create_refresh_column()

func _create_slot_grid() -> void:
	var slot_size = Vector2(97, 135)   # 88×123 再增大 10% → 97×135
	var slot_spacing = 8
	var start_x = 40
	var start_y = 24

	for i in range(slot_count):
		var row = i / columns
		var col = i % columns
		var x = start_x + col * (slot_size.x + slot_spacing)
		var y = start_y + row * (slot_size.y + slot_spacing)

		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, y)
		slot.area_type = "pool"
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_double_clicked.connect(_on_slot_double_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("pool", idx))
		slots.append(slot)
		add_child(slot)

func _create_refresh_column() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# 锚点 right=1.0 时 offset 是从右边缘算起的边距，必须为 0 或负数才能可见
	vbox.offset_left = -120    # -(110 宽 + 10 右边距)
	vbox.offset_right = -10
	vbox.offset_top = -70      # 垂直居中: 高 140 → ±70
	vbox.offset_bottom = 70
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var btn_free = Button.new()
	btn_free.text = "🔄 免费刷新"
	btn_free.custom_minimum_size = Vector2(100, 36)
	btn_free.pressed.connect(_on_free_refresh)
	vbox.add_child(btn_free)

	var btn_gold = Button.new()
	btn_gold.text = "💛 金币刷新"
	btn_gold.custom_minimum_size = Vector2(100, 36)
	btn_gold.pressed.connect(_on_gold_refresh)
	vbox.add_child(btn_gold)

	var btn_gem = Button.new()
	btn_gem.text = "💎 宝石刷新"
	btn_gem.custom_minimum_size = Vector2(100, 36)
	btn_gem.pressed.connect(_on_gem_refresh)
	vbox.add_child(btn_gem)

# ── 刷新回调 ──
func _on_free_refresh() -> void:
	if CardPoolSystem.do_refresh("free"):
		CardPoolSystem.refresh_pool("free")

func _on_gem_refresh() -> void:
	if CardPoolSystem.do_refresh("gem"):
		CardPoolSystem.refresh_pool("gem")

func _on_gold_refresh() -> void:
	if CardPoolSystem.do_refresh("gold"):
		CardPoolSystem.refresh_pool("gold")

# ── 卡槽点击 → 转派为 card_clicked ──
func _on_slot_clicked(index: int) -> void:
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_clicked.emit(card)

# ── 卡槽双击 → 转派为 card_double_clicked（含槽位索引） ──
func _on_slot_double_clicked(index: int) -> void:
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_double_clicked.emit(card, index)

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	# 只处理目标是卡池的拖放
	if source == "hand":
		# hand → pool: 从手牌移除，加入卡池
		_handle_hand_to_pool(card, source_index)
		DragSystem.notify_drop_completed(card, source, "pool")
	elif source == "pool":
		# pool → pool: 不应该发生，但防御性忽略
		DragSystem.cancel_drag()


func _handle_hand_to_pool(card: CardInfo, hand_idx: int) -> void:
	var hand = GameManager.player_data.hand_cards
	if hand_idx < hand.size() and hand[hand_idx] != null:
		hand[hand_idx] = null  # 清空手牌槽

	# 加入卡池
	var added = false
	var pool = CardPoolSystem.current_pool
	for i in range(GameManager.player_data.pool_slots):
		if i >= pool.size():
			pool.append(card)
			added = true
			break
		if pool[i] == null:
			pool[i] = card
			added = true
			break
	if not added:
		# 卡池满，回到手牌
		if hand_idx < hand.size():
			hand[hand_idx] = card
		print("[CardPoolUI] 卡池已满")
		return

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, hand_idx)


# ── 卡池数据更新 ──
func _on_pool_updated(cards: Array[CardInfo]) -> void:
	_refresh_display(cards)

func _on_pool_filled(cards: Array[CardInfo]) -> void:
	_refresh_display(cards)

func _refresh_display(cards: Array[CardInfo]) -> void:
	# 固定 16 槽，无翻页
	var unlocked_count = GameManager.player_data.pool_slots
	for i in range(slot_count):
		if i >= slots.size():
			continue
		# 应用槽位锁定状态（前 N 个解锁，其余锁定）
		slots[i].set_unlocked(i < unlocked_count)
		if i < unlocked_count and i < cards.size():
			slots[i].set_card(cards[i], i)
		else:
			slots[i].clear_slot()
		slots[i].visible = true


# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	_refresh_display(CardPoolSystem.current_pool)
	# 通知手牌区也刷新（通过 DragSystem 的 drag_ended 信号，HandAreaUI 也监听）
