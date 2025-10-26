# Quick Start Guide

## Running the Squad Battle Demo

1. **Open the Project**
   ```bash
   cd /home/ikec/Documents/Code/Godot/try-1-gd
   # Open in Godot 4.x editor
   ```

2. **Run the Demo Scene**
   - In Godot Editor: Open `squad_battle_demo.tscn`
   - Press F5 or click the "Play Scene" button
   - Watch the automated battle unfold

3. **What You'll See**
   - Turn-by-turn combat simulation
   - Entity stats displayed in real-time
   - Console logs showing detailed combat events
   - Battle automatically ends when one team wins

## Understanding the Output

### On-Screen Display
- **Round Counter**: Current battle round
- **Team Info**: Shows each team's total strength
- **Squad Info**: Lists squads and entity count
- **Entity Details**: Shows each entity's:
  - Name
  - HP (current/max)
  - Organization (morale)
  - Location (Front=1, Middle=2, Back=3)

### Console Output
```
--- Round 1 ---
[Squad:Heroes Front] ⚔️ [Goblins]
[Sir Galahad] Deciding action...
[Sir Galahad] || Chose action: IDLE
--- Round 1 Updates ---
  - 1 -> 1: HP 92 -> 95
  - 1 -> 1: ORG 120 -> 125
```

## Customizing the Battle

Edit `squad_battle_demo.gd`:

### Change Entity Stats
```gdscript
# Modify stats: (id, str, dex, acr, spd, siz, int, spr, fai, cha, beu, wil, end)
var entity_stats = Types.EntityBaseStats.new(
    "warrior1",  # ID
    20,          # Strength (increased from 15)
    15,          # Dexterity
    # ... other stats
)
```

### Add More Entities
```gdscript
var new_entity = {
    "player_id": 6,
    "name": "New Hero",
    "stats": entity_stats,
    "team": "heroes",
    "starting_location": Types.SquadEntityInSquadLocation.Middle,
    "logic_type": "default"
}
# Add to squad1_config["entities"]
```

### Change Battle Speed
```gdscript
# In _ready():
delay_between_rounds = 1.0  # Faster (default: 2.0)
# or
delay_between_rounds = 5.0  # Slower
```

### Try Different AI Logic
```gdscript
# In entity config:
"logic_type": "absurd"          # Always moves forward, retreats on reaction
"logic_type": "adjust_weapon"   # Optimizes weapon range
"logic_type": "default"         # Standard tactical behavior
```

## Project Structure

```
try-1-gd/
├── squad_battle/
│   ├── types.gd              # Data types & enums
│   ├── squad_entity.gd       # Entity logic
│   ├── weapon.gd             # Weapon system
│   ├── armour.gd             # Armour system
│   ├── logic.gd              # AI decision-making
│   ├── squad.gd              # Squad management
│   ├── squad_battle.gd       # Battle coordinator
│   └── README.md             # Detailed docs
├── squad_battle_demo.gd      # Demo script
├── squad_battle_demo.tscn    # Demo scene
├── MIGRATION_SUMMARY.md      # Migration details
└── QUICKSTART.md             # This file
```

## Common Modifications

### Make Battle Last Longer
Increase entity endurance and size (affects HP):
```gdscript
var stats = Types.EntityBaseStats.new(
    "tank", 15, 12, 10, 10,
    20,  # Size (increased)
    8, 8, 10, 9, 8, 12,
    20   # Endurance (increased)
)
```

### Create More Teams
```gdscript
var battle_config = {
    "teams": {
        "heroes": [squad1_config],
        "monsters": [squad2_config],
        "undead": [squad3_config]    # New team!
    }
}
```

### Adjust Combat Behavior
Modify `logic.gd` methods:
- `choose_action()` - What entity does on its turn
- `choose_reaction()` - How entity responds to attacks
- `retreat_if_outnumbered()` - Retreat logic
- `heal_others_if_around()` - Support behavior

## Troubleshooting

**Battle doesn't start:**
- Check console for errors
- Verify `squad_battle_demo.tscn` is the active scene
- Ensure all `.gd` files are in `squad_battle/` folder

**Entities don't attack:**
- Logic system might be set to idle
- Check `choose_clash()` implementation
- Verify weapon ranges in `weapon.gd`

**Performance issues:**
- Reduce `delay_between_rounds` for faster processing
- Limit number of entities
- Disable verbose console logging

## Next Steps

1. **Add Visuals**: Create sprites for entities
2. **Player Control**: Add UI buttons for player actions
3. **More Content**: Design new weapons, armour, skills
4. **Balancing**: Tune combat values
5. **Features**: Implement full skill/ability system

Enjoy your squad battle system! 🎮⚔️
