class_name RecruitActivity extends Activity

func execute(squad: StrategicSquad, world: World) -> ActivityResult:
	assert(result)
	
	# Simple recruit logic: add a new warrior to the squad
	var new_warrior = Warrior.new()
	new_warrior.name = "Recruit_%d" % world.turn_count
	#new_warrior.level = 1
	#new_warrior.health = 100
	#new_warrior.attack = 10
	#new_warrior.defense = 5
	
	#squad.add_warrior(new_warrior)
	
	print("[RecruitActivity] Recruited new warrior: %s" % new_warrior.name)
	
	# Append the new recruit to the result
	result.append_new_recruits([new_warrior])
	
	return result
