# Squad Battle System - Roblox to Godot Migration

This directory contains the migrated squad battle logic from the `life-is-roblox` project to Godot/GDScript.

## Overview

The squad battle system is a turn-based tactical combat system featuring:
- **Entities** with stats (strength, dexterity, intelligence, etc.)
- **Squads** that group entities together
- **Teams** composed of multiple squads
- **AI Logic** for entity decision-making (attack, retreat, heal, etc.)
- **Weapons & Armour** with damage calculations and resistances
- **Changeable Stats** (HP, Stamina, Organization, Position, Mana, Location)

## File Structure

```
squad_battle/
├── types.gd              # Core data types and enums
├── squad_entity.gd       # Entity class with combat methods
├── weapon.gd             # Weapon system with damage calculations
├── armour.gd             # Armour system with resistances
├── logic.gd              # AI decision-making logic
├── squad.gd              # Squad management
└── squad_battle.gd       # Battle system coordinator

squad_battle_demo.gd      # Demo script showcasing the system
squad_battle_demo.tscn    # Demo scene
```

## Key Classes

### SquadBattleTypes (types.gd)
Defines all enums and data structures:
- `Reality` - Reality values (HP, Force, Mana, etc.)
- `Potency` - Damage types (Strike, Slash, Stab, etc.)
- `DamageType` - Physical, Cut, Impale, Magic
- `SquadEntityInSquadLocation` - Front/Middle/Back positioning
- `EntityBaseStats` - Core entity attributes
- `EntityChange` & `EntityUpdate` - State change tracking

### SquadEntity (squad_entity.gd)
Represents a combat entity with:
- Base stats (strength, dexterity, intelligence, etc.)
- Changeable stats (HP, Organization, Location, etc.)
- Combat methods (`damage()`, `heal()`, `boost()`, `recover()`)
- Action/reaction system for turn-based combat
- Equipment (weapon, armour)
- AI logic integration

### SquadWeapon (weapon.gd)
Weapon system featuring:
- Hit bonus and penetration bonus
- Damage translation (Reality → Potency → Damage)
- Range based on squad location
- Damage calculations based on entity stats

### SquadArmour (armour.gd)
Armour system with:
- Defense Value (DV) and Protection Value (PV)
- Damage type resistances
- Damage mitigation calculations

### SquadLogic (logic.gd)
AI decision-making system:
- Base `Logic` class with situation awareness
- `choose_action()` - Decides what to do during turn
- `choose_reaction()` - Responds to enemy actions
- Specialized subclasses: `AbsurdLogic`, `AdjustWeaponTestLogic`

### Squad (squad.gd)
Manages a group of entities:
- Entity positioning (Front/Middle/Back)
- Round-based actions
- Recovery between rounds
- Squad-level combat coordination

### SquadBattle (squad_battle.gd)
Top-level battle coordinator:
- Team management
- Victory condition checking
- Round progression
- Entity removal (dead/capitulated)
- Update logging

## Migration Notes

### TypeScript → GDScript Changes

1. **Type System**
   - TypeScript interfaces → GDScript classes/dictionaries
   - `Atom<number>` (reactive) → plain `float` values
   - `Record<K, V>` → `Dictionary`
   - `Array<T>` → `Array` (untyped in GDScript)

2. **Language Differences**
   - `const` → `const` (similar)
   - Arrow functions → `func`
   - Template literals → String formatting with `%`
   - `for...of` → `for...in`
   - `.map()`, `.filter()` → manual loops or lambdas

3. **Roblox-Specific Features Removed**
   - `@rbxts/charm` atoms replaced with direct values
   - Event bus simplified (stubbed out)
   - Graphics/rendering layer not migrated
   - Roblox Vector2 → Godot positioning concepts

4. **Godot-Specific Additions**
   - `extends RefCounted` for non-Node classes
   - `class_name` for global class registration
   - `@onready` for node references
   - Scene-based architecture

## Usage Example

```gdscript
# Create entity stats
var stats = Types.EntityBaseStats.new("warrior", 15, 12, 10, 10, 12, 8, 8, 10, 9, 8, 12, 14)

# Create squad configuration
var squad_config = {
    "name": "Heroes",
    "team": "heroes",
    "entities": [
        {
            "player_id": 1,
            "name": "Hero 1",
            "stats": stats,
            "team": "heroes",
            "starting_location": Types.SquadEntityInSquadLocation.Front,
            "logic_type": "default"
        }
    ]
}

# Create battle configuration
var battle_config = {
    "teams": {
        "heroes": [squad_config],
        "monsters": [enemy_squad_config]
    }
}

# Initialize battle
var battle = SquadBattle.new(battle_config)

# Run rounds
while not battle.check_victory():
    battle.round_count += 1
    battle.remove_dead_entities()
    var updates = battle.squad_actions()
    battle.squad_recoveries()
```

## Running the Demo

1. Open the project in Godot 4.x
2. Run the `squad_battle_demo.tscn` scene
3. Watch the turn-based combat unfold
4. Check console for detailed combat logs

## Future Enhancements

- [ ] Add visual representation of entities on battlefield
- [ ] Implement skill system fully
- [ ] Add status effects
- [ ] Create UI for player control
- [ ] Add animations for combat actions
- [ ] Implement save/load system
- [ ] Add more AI logic types
- [ ] Create level editor for battles

## Original Source

Migrated from: `life-is-roblox/src/squad-battle/`

The original TypeScript implementation was designed for Roblox with:
- roblox-ts for TypeScript → Luau compilation
- Charm for reactive state management
- Custom event bus system
- Roblox-specific rendering

This GDScript version maintains the core game logic while adapting to Godot's architecture and GDScript's capabilities.
