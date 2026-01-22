class_name EventResult extends GenericResult

# var choices: Array[EventChoice] = []
var immediate_effects: Dictionary = {}
var auto_resolved: bool = true

# func add_choice(choice: EventChoice) -> void:
#     choices.append(choice)
#     auto_resolved = false