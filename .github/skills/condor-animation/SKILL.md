---
name: condor-animation
description: "CONDOR animation system: WarriorRig, skeletal animations, art style, stage/VN system, GrimdarkFX shaders, UIAnimations. Use when working on character rigs, animations, visual novel scenes, stage presentation, shaders, or visual effects."
---

# CONDOR Animation & Visuals

## Animation System

`src/animation/` — 5-layer system: Clips→iExpression→AnimAction→Behavior→WarriorAnimController.

- `WarriorRig` (src/animation/warrior_rig.gd) — generates placeholder Polygon2D body parts, `apply_config()` replaces with textures
- `WarriorRigConfig/Factory` for per-class configs

### Animation Behaviors

`AnimTypes.Behavior`: IDLE, WALKING, ATTACKING, DEFENDING, HURT, DYING, TALKING, GESTURING

| Behavior | Duration | Style |
|----------|----------|-------|
| IDLE | 2s | Slow breathe |
| WALKING | 1s | Heavy stride with shin bend |
| ATTACKING | 0.9s | Explosive wind-up |
| DEFENDING | 0.7s | Bracing |
| HURT | 0.6s | Stagger |
| DYING | 1.5s | Tragic collapse with alpha fade |
| TALKING | 1.6s | Weighted gestures |
| GESTURING | 1s | Dramatic flourish |

### Rig Art Style

2D anime SD (super deformed) flat vector — clean 2px black outlines, solid color fills, no gradients or cross-hatching, 1:2.5 head-to-body ratio. SVG textures in `assets/rig_textures/<class>/` (15 bones × 7 classes = 105 SVGs). Canvas demo copies in `scenes/demos/canvas/svgs/rig/<class>/`. Generator: `python3 tools/generate_sd_svgs.py`.

## Warrior Stage

`src/strategy/ui/stage/`: `StageView` + `StagePresenter` — shared 2D viewport for march and VN:
- Modes: MARCH/VN/HIDDEN
- `SpeechBubble` with typewriter effect
- `StageCamera` with tween-based focus

## Visual Novel System

`src/strategy/ui/vn/`:
- `EventChain` triggers via `event_chain_path` in results
- `VnPresenter` is stage-aware (speech bubble on rig or fallback textbox)
- `DialogueInstruction` extends `CinematicInstruction` with speaker_name, line_spoken, after_id
- `GroupPlayback` processes `CinematicGroup` trees (parallel/sequential/auto-gate)
- `CharacterInstruction` (SHOW/HIDE + StageAnchor)
- `CameraInstruction` (screen position panning)

## GrimdarkFX

`src/singletons/grimdark_fx.gd` + `scenes/grimdark_fx.tscn` — `GrimdarkFX` autoload. Two layers: texture-based (applied to bg/fg) + overlay (CanvasLayer 200). Disabled in headless.

| Shader | File | Effect |
|--------|------|--------|
| World atmosphere | `assets/shaders/fx/world_atmosphere.gdshader` | Time-of-day tinting, desaturation, contrast, fog wisps. Applied to MainBackground/Foreground via `register_world_textures()` |
| Vignette | `assets/shaders/fx/vignette.gdshader` | Dark radial edges overlay, intensifies at night |
| Film grain | `assets/shaders/fx/film_grain.gdshader` | Subtle animated noise overlay, salt-and-pepper speckle |
| Damage pulse | `assets/shaders/fx/damage_pulse.gdshader` | Red vignette flash, triggered via `GrimdarkFX.trigger_damage_pulse()` |
| Combat atmosphere | `assets/shaders/fx/combat_atmosphere.gdshader` | Desaturation + contrast + red shift during combat. `GrimdarkFX.set_combat_mode(true/false)` |

## Supporting

- **SFX** (`src/singletons/sfx.gd`): `SFX` autoload, semantic play methods. Disabled in headless
- **UIAnimations** (`src/utils/ui_animations.gd`): static class — `register_button()` (hover/press/SFX), `show_overlay/hide_overlay()`, `stagger_buttons()`, `slide_in/out_panel()`, `pulse()`, `animate_label_number()`
- **Theme** (`resources/theme/condor_theme.tres`): EB Garamond font, multi-use styles via `theme_type_variation`, single-use via `theme_override_*` or standalone `.tres` in `resources/theme/styles/`. `ThemeConstants` for GDScript color/size constants
