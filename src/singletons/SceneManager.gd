extends CanvasLayer

signal transitioned_in();
signal transitioned_out();


@onready var animation_player: AnimationPlayer = $AnimationPlayer

func transition_in():
	animation_player.play("in")

func transition_out():
	animation_player.play("out")
	
func transition_quick(sneak_in: Callable):
	transition_in()
	await transitioned_in

	sneak_in.call();

	transition_out()
	await transitioned_out
	

func transition_to(scene_path: String):
	transition_in()
	await transitioned_in

	var scene_resource: PackedScene = load(scene_path)
	var new_scene: Node = scene_resource.instantiate();

	var root: Window = get_tree().root
	root.get_child(root.get_child_count() - 1).free();
	root.add_child(new_scene);

	transition_out()
	await transitioned_out





func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"in":
			transitioned_in.emit();
		"out":
			transitioned_out.emit();
		_:
			assert(false)
