extends Resource
class_name GovernmentConfig

@export var push_weight: float = 0.7
@export var pull_weight: float = 0.3
@export var max_budget_ratio: float = 0.3
@export var priority_goods: Array[String] = []
@export var tax_rate: float = 0.05
@export var starting_treasury: float = 100.0
