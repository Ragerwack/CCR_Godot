class_name CardColor
extends RefCounted

# 颜色枚举: 白=1, 绿=2, 蓝=3, 紫=4, 橙=5, 黑=6, 红=7
enum ColorType { WHITE, GREEN, BLUE, PURPLE, ORANGE, BLACK, RED }

const NAMES: Array[String] = ["白", "绿", "蓝", "紫", "橙", "黑", "红"]
const RARITY: Array[int] = [1, 2, 3, 4, 5, 6, 7]
const EXP_VALUES: Array[int] = [20, 40, 60, 100, 200, 400, 1000]
const GLOBAL_LIMITS: Array[int] = [0, 1000000, 30000, 900, 30, 1, 1]

# 颜色概率（万分比）
const COLOR_WEIGHTS: Array[float] = [
	10000.0,  # WHITE 基础
	1000.0,   # GREEN 10%
	100.0,    # BLUE 1%
	10.0,     # PURPLE 0.1%
	1.0,      # ORANGE 0.01%
	0.1,      # BLACK 0.001%
	0.0,      # RED 终极
]

# 降级链: 红→黑→橙→紫→蓝→绿→白
const DEMOTE_CHAIN: Array[ColorType] = [
	ColorType.RED,
	ColorType.BLACK,
	ColorType.ORANGE,
	ColorType.PURPLE,
	ColorType.BLUE,
	ColorType.GREEN,
	ColorType.WHITE,
]

static func display_name(c: ColorType) -> String:
	return NAMES[c]

static func get_rarity(c: ColorType) -> int:
	return RARITY[c]

static func get_exp(c: ColorType) -> int:
	return EXP_VALUES[c]

static func get_global_limit(c: ColorType) -> int:
	return GLOBAL_LIMITS[c]

static func get_weight(c: ColorType) -> float:
	return COLOR_WEIGHTS[c]

# 获取降级后的颜色
static func demote(c: ColorType) -> ColorType:
	var idx: int = DEMOTE_CHAIN.find(c)
	if idx > 0:
		return DEMOTE_CHAIN[idx - 1]
	return ColorType.WHITE

# 从字符串创建颜色（不区分大小写，兼容服务端返回的英文小写）
static func from_string(s: String) -> ColorType:
	var upper = s.to_upper()
	match upper:
		"白", "WHITE": return ColorType.WHITE
		"绿", "GREEN": return ColorType.GREEN
		"蓝", "BLUE": return ColorType.BLUE
		"紫", "PURPLE": return ColorType.PURPLE
		"橙", "ORANGE": return ColorType.ORANGE
		"黑", "BLACK": return ColorType.BLACK
		"红", "RED": return ColorType.RED
	return ColorType.WHITE
