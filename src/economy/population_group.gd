extends Resource
class_name PopulationGroup

@export var count: int = 0
@export var social_class: EconomyTypes.SocialClass = EconomyTypes.SocialClass.PEASANT
@export var job: EconomyTypes.JobType = EconomyTypes.JobType.FARMER
@export var starting_money: float = 0.0

static func create(p_count: int, p_class: EconomyTypes.SocialClass, p_job: EconomyTypes.JobType, p_money: float) -> PopulationGroup:
	var g := PopulationGroup.new()
	g.count = p_count
	g.social_class = p_class
	g.job = p_job
	g.starting_money = p_money
	return g
