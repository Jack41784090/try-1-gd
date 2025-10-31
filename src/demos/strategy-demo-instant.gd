extends Node

var scenario: GameScenario = preload("res://resources/scenarios/test scenario/t-scene.tres")

func _ready() -> void:
	var activity = DrillActivity.new()
	var turn = scenario.execute_turn(activity)
	print(turn)
	pass
