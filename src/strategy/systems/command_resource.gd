class_name CommandResource
extends Resource

## Authored, data-driven definition for one DebugCommandSystem command
## (e.g. "/travel"). A CommandResource never holds a live reference to the
## System it targets — Resources are authored in the editor long before any
## System node exists at runtime — so the target is named by StringName and
## resolved at dispatch time by main.gd, the one place that already knows
## every System under $Systems (see main.gd's load_scenario()).

@export var command_name: String = "" ## "Travel"
@export var command: String = "" ## "/travel" — the literal leading token, must start with "/"
@export var subcommands: Array[CommandResource] = []

@export var target_system_name: StringName = &"" ## $Systems child node name, e.g. &"SquadTravelSystem"
@export var target_signal_name: StringName = &"" ## signal to prefer on that system; falls back to a same-named method if it has no such signal

## One entry per positional arg following the command token(s), naming which
## resolver (registered on DebugCommandSystem, keyed by this StringName) to
## run the raw text token through, e.g. [&"squad", &"location_id"].
@export var arg_kinds: Array[StringName] = []


func matches_token(token: String) -> bool:
	return token == command


func find_subcommand(token: String) -> CommandResource:
	for sub in subcommands:
		if sub.matches_token(token):
			return sub
	return null
