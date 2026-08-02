extends RefCounted
class_name SBLog

## 1-space-per-level indentation
static func _indent(level: int) -> String:
	if level <= 0:
		return ""
	return " ".repeat(level)

## Prints a section header with style based on level
## level 0: ==================== Title ====================
## level 1: ────────── Title ──────────
## level 2: --- Title ---
## else: falls back to an indented line
static func section(title: String, level: int = 0, blank_before: int = 1, blank_after: int = 0) -> void:
	for i in range(max(blank_before, 0)):
		print("")
	match level:
		0:
			var pad = "=".repeat(max(3, 10))
			print("%s %s %s" % [pad, title, pad])
		1:
			var pad = "─".repeat(max(3, 10))
			print("%s %s %s" % [pad, title, pad])
		2:
			print("--- %s ---" % title)
		_:
			line(level, title)
	for i in range(max(blank_after, 0)):
		print("")

## Prints an indented line with optional prefix and blank lines
static func line(level: int, msg: String, prefix_text: String = "", blank_before: int = 0, blank_after: int = 0) -> void:
	for i in range(max(blank_before, 0)):
		print("")
	var p = prefix_text if prefix_text != "" else ""
	var content = "%s%s%s" % [_indent(level), p, (" " + msg) if p != "" else msg]
	print(content)
	for i in range(max(blank_after, 0)):
		print("")


