class_name BattleResolutionSystem
extends Node

## Thin wrapper around CombatOrchestrator/CombatController — the existing
## "ClashResolve" tactical combat pipeline. Owns the offscreen SubViewport +
## CanvasLayer combat needs to build a battle scene into when no real Hud
## has injected its own (mirrors the fallback HeadlessStrategyView already
## uses for the legacy scenario.tscn path).

signal battle_resolved(attacker: StrategySquad, defender: StrategySquad, result: CombatController.CombatResult)

var combat_orch: CombatOrchestrator
var battle_viewport: SubViewport
var combat_overlay: CanvasLayer


func setup(contact_tracker = null) -> void:
	combat_orch = CombatOrchestrator.new()
	combat_orch.setup(contact_tracker)

	battle_viewport = SubViewport.new()
	battle_viewport.name = "BattleViewport"
	add_child(battle_viewport)

	combat_overlay = CanvasLayer.new()
	combat_overlay.name = "CombatOverlay"
	add_child(combat_overlay)


func resolve_combat(
	attacker: StrategySquad,
	defender: StrategySquad,
	engagement_type: StrategyTypes.EngagementType = StrategyTypes.EngagementType.SET_PIECE,
) -> CombatController.CombatResult:
	LogGd.debug("[BattleResolutionSystem] %s vs %s (%s)" % [attacker.squad_name, defender.squad_name, StrategyTypes.EngagementType.keys()[engagement_type]])
	combat_orch.inject_context(attacker, defender, battle_viewport, combat_overlay, engagement_type)
	var result: CombatController.CombatResult = await combat_orch.execute_choice(CombatController.IntermissionChoice.FIGHT)
	LogGd.debug("[BattleResolutionSystem] resolved: %s" % result)
	battle_resolved.emit(attacker, defender, result)
	return result