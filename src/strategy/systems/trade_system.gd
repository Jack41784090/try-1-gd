class_name TradeSystem
extends Node

## Never touches World: each Trade already carries its squad and location, resolved by the composition root before queue_trade() is called.

signal buy_requested(squad: StrategySquad, thing: Thing, qty: float)
signal sell_requested(squad: StrategySquad, thing: Thing, qty: float)
signal trade_queued(trade: Trade)
signal trade_committed(trade: Trade)
signal trade_rejected(trade: Trade, reason: String)

var pending_trades: Array[Trade] = []
var committed_trades: Array[Trade] = []

var market_offers: Dictionary = {} ## location_id -> {"surplus": Dictionary, "unmet": Dictionary}


func _on_trade_offer(location_id: String, surplus: Dictionary, unmet: Dictionary) -> void:
	market_offers[location_id] = {"surplus": surplus, "unmet": unmet}


## Validates up front for immediate feedback; still re-validated at commit time since the market can move before the hourly barrier.
func queue_trade(trade: Trade) -> void:
	var reason := trade.get_rejection_reason()
	if not reason.is_empty():
		trade.state = EconomyTypes.TradeState.REJECTED
		trade_rejected.emit(trade, reason)
		LogGd.warn("[Trade] rejected %s — %s" % [trade, reason])
		return
	pending_trades.append(trade)
	trade_queued.emit(trade)
	LogGd.info("[Trade] queued %s" % trade)


## Must connect to ClockSystem.hour_changed BEFORE LocationEconomySystem so committed trades are already in inventory/cargo when the phase column reads them.
func _on_hour_changed(_hour: int) -> void:
	for trade: Trade in pending_trades:
		if trade.commit():
			committed_trades.append(trade)
			trade_committed.emit(trade)
			LogGd.info("[Trade] committed %s" % trade)
		else:
			var reason := trade.get_rejection_reason()
			trade_rejected.emit(trade, reason)
			LogGd.warn("[Trade] rejected %s — %s" % [trade, reason])
	pending_trades.clear()
