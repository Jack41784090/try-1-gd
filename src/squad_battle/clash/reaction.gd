class_name ReactionSkill
extends Resource

enum Relation { SELF, ALLY, ENEMY, ANY }

@export var reaction_name: String = ""
@export var window: SquadBattleTypes.ReactionWindow = 5
@export var relation_to_target: Relation = Relation.SELF
@export var condition: Consideration = null
@export var skill: Skill = null
@export var effect: ReactionEffect = null
@export var duration: int = 1
@export var sta_cost: float = 10.0
@export var priority: int = 0

var remaining_activations: int = 0
var _connected_resolver: ClashResolver = null
var _connected_callable: Callable


func subscribe_to(resolver: ClashResolver, owner: CombatEntity) -> void:
	_disconnect_current()
	if remaining_activations <= 0:
		remaining_activations = duration
	_connected_resolver = resolver
	_connected_callable = _on_reaction_window.bind(resolver, owner)
	resolver.window_raised.connect(_connected_callable)


func unsubscribe() -> void:
	_disconnect_current()


func _disconnect_current() -> void:
	if _connected_resolver != null and _connected_resolver.window_raised.is_connected(_connected_callable):
		_connected_resolver.window_raised.disconnect(_connected_callable)
	_connected_resolver = null


func _on_reaction_window(intent: ClashIntent, window: int, resolver: ClashResolver, owner: CombatEntity) -> void:
	if window != self.window:
		return
	if owner.is_dead():
		return
	if intent.phase == ClashIntent.Phase.CANCELLED:
		return
	if remaining_activations <= 0:
		return
	if resolver.has_ancestor_reaction(intent, owner, reaction_name):
		return
	if not resolver.reaction_allowed(owner, self):
		return
	var situation: Situation = null
	if condition != null:
		situation = resolver.build_situation(owner)
	if not can_react(window, intent, owner, situation):
		return
	resolver.execute_reaction(self, intent, owner)


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
