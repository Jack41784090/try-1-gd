class_name ShopPresenter extends Node

signal purchase_completed(purchases: Dictionary)
signal shop_closed

var view: ShopView
var current_shop: Shop
var squad: SquadStrategicData
var cart: Dictionary = {}
var _location: Location = null

func bind_view(v: ShopView) -> void:
	view = v
	view.thing_quantity_changed.connect(_on_thing_quantity_changed)
	view.confirm_pressed.connect(_on_confirm_pressed)
	view.pay_pressed.connect(_on_pay_pressed)
	view.back_pressed.connect(_on_back_pressed)
	view.closed.connect(_on_closed)

func open(shop: Shop, _squad: SquadStrategicData, location: Location = null) -> void:
	assert(shop != null)
	assert(_squad != null)
	current_shop = shop
	squad = _squad
	_location = location
	cart.clear()
	view.show_shop(shop.shop_name, squad.money)
	_refresh_display()

func _on_thing_quantity_changed(thing_id: String, delta: int) -> void:
	var current_qty: int = cart.get(thing_id, 0)
	var new_qty: int = max(0, current_qty + delta)

	if delta > 0:
		var thing := _find_thing(thing_id)
		assert(thing != null)
		var max_qty = _get_max_affordable(thing)
		new_qty = min(new_qty, max_qty)

	if new_qty == 0:
		cart.erase(thing_id)
	else:
		cart[thing_id] = new_qty

	_refresh_display()

func _on_confirm_pressed() -> void:
	var summary_lines: Array[String] = []
	var total := _calculate_total()

	for thing_id in cart:
		var qty: int = cart[thing_id]
		var thing := _find_thing(thing_id)
		assert(thing != null)
		var price := _get_effective_price(thing)
		summary_lines.append("%dx %s — %.0f gold" % [qty, thing.get_label(), price * qty])

	view.show_confirmation(summary_lines, total, squad.money - total)

func _on_pay_pressed() -> void:
	var total := _calculate_total()
	assert(squad.money >= total)

	var purchases: Dictionary = {}
	for thing_id in cart:
		purchases[thing_id] = cart[thing_id]

	squad.spend_money(total)

	for thing_id in purchases:
		var qty: int = purchases[thing_id]
		var thing := _find_thing(thing_id)
		assert(thing != null)
		_apply_thing_effect(thing, qty)

	Log.debug("Shop", "Purchase completed: %s for %.0f gold" % [purchases, total])

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
	for thing_id in cart:
		var qty: int = cart[thing_id]
		var thing := _find_thing(thing_id)
		assert(thing != null)
		total += _get_effective_price(thing) * qty
	return total

func _get_max_affordable(thing: Thing) -> int:
	var total_without_this := 0.0
	for tid in cart:
		if tid != thing.thing_id:
			var qty: int = cart[tid]
			var other := _find_thing(tid)
			total_without_this += _get_effective_price(other) * qty

	var budget: float = squad.money - total_without_this
	var price := _get_effective_price(thing)
	if price <= 0.0:
		return 0
	return int(budget / price)


func _get_effective_price(thing: Thing) -> float:
	if _location == null or not _location.has_economy():
		return thing.base_price
	var inv := _location.inventory
	if thing in inv.prices:
		return inv.prices[thing]
	return thing.base_price

func _apply_thing_effect(thing: Thing, quantity: int) -> void:
	match thing.thing_type:
		EconomyTypes.ThingType.FOOD:
			squad.food += quantity
			Log.debug("Shop", "Added %d food supplies" % quantity)
		EconomyTypes.ThingType.CLOTH:
			squad.gain_money(float(quantity) * 2.0)
			Log.debug("Shop", "Bought %d cloth" % quantity)
		EconomyTypes.ThingType.TOOLS:
			squad.travel_tools += quantity
			Log.debug("Shop", "Added %d travel tools" % quantity)
		EconomyTypes.ThingType.LUXURY:
			squad.modify_morale(float(quantity) * 3.0)
			Log.debug("Shop", "Bought %d luxuries (morale boost)" % quantity)
	_consume_from_economy(thing, quantity)


func _consume_from_economy(thing: Thing, quantity: int) -> void:
	if _location == null or not _location.has_economy():
		return
	var inv := _location.inventory
	inv.consume(thing, float(quantity))
	Log.debug("Shop", "Consumed %.1f %s from economy at %s" % [float(quantity), thing.thing_name, _location.location_id])


func _find_thing(thing_id: String) -> Thing:
	for thing in current_shop.items:
		if thing.thing_id == thing_id:
			return thing
	return null
