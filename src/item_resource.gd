class_name ItemResource
extends Resource

@export var display_name: String;
@export var max_durability: float;
var durability: float;

@export var economic_comp: Thing;
@export var combat_comp: CombatEquipment;

var strategy_comp: StrategyItem;

func _init() -> void:
	strategy_comp = StrategyItem.new()
	durability = max_durability
