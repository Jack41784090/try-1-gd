class_name ShopView extends Control

signal thing_quantity_changed(thing_id: String, delta: int)
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

var _item_rows: Array[ShopItemRow]
var _summary_labels: Array[Label]

func _ready() -> void:
	overlay_panel.visible = false
	confirm_button.pressed.connect(func(): confirm_pressed.emit())
	close_button.pressed.connect(func(): closed.emit())
	pay_button.pressed.connect(func(): pay_pressed.emit())
	back_button.pressed.connect(func(): back_pressed.emit())
	presenter.bind_view(self)

	for child in items_container.get_children():
		var row := child as ShopItemRow
		row.quantity_changed.connect(func(tid: String, delta: int): thing_quantity_changed.emit(tid, delta))
		_item_rows.append(row)

	for child in summary_container.get_children():
		_summary_labels.append(child as Label)

	for row in _item_rows:
		row.visible = false
	for lbl in _summary_labels:
		lbl.visible = false

func show_shop(shop_name: String, money: float) -> void:
	self.visible = true
	overlay_panel.visible = true
	title_label.text = shop_name
	money_label.text = "Available: %.0f gold" % money
	show_browsing()
	await UIAnimations.show_overlay(self, overlay_panel)

func display_items(items: Array[Thing], cart: Dictionary, money: float, stock_info: Dictionary = {}) -> void:
	money_label.text = "Available: %.0f gold" % money

	var cart_total := 0.0
	for thing in items:
		cart_total += thing.base_price * cart.get(thing.thing_id, 0)

	for i in _item_rows.size():
		if i < items.size():
			var thing := items[i]
			var quantity: int = cart.get(thing.thing_id, 0)
			var remaining_stock: int = stock_info.get(thing.thing_id, 999)
			var can_afford_more: bool = (money - cart_total) >= thing.base_price and remaining_stock > 0
			_item_rows[i].populate(thing, quantity, can_afford_more, remaining_stock)
		else:
			_item_rows[i].visible = false

func update_total(total: float, can_confirm: bool) -> void:
	if total > 0:
		total_label.text = "Cart Total: %.0f gold" % total
	else:
		total_label.text = "Cart is empty"
	confirm_button.disabled = not can_confirm

func show_confirmation(summary_lines: Array[String], total: float, remaining: float) -> void:
	browsing_container.visible = false
	confirmation_panel.visible = true
	confirm_title_label.text = "Confirm Purchase"

	for i in _summary_labels.size():
		if i < summary_lines.size():
			_summary_labels[i].text = summary_lines[i]
			_summary_labels[i].visible = true
		else:
			_summary_labels[i].visible = false

	total_summary_label.text = "Total: %.0f gold" % total
	remaining_label.text = "Remaining: %.0f gold" % remaining

func show_browsing() -> void:
	browsing_container.visible = true
	confirmation_panel.visible = false

func hide_shop() -> void:
	await UIAnimations.hide_overlay(self, overlay_panel)
	overlay_panel.visible = false
