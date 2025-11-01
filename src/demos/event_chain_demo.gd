extends Node

## Demo script that loads and plays an EventChain through the VisualNovelScreen

const EventChainClass = preload("res://src/strategy/events/event_chain.gd")
const VisualNovelScreenClass = preload("res://src/strategy/ui/visual_novel_screen.gd")

@export var event_chain_resource: Resource
@export_file("*.json") var event_chain_json_path: String = ""

@onready var vn_screen: Control = $VisualNovelScreen

func _ready() -> void:
	var chain_to_load: EventChainClass = null
	
	# Priority: Load from JSON if path is provided, otherwise use Resource
	if not event_chain_json_path.is_empty():
		print("Loading EventChain from JSON: ", event_chain_json_path)
		chain_to_load = EventChainClass.load_from_json_file(event_chain_json_path)
		if not chain_to_load:
			push_error("Failed to load EventChain from JSON")
			return
	elif event_chain_resource:
		chain_to_load = event_chain_resource
	else:
		push_error("No EventChain resource or JSON path assigned to demo!")
		return
	
	if not vn_screen:
		push_error("VisualNovelScreen node not found!")
		return
	
	# Connect signals
	vn_screen.dialogue_advanced.connect(_on_dialogue_advanced)
	vn_screen.chain_completed.connect(_on_chain_completed)
	
	# Start the chain after a brief delay
	await get_tree().create_timer(0.5).timeout
	print("=== Starting EventChain Demo ===")
	print("Chain ID: ", chain_to_load.chain_id)
	print("Chain Name: ", chain_to_load.chain_name)
	print("Number of dialogues: ", chain_to_load.get_dialogue_count())
	print("Characters: ", chain_to_load.get_all_character_ids())
	print("================================")
	
	vn_screen.load_event_chain(chain_to_load)

func _on_dialogue_advanced() -> void:
	print("Dialogue advanced")

func _on_chain_completed() -> void:
	print("=== EventChain Demo Completed ===")
	print("You can close the window now or press ESC")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
