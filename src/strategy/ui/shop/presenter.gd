class_name ShopPresenter extends Node

signal purchase_completed(purchases: Dictionary)
signal shop_closed

var view: ShopView
var current_shop: Shop
var squad: SquadStrategicData
var cart: Dictionary = {}

func bind_view(v: ShopView) -> void:
	view = v
	view.item_quantity_changed.connect(_on_item_quantity_changed)
	view.confirm_pressed.connect(_on_confirm_pressed)
	view.pay_pressed.connect(_on_pay_pressed)
	view.back_pressed.connect(_on_back_pressed)
	view.closed.connect(_on_closed)

func open(shop: Shop, _squad: SquadStrategicData) -> void:
	assert(shop != null)
	assert(_squad != null)
	current_shop = shop
	squad = _squad
	cart.clear()
	view.show_shop(shop.shop_name, squad.money)
	_refresh_display()

func _on_item_quantity_changed(item_type: StrategyTypes.ItemType, delta: int) -> void:
	var current_qty: int = cart.get(item_type, 0)
	var new_qty: int = max(0, current_qty + delta)

	if delta > 0:
		var item = current_shop.get_item_by_type(item_type)
		assert(item != null)
		var max_qty = _get_max_affordable(item)
		new_qty = min(new_qty, max_qty)

	if new_qty == 0:
		cart.erase(item_type)
	else:
		cart[item_type] = new_qty

	_refresh_display()

func _on_confirm_pressed() -> void:
	var summary_lines: Array[String] = []
	var total := _calculate_total()

	for item_type in cart:
		var qty: int = cart[item_type]
		var item = current_shop.get_item_by_type(item_type)
		assert(item != null)
		summary_lines.append("%dx %s — %.0f gold" % [qty, item.get_label(), item.price * qty])

	view.show_confirmation(summary_lines, total, squad.money - total)

func _on_pay_pressed() -> void:
	var total := _calculate_total()
	assert(squad.money >= total)

	var purchases: Dictionary = {}
	for item_type in cart:
		purchases[item_type] = cart[item_type]

	squad.spend_money(total)

	for item_type in purchases:
		var qty: int = purchases[item_type]
		_apply_item_effect(item_type, qty)

	print("[ShopPresenter] Purchase completed: %s for %.0f gold" % [purchases, total])

	cart.clear()
	view.hide_shop()
	purchase_completed.emit(purchases)

func _on_back_pressed() -> void:
	view.show_browsing()
	_refresh_display()

func _on_closed() -> void:
	cart.clear()
	view.hide_shop()
	shop_closed.emit()

func _refresh_display() -> void:
	view.display_items(current_shop.items, cart, squad.money)
	var total := _calculate_total()
	var can_confirm := total > 0 and squad.money >= total
	view.update_total(total, can_confirm)

func _calculate_total() -> float:
	var total := 0.0
	for item_type in cart:
		var qty: int = cart[item_type]
		var item = current_shop.get_item_by_type(item_type)
		assert(item != null)
		total += item.price * qty
	return total

func _get_max_affordable(item: ShopItem) -> int:
	var total_without_this := 0.0
	for item_type in cart:
		if item_type != item.item_type:
			var qty: int = cart[item_type]
			var other_item = current_shop.get_item_by_type(item_type)
			total_without_this += other_item.price * qty

	var budget: float = squad.money - total_without_this
	return int(budget / item.price)

func _apply_item_effect(item_type: StrategyTypes.ItemType, quantity: int) -> void:
	match item_type:
		StrategyTypes.ItemType.SUPPLY:
			squad.food += quantity
			print("[ShopPresenter] Added %d food supplies" % quantity)
