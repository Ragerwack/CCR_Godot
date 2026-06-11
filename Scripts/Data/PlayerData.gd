class_name PlayerData
extends RefCounted

signal changed()

var level: int = 1
var exp: int = 0
var gold: int = 100
var gems: int = 50
var user_id: int = 0
var hand_cards: Array = []
var vault_cards: Array = []
var decks: Array[Deck] = []

# 槽位
var hand_slots: int = 8
var pool_slots: int = 8
var vault_slots: int = 2
var nickname: String = ""
var combat_power: int = 0

# 卡池（当前展示的卡）
var pool_cards: Array = []

# 后端返回的等级阈值信息（由 GameManager 从 /user/level API 同步）
var exp_in_level: int = 0       # 当前等级内已获得的经验值
var exp_for_next: int = 400     # 升至下一级所需的总经验（当前等级阈值范围）

# ============ 货币 ============
func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		changed.emit()
		return true
	return false

func add_gems(amount: int) -> void:
	gems += amount
	changed.emit()

func spend_gems(amount: int) -> bool:
	if gems >= amount:
		gems -= amount
		changed.emit()
		return true
	return false

# ============ 手牌 ============
func get_hand_empty_slots() -> int:
	var used := 0
	for i in range(mini(hand_slots, hand_cards.size())):
		if hand_cards[i] != null:
			used += 1
	return hand_slots - used

func add_to_hand(card: CardInfo) -> bool:
	for i in range(hand_slots):
		while hand_cards.size() <= i:
			hand_cards.append(null)
		if hand_cards[i] == null:
			hand_cards[i] = card
			changed.emit()
			return true
	return false

func remove_from_hand(card: CardInfo) -> bool:
	var idx = hand_cards.find(card)
	if idx >= 0:
		hand_cards[idx] = null
		changed.emit()
		return true
	return false

func remove_from_hand_at(idx: int) -> bool:
	if idx >= 0 and idx < hand_cards.size():
		hand_cards[idx] = null
		changed.emit()
		return true
	return false

# ============ 卡池 ============
func get_pool_empty_slots() -> int:
	var used := 0
	for i in range(mini(pool_slots, pool_cards.size())):
		if pool_cards[i] != null:
			used += 1
	return pool_slots - used

func add_to_pool(card: CardInfo) -> bool:
	for i in range(pool_slots):
		while pool_cards.size() <= i:
			pool_cards.append(null)
		if pool_cards[i] == null:
			pool_cards[i] = card
			changed.emit()
			return true
	return false

func clear_pool() -> void:
	pool_cards.clear()
	changed.emit()

# ============ 保险箱 ============
func get_vault_empty_slots() -> int:
	var used := 0
	for i in range(mini(vault_slots, vault_cards.size())):
		if vault_cards[i] != null:
			used += 1
	return vault_slots - used

func add_to_vault(card: CardInfo) -> bool:
	for i in range(vault_slots):
		while vault_cards.size() <= i:
			vault_cards.append(null)
		if vault_cards[i] == null:
			vault_cards[i] = card
			changed.emit()
			return true
	return false

func remove_from_vault(card: CardInfo) -> bool:
	var idx = vault_cards.find(card)
	if idx >= 0:
		vault_cards[idx] = null
		changed.emit()
		return true
	return false
