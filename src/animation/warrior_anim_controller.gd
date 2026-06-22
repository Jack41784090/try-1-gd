class_name WarriorAnimController
extends Node

signal action_completed
signal behavior_changed(new_behavior: AnimTypes.Behavior)

var current_behavior: AnimTypes.Behavior = AnimTypes.Behavior.IDLE
var current_expression: iExpression

var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _state_machine: AnimationNodeStateMachinePlayback


func setup(anim_tree: AnimationTree, anim_player: AnimationPlayer) -> void:
	_anim_tree = anim_tree
	_anim_player = anim_player
	_anim_tree.active = true
	_state_machine = _anim_tree.get("parameters/BodyStateMachine/playback") as AnimationNodeStateMachinePlayback


func play_behavior(behavior: AnimTypes.Behavior) -> void:
	if current_behavior == behavior:
		if _state_machine:
			var current_node = _state_machine.get_current_node()
			var target_state = _behavior_to_state(behavior)
			if current_node != target_state and current_node != &"Start":
				_state_machine.travel(target_state)
		return
	current_behavior = behavior
	var state_name = _behavior_to_state(behavior)
	if _state_machine:
		_state_machine.travel(state_name)
	behavior_changed.emit(behavior)


## Facial expressions are applied as overlay sprite textures by WarriorRig
## (which owns the face sprites); the controller only tracks the current one so
## play_action's body/face stay in sync. The rig calls this after swapping.
func set_expression(expr: iExpression) -> void:
	if not expr:
		return
	current_expression = expr


func play_action(action: AnimAction) -> void:
	if not action:
		return
	if action.expression:
		set_expression(action.expression)
	var state_name = _body_clip_to_state(action.body_clip)
	if _state_machine:
		_state_machine.travel(state_name)


func _behavior_to_state(behavior: AnimTypes.Behavior) -> StringName:
	match behavior:
		AnimTypes.Behavior.IDLE:
			return &"idle"
		AnimTypes.Behavior.WALKING:
			return &"walking"
		AnimTypes.Behavior.ATTACKING:
			return &"attacking"
		AnimTypes.Behavior.DEFENDING:
			return &"defending"
		AnimTypes.Behavior.HURT:
			return &"hurt"
		AnimTypes.Behavior.DYING:
			return &"dying"
		AnimTypes.Behavior.TALKING:
			return &"talking"
		AnimTypes.Behavior.GESTURING:
			return &"gesturing"
		_:
			return &"idle"


func _body_clip_to_state(clip: StringName) -> StringName:
	match clip:
		&"idle_body":
			return &"idle"
		&"walk_body":
			return &"walking"
		&"attack_swing_body":
			return &"attacking"
		&"defend_body":
			return &"defending"
		&"hurt_body":
			return &"hurt"
		&"die_body":
			return &"dying"
		&"talk_body":
			return &"talking"
		&"gesture_wave_body":
			return &"gesturing"
		_:
			return &"idle"
