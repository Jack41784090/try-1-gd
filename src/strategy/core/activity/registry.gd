class_name ActivityRegistry
extends RefCounted

var _handlers: Dictionary = {}


func _init():
	_handlers[StrategyTypes.ActivityType.ATTACK] = AttackHandler.new()
	_handlers[StrategyTypes.ActivityType.TRAVEL] = TravelHandler.new()
	_handlers[StrategyTypes.ActivityType.FORCE_MARCH] = ForceMarchHandler.new()
	_handlers[StrategyTypes.ActivityType.RECRUIT] = RecruitHandler.new()
	_handlers[StrategyTypes.ActivityType.INVESTIGATE] = InvestigateHandler.new()
	_handlers[StrategyTypes.ActivityType.FORAGE] = ForageHandler.new()
	_handlers[StrategyTypes.ActivityType.HEAL] = HealHandler.new()
	_handlers[StrategyTypes.ActivityType.BUY_SUPPLIES] = BuySuppliesHandler.new()
	_handlers[StrategyTypes.ActivityType.MERCENARY_WORK] = MercenaryWorkHandler.new()
	_handlers[StrategyTypes.ActivityType.PATROL] = PatrolHandler.new()


func get_handler(activity_type: StrategyTypes.ActivityType) -> ActivityHandler:
	return _handlers.get(activity_type)
