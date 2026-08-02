class_name ReactionSkill
extends Resource

enum Relation { SELF, ALLY, ENEMY, ANY }

@export var reaction_name: String = ""
@export var window: SquadBattleTypes.ReactionWindow = 5
@export var relation_to_target: Relation = Relation.SELF
@export var condition: Consideration = null
@export var skill: Skill = null
@export var effect: ReactionEffect = null
@export var once_per_round: bool = true
@export var priority: int = 0


func can_react(p_window: int, intent, reactor: CombatEntity, situation: Situation) -> bool:
	if p_window != window:
		return false
	var relation_ok := false
	match relation_to_target:
		Relation.SELF:
			relation_ok = reactor.player_id == intent.target.player_id
		Relation.ALLY:
			relation_ok = reactor.side == intent.target.side and reactor.player_id != intent.target.player_id
		Relation.ENEMY:
			relation_ok = reactor.side != intent.target.side
		Relation.ANY:
			relation_ok = true
	if not relation_ok:
		return false
	if condition != null:
		var score = condition.score(reactor, situation, {})
		if score <= 0.0:
			return false
	return true
