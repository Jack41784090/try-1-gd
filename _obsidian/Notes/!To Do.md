# CONDOR Project - To Do List

Last Updated: 2025-11-16

## ✅ Completed Features

### Tactical Combat System
- [x] Entity stats system with reality values (HP, Force, Mana, etc.)
- [x] Changeable stats (HP, STA, ORG, LOC)
- [x] Weapon system with hit/penetration mechanics
- [x] Armor system with DV/PV and damage mitigation
- [x] Combat resolution (OneClash) with hit/pierce rolls
- [x] Skill system with effects
- [x] Status effects with duration and triggers
- [x] AI Logic system with base implementation
- [x] Specialized AI types:
  - [x] FrontlineLogic (aggressive melee)
  - [x] ArcherLogic (defensive ranged)
  - [x] AbsurdLogic (test AI)
  - [x] AdjustWeaponTestLogic (position optimizer)
- [x] Squad management and coordination
- [x] Team-based battle orchestration
- [x] Entity update tracking system
- [x] Visual representation of entities on battlefield (3D sprites with shaders)
- [x] Battlefield scene with visual elements

### Strategic Campaign Layer
- [x] World system with global state tracking
- [x] Location system with adjacency graph
- [x] Travel graph with pathfinding (BFS)
- [x] Turn-based activity system
- [x] Activity implementations:
  - [x] REST (morale recovery)
  - [x] DRILL (stat improvement)
  - [x] TRAVEL (location movement)
  - [x] PATROL (stability improvement)
  - [x] INVESTIGATE (mission discovery)
  - [x] HOLD_MASS (religious ceremony)
- [x] Event system with trigger conditions
- [x] Mission system with dependency graphs
- [x] Faction system with reputation tracking
- [x] Ending system
- [x] Triggerable base class architecture
- [x] TriggerableManager for unified event handling
- [x] Generic result pattern for all outcomes
- [x] Strategic squad with warriors and resources

### Visual Novel System
- [x] EventChain resource class
- [x] Dialogue resource class with trigger support
- [x] VisualNovelComponent logic class
- [x] Integration with activities, events, missions, and endings
- [x] Training screen UI with VN mode switching
- [x] Event chain resources for activities

### UI & Player Control
- [x] Training screen with activity selection buttons
- [x] Status display (morale, resources, location)
- [x] Visual novel screen for narrative presentation
- [x] Basic player control through UI buttons
- [x] Progress bars for squad stats

### Bridge Systems
- [x] Strategy ↔ Tactical conversion patterns defined
- [x] EntityUpdate return pattern for combat results

## 🚧 In Progress / Partially Complete

### Combat System Enhancements
- [ ] Expand skill system with more diverse abilities
  - Current: Basic skill effects implemented
  - Need: More skill types, combos, and synergies
- [ ] Expand AI logic types
  - Current: 4 basic types implemented
  - Need: More sophisticated behavior patterns (defensive, support, mixed)
- [ ] Full status effect integration in combat flow
  - Current: Status effects exist but limited integration
  - Need: More trigger types, stacking rules, dispel mechanics

### Strategic Layer Improvements
- [ ] Complete combat bridge implementation
  - Current: Conversion patterns defined but not fully implemented
  - Need: `StrategicSquad.to_combat_squad()` and `from_combat_results()` completion
- [ ] Expand event library
  - Current: 4 generic events
  - Need: More diverse events, random encounters, story events
- [ ] Mission content creation
  - Current: Mission system complete, needs content
  - Need: Mission trees for each faction, varied objectives
- [ ] Multiple endings implementation
  - Current: Ending system exists
  - Need: Multiple ending scenarios with different conditions

### Visual & Polish
- [ ] Combat animations
  - Current: Static visual representation
  - Need: Attack animations, hit effects, movement animations
- [ ] UI polish and improvements
  - Current: Functional but basic
  - Need: Better styling, tooltips, feedback animations
- [ ] Sound effects and music
  - Current: None
  - Need: Combat sounds, UI sounds, background music

## 📋 To Do - High Priority

### Core Gameplay
1. [ ] **Complete Combat Bridge** (Strategic ↔ Tactical)
   - Implement `StrategicSquad.to_combat_squad()` conversion
   - Implement `StrategicSquad.from_combat_results()` updates
   - Test round-trip conversion and data preservation
   - Handle warrior casualties and stat changes

2. [ ] **Save/Load System**
   - Design save file structure (JSON or binary)
   - Implement world state serialization
   - Implement squad/warrior serialization
   - Save/load mission progress and completion
   - Auto-save functionality
   - Multiple save slots

3. [ ] **Tutorial System**
   - Introduction to tactical combat
   - Introduction to strategic layer
   - Activity explanations
   - Mission system overview

### Content Expansion

4. [ ] **Mission Content Creation**
   - Design mission trees for each faction
   - Create prerequisite/postrequisite chains
   - Define mission completion conditions
   - Write mission narratives
   - Create mission-specific events

