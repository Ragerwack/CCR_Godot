extends LoadingScreenUI
class_name LoadingTutorialUI

const LOADING_TUTORIAL_TIPS: Array[Dictionary] = [
	{"id": "loading_tip_basic_001", "min_level": 1, "max_level": 999, "category": "basic", "title": "卡池与手牌", "body": "卡池中会出现当前可抽取的卡牌。你可以将卡池里的卡牌拖到手牌中，先暂时保留，再决定是否继续收集、合成或整理。", "short_tip": "先把卡池里的卡拖到手牌，这是 CCR 最基础的收藏动作。"},
	{"id": "loading_tip_basic_002", "min_level": 1, "max_level": 999, "category": "basic", "title": "什么是卡组", "body": "CCR 中的每个主题都是一个卡组。一个卡组通常由 5 张子卡组成，每张子卡都有自己的编号。", "short_tip": "同一个卡组的 5 张子卡，是合成 relic 的基础材料。"},
	{"id": "loading_tip_basic_003", "min_level": 1, "max_level": 999, "category": "basic", "title": "合成 relic 的条件", "body": "合成 relic 需要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡。例如：同一套卡组的白色 1/5、2/5、3/5、4/5、5/5，可以合成一个白色 relic。", "short_tip": "同卡组、同颜色、5个不同编号，才能合成 relic。"},
	{"id": "loading_tip_basic_004", "min_level": 1, "max_level": 999, "category": "basic", "title": "合成会消耗卡牌", "body": "当你合成 relic 时，用于合成的 5 张子卡会被消耗，并转化为一个完整 relic。Relic 是 CCR 中更长期、更稳定的收藏单位。", "short_tip": "卡牌是材料，relic 是成品收藏。"},
	{"id": "loading_tip_basic_005", "min_level": 1, "max_level": 999, "category": "basic", "title": "不要急着合成所有卡牌", "body": "有些卡牌适合马上合成，有些卡牌适合先保留。CCR 是长期收藏游戏，仓位、稀有度、卡组主题都会影响你的选择。", "short_tip": "CCR 的核心不是抽得快，而是判断什么值得留下。"},
	{"id": "loading_tip_vault_001", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱是什么", "body": "保险箱是用于长期保存卡牌的地方。和手牌不同，保险箱更像你的永久收藏柜，适合存放你暂时不想合成、但又不想丢掉的卡牌。", "short_tip": "手牌适合临时整理，保险箱适合长期收藏。"},
	{"id": "loading_tip_vault_002", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱只进不出", "body": "放入保险箱的卡牌不能再取回手牌。放入前请确认清楚：这张卡是否值得长期保存，是否属于你真正想收藏或未来想合成的卡组。", "short_tip": "保险箱是单向收藏空间，放入前要慎重。"},
	{"id": "loading_tip_vault_003", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱也可以合成", "body": "保险箱中的卡牌也可以参与 5 张合成。只要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡，就可以在保险箱中合成 relic。", "short_tip": "保险箱不是死仓库，它也能慢慢凑出 relic。"},
	{"id": "loading_tip_vault_004", "min_level": 5, "max_level": 999, "category": "vault", "title": "长期收藏需要仓位判断", "body": "保险箱空间是珍贵资源。你可以选择保存热门卡组，也可以选择保存冷门但有个人意义的卡组。真正的收藏价值，往往来自长期判断。", "short_tip": "不是每张卡都值得留下，但留下哪张卡是你的选择。"},
	{"id": "loading_tip_vault_005", "min_level": 5, "max_level": 999, "category": "vault", "title": "冷门卡组也可能有价值", "body": "有些卡组今天看起来冷门，但未来可能因为纪念意义、玩家情感或历史事件而变得重要。CCR 的收藏价值不只来自稀有度，也来自时间。", "short_tip": "时间本身，也是 CCR 的一部分。"},
	{"id": "loading_tip_rarity_001", "min_level": 10, "max_level": 999, "category": "rarity", "title": "卡牌颜色代表稀有度", "body": "CCR 的卡牌颜色从常见到稀有依次为：白、绿、蓝、紫、橙、黑、红。颜色越稀有，合成对应颜色 relic 的难度越高。", "short_tip": "白、绿、蓝、紫、橙、黑、红，越往后越稀有。"},
	{"id": "loading_tip_rarity_002", "min_level": 10, "max_level": 999, "category": "rarity", "title": "每次抽卡都是独立随机", "body": "每一次抽卡都会独立决定颜色结果。之前抽到了什么，不会改变下一次抽卡的颜色概率。CCR 的稀有收藏来自长期随机，而不是短期保证。", "short_tip": "每次抽卡独立随机，不要把上一次结果当成下一次的预告。"},
	{"id": "loading_tip_rarity_003", "min_level": 10, "max_level": 999, "category": "rarity", "title": "颜色概率", "body": "不同颜色拥有不同出现概率。白色最常见，绿色、蓝色、紫色逐渐稀有，橙色及以上属于极稀有收藏。具体概率以当前版本的游戏内公示和服务器配置为准。", "short_tip": "颜色概率请以游戏内当前版本公示为准。"},
	{"id": "loading_tip_rarity_004", "min_level": 10, "max_level": 999, "category": "rarity", "title": "稀有颜色不等于一定更适合你", "body": "高稀有度卡牌更难获得，但不代表每一张都必须留下。你真正喜欢的卡组、与你有情感连接的主题，也可能比单纯的颜色更重要。", "short_tip": "稀有度决定难度，收藏价值由你决定。"},
	{"id": "loading_tip_rarity_005", "min_level": 10, "max_level": 999, "category": "rarity", "title": "白卡也有收藏意义", "body": "白卡虽然常见，但它们也记录了卡组、日期和玩家选择。对于长期收藏游戏来说，早期白卡、特殊主题白卡、个人记忆相关白卡，也可能拥有自己的价值。", "short_tip": "CCR 中，常见不等于没有意义。"},
	{"id": "loading_tip_cap_001", "min_level": 20, "max_level": 999, "category": "cap", "title": "Relic 有颜色数量上限", "body": "不同颜色的 relic 拥有不同数量上限。越稀有的颜色，服务器允许存在的 relic 数量越少。这个机制让高级 relic 成为真正稀缺的长期收藏品。", "short_tip": "高级颜色 relic 的稀缺，不只来自概率，也来自数量上限。"},
	{"id": "loading_tip_cap_002", "min_level": 20, "max_level": 999, "category": "cap", "title": "为什么高级 relic 很难合成", "body": "合成高级 relic 需要先获得同卡组、同颜色、5个不同编号的子卡。同时，高级颜色 relic 还受到服务器数量上限影响。因此，高级 relic 不是短期目标，而是长期收藏目标。", "short_tip": "高级 relic 是长期收藏目标，不是日常消耗品。"},
	{"id": "loading_tip_cap_003", "min_level": 20, "max_level": 999, "category": "cap", "title": "达到上限后的颜色降级", "body": "当某个卡组的某种颜色 relic 已达到服务器数量上限后，后续原本会生成该颜色的卡牌，会按照规则降到下一档可用颜色。这样可以维持系统稀缺性，同时避免新卡牌完全无法产生。", "short_tip": "满上限后，高级颜色会按规则降到下一档可用颜色。"},
	{"id": "loading_tip_cap_004", "min_level": 20, "max_level": 999, "category": "cap", "title": "颜色降级不代表失败", "body": "颜色降级是 CCR 世界规则的一部分。它说明某个颜色的 relic 已经被玩家铸造到上限，新的收藏会自然流向下一个可用颜色层级。", "short_tip": "降级不是惩罚，而是稀缺系统的自然结果。"},
	{"id": "loading_tip_cap_005", "min_level": 20, "max_level": 999, "category": "cap", "title": "越早形成的 relic 越特殊", "body": "当一个卡组的高级颜色 relic 接近上限时，早期合成的 relic 会变得更特殊。它们不仅代表稀有颜色，也代表玩家在 CCR 历史中的早期选择。", "short_tip": "Relic 记录的不只是颜色，也记录时间。"},
	{"id": "loading_tip_whalefall_001", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "什么是鲸落", "body": "如果一个拥有重要收藏的玩家长期离开 CCR，他的部分高级收藏可能会在规则触发后进入鲸落流程。鲸落不是删除收藏，而是让沉睡的稀有收藏重新回到世界循环中。", "short_tip": "鲸落让沉睡的收藏重新进入 CCR 世界。"},
	{"id": "loading_tip_whalefall_002", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "2年不上线触发鲸落", "body": "当玩家连续 2 年不上线，并且满足鲸落条件时，系统会触发鲸落机制。相关 relic 会按照规则进入后续处理流程，让其他玩家有机会重新见到这些沉睡的收藏。", "short_tip": "连续 2 年不上线，可能触发鲸落机制。"},
	{"id": "loading_tip_whalefall_003", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "鲸落是 CCR 的长期生态机制", "body": "CCR 是一个长期运行的收藏世界。鲸落机制用于处理长期沉睡的高级收藏，让稀有 relic 不会永远消失在无人登录的账号中。", "short_tip": "鲸落保护的是整个 CCR 世界的长期流动性。"},
	{"id": "loading_tip_whalefall_004", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "鲸落不是普通回收", "body": "鲸落只针对满足条件的长期沉睡收藏，不是日常回收，也不是惩罚活跃玩家。只要玩家保持正常登录和管理收藏，就不会触发鲸落。", "short_tip": "活跃玩家不会因为正常收藏而触发鲸落。"},
	{"id": "loading_tip_whalefall_005", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "真正的收藏会留下痕迹", "body": "CCR 的 relic 会记录它的形成时间和创造者信息。即使某些 relic 未来进入鲸落流程，它们曾经属于谁、何时被创造，仍然是这件收藏历史的一部分。", "short_tip": "Relic 不只是道具，也是 CCR 世界中的历史记录。"},
]

const LOADING_TUTORIAL_TIPS_EN: Array[Dictionary] = [
	{"id": "loading_tip_basic_en", "min_level": 1, "max_level": 999, "title": "Card Pool and Hand", "body": "Drawn cards appear in the card pool. Move cards you want to keep into your hand before drawing again, crafting a relic, or organizing your collection.", "short_tip": "Moving cards from the pool to your hand is the basic collection action."},
	{"id": "loading_tip_craft_en", "min_level": 1, "max_level": 999, "title": "Crafting Relics", "body": "A relic requires five cards from the same series, deck, and color, with one card for each number from 1 to 5. Those five cards are consumed when the relic is crafted.", "short_tip": "Same deck, same color, five different numbers: one relic."},
	{"id": "loading_tip_vault_en", "min_level": 5, "max_level": 999, "title": "The Vault", "body": "The vault is long-term storage. Cards placed there cannot return to your hand, but complete groups of five can still be crafted inside the vault.", "short_tip": "Use your vault slots carefully; storing a card is a one-way action."},
	{"id": "loading_tip_rarity_en", "min_level": 10, "max_level": 999, "title": "Card Rarity", "body": "Card colors progress from white, green, blue, purple, orange, and black to the special red tier. Each draw is independent, and exact rates follow the current server configuration.", "short_tip": "Rarer colors are harder to complete, but every collection choice is yours."},
	{"id": "loading_tip_caps_en", "min_level": 20, "max_level": 999, "title": "Relic Supply Limits", "body": "Higher-rarity relics have global supply limits. The server validates supply and assigns collectible serial numbers when eligible relics are created.", "short_tip": "Advanced relics are long-term collectibles, not routine consumables."},
	{"id": "loading_tip_history_en", "min_level": 30, "max_level": 999, "title": "A Persistent Collection", "body": "CCR records when a relic was created and who created it. A relic is part of the world's history, even if its owner changes in future systems.", "short_tip": "Relics preserve history as well as rarity."},
]

const LOADING_BACKGROUND_PATHS: Array[String] = [
	"res://Resources/Backgrounds/loading_appraisal_workbench.png",
	"res://Resources/Backgrounds/loading_collection_showcase.png",
	"res://Resources/Backgrounds/loading_cosmic_archive_corridor.png",
	"res://Resources/Backgrounds/loading_deep_space_museum_dome.png",
	"res://Resources/Backgrounds/loading_star_map_corridor.png",
]

func _ready() -> void:
	super._ready()

func setup_for_level(level: int) -> void:
	apply_fullscreen_layout()
	if LOADING_BACKGROUND_PATHS.size() > 0:
		var background_path := LOADING_BACKGROUND_PATHS[randi() % LOADING_BACKGROUND_PATHS.size()]
		set_background(load(background_path))
	var tip := _pick_tip(level)
	var category := str(tip.get("category", "tip" if Localization.locale == "en" else "收藏提示"))
	set_tip(category, str(tip.get("title", "Collection Tip" if Localization.locale == "en" else "收藏提示")), str(tip.get("body", "")))
	set_progress(0.0, Localization.t("ui.login.loading.entering"))
	set_server_status(Localization.t("ui.login.loading.online"))
	set_version(_project_version_text())

func set_progress(value: float, status: String = "") -> void:
	super.set_progress(value, status)

func finish() -> void:
	set_progress(100.0, Localization.t("ui.login.loading.done"))
	await get_tree().create_timer(0.35).timeout

func _pick_tip(level: int) -> Dictionary:
	return pick_tip_for_locale(level, Localization.locale)

static func pick_tip_for_locale(level: int, target_locale: String) -> Dictionary:
	var source: Array[Dictionary] = LOADING_TUTORIAL_TIPS_EN if target_locale == "en" else LOADING_TUTORIAL_TIPS
	var available: Array[Dictionary] = []
	for tip in source:
		if level >= int(tip.get("min_level", 1)) and level <= int(tip.get("max_level", 999)):
			available.append(tip)
	if available.is_empty():
		return source[0]
	return available[randi() % available.size()]

func _project_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	if version == "" or version == "dev":
		return "CCR dev"
	return "CCR v" + version
