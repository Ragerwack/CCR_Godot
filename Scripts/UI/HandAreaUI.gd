extends Control
class_name HandAreaUI

signal card_clicked(card: CardInfo)
signal card_double_clicked(card: CardInfo, slot_index: int)
signal card_dragged(card: CardInfo, from_slot: int)
signal synthesize_requested()
signal discard_requested()
signal vault_save_requested()

@export var columns: int = 8
@export var rows_visible: int = 2   # 可见行数
@export var total_rows: int = 4     # 总行数（2 页）

var slot_count: int = 16           # 2×8 每页
var total_slots: int = 32          # 4×8 总计
var slots: Array[CardSlotUI] = []
var current_page: int = 0

func _ready() -> void:
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 监听拖拽事件
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func setup_ui() -> void:
	_create_slot_grid()
	_create_action_column()

func _create_slot_grid() -> void:
	var slot_size = Vector2(97, 135)   # 88×123 再增大 10% → 97×135
	var slot_spacing = 8
	var start_x = 40
	var start_y = 12

	for i in range(slot_count):  # 16 可见槽
		var row = i / columns
		var col = i % columns
		var x = start_x + col * (slot_size.x + slot_spacing)
		var y = start_y + row * (slot_size.y + slot_spacing)

		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, y)
		slot.area_type = "hand"
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_double_clicked.connect(_on_slot_double_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("hand", idx))
		slots.append(slot)
		add_child(slot)

func _create_action_column() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# 锚点 right=1.0 时 offset 是从右边缘算起的边距，必须为 0 或负数才能可见
	vbox.offset_left = -120    # -(110 宽 + 10 右边距)
	vbox.offset_right = -10
	vbox.offset_top = -100     # 垂直居中: 高 200 → ±100
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# 翻页按钮
	var btn_page = Button.new()
	btn_page.text = "◀▶ 翻页"
	btn_page.custom_minimum_size = Vector2(100, 36)
	btn_page.pressed.connect(_on_page_flip)
	vbox.add_child(btn_page)

	# 合成
	var btn_synth = Button.new()
	btn_synth.text = "⚗ 合成"
	btn_synth.custom_minimum_size = Vector2(100, 36)
	btn_synth.pressed.connect(func(): synthesize_requested.emit())
	vbox.add_child(btn_synth)

	# 丢弃
	var btn_discard = Button.new()
	btn_discard.text = "🗑 丢弃"
	btn_discard.custom_minimum_size = Vector2(100, 36)
	btn_discard.pressed.connect(func(): discard_requested.emit())
	vbox.add_child(btn_discard)

	# 存入保险箱
	var btn_vault = Button.new()
	btn_vault.text = "📦 存保险箱"
	btn_vault.custom_minimum_size = Vector2(100, 36)
	btn_vault.pressed.connect(func(): vault_save_requested.emit())
	vbox.add_child(btn_vault)

# ── 翻页 ──
func _on_page_flip() -> void:
	var max_page = max(0, ceili(float(total_slots) / float(slot_count)) - 1)
	current_page = (current_page + 1) % (max_page + 1)
	refresh_display()

# ── 卡槽点击 ──
func _on_slot_clicked(index: int) -> void:
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_clicked.emit(card)

# ── 卡槽双击 → 转派为 card_double_clicked（含全局索引） ──
func _on_slot_double_clicked(index: int) -> void:
	var global_idx = current_page * slot_count + index
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_double_clicked.emit(card, global_idx)

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_slot_index: int, card: CardInfo, source: String, source_index: int) -> void:
	var global_target = current_page * slot_count + target_slot_index

	if source == "pool":
		# pool → hand: 从卡池移除，加入手牌
		_handle_pool_to_hand(card, global_target)
		DragSystem.notify_drop_completed(card, source, "hand")

	elif source == "hand":
		# hand → hand: 同区移动（重新排序）
		# 目前不支持
		DragSystem.cancel_drag()


func _handle_pool_to_hand(card: CardInfo, target_hand_idx: int) -> void:
	# 从卡池移除
	var pool = CardPoolSystem.current_pool
	for i in range(pool.size()):
		if pool[i] != null and pool[i].get_uid() == card.get_uid():
			pool.remove_at(i)
			break

	# 加入手牌目标槽
	var hand = GameManager.player_data.hand_cards
	var max_slots = GameManager.player_data.hand_slots
	if target_hand_idx >= max_slots:
		print("[HandAreaUI] 目标手牌槽位超出解锁范围")
		# 回退: 放回卡池
		pool.append(card)
		return

	while hand.size() <= target_hand_idx:
		hand.append(null)
	if target_hand_idx < hand.size():
		if hand[target_hand_idx] != null:
			# 目标已被占用（不应发生，因为 drop target 的空槽检查）
			# 找下一个空槽
			var placed = false
			for i in range(max_slots):
				if i >= hand.size():
					hand.append(card)
					placed = true
					break
				if hand[i] == null:
					hand[i] = card
					placed = true
					break
			if not placed:
				pool.append(card)  # 回退
				print("[HandAreaUI] 手牌已满")
				return
		else:
			hand[target_hand_idx] = card
	else:
		hand.append(card)

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, target_hand_idx)


# ── 数据变更 ──
func _on_player_data_changed() -> void:
	refresh_display()


# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	refresh_display()
	# CardPoolUI 也通过 DragSystem.drag_ended 获得刷新


func refresh_display() -> void:
	var cards = GameManager.player_data.hand_cards
	var hand_slots_unlocked = GameManager.player_data.hand_slots
	var start_idx = current_page * slot_count
	var end_idx = start_idx + slot_count

	for i in range(slot_count):
		var global_idx = start_idx + i
		if i < slots.size():
			# 应用槽位锁定状态（前 N 个解锁，其余锁定）
			slots[i].set_unlocked(global_idx < hand_slots_unlocked)
			if global_idx < hand_slots_unlocked and global_idx < cards.size() and cards[global_idx] != null:
				slots[i].set_card(cards[global_idx], global_idx)
			else:
				slots[i].clear_slot()
			slots[i].visible = true