5. [ ] **Event Library Expansion**
   - Random encounters during travel
   - Location-specific events
   - Religion-based events
   - Warrior personality events
   - Reputation milestone events
   - Combat-triggered events

6. [ ] **Ending Scenarios**
   - Victory endings (multiple paths)
   - Defeat endings
   - Faction-specific endings
   - Hidden endings based on choices
   - Epilogue scenes for each ending

### Combat Enhancements

7. [ ] **Advanced AI Behaviors**
   - Support AI (healing, buffing)
   - Defensive AI (protect allies)
   - Berserker AI (high risk/reward)
   - Commander AI (tactical coordination)
   - Enemy-specific behaviors

8. [ ] **Skill Expansion**
   - AOE skills (affect multiple targets)
   - Buff/debuff skills
   - Healing skills
   - Position manipulation skills
   - Combo skills (trigger on conditions)
   - Ultimate abilities

9. [ ] **Combat Animations**
   - Attack animations (melee, ranged, magic)
   - Hit/damage flash effects
   - Movement animations
   - Skill effect animations
   - Death animations
   - Victory/defeat animations

### UI/UX Improvements

10. [ ] **Enhanced Battle UI**
    - Turn order display
    - Entity health bars
    - Skill/status effect indicators
    - Combat log with filtering
    - Tactical overlay (ranges, threats)

11. [ ] **Strategic UI Enhancements**
    - World map visualization
    - Mission tree visualization
    - Faction reputation display
    - Warrior management screen
    - Equipment/inventory management

12. [ ] **Quality of Life Features**
    - Combat speed controls (pause, fast-forward)
    - Combat replay system
    - Battle auto-resolve option
    - Hotkeys for common actions
    - Settings menu (audio, graphics, gameplay)

## 📋 To Do - Medium Priority

### Polish & Balance

13. [ ] **Game Balance**
    - Entity stat balancing
    - Weapon/armor balancing
    - Skill cost/power balancing
    - Activity resource cost balancing
    - Mission difficulty progression

14. [ ] **Audio System**
    - Sound effect library
    - Background music tracks
    - Audio manager implementation
    - Volume controls
    - Dynamic music (combat vs exploration)

15. [ ] **Visual Polish**
    - Particle effects for combat
    - Screen shake on impacts
    - UI transitions and animations
    - Better visual feedback for actions
    - Improved sprite art

### System Enhancements

16. [ ] **Achievement System**
    - Define achievement list
    - Track achievement progress
    - Achievement notification UI
    - Steam/platform integration (future)

17. [ ] **Statistics Tracking**
    - Combat statistics (kills, damage dealt, etc.)
    - Strategic statistics (turns, resources spent)
    - Per-warrior statistics
    - Statistics display screen

18. [ ] **Difficulty Settings**
    - Easy/Normal/Hard modes
    - Ironman mode (no save scumming)
    - Custom difficulty options
    - Difficulty affects rewards

### Content Tools

19. [ ] **Level/Battle Editor**
    - Visual editor for battle setups
    - Entity placement and configuration
    - Save/load custom battles
    - Share custom battles

20. [ ] **Event/Mission Editor**
    - Visual editor for event chains
    - Mission tree editor
    - Trigger condition builder
    - Event chain preview/test mode

## 📋 To Do - Low Priority

### Future Features

21. [ ] **Multiplayer/Co-op**
    - Design multiplayer architecture
    - Implement network synchronization
    - Co-op campaign mode
    - PvP battle mode

22. [ ] **Modding Support**
    - Mod loading system
    - Custom entity definitions
    - Custom skill/status effect mods
    - Custom campaign mods
    - Steam Workshop integration

23. [ ] **Platform Ports**
    - Mobile optimization
    - Console controller support
    - Console-specific UI adaptations

24. [ ] **Localization**
    - Translation system
    - Text extraction for translation
    - Multi-language support
    - Cultural adaptations

25. [ ] **Advanced Visual Effects**
    - Weather effects
    - Day/night cycle
    - Dynamic lighting
    - Post-processing effects
    - Cinematic camera angles

## 🐛 Known Issues / Tech Debt

- [ ] Broken `_obsidian` symlink (resolved: converted to real directory)
- [ ] Limited error handling in some systems
- [ ] Some stub implementations need completion
- [ ] Type safety improvements needed in some areas
- [ ] Performance optimization for large battles
- [ ] Memory leak checks needed

## 📝 Documentation Needs

- [ ] API documentation for core systems
- [ ] Tutorial documentation for new developers
- [ ] Design document for combat mechanics
- [ ] Design document for strategic layer
- [ ] Content creation guidelines
- [ ] Modding documentation

---

## Notes

- Priority is somewhat flexible based on current development focus
- Combat and strategic systems are well-architected and extensible
- Visual Novel system is a strong foundation for narrative delivery
- Main gaps are in content (missions, events, endings) and polish (animations, audio)
- Save/load system is critical for player experience
- Tutorial system is important for accessibility
