@tool
class_name CharacterManifest extends Resource

## Single registry entry for a character — every file that makes them up,
## in one place. Lives in resources/characters/<id>.tres.

@export var character_id: String = ""
@export var art_dir: String = ""
@export var rig_config: WarriorRigConfig
@export var combat_template: CombatEntityResource
@export var warrior_preset: WarriorBackground
@export var has_face: bool = false
