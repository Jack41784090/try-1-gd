class_name Town extends Resource

@export var population: int = 10
@export var stability: float = 100

# economy
@export var needs = {
    "food": 0,
    "medicine": 0,
    "tools": 0
}
@export var inventory = {
    "food": 50,
    "medicine": 20,
    "tools": 10
}

func _pass_turn():
    # Simple economy simulation
    for need in needs.keys():
        var total_need = needs[need] * population
        if inventory[need] >= total_need:
            inventory[need] -= total_need
        else:
            var shortage = total_need - inventory[need]
            inventory[need] = 0
            stability -= shortage * 0.1  # Decrease stability based on shortage

    stability = clamp(stability, 0, 100)


