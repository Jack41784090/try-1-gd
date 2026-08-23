class_name DebugCommandSystem
extends Node

## Never holds refs to sibling Systems — main.gd listens for command_dispatched and dispatches to whichever System the command named, so new commands are new .tres files, not new code.

signal command_dispatched(target_system_name: StringName, target_signal_name: StringName, args: Array)
signal command_failed(raw_text: String, reason: String)

var commands: Array[CommandResource] = []
var arg_resolvers: Dictionary = {} ## StringName kind -> Callable(String token) -> Variant (null = unresolved)


func setup(_commands: Array[CommandResource], _arg_resolvers: Dictionary = {}) -> void:
	commands = _commands
	arg_resolvers = _arg_resolvers


func register_command(command: CommandResource) -> void:
	commands.append(command)


func register_arg_resolver(kind: StringName, resolver: Callable) -> void:
	arg_resolvers[kind] = resolver


func interpret(raw_text: String) -> void:
	var text := raw_text.strip_edges()
	if not text.begins_with("/"):
		return

	var tokens := text.split(" ", false)
	if tokens.is_empty():
		return

	var matched: CommandResource = null
	for cmd in commands:
		if cmd.matches_token(tokens[0]):
			matched = cmd
			break

	if matched == null:
		_fail(raw_text, "unknown command '%s'" % tokens[0])
		return
	tokens.remove_at(0)

	while not tokens.is_empty():
		var sub := matched.find_subcommand(tokens[0])
		if sub == null:
			break
		matched = sub
		tokens.remove_at(0)

	var args: Array = []
	for i in range(matched.arg_kinds.size()):
		if i >= tokens.size():
			_fail(raw_text, "%s: missing arg #%d (%s)" % [matched.command, i + 1, matched.arg_kinds[i]])
			return

		var kind: StringName = matched.arg_kinds[i]
		if not arg_resolvers.has(kind):
			_fail(raw_text, "%s: no resolver registered for arg kind '%s'" % [matched.command, kind])
			return

		var resolver: Callable = arg_resolvers[kind]
		var resolved: Variant = resolver.call(tokens[i])
		if resolved == null:
			_fail(raw_text, "%s: could not resolve '%s' as %s" % [matched.command, tokens[i], kind])
			return
		args.append(resolved)

	LogGd.debug("[DebugCommandSystem] dispatching %s -> %s.%s(%s)" % [
		matched.command, matched.target_system_name, matched.target_signal_name, args,
	])
	command_dispatched.emit(matched.target_system_name, matched.target_signal_name, args)


func _fail(raw_text: String, reason: String) -> void:
	LogGd.warn("[DebugCommandSystem] %s" % reason)
	command_failed.emit(raw_text, reason)
