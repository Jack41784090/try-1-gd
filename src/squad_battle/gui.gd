class_name SquadBattleGraphics
const Types = preload("res://src/squad_battle/types.gd")

var battle: SquadBattle

func _init(_battle: SquadBattle) -> void:
    battle = _battle
    # for squad in battle.teams_and_squads.values():
    #     for entity in squad.entities:
    #         entity.connect("change", self, "_on_entity_change")

func _handle_hp_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " HP changed from ", change.from, " to ", change.to)

func _handle_sta_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " STA changed from ", change.from, " to ", change.to)

func _handle_org_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " ORG changed from ", change.from, " to ", change.to)

func _handle_pos_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " POS changed from ", change.from, " to ", change.to)

func _handle_mag_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " MAG changed from ", change.from, " to ", change.to)

func _handle_loc_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " LOC changed from ", change.from, " to ", change.to)

func _handle_die_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " DIE changed from ", change.from, " to ", change.to)

func _handle_capitulate_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " CAPITULATE changed from ", change.from, " to ", change.to)

func _handle_clink_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " CLINK changed from ", change.from, " to ", change.to)

func _handle_dodge_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " DODGE changed from ", change.from, " to ", change.to)

func _handle_proc_change(update: Types.EntityUpdate) -> void:
    var change: Types.EntityChange = update.change
    print("Entity ", update.affected, " PROC changed from ", change.from, " to ", change.to)

func process_updates(updates: Array[Types.EntityUpdate]) -> void:
    for update in updates:
        var change: Types.EntityChange = update.change
        match change.property:
            Types.EntityChangeable.HP:
                _handle_hp_change(update)
            Types.EntityChangeable.STA:
                _handle_sta_change(update)
            Types.EntityChangeable.ORG:
                _handle_org_change(update)
            Types.EntityChangeable.POS:
                _handle_pos_change(update)
            Types.EntityChangeable.MAG:
                _handle_mag_change(update)
            Types.EntityChangeable.LOC:
                _handle_loc_change(update)
            Types.EntityChangeable.DIE:
                _handle_die_change(update)
            Types.EntityChangeable.CAPITULATE:
                _handle_capitulate_change(update)
            Types.EntityChangeable.CLINK:
                _handle_clink_change(update)
            Types.EntityChangeable.DODGE:
                _handle_dodge_change(update)
            Types.EntityChangeable.PROC:
                _handle_proc_change(update)
            _:
                assert(false, "Unhandled EntityChangeable type in GUI: " % change.property)

            
            
