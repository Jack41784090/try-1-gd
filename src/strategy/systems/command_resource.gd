class_name CommandResource
extends Resource

## Never holds a live System reference — Resources are authored before any System node exists — so the target is named by StringName and resolved at dispatch time by main.gd.

@export var command_name: String = "" ## "Travel"
@export var command: String = "" ## "/travel" — the literal leading token, must start with "/"
@export var subcommands: Array[CommandResource] = []

@export var target_system_name: StringName = &"" ## $Systems child node name, e.g. &"SquadTravelSystem"
@export var target_signal_name: StringName = &"" ## signal to prefer on that system; falls back to a same-named method if it has no such signal

@export var arg_kinds: Array[StringName] = [] ## one entry per positional arg, keyed to a resolver registered on DebugCommandSystem


func matches_token(token: String) -> bool:
	return token == command


func find_subcommand(token: String) -> CommandResource:
	for sub in subcommands:
		if sub.matches_token(token):
			return sub
	return null
