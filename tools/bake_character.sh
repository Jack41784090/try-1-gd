#!/usr/bin/env bash
set -euo pipefail

## One-command character bake pipeline.
##
## Usage:
##   tools/bake_character.sh rachelle
##   tools/bake_character.sh landsknecht
##
## Steps:
##   1. bake_svg_clips.py  — resolves <use>/<clipPath> for Godot's ThorVG,
##                           splits face parts if a Face layer exists
##   2. bake_rig_scene.gd  — bakes textures + face subtree into warrior_rig_2.tscn,
##                           rebuilds RESET from bind pose
##
## Prerequisites: inkscape on PATH (for face-part pivot queries), godot on PATH.

CHARACTER="${1:?Usage: tools/bake_character.sh <character-id>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART_DIR="$ROOT/assets/rig_textures/$CHARACTER"

if [ ! -d "$ART_DIR" ]; then
	echo "error: no art directory for '$CHARACTER' at $ART_DIR" >&2
	exit 1
fi

echo "=== [1/2] bake_svg_clips: $CHARACTER ==="
python3 "$ROOT/tools/bake_svg_clips.py" "$ART_DIR"

echo "=== [2/2] bake_rig_scene: $CHARACTER ==="
godot --headless --path "$ROOT" --script res://tools/bake_rig_scene.gd -- "$CHARACTER"

echo "=== done: $CHARACTER ==="
