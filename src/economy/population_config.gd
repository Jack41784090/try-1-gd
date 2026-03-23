extends Resource
class_name PopulationConfig

@export var groups: Array[PopulationGroup] = []

func build_population(location_id: String) -> Population:
	var pop := Population.new()
	for group in groups:
		var prefix := "%s_%s" % [location_id, EconomyTypes.JobType.keys()[group.job].to_lower()]
		for p in Population.create_batch(group.count, prefix, group.social_class, group.job, group.starting_money):
			pop.add_person(p)
	return pop
