---
name: condor-play
description: "CONDOR interactive play via play.sh, screenshot workflow, MCP tools, SVG canvas, per-agent game isolation. Use when running the game interactively, taking screenshots, testing gameplay, or using the canvas drawing tool."
---

# CONDOR Interactive Play

## Quick Start

```bash
bash tools/play.sh "status"         # Auto-starts game, sends command
bash tools/play.sh "screenshot" --gui  # GUI mode with screenshot
```

No manual setup needed — `play.sh` auto-starts a dedicated game instance per session.

## Session Management

Each agent gets a dedicated game instance via `CONDOR_SESSION`:
- `play.sh` auto-generates a session ID if `CONDOR_SESSION` is unset
- Set `export CONDOR_SESSION=<id>` for persistence across calls
- `start_game.sh [session_id]` / `start_game_gui.sh [session_id]` accept optional session IDs (default: `default`)
- Pipes: `/tmp/condor_{input,output,pid}_<session>`

## Commands

- **GOD commands**: `god_squads`/`gs`, `god_contacts`/`gc`, `god_lock`/`gl <id>`, `god_economy`/`ge`
- **Flags**: `--gui` (visible window for screenshots), `--stop` (kill session's game)
- **Stop a session**: `CONDOR_SESSION=<id> bash tools/play.sh --stop`

## Screenshot Workflow

1. Just call `bash tools/play.sh "status"` — game auto-starts (headless). For screenshots: `bash tools/play.sh "screenshot" --gui`
2. Or start manually: `bash tools/start_game_gui.sh mysession` then `CONDOR_SESSION=mysession bash tools/play.sh "screenshot"`
3. MCP tools (auto-discovered via `.vscode/mcp.json`): `screenshot_game` (command + screenshot), `view_screenshot` (last screenshot), `game_command` (text-only) — all auto-start their own game
4. The `screenshot`/`ss` command uses `get_viewport().get_texture().get_image().save_png()` — only works in GUI mode, errors gracefully in headless
5. Clock overlay: `ClockLabel` in top-left corner shows `⌚ HH:00`, updated by `StrategyView.update_clock()`

## SVG Drawing Canvas

`canvas_demo.tscn` — AI drawing sandbox with auto-reload:

1. Start: `bash tools/start_canvas.sh [session_id]` — GUI window + per-session pipes. Defaults to session `canvas`
2. **Multi-instance**: `bash tools/start_canvas.sh agent1`, `bash tools/start_canvas.sh agent2`
3. Wait ~10s, then `CONDOR_SESSION=<id> bash tools/play.sh "info"` to verify
4. **Free-form mode**: Edit `scenes/demos/canvas/default.tscn` (Sprite2D nodes with `metadata/svg_path`), edit SVGs in `scenes/demos/canvas/svgs/` — auto-reloads within 0.5s
5. **Rig mode**: `CONDOR_SESSION=canvas bash tools/play.sh "rig landsknecht"` — loads warrior skeleton from `svgs/rig/landsknecht/` (15 bones)
6. Rig animations: `bash tools/play.sh "anim idle"` / `walk` / `attack` / `defend` / `hurt` / `die`
7. Camera: `zoom 3.0`, `zoom_in`, `zoom_out`, `pan 500 300`, `center`
8. Other: `grid` (toggle), `bg #1a1a2e` (background), `tree` (node dump), `sizes` (bone dimensions), `shader <node> <param> <value>`
9. SVG viewBox sizes (base ×4): Head=120×136, Torso=168×144, Hips=144×40, Arm=48×112, Forearm=40×88, Hand=32×32, Leg=56×136, Shin=48×112, Foot=80×40
10. Shaders: put `.gdshader` files in `assets/shaders/canvas/`, reference from canvas `.tscn` as ShaderMaterial — auto-reloads on edit

## Concurrency

- `play.sh` uses `flock` per-session to serialize commands from parallel agents
- `canvas_demo.gd` debounces file-watch reloads (0.3s) and gates commands/reloads behind `_busy` flag

## Sound Generation

`python3 tools/sound_designer.py` (`--list`, `--preset <name>`, `--format wav|mp3|ogg`)
