class_name EntityUpdate

## Signal emitted when the update animation/processing is complete
signal completed

var source: int
var affected: int
var change: EntityChange
var done: bool = false


func _to_string() -> String:
	return "EntityUpdate(source=%d%s)" % [source,
	(", affected=%d, change=%s, done=%s" % [affected, change.to_string(), done] if affected != -1 else "") if change.from != -1 and change.to != -1 else ""]


func _init(p_source: int, p_affected: int, p_change: EntityChange):
	source = p_source
	affected = p_affected
	change = p_change


## Async function that applies this update to a display and waits for completion
## Usage: await entity_update.commit(display)
func commit(display: EntityDisplay) -> void:
	if not display:
		push_error("EntityUpdate.commit() called with null display")
		completed.emit()
		return

	print("[EntityUpdate] Committing update for entity %d: %s" % [affected, change.to_string()])

	display.update_stat(change.property, change.from, change.to)

	if display.has_signal("animation_completed"):
		print("		[EntityUpdate] Waiting for animation to complete for entity %d" % affected)
		await display.animation_completed
	else:
		print("		[EntityUpdate] No animation_completed signal for entity %d, waiting default time" % affected)
		await display.get_tree().create_timer(0.3).timeout

	done = true
	completed.emit()
	print("[EntityUpdate] Update completed for entity %d" % affected)
