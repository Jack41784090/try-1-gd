class_name Character
extends Resource

## Mediator composing the persistent campaign entity (StrategyEntity, tier 2)
## and the ephemeral per-battle entity (CombatEntity, tier 3). The only class
## that knows about both; the two entity types never reference each other.

@export var strategy: StrategyEntity = null:
	set(value):
		if strategy == value:
			return
		if strategy != null and strategy.changed.is_connected(_on_strategy_changed):
			strategy.changed.disconnect(_on_strategy_changed)
		strategy = value
		if strategy != null and not strategy.changed.is_connected(_on_strategy_changed):
			strategy.changed.connect(_on_strategy_changed)
@export var combat_identification: String = ""
var combat: CombatEntity = null


func _init(_strategy: StrategyEntity = null, _combat_identification: String = "") -> void:
	strategy = _strategy
	combat_identification = _combat_identification


func _on_strategy_changed() -> void:
	emit_changed()


func get_combat_identification() -> String:
	if not combat_identification.is_empty():
		return combat_identification
	assert(strategy != null, "Character has no combat_identification and no strategy fallback")
	return strategy.resource.identification


## Tier-2→tier-1 resolution: a persistent character's own (possibly grown) constant
## stat wins if present; otherwise fall back to the tier-1 class template. Nothing in
## StrategyEntityResource authors BASE_ATTRIBUTE_STATS entries today, so every lookup
## currently falls through to the template — this is the extension seam for a future
## training/growth system, not something this refactor builds.
func get_constant_stat_value(key: StatName.I) -> Variant:
	if strategy != null and strategy.get_stat(key) != null:
		return strategy.get_stat_value(key)
	return CombatEntityFactory.get_resource(get_combat_identification()).get_stat_value(key)


func enter_battle(side: SquadBattleTypes.Side, player_id: int,
		starting_location: SquadBattleTypes.SquadEntityInSquadLocation) -> CombatEntity:
	assert(combat == null, "Character is already in a battle")
	var template := CombatEntityFactory.get_resource(get_combat_identification())
	var resolved: Dictionary[StatName.I, Variant] = {}
	for key in StatName.BASE_ATTRIBUTE_STATS:
		resolved[key] = get_constant_stat_value(key)
	var config := CombatEntityConfig.new(template, side, player_id, starting_location, resolved)
	combat = CombatEntity.new(config)
	return combat


func exit_battle() -> void:
	assert(combat != null, "Character is not in a battle")
	combat = null


var id: String:
	get:
		return strategy.id if strategy else ""
var display_name: String:
	get:
		return strategy.display_name if strategy else (combat.display_name if combat else get_combat_identification())
var resource: StrategyEntityResource:
	get:
		return strategy.resource if strategy else null
var is_dead: bool:
	get:
		return strategy.is_dead if strategy else (combat != null and combat.is_dead())
	set(v):
		assert(strategy != null)
		strategy.is_dead = v
var is_injured: bool:
	get:
		return strategy.is_injured if strategy else false
	set(v):
		assert(strategy != null)
		strategy.is_injured = v
var location_prebattle: SquadBattleTypes.SquadEntityInSquadLocation:
	get:
		return strategy.location_prebattle if strategy else SquadBattleTypes.SquadEntityInSquadLocation.Front
	set(v):
		if strategy:
			strategy.location_prebattle = v
var identification: String:
	get:
		return get_combat_identification()


func get_stat(key: StatName.I) -> ReactiveStat:
	return strategy.get_stat(key) if strategy else null


func get_stat_value(key: StatName.I) -> Variant:
	return strategy.get_stat_value(key) if strategy else null


func modify_morale(amount: float) -> void:
	assert(strategy != null)
	strategy.modify_morale(amount)


func get_equipped_weapon() -> WeaponResource:
	return strategy.get_equipped_weapon() if strategy else null


func get_equipped_armor() -> ArmorConfig:
	return strategy.get_equipped_armor() if strategy else null


func equip_weapon(w: WeaponResource) -> void:
	assert(strategy != null)
	strategy.equip_weapon(w)


func unequip_weapon() -> WeaponResource:
	assert(strategy != null)
	return strategy.unequip_weapon()


func equip_armor(a: ArmorConfig) -> void:
	assert(strategy != null)
	strategy.equip_armor(a)


func unequip_armor() -> ArmorConfig:
	assert(strategy != null)
	return strategy.unequip_armor()


func get_speed_kmh() -> float:
	assert(strategy != null)
	return strategy.get_speed_kmh()


func check_religion(religion_type: StrategyTypes.Religion) -> bool:
	return strategy.check_religion(religion_type) if strategy else false


func get_demand() -> Dictionary:
	return strategy.get_demand() if strategy else {}


## TODO: WarriorAttribute system is unbuilt; see StrategyEntity.get_attribute.
func get_attribute(attribute: StrategyTypes.WarriorAttribute) -> int:
	return strategy.get_attribute(attribute) if strategy else 0


## TODO: WarriorAttribute system is unbuilt; see StrategyEntity.set_attribute.
func set_attribute(attribute: StrategyTypes.WarriorAttribute, value: int) -> void:
	if strategy:
		strategy.set_attribute(attribute, value)
