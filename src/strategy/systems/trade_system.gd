class_name TradeSystem
extends Node

## Owns every Trade (src/economy/trade.gd) between a StrategySquad and a
## Location market — the trade domain itself, the way SquadBeingSystem owns
## squads and CaravanEconomySystem owns EconomyMoves. Never touches World:
## each Trade already carries its squad and location, resolved by the
## composition root before queue_trade() is called.
##
## Trades accumulate in pending_trades as they are requested and are applied
## together on the hourly barrier (_on_hour_changed, wired to
## ClockSystem.hour_changed by main.gd BEFORE LocationEconomySystem's phase
## column so committed trades are visible to that hour's economy).
##
## Also caches the latest LocationEconomySystem.trade_offer per location so
## callers (HUD, debug terminal) can read current market state without
## reaching into LocationEconomySystem directly.

signal buy_requested(squad: StrategySquad, thing: Thing, qty: float)
signal sell_requested(squad: StrategySquad, thing: Thing, qty: float)
signal trade_queued(trade: Trade)
signal trade_committed(trade: Trade)
signal trade_rejected(trade: Trade, reason: String)

var pending_trades: Array[Trade] = []
var committed_trades: Array[Trade] = []

## location_id -> {"surplus": Dictionary, "unmet": Dictionary} — latest
## LocationEconomySystem.trade_offer per location (market report display).
var market_offers: Dictionary = {}


## Connected to LocationEconomySystem.trade_offer by the composition root.
func _on_trade_offer(location_id: String, surplus: Dictionary, unmet: Dictionary) -> void:
	market_offers[location_id] = {"surplus": surplus, "unmet": unmet}


## Validates up front so the requester (debug terminal, HUD) gets immediate
## feedback; a queued trade is still re-validated at commit time, since the
## market can move between queueing and the hourly barrier.
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


## Connected to ClockSystem.hour_changed by the composition root — must be
## connected BEFORE LocationEconomySystem's own hour_changed handler so
## committed trades are already in inventory/cargo when the phase column
## reads them.
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
