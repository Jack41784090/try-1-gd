class_name MarketView
extends Control

signal closed

const GOODS_CARD_SCENE = preload("res://scenes/ui/market_goods_card.tscn")
const LABEL_SCENE = preload("res://scenes/ui/styled_label.tscn")

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var presenter: Node = $MarketPresenter
@onready var _title_label: Label = $OverlayPanel/MarginContainer/MainVBox/TitleLabel
@onready var _goods_container: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentScroll/ContentVBox/GoodsContainer
@onready var _production_label: Label = $OverlayPanel/MarginContainer/MainVBox/ContentScroll/ContentVBox/ProductionLabel
@onready var _pop_vbox: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentScroll/ContentVBox/PopulationVBox
@onready var _rumors_vbox: VBoxContainer = $OverlayPanel/MarginContainer/MainVBox/ContentScroll/ContentVBox/RumorsVBox
@onready var _close_btn: Button = $OverlayPanel/MarginContainer/MainVBox/CloseButton


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(func():
		hide_market()
		closed.emit()
	)



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

	_clear_container(_goods_container)
	if goods_cards.is_empty():
		_add_detail(_goods_container, "No goods available", Color(0.5, 0.5, 0.5))
	else:
		for card in goods_cards:
			var card_node: HBoxContainer = GOODS_CARD_SCENE.instantiate()
			var name_label: Label = card_node.get_node("NameLabel")
			var stock_label: Label = card_node.get_node("StockLabel")
			var price_label: Label = card_node.get_node("PriceLabel")
			var abundance_bar: ProgressBar = card_node.get_node("AbundanceBar")
			var abundance_label: Label = card_node.get_node("AbundanceLabel")
			name_label.text = card["name"]
			stock_label.text = "%.0f" % card["stock"]
			var price_ratio: float = card["price_ratio"]
			if price_ratio < 0.8:
				price_label.text = "%.2f ↓" % card["price"]
				price_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			elif price_ratio > 1.3:
				price_label.text = "%.2f ↑" % card["price"]
				price_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			else:
				price_label.text = "%.2f →" % card["price"]
				price_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			var abundance_ratio: float = card["abundance_ratio"]
			abundance_bar.value = clampf(abundance_ratio * 25.0, 0.0, 100.0)
			if abundance_ratio < 0.5:
				abundance_label.text = "Scarce"
				abundance_bar.modulate = Color(1.0, 0.4, 0.4)
			elif abundance_ratio < 1.5:
				abundance_label.text = "Moderate"
				abundance_bar.modulate = Color(1.0, 0.9, 0.4)
			elif abundance_ratio < 3.0:
				abundance_label.text = "Plentiful"
				abundance_bar.modulate = Color(0.4, 1.0, 0.4)
			else:
				abundance_label.text = "Abundant"
				abundance_bar.modulate = Color(0.3, 0.8, 1.0)
			abundance_label.add_theme_color_override("font_color", abundance_bar.modulate)
			_goods_container.add_child(card_node)

	if production.is_empty():
		_production_label.text = "No local production"
	else:
		_production_label.text = "Produces: %s" % ", ".join(production)

	_clear_container(_pop_vbox)
	if pop_data.is_empty():
		_add_detail(_pop_vbox, "No population data", Color(0.5, 0.5, 0.5))
	else:
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

	_clear_container(_rumors_vbox)
	if rumors.is_empty():
		_add_detail(_rumors_vbox, "No rumors from other markets", Color(0.5, 0.5, 0.5))
	else:
		for rumor in rumors:
			_add_detail(_rumors_vbox, "• %s" % rumor, Color(0.75, 0.75, 0.75))

#endregion


#region Helpers

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	parent.add_child(label)


func _add_detail(parent: VBoxContainer, text: String, color: Color) -> void:
	var label: Label = LABEL_SCENE.instantiate()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()

#endregion
