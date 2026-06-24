extends Node

signal activity_started(activity_name: String)
signal activity_completed(activity_name: String, result: ActivityResult)
signal event_fired(event_name: String)
signal mission_unlocked(mission_name: String)
signal mission_completed(mission_name: String)
signal mission_failed(mission_name: String)
signal faction_reputation_changed(faction_name: String, new_reputation: float)
signal squad_morale_changed(new_morale: float)
signal squad_resource_changed(resource_name: String, new_amount: Variant)
signal warrior_joined(warrior_name: String)
signal warrior_died(warrior_name: String)
signal location_changed(old_location: String, new_location: String)
signal strategy_hour_tick(hour_number: int)
signal game_ended(ending_name: String)

# HUD display signals — Presenter computes, View renders. Lets any panel
# subscribe to top-bar state without the Presenter holding a View reference.
signal hud_location_changed(display_text: String)
signal hud_condition_changed(condition_text: String)
signal hud_stats_changed(money: float, food: int, karma: float, stability: float, development: int)
signal hud_contact_bars_changed(bars: Array)
signal pause_state_changed(is_paused: bool)
signal speed_changed(speed: float)
