class_name StrategySquadResource
extends Resource

var identification: String;
@export var name: String;
@export var entities: Array[StrategyEntityResource];
@export var formation: Array[SquadBattleTypes.SquadEntityInSquadLocation];
@export var starting_location_id: String;
@export var starting_inventory: SquadInventoryResource;
@export var squad_role: StrategyTypes.SquadRole;
