class_name ShopView extends Control

signal item_quantity_changed(item_type: StrategyTypes.ItemType, delta: int)
signal confirm_pressed
signal pay_pressed
signal back_pressed
signal closed

@onready var overlay_panel: PanelContainer = $OverlayPanel
@onready var title_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var money_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/MoneyLabel
@onready var items_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer/ScrollContainer/ItemsContainer
@onready var total_label: Label = $OverlayPanel/MarginContainer/VBoxContainer/TotalLabel
@onready var confirm_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/ConfirmButton
@onready var close_button: Button = $OverlayPanel/MarginContainer/VBoxContainer/CloseButton
@onready var browsing_container: VBoxContainer = $OverlayPanel/MarginContainer/VBoxContainer
@onready var confirmation_panel: PanelContainer = $OverlayPanel/MarginContainer/ConfirmationPanel
@onready var confirm_title_label: Label = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/ConfirmTitleLabel
@onready var summary_container: VBoxContainer = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/SummaryContainer
@onready var total_summary_label: Label = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/TotalSummaryLabel
@onready var remaining_label: Label = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/RemainingLabel
@onready var pay_button: Button = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/ButtonsHBox/PayButton
@onready var back_button: Button = $OverlayPanel/MarginContainer/ConfirmationPanel/ConfirmMargin/ConfirmVBox/ButtonsHBox/BackButton
@onready var presenter: ShopPresenter = $ShopPresenter

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.pressed.connect(func(): confirm_pressed.emit())
	close_button.pressed.connect(func(): closed.emit())
	pay_button.pressed.connect(func(): pay_pressed.emit())
	back_button.pressed.connect(func(): back_pressed.emit())
	presenter.bind_view(self)

func show_shop(shop_name: String, money: float) -> void:
	self.visible = true
	overlay_panel.visible = true
	title_label.text = shop_name
	money_label.text = "Available: %.0f gold" % money
	show_browsing()
	await UIAnimations.show_overlay(self, overlay_panel)

func display_items(items: Array[ShopItem], cart: Dictionary, money: float) -> void:
	_clear_items()
	money_label.text = "Available: %.0f gold" % money

	var cart_total := 0.0
	for item in items:
		cart_total += item.price * cart.get(item.item_type, 0)

	for item in items:
		var quantity: int = cart.get(item.item_type, 0)
		var can_afford_more: bool = (money - cart_total) >= item.price
		_create_item_row(item, quantity, can_afford_more)

func update_total(total: float, can_confirm: bool) -> void:
	if total > 0:
		total_label.text = "Cart Total: %.0f gold" % total
	else:
		total_label.text = "Cart is empty"
	confirm_button.disabled = not can_confirm

func update_money(money: float) -> void:
	money_label.text = "Available: %.0f gold" % money

func show_confirmation(summary_lines: Array[String], total: float, remaining: float) -> void:
	browsing_container.visible = false
	confirmation_panel.visible = true
	confirm_title_label.text = "Confirm Purchase"

	_clear_summary()
	for line in summary_lines:
		var line_label = Label.new()
		line_label.text = line
		line_label.add_theme_font_size_override("font_size", 16)
		line_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		summary_container.add_child(line_label)

	total_summary_label.text = "Total: %.0f gold" % total
	remaining_label.text = "Remaining: %.0f gold" % remaining

func show_browsing() -> void:
	browsing_container.visible = true
	confirmation_panel.visible = false

func hide_shop() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false

func _create_item_row(item: ShopItem, quantity: int, can_afford_more: bool) -> void:
	var row_panel = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 90)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var top_row = HBoxContainer.new()
	vbox.add_child(top_row)

	var name_label = Label.new()
	name_label.text = item.get_label()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var price_label = Label.new()
	price_label.text = "%.0f gold" % item.price
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	top_row.add_child(price_label)

	if item.description != "":
		var desc_label = Label.new()
		desc_label.text = item.description
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

	var controls_row = HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 12)
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(controls_row)

	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(40, 32)
	minus_button.disabled = quantity <= 0
	minus_button.pressed.connect(func(): item_quantity_changed.emit(item.item_type, -1))
	controls_row.add_child(minus_button)

	var qty_label = Label.new()
	qty_label.text = str(quantity)
	qty_label.add_theme_font_size_override("font_size", 18)
	qty_label.add_theme_color_override("font_color", Color(1, 1, 1))
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.custom_minimum_size = Vector2(40, 0)
	controls_row.add_child(qty_label)

	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(40, 32)
	plus_button.disabled = not can_afford_more
	plus_button.pressed.connect(func(): item_quantity_changed.emit(item.item_type, 1))
	controls_row.add_child(plus_button)

	if quantity > 0:
		var subtotal_label = Label.new()
		subtotal_label.text = "= %.0f gold" % (item.price * quantity)
		subtotal_label.add_theme_font_size_override("font_size", 14)
		subtotal_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		controls_row.add_child(subtotal_label)

	items_container.add_child(row_panel)

func _clear_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

func _clear_summary() -> void:
	for child in summary_container.get_children():
		child.queue_free()
