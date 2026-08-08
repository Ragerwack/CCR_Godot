extends Node

const CountryCatalogScript = preload("res://Scripts/Data/CountryCatalog.gd")

const SIMPLIFIED_TO_TRADITIONAL := {
	"万": "萬", "与": "與", "丢": "丟", "个": "個", "为": "為", "乐": "樂", "于": "於",
	"仪": "儀", "优": "優", "会": "會", "传": "傳", "体": "體", "册": "冊", "写": "寫",
	"准": "準", "击": "擊", "刚": "剛", "务": "務", "动": "動", "励": "勵", "区": "區",
	"卖": "賣", "台": "臺", "号": "號", "后": "後", "吗": "嗎", "启": "啓", "员": "員",
	"围": "圍", "圣": "聖", "处": "處", "备": "備", "复": "復", "头": "頭", "奖": "獎",
	"宝": "寶", "导": "導", "将": "將", "币": "幣", "师": "師", "并": "並", "开": "開",
	"异": "異", "弃": "棄", "张": "張", "当": "當", "录": "錄", "态": "態", "总": "總",
	"戏": "戲", "战": "戰", "户": "戶", "扩": "擴", "择": "擇", "换": "換", "据": "據",
	"摇": "搖", "数": "數", "断": "斷", "无": "無", "时": "時", "显": "顯", "机": "機",
	"权": "權", "条": "條", "极": "極", "柜": "櫃", "标": "標", "档": "檔", "检": "檢",
	"汇": "匯", "没": "沒", "测": "測", "游": "遊", "满": "滿", "点": "點", "状": "狀",
	"现": "現", "盘": "盤", "码": "碼", "础": "礎", "确": "確", "种": "種", "称": "稱",
	"稳": "穩", "简": "簡", "类": "類", "红": "紅", "级": "級", "线": "線", "组": "組",
	"经": "經", "结": "結", "络": "絡", "继": "繼", "续": "續", "绿": "綠", "编": "編",
	"网": "網", "范": "範", "获": "獲", "蓝": "藍", "蜡": "蠟", "装": "裝", "见": "見",
	"观": "觀", "计": "計", "认": "認", "记": "記", "设": "設", "证": "證", "译": "譯",
	"试": "試", "诗": "詩", "话": "話", "语": "語", "说": "說", "请": "請", "读": "讀",
	"败": "敗", "账": "賬", "费": "費", "资": "資", "赠": "贈", "载": "載", "辉": "輝",
	"还": "還", "这": "這", "进": "進", "远": "遠", "连": "連", "选": "選", "邮": "郵",
	"里": "裡", "鉴": "鑑", "钥": "鑰", "锁": "鎖", "键": "鍵", "锻": "鍛", "镜": "鏡",
	"长": "長", "间": "間", "队": "隊", "险": "險", "随": "隨", "静": "靜", "页": "頁",
	"顺": "順", "预": "預", "频": "頻", "馆": "館", "驼": "駝", "骆": "駱", "验": "驗",
	"骤": "驟", "鸟": "鳥", "鸵": "鴕", "齐": "齊",
}

func _ready() -> void:
	var base: Dictionary = Localization._texts["en"]
	for target_locale in ["ja", "ko"]:
		var overrides: Dictionary = Localization._locale_overrides[target_locale]
		if overrides.size() != base.size():
			_fail("%s key_count=%d expected=%d" % [target_locale, overrides.size(), base.size()])
			return
		for key in base.keys():
			if not overrides.has(key):
				_fail("%s missing=%s" % [target_locale, key])
				return

	var native_language_labels := {
		"zh-CN": "简体中文",
		"en": "English",
		"zh-TW": "繁體中文",
		"ja": "日本語",
		"ko": "한국어",
	}
	for target_locale in Localization.get_supported_locales():
		Localization.set_locale(str(target_locale))
		for language_locale in native_language_labels.keys():
			if Localization.language_label(str(language_locale)) != native_language_labels[language_locale]:
				_fail("language option is not native locale=%s current=%s" % [language_locale, target_locale])
				return

	var earth_user_id := 987654321
	Localization.save_account_locale_preference("ja", earth_user_id)
	Localization.set_locale("en")
	Localization.apply_account_default("EARTH", earth_user_id)
	if Localization.locale != "ja":
		_fail("EARTH account did not restore registration locale")
		return
	Config.set_value("localization", "user_%d" % earth_user_id, "")

	Localization.set_locale("ja")
	if Localization.t("ui.menu.title") != "設定" or Localization.t("ui.nav.vault") != "保管庫":
		_fail("ja sample text did not switch")
		return
	if not Localization.t("ui.synthesis.title").contains("聖物") or Localization.t("ui.synthesis.title").contains("レリック") or Localization.t("ui.login.loading.entering") != "万象カード界へ移動中":
		_fail("ja CCR glossary terms are inconsistent")
		return
	Localization.set_locale("ko")
	if Localization.t("ui.menu.title") != "설정" or Localization.t("ui.nav.vault") != "보관함":
		_fail("ko sample text did not switch")
		return
	if not Localization.t("ui.synthesis.title").contains("성물") or Localization.t("ui.synthesis.title").contains("렐릭") or Localization.t("ui.login.loading.entering") != "만상 카드계로 이동 중":
		_fail("ko CCR glossary terms are inconsistent")
		return
	var ja_countries: Array[Dictionary] = CountryCatalogScript.localized_entries("ja")
	var ko_countries: Array[Dictionary] = CountryCatalogScript.localized_entries("ko")
	if _country_label(ja_countries, "CN") != "中国" or _country_label(ko_countries, "CN") != "중국":
		_fail("country names did not switch with locale")
		return
	var zh_tw_countries: Array[Dictionary] = CountryCatalogScript.localized_entries("zh-TW")
	if _country_label(zh_tw_countries, "CN") != "中國" or _country_label(zh_tw_countries, "HK") != "中國香港":
		_fail("traditional country names did not convert")
		return

	Localization.set_locale("zh-TW")
	for key in base.keys():
		var simplified := str(Localization._texts["zh-CN"].get(key, ""))
		var traditional := Localization.t(str(key))
		for source in SIMPLIFIED_TO_TRADITIONAL.keys():
			if simplified.contains(source) and traditional.contains(source):
				_fail("zh-TW contains simplified character key=%s char=%s text=%s" % [key, source, traditional])
				return

	Localization.set_locale("en")
	print("LOCALE_COMPLETENESS ok keys=%d locales=5" % base.size())
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("LOCALE_COMPLETENESS " + message)
	get_tree().quit(1)

func _country_label(entries: Array[Dictionary], code: String) -> String:
	for entry in entries:
		if str(entry.get("code", "")) == code:
			return str(entry.get("label", ""))
	return ""
