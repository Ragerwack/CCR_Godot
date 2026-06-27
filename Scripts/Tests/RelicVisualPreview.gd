extends Node

const RELIC_VIEW_SCENE := preload("res://Scenes/UI/RelicView.tscn")
const ALL_COLORS := [
	CardColor.ColorType.WHITE,
	CardColor.ColorType.GREEN,
	CardColor.ColorType.BLUE,
	CardColor.ColorType.PURPLE,
	CardColor.ColorType.ORANGE,
	CardColor.ColorType.BLACK,
	CardColor.ColorType.RED,
]

func _ready() -> void:
	$Title.text = "七色 Relic · Godot 正式运行时渲染"
	for index in range(ALL_COLORS.size()):
		var color_type: int = ALL_COLORS[index]
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		$Scroll/Gallery.add_child(column)

		var label := Label.new()
		label.text = CardColor.NAMES[color_type] + " Relic"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 1.0))
		column.add_child(label)

		var relic_view := RELIC_VIEW_SCENE.instantiate() as RelicView
		relic_view.set_relic_color(color_type)
		column.add_child(relic_view)
		await get_tree().process_frame
		var relic_height := minf(get_viewport().get_visible_rect().size.y - 155.0, 560.0)
		var relic_width := relic_height * relic_view.get_aspect_ratio()
		relic_view.custom_minimum_size = Vector2(relic_width, relic_height)
		relic_view.size = relic_view.custom_minimum_size
		var cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(index + 1)
		relic_view.set_cards(cards)
	# 纹理完成首次布局后再归零，避免 ScrollContainer 自动跟随最后加入的控件。
	for _frame in range(4):
		await get_tree().process_frame
		$Scroll.scroll_horizontal = 0
