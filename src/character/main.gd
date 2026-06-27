class_name Entity
extends Node

@onready var strat = $Strat
@onready var combat = $Combat


func _init(_strat: StrategyEntityResource, _combat: CombatEntityResource) -> void:
	if _strat:
		strat = StrategyEntity.new(_strat)
	if _combat:
		combat = _combat


func _ready() -> void:
	print("ready")
