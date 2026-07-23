extends LoadingScreenUI
class_name LoadingTutorialUI

const LOADING_TUTORIAL_TIPS: Array[Dictionary] = [
	{"id": "loading_tip_basic_001", "min_level": 1, "max_level": 999, "category": "basic", "title": "卡池与手牌", "body": "卡池中会出现当前可抽取的卡牌。你可以将卡池里的卡牌拖到手牌中，先暂时保留，再决定是否继续收集、合成或整理。", "short_tip": "先把卡池里的卡拖到手牌，这是 CCR 最基础的收藏动作。"},
	{"id": "loading_tip_basic_002", "min_level": 1, "max_level": 999, "category": "basic", "title": "什么是卡组", "body": "CCR 中的每个主题都是一个卡组。一个卡组通常由 5 张子卡组成，每张子卡都有自己的编号。", "short_tip": "同一个卡组的 5 张子卡，是合成圣物的基础材料。"},
	{"id": "loading_tip_basic_003", "min_level": 1, "max_level": 999, "category": "basic", "title": "合成圣物的条件", "body": "合成圣物需要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡。例如：同一套卡组的白色 1/5、2/5、3/5、4/5、5/5，可以合成一个白色圣物。", "short_tip": "同卡组、同颜色、5个不同编号，才能合成圣物。"},
	{"id": "loading_tip_basic_004", "min_level": 1, "max_level": 999, "category": "basic", "title": "合成会消耗卡牌", "body": "当你合成圣物时，用于合成的 5 张子卡会被消耗，并转化为一个完整圣物。圣物是 CCR 中更长期、更稳定的收藏单位。", "short_tip": "卡牌是材料，圣物是成品收藏。"},
	{"id": "loading_tip_basic_005", "min_level": 1, "max_level": 999, "category": "basic", "title": "不要急着合成所有卡牌", "body": "有些卡牌适合马上合成，有些卡牌适合先保留。CCR 是长期收藏游戏，仓位、稀有度、卡组主题都会影响你的选择。", "short_tip": "CCR 的核心不是抽得快，而是判断什么值得留下。"},
	{"id": "loading_tip_basic_006", "min_level": 1, "max_level": 999, "category": "basic", "title": "先看清当前卡组", "body": "每次抽卡前，先看清当前可见卡组。不同卡组对应不同的收藏方向，选择目标比盲目抽取更重要。", "short_tip": "先看卡组，再决定今天想补什么。"},
	{"id": "loading_tip_vault_001", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱是什么", "body": "保险箱是用于长期保存卡牌的地方。和手牌不同，保险箱更像你的永久收藏柜，适合存放你暂时不想合成、但又不想丢掉的卡牌。", "short_tip": "手牌适合临时整理，保险箱适合长期收藏。"},
	{"id": "loading_tip_vault_002", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱只进不出", "body": "放入保险箱的卡牌不能再取回手牌。放入前请确认清楚：这张卡是否值得长期保存，是否属于你真正想收藏或未来想合成的卡组。", "short_tip": "保险箱是单向收藏空间，放入前要慎重。"},
	{"id": "loading_tip_vault_003", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱也可以合成", "body": "保险箱中的卡牌也可以参与 5 张合成。只要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡，就可以在保险箱中合成圣物。", "short_tip": "保险箱不是死仓库，它也能慢慢凑出圣物。"},
	{"id": "loading_tip_vault_004", "min_level": 5, "max_level": 999, "category": "vault", "title": "长期收藏需要仓位判断", "body": "保险箱空间是珍贵资源。你可以选择保存热门卡组，也可以选择保存冷门但有个人意义的卡组。真正的收藏价值，往往来自长期判断。", "short_tip": "不是每张卡都值得留下，但留下哪张卡是你的选择。"},
	{"id": "loading_tip_vault_005", "min_level": 5, "max_level": 999, "category": "vault", "title": "冷门卡组也可能有价值", "body": "有些卡组今天看起来冷门，但未来可能因为纪念意义、玩家情感或历史事件而变得重要。CCR 的收藏价值不只来自稀有度，也来自时间。", "short_tip": "时间本身，也是 CCR 的一部分。"},
	{"id": "loading_tip_vault_006", "min_level": 5, "max_level": 999, "category": "vault", "title": "保险箱也要留出空间", "body": "不要把所有卡牌都放进保险箱。手牌需要保留流动空间，保险箱也应优先留给真正想长期沉淀的收藏。", "short_tip": "保险箱保护收藏，手牌保留选择。"},
	{"id": "loading_tip_daily_001", "min_level": 5, "max_level": 999, "category": "daily", "title": "今日可见卡组", "body": "每天服务器会展示一批当前可见卡组。所有玩家共享同一套每日节奏，但不同等级能看到的卡组数量不同。", "short_tip": "升级会逐步打开更完整的收藏视野。"},
	{"id": "loading_tip_daily_002", "min_level": 5, "max_level": 999, "category": "daily", "title": "新卡组的可见窗口", "body": "今天、昨天和前天的新卡组都会在当前可见范围内出现。想补齐某个卡组时，不必只盯着当天。", "short_tip": "新卡组会连续出现几天，留意补齐机会。"},
	{"id": "loading_tip_daily_003", "min_level": 5, "max_level": 999, "category": "daily", "title": "旧卡组仍会再见", "body": "暂时不在今日列表中的旧卡组，之后仍可能通过每日随机卡组再次出现。长期收藏不必急于一次完成。", "short_tip": "错过不是终点，旧卡组仍可能回归。"},
	{"id": "loading_tip_daily_004", "min_level": 5, "max_level": 999, "category": "daily", "title": "每天看一眼今日卡组", "body": "载入完成后，先看看今日可见卡组。确认目标、补齐缺口，是 CCR 最基础的长期收藏习惯。", "short_tip": "每天先看今日卡组，再开始整理收藏。"},
	{"id": "loading_tip_rarity_001", "min_level": 10, "max_level": 999, "category": "rarity", "title": "卡牌颜色代表稀有度", "body": "CCR 的卡牌颜色从常见到稀有依次为：白、绿、蓝、紫、橙、黑。颜色越稀有，合成对应颜色圣物的难度越高。", "short_tip": "白、绿、蓝、紫、橙、黑，越往后越稀有。"},
	{"id": "loading_tip_rarity_002", "min_level": 10, "max_level": 999, "category": "rarity", "title": "每次抽卡都是独立随机", "body": "每一次抽卡都会独立决定颜色结果。之前抽到了什么，不会改变下一次抽卡的颜色概率。CCR 的稀有收藏来自长期随机，而不是短期保证。", "short_tip": "每次抽卡独立随机，不要把上一次结果当成下一次的预告。"},
	{"id": "loading_tip_rarity_003", "min_level": 10, "max_level": 999, "category": "rarity", "title": "颜色概率", "body": "不同颜色拥有不同出现概率。白色最常见，绿色、蓝色、紫色逐渐稀有，橙色及以上属于极稀有收藏。具体概率以当前版本的游戏内公示和服务器配置为准。", "short_tip": "颜色概率请以游戏内当前版本公示为准。"},
	{"id": "loading_tip_rarity_004", "min_level": 10, "max_level": 999, "category": "rarity", "title": "稀有颜色不等于一定更适合你", "body": "高稀有度卡牌更难获得，但不代表每一张都必须留下。你真正喜欢的卡组、与你有情感连接的主题，也可能比单纯的颜色更重要。", "short_tip": "稀有度决定难度，收藏价值由你决定。"},
	{"id": "loading_tip_rarity_005", "min_level": 10, "max_level": 999, "category": "rarity", "title": "白卡也有收藏意义", "body": "白卡虽然常见，但它们也记录了卡组、日期和玩家选择。对于长期收藏游戏来说，早期白卡、特殊主题白卡、个人记忆相关白卡，也可能拥有自己的价值。", "short_tip": "CCR 中，常见不等于没有意义。"},
	{"id": "loading_tip_rarity_006", "min_level": 10, "max_level": 999, "category": "rarity", "title": "橙卡与黑卡", "body": "橙卡和黑卡都非常稀有。它们值得珍惜，但不必把每天获得高稀有度卡牌当成唯一目标。", "short_tip": "稀有值得等待，完整收藏同样重要。"},
	{"id": "loading_tip_rarity_007", "min_level": 10, "max_level": 999, "category": "rarity", "title": "收藏也需要留白", "body": "CCR 不需要每天都出现高稀有度卡牌。慢慢补齐卡组、保留选择，正是长期收藏的一部分。", "short_tip": "不急于出稀有，慢慢补齐也很重要。"},
	{"id": "loading_tip_relic_001", "min_level": 10, "max_level": 999, "category": "圣物", "title": "锻造前确认卡组", "body": "锻造前请确认 5 张子卡属于同一卡组、同一颜色且编号完整。正确的组合，才能形成一枚圣物。", "short_tip": "同组、同色、1 到 5，才是一套完整材料。"},
	{"id": "loading_tip_relic_002", "min_level": 10, "max_level": 999, "category": "圣物", "title": "完整也是收藏价值", "body": "收藏不只是追逐最高稀有度。完整、早期、成系列的圣物，也会让你的博物馆留下独特的时间痕迹。", "short_tip": "完整收藏，本身就是值得珍惜的成就。"},
	{"id": "loading_tip_cap_001", "min_level": 20, "max_level": 999, "category": "cap", "title": "圣物有颜色数量上限", "body": "不同颜色的圣物拥有不同数量上限。越稀有的颜色，服务器允许存在的圣物数量越少。这个机制让高级圣物成为真正稀缺的长期收藏品。", "short_tip": "高级颜色圣物的稀缺，不只来自概率，也来自数量上限。"},
	{"id": "loading_tip_cap_002", "min_level": 20, "max_level": 999, "category": "cap", "title": "为什么高级圣物很难合成", "body": "合成高级圣物需要先获得同卡组、同颜色、5个不同编号的子卡。同时，高级颜色圣物还受到服务器数量上限影响。因此，高级圣物不是短期目标，而是长期收藏目标。", "short_tip": "高级圣物是长期收藏目标，不是日常消耗品。"},
	{"id": "loading_tip_cap_003", "min_level": 20, "max_level": 999, "category": "cap", "title": "达到上限后的颜色降级", "body": "当某个卡组的某种颜色圣物已达到服务器数量上限后，后续原本会生成该颜色的卡牌，会按照规则降到下一档可用颜色。这样可以维持系统稀缺性，同时避免新卡牌完全无法产生。", "short_tip": "满上限后，高级颜色会按规则降到下一档可用颜色。"},
	{"id": "loading_tip_cap_004", "min_level": 20, "max_level": 999, "category": "cap", "title": "颜色降级不代表失败", "body": "颜色降级是 CCR 世界规则的一部分。它说明某个颜色的圣物已经被玩家铸造到上限，新的收藏会自然流向下一个可用颜色层级。", "short_tip": "降级不是惩罚，而是稀缺系统的自然结果。"},
	{"id": "loading_tip_cap_005", "min_level": 20, "max_level": 999, "category": "cap", "title": "越早形成的圣物越特殊", "body": "当一个卡组的高级颜色圣物接近上限时，早期合成的圣物会变得更特殊。它们不仅代表稀有颜色，也代表玩家在 CCR 历史中的早期选择。", "short_tip": "圣物记录的不只是颜色，也记录时间。"},
	{"id": "loading_tip_whalefall_001", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "什么是鲸落", "body": "如果一个拥有重要收藏的玩家长期离开 CCR，他的部分橙色以及以上圣物可能会在规则触发后进入鲸落流程。鲸落不是删除收藏，而是让沉睡的稀有收藏重新回到世界循环中。", "short_tip": "鲸落让沉睡的收藏重新进入 CCR 世界。"},
	{"id": "loading_tip_whalefall_002", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "2年不上线触发鲸落", "body": "当玩家连续 2 年不上线，并且满足鲸落条件时，系统会触发鲸落机制。相关圣物会按照规则进入后续处理流程，让其他玩家有机会重新见到这些沉睡的收藏。", "short_tip": "连续 2 年不上线，可能触发鲸落机制。"},
	{"id": "loading_tip_whalefall_003", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "鲸落是 CCR 的长期生态机制", "body": "CCR 是一个长期运行的收藏世界。鲸落机制用于处理长期沉睡的橙色以及以上圣物，让稀有圣物不会永远消失在无人登录的账号中。", "short_tip": "鲸落保护的是整个 CCR 世界的长期流动性。"},
	{"id": "loading_tip_whalefall_004", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "鲸落不是普通回收", "body": "鲸落只针对满足条件的长期沉睡收藏，不是日常回收，也不是惩罚活跃玩家。只要玩家保持正常登录和管理收藏，就不会触发鲸落。", "short_tip": "活跃玩家不会因为正常收藏而触发鲸落。"},
	{"id": "loading_tip_whalefall_005", "min_level": 30, "max_level": 999, "category": "whalefall", "title": "真正的收藏会留下痕迹", "body": "CCR 的圣物会记录它的形成时间和创造者信息。即使某些圣物未来进入鲸落流程，它们曾经属于谁、何时被创造，仍然是这件收藏历史的一部分。", "short_tip": "圣物不只是道具，也是 CCR 世界中的历史记录。"},
]

const LOADING_TUTORIAL_TIPS_EN: Array[Dictionary] = [
	{"id": "loading_tip_basic_en", "min_level": 1, "max_level": 999, "title": "Card Pool and Hand", "body": "Drawn cards appear in the card pool. Move cards you want to keep into your hand before drawing again, forging a relic, or organizing your collection.", "short_tip": "Moving cards from the pool to your hand is the basic collection action."},
	{"id": "loading_tip_craft_en", "min_level": 1, "max_level": 999, "title": "Forging Relics", "body": "A relic requires five cards from the same series, deck, and color, with one card for each number from 1 to 5. Those five cards are consumed when the relic is forged.", "short_tip": "Same deck, same color, five different numbers: one relic."},
	{"id": "loading_tip_vault_en", "min_level": 5, "max_level": 999, "title": "The Vault", "body": "The vault is long-term storage. Cards placed there cannot return to your hand, but complete groups of five can still be forged inside the vault.", "short_tip": "Use your vault slots carefully; storing a card is a one-way action."},
	{"id": "loading_tip_rarity_en", "min_level": 10, "max_level": 999, "title": "Card Rarity", "body": "Card colors range from white through green, blue, purple, orange, and black. Each draw is independent, and exact rates follow the current server configuration.", "short_tip": "Rarer colors are harder to complete, but every collection choice is yours."},
	{"id": "loading_tip_caps_en", "min_level": 20, "max_level": 999, "title": "Relic Supply Limits", "body": "Higher-rarity relics have global supply limits. The server validates supply and assigns collectible serial numbers when eligible relics are created.", "short_tip": "Advanced relics are long-term collectibles, not routine consumables."},
	{"id": "loading_tip_history_en", "min_level": 30, "max_level": 999, "title": "A Persistent Collection", "body": "CCR records when a relic was created and who created it. A relic is part of the world's history, even if its owner changes in future systems.", "short_tip": "Relics preserve history as well as rarity."},
]

const LOADING_TUTORIAL_TIPS_ZH_TW: Array[Dictionary] = [
	{"id": "loading_tip_basic_zh_tw", "min_level": 1, "max_level": 999, "category": "basic", "title": "卡池與手牌", "body": "卡池中會出現目前可抽取的卡牌。你可以先把想留下的卡牌移到手牌，再決定是否繼續抽取、鍛造聖物或整理收藏。", "short_tip": "先把卡池裡的卡移到手牌，這是 CCR 最基礎的收藏動作。"},
	{"id": "loading_tip_forge_zh_tw", "min_level": 1, "max_level": 999, "category": "forge", "title": "鍛造聖物", "body": "鍛造聖物需要同系列、同卡組、同顏色，並湊齊 1 到 5 號五張子卡。鍛造完成後，這五張子卡會被消耗。", "short_tip": "同卡組、同顏色、五個不同編號，才能形成一枚聖物。"},
	{"id": "loading_tip_vault_zh_tw", "min_level": 5, "max_level": 999, "category": "vault", "title": "保險箱", "body": "保險箱是長期保存卡牌的地方。放入後不能回到手牌，但湊齊五張時仍然可以在保險箱中鍛造聖物。", "short_tip": "謹慎使用保險箱槽位；存入卡牌是單向動作。"},
	{"id": "loading_tip_rarity_zh_tw", "min_level": 10, "max_level": 999, "category": "rarity", "title": "卡牌稀有度", "body": "卡牌顏色從白、綠、藍、紫、橙到黑逐步稀有。每次抽卡都是獨立隨機，具體概率以目前伺服器配置為準。", "short_tip": "稀有顏色更難集齊，但收藏取捨由你決定。"},
	{"id": "loading_tip_caps_zh_tw", "min_level": 20, "max_level": 999, "category": "cap", "title": "聖物數量上限", "body": "高稀有度聖物有全域數量上限。伺服器會驗證上限，並在符合條件時分配可收藏的公開編號。", "short_tip": "高階聖物是長期收藏品，不是日常消耗品。"},
	{"id": "loading_tip_history_zh_tw", "min_level": 30, "max_level": 999, "category": "history", "title": "持續存在的收藏", "body": "CCR 會記錄聖物何時被創造，以及誰創造了它。即使未來擁有者改變，聖物仍然是世界歷史的一部分。", "short_tip": "聖物保存的不只是稀有度，也保存歷史。"},
]

const LOADING_TUTORIAL_TIPS_JA: Array[Dictionary] = [
	{"id": "loading_tip_basic_ja", "min_level": 1, "max_level": 999, "category": "basic", "title": "カードプールと手札", "body": "引いたカードはカードプールに表示されます。残したいカードを手札に移してから、次のドロー、レリックの鍛造、コレクション整理を判断できます。", "short_tip": "プールから手札へ移すことが、CCR の基本的な収集操作です。"},
	{"id": "loading_tip_forge_ja", "min_level": 1, "max_level": 999, "category": "forge", "title": "レリックの鍛造", "body": "レリックには、同じシリーズ、デッキ、色で、1 から 5 までの番号がそろった 5 枚のカードが必要です。鍛造時にその 5 枚は消費されます。", "short_tip": "同じデッキ、同じ色、5 つの異なる番号で 1 つのレリックになります。"},
	{"id": "loading_tip_vault_ja", "min_level": 5, "max_level": 999, "category": "vault", "title": "保管庫", "body": "保管庫は長期保存用の場所です。入れたカードは手札へ戻せませんが、5 枚の組み合わせがそろえば保管庫内でも鍛造できます。", "short_tip": "保管庫スロットは慎重に使ってください。保存は一方通行です。"},
	{"id": "loading_tip_rarity_ja", "min_level": 10, "max_level": 999, "category": "rarity", "title": "カードのレアリティ", "body": "カードの色は白、緑、青、紫、橙、黒の順に希少になります。各ドローは独立しており、正確な確率は現在のサーバー設定に従います。", "short_tip": "希少な色ほど完成は難しくなりますが、何を集めるかはあなた次第です。"},
	{"id": "loading_tip_caps_ja", "min_level": 20, "max_level": 999, "category": "cap", "title": "レリック供給上限", "body": "高レアリティのレリックには全体の供給上限があります。サーバーが上限を検証し、対象となるレリックには収集番号を割り当てます。", "short_tip": "高位レリックは長期収集品であり、日常消耗品ではありません。"},
	{"id": "loading_tip_history_ja", "min_level": 30, "max_level": 999, "category": "history", "title": "残り続けるコレクション", "body": "CCR はレリックがいつ、誰によって作られたかを記録します。将来所有者が変わっても、そのレリックは世界の歴史の一部です。", "short_tip": "レリックは希少性だけでなく、歴史も保存します。"},
]

const LOADING_TUTORIAL_TIPS_KO: Array[Dictionary] = [
	{"id": "loading_tip_basic_ko", "min_level": 1, "max_level": 999, "category": "basic", "title": "카드 풀과 손패", "body": "뽑은 카드는 카드 풀에 표시됩니다. 남기고 싶은 카드를 손패로 옮긴 뒤 다음 뽑기, 렐릭 제작, 컬렉션 정리를 결정할 수 있습니다.", "short_tip": "풀에서 손패로 카드를 옮기는 것이 CCR의 기본 수집 행동입니다."},
	{"id": "loading_tip_forge_ko", "min_level": 1, "max_level": 999, "category": "forge", "title": "렐릭 제작", "body": "렐릭을 만들려면 같은 시리즈, 같은 덱, 같은 색의 1번부터 5번까지 카드 다섯 장이 필요합니다. 제작 시 그 다섯 장은 소비됩니다.", "short_tip": "같은 덱, 같은 색, 서로 다른 다섯 번호가 하나의 렐릭이 됩니다."},
	{"id": "loading_tip_vault_ko", "min_level": 5, "max_level": 999, "category": "vault", "title": "보관함", "body": "보관함은 장기 보관 공간입니다. 넣은 카드는 손패로 되돌릴 수 없지만, 다섯 장 조합이 완성되면 보관함 안에서도 렐릭을 제작할 수 있습니다.", "short_tip": "보관함 슬롯은 신중하게 사용하세요. 저장은 되돌릴 수 없는 행동입니다."},
	{"id": "loading_tip_rarity_ko", "min_level": 10, "max_level": 999, "category": "rarity", "title": "카드 희귀도", "body": "카드 색은 흰색, 초록, 파랑, 보라, 주황, 검정 순으로 희귀해집니다. 각 뽑기는 독립적이며 정확한 확률은 현재 서버 설정을 따릅니다.", "short_tip": "희귀한 색일수록 완성은 어렵지만, 무엇을 수집할지는 당신의 선택입니다."},
	{"id": "loading_tip_caps_ko", "min_level": 20, "max_level": 999, "category": "cap", "title": "렐릭 공급 한도", "body": "높은 희귀도의 렐릭에는 전체 공급 한도가 있습니다. 서버가 한도를 검증하고, 조건에 맞는 렐릭에는 수집 번호를 부여합니다.", "short_tip": "상위 렐릭은 장기 수집품이지 일상 소모품이 아닙니다."},
	{"id": "loading_tip_history_ko", "min_level": 30, "max_level": 999, "category": "history", "title": "지속되는 컬렉션", "body": "CCR은 렐릭이 언제, 누가 만들었는지 기록합니다. 미래에 소유자가 바뀌더라도 그 렐릭은 세계의 역사 일부입니다.", "short_tip": "렐릭은 희귀도뿐 아니라 역사도 보존합니다."},
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
	var category := str(tip.get("category", Localization.t("ui.loading_tip.default_category")))
	set_tip(category, str(tip.get("title", Localization.t("ui.loading_tip.default_title"))), str(tip.get("body", "")), str(tip.get("short_tip", "")))
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
	var source := _tip_source_for_locale(target_locale)
	var available: Array[Dictionary] = []
	for tip in source:
		if level >= int(tip.get("min_level", 1)) and level <= int(tip.get("max_level", 999)):
			available.append(tip)
	if available.is_empty():
		return source[0]
	return available[randi() % available.size()]

static func _tip_source_for_locale(target_locale: String) -> Array[Dictionary]:
	match target_locale:
		"zh-CN":
			return LOADING_TUTORIAL_TIPS
		"zh-TW":
			return LOADING_TUTORIAL_TIPS_ZH_TW
		"ja":
			return LOADING_TUTORIAL_TIPS_JA
		"ko":
			return LOADING_TUTORIAL_TIPS_KO
		_:
			return LOADING_TUTORIAL_TIPS_EN

func _project_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	if version == "" or version == "dev":
		return "CCR dev"
	return "CCR v" + version
