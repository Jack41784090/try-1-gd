class_name Clue extends Resource

@export var clue_id: String = ""
@export var clue_name: String = ""
@export var destination_id: String = ""
@export var decay: int = 120
@export var created_hour: int = 0
@export var left_by_warrior_id: String = ""
@export var left_by_squad_id: String = ""
@export var detail_level: int = 0


func _init() -> void:
	pass


func is_expired(current_hour: int) -> bool:
	return get_age(current_hour) >= decay


func get_age(current_hour: int) -> int:
	return current_hour - created_hour


func get_age_description(current_hour: int) -> String:
	var age := get_age(current_hour)
	if age <= 0:
		return "fresh, left within the hour"
	elif age < 6:
		return "a few hours old"
	elif age < 24:
		return "less than a day old"
	elif age < 48:
		return "1 to 2 days old"
	elif age < 72:
		return "2 to 3 days old"
	elif age < 96:
		return "3 to 4 days old"
	elif age < 120:
		return "4 to 5 days old"
	else:
		return "nearly faded, at least %d days old" % (age / 24)


func get_destination_hint(perception_roll: int) -> String:
	if destination_id.is_empty():
		return "destination unknown"
	
	if perception_roll >= detail_level:
		return "heading towards %s" % destination_id
	elif perception_roll >= detail_level - 20:
		return "heading in a known direction"
	else:
		return "direction unclear"


func decay_one_hour() -> void:
	decay -= 1


static func create_clue(
	clue_name_param: String,
	squad_id: String,
	warrior_id: String,
	current_hour: int,
	stealth_failure_margin: int,
	destination: String = ""
) -> Clue:
	var clue := Clue.new()
	clue.clue_id = "%s_%s_%d" % [squad_id, warrior_id, current_hour]
	clue.clue_name = clue_name_param
	clue.left_by_squad_id = squad_id
	clue.left_by_warrior_id = warrior_id
	clue.created_hour = current_hour
	clue.destination_id = destination
	clue.decay = randi_range(72, 168)
	clue.detail_level = clampi(stealth_failure_margin * 10, 0, 100)
	return clue

static func get_random_clue_name(religion: StrategyTypes.Religion) -> String:
	var generic_clues = [
		"Boot Prints",
		"Torn Cloth",
		"Discarded Rations",
		"Campfire Remains",
		"Weapon Marks",
		"Trampled Grass"
	]
	
	var religious_clues = {
		StrategyTypes.Religion.CATHOLIC: ["Christian Cross", "Prayer Beads", "Saint's Medal"],
		StrategyTypes.Religion.MUSLIM: ["Prayer Rug Fragment", "Crescent Pendant"],
		StrategyTypes.Religion.PROTESTANT: ["Bible Page", "Simple Cross"],
		StrategyTypes.Religion.PAGAN: ["Rune Stone", "Herb Bundle"],
		StrategyTypes.Religion.BUDDHIST: ["Incense Stick", "Prayer Wheel Fragment"],
		StrategyTypes.Religion.TENGRIST: ["Sky Token", "Horse Hair Charm"],
		StrategyTypes.Religion.SAVINKOVIST: ["Revolutionary Pamphlet", "Red Cloth"]
	}
	
	if randf() < 0.3 and religious_clues.has(religion):
		var options = religious_clues[religion]
		return options[randi() % options.size()]
	else:
		return generic_clues[randi() % generic_clues.size()]
