class_name FactionDirective extends Resource

@export var directive_type: StrategicAITypes.DirectiveType = StrategicAITypes.DirectiveType.NONE
@export var target_location_id: String = ""
@export var target_squad_id: String = ""
@export var priority: float = 0.0

static func create_none() -> FactionDirective:
	var d = FactionDirective.new()
	d.directive_type = StrategicAITypes.DirectiveType.NONE
	return d

static func create_attack(location_id: String, p_priority: float = 1.0) -> FactionDirective:
	var d = FactionDirective.new()
	d.directive_type = StrategicAITypes.DirectiveType.ATTACK_LOCATION
	d.target_location_id = location_id
	d.priority = p_priority
	return d

static func create_defend(location_id: String, p_priority: float = 1.0) -> FactionDirective:
	var d = FactionDirective.new()
	d.directive_type = StrategicAITypes.DirectiveType.DEFEND_LOCATION
	d.target_location_id = location_id
	d.priority = p_priority
	return d
