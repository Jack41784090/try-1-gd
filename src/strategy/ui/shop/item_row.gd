class_name ShopItemRow extends PanelContainer

signal quantity_changed(thing_id: String, delta: int)

@onready var name_label: Label = $MarginContainer/VBoxContainer/TopRow/NameLabel
@onready var price_label: Label = $MarginContainer/VBoxContainer/TopRow/PriceLabel
@onready var stock_label: Label = $MarginContainer/VBoxContainer/TopRow/StockLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var minus_button: Button = $MarginContainer/VBoxContainer/ControlsRow/MinusButton
@onready var qty_label: Label = $MarginContainer/VBoxContainer/ControlsRow/QtyLabel
@onready var plus_button: Button = $MarginContainer/VBoxContainer/ControlsRow/PlusButton
@onready var subtotal_label: Label = $MarginContainer/VBoxContainer/ControlsRow/SubtotalLabel

var _thing_id: String

func _ready() -> void:
	minus_button.pressed.connect(func(): quantity_changed.emit(_thing_id, -1))
	plus_button.pressed.connect(func(): quantity_changed.emit(_thing_id, 1))

func populate(thing: Thing, quantity: int, can_afford_more: bool, remaining_stock: int = 999) -> void:
	_thing_id = thing.thing_id
	name_label.text = thing.get_label()
	price_label.text = "%.0f gold" % thing.base_price

	if remaining_stock < 999:
		stock_label.visible = true
		if remaining_stock + quantity <= 0:
			stock_label.text = "Out of Stock"
			stock_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		else:
			stock_label.text = "Stock: %d" % (remaining_stock + quantity)
			stock_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	else:
		stock_label.visible = false

	if thing.description != "":
		desc_label.visible = true
		desc_label.text = thing.description
	else:
		desc_label.visible = false

	minus_button.disabled = quantity <= 0
	qty_label.text = str(quantity)
	plus_button.disabled = not can_afford_more

	if quantity > 0:
		subtotal_label.visible = true
		subtotal_label.text = "= %.0f gold" % (thing.base_price * quantity)
	else:
		subtotal_label.visible = false

	visible = true
