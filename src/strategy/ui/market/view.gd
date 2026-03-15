class_name MarketView
extends Control

signal closed

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var presenter: Node = $MarketPresenter

var _title_label: Label
var _content_vbox: VBoxContainer
var _goods_container: VBoxContainer
var _production_label: Label
var _pop_vbox: VBoxContainer
var _rumors_vbox: VBoxContainer


func _ready() -> void:
	visible = false
	_rebuild_panel()


func _rebuild_panel() -> void:
	for child in overlay_panel.get_children():
		overlay_panel.remove_child(child)
		child.free()

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	overlay_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Market Board"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(title)
	_title_label = title

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(_content_vbox)

	_build_goods_section()
	_build_production_section()
	_build_population_section()
	_build_rumors_section()

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		hide_market()
		closed.emit()
	)
	main_vbox.add_child(close_btn)


func _build_goods_section() -> void:
	_add_section_header(_content_vbox, "Goods & Prices")
	_goods_container = VBoxContainer.new()
	_goods_container.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(_goods_container)


func _build_production_section() -> void:
	_add_section_header(_content_vbox, "Local Industry")
	_production_label = Label.new()
	_production_label.add_theme_font_size_override("font_size", 14)
	_production_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_production_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(_production_label)


func _build_population_section() -> void:
	_add_section_header(_content_vbox, "Townsfolk")
	_pop_vbox = VBoxContainer.new()
	_pop_vbox.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(_pop_vbox)


func _build_rumors_section() -> void:
	_add_section_header(_content_vbox, "Market Rumors")
	_rumors_vbox = VBoxContainer.new()
	_rumors_vbox.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(_rumors_vbox)


#region Public API

func show_market(world: World, location: Location, visited_ids: Array[String]) -> void:
	visible = true
	overlay_panel.visible = true
	presenter.refresh(world, location, visited_ids)
	await UIAnimations.show_overlay(self, overlay_panel)


func hide_market() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
	visible = false


func display_market(location: Location, goods_cards: Array[Dictionary], production: Array[String], pop_data: Dictionary, rumors: Array[String]) -> void:
	var type_str: String = str(StrategyTypes.LocationType.keys()[location.type]).capitalize()
	_title_label.text = "Market Board — %s (%s)" % [location.location_name, type_str]

	_display_goods(goods_cards)
	_display_production(production)
	_display_population(pop_data)
	_display_rumors(rumors)

#endregion


#region Display Sections

func _display_goods(cards: Array[Dictionary]) -> void:
	_clear_container(_goods_container)
	if cards.is_empty():
		_add_detail(_goods_container, "No goods available", Color(0.5, 0.5, 0.5))
		return

	for card in cards:
		_create_goods_card(card)


func _create_goods_card(data: Dictionary) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	name_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(name_label)

	var stock_label = Label.new()
	stock_label.text = "%.0f" % data["stock"]
	stock_label.add_theme_font_size_override("font_size", 14)
	stock_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stock_label.custom_minimum_size = Vector2(40, 0)
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(stock_label)

	var price_ratio: float = data["price_ratio"]
	var trend_text: String
	var trend_color: Color
	if price_ratio < 0.8:
		trend_text = "%.2f ↓" % data["price"]
		trend_color = Color(0.4, 1.0, 0.4)
	elif price_ratio > 1.3:
		trend_text = "%.2f ↑" % data["price"]
		trend_color = Color(1.0, 0.4, 0.4)
	else:
		trend_text = "%.2f →" % data["price"]
		trend_color = Color(0.8, 0.8, 0.8)

	var price_label = Label.new()
	price_label.text = trend_text
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", trend_color)
	price_label.custom_minimum_size = Vector2(70, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)

	var abundance_ratio: float = data["abundance_ratio"]
	var abundance_bar = ProgressBar.new()
	abundance_bar.min_value = 0.0
	abundance_bar.max_value = 100.0
	abundance_bar.value = clampf(abundance_ratio * 25.0, 0.0, 100.0)
	abundance_bar.custom_minimum_size = Vector2(100, 16)
	abundance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abundance_bar.show_percentage = false
	hbox.add_child(abundance_bar)

	var abundance_text: String
	if abundance_ratio < 0.5:
		abundance_text = "Scarce"
		abundance_bar.modulate = Color(1.0, 0.4, 0.4)
	elif abundance_ratio < 1.5:
		abundance_text = "Moderate"
		abundance_bar.modulate = Color(1.0, 0.9, 0.4)
	elif abundance_ratio < 3.0:
		abundance_text = "Plentiful"
		abundance_bar.modulate = Color(0.4, 1.0, 0.4)
	else:
		abundance_text = "Abundant"
		abundance_bar.modulate = Color(0.3, 0.8, 1.0)

	var desc_label = Label.new()
	desc_label.text = abundance_text
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", abundance_bar.modulate)
	desc_label.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(desc_label)

	_goods_container.add_child(hbox)


func _display_production(production: Array[String]) -> void:
	if production.is_empty():
		_production_label.text = "No local production"
	else:
		_production_label.text = "Produces: %s" % ", ".join(production)


func _display_population(pop_data: Dictionary) -> void:
	_clear_container(_pop_vbox)
	if pop_data.is_empty():
		_add_detail(_pop_vbox, "No population data", Color(0.5, 0.5, 0.5))
		return

	_add_detail(_pop_vbox, "Population: %d" % pop_data["total"], Color(0.8, 0.8, 0.8))
	_add_detail(
		_pop_vbox,
		"  Peasants: %d  |  Bourgeois: %d  |  Nobles: %d" % [pop_data["peasants"], pop_data["bourgeois"], pop_data["nobles"]],
		Color(0.75, 0.75, 0.75)
	)

	var sat: float = pop_data["satisfaction"]
	var sat_color: Color
	var sat_desc: String
	if sat >= 70.0:
		sat_desc = "Content"
		sat_color = Color(0.4, 1.0, 0.4)
	elif sat >= 40.0:
		sat_desc = "Uneasy"
		sat_color = Color(1.0, 0.9, 0.4)
	else:
		sat_desc = "Disgruntled"
		sat_color = Color(1.0, 0.4, 0.4)

	_add_detail(_pop_vbox, "  Satisfaction: %.0f (%s)" % [sat, sat_desc], sat_color)
	_add_detail(_pop_vbox, "  Average Wealth: %.1f" % pop_data["avg_money"], Color(0.85, 0.8, 0.5))


func _display_rumors(rumors: Array[String]) -> void:
	_clear_container(_rumors_vbox)
	if rumors.is_empty():
		_add_detail(_rumors_vbox, "No rumors from other markets", Color(0.5, 0.5, 0.5))
		return

	for rumor in rumors:
		_add_detail(_rumors_vbox, "• %s" % rumor, Color(0.75, 0.75, 0.75))

#endregion


#region Helpers

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	parent.add_child(label)


func _add_detail(parent: VBoxContainer, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()

#endregion
