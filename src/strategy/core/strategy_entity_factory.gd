class_name StrategyEntityFactory


static func Create(background: WarriorBackground, religion: StrategyTypes.Religion) -> StrategyEntity:
	var res := StrategyEntityResource.new()
	res.name = background.display_name
	res.religion = religion
	res.social_class = StrategyTypes.SocialClass.PEASANT
	res.identification = background.background_id
	var morale := ReactiveStat.new()
	morale.stat_name = StatName.I.MORALE
	morale.stat_value = 0.5
	var mv_spd := ReactiveStat.new()
	mv_spd.stat_name = StatName.I.MV_SPD
	mv_spd.stat_value = background.speed_kmh
	var weapon := ReactiveStat.new()
	weapon.stat_name = StatName.I.WEAPON
	weapon.stat_value = null
	var armour := ReactiveStat.new()
	armour.stat_name = StatName.I.ARMOUR
	armour.stat_value = null
	res.rs_array = [morale, mv_spd, weapon, armour]
	var entity := StrategyEntity.new(res)
	entity.location_prebattle = background.default_position
	return entity
