#!/bin/bash
# Start the CONDOR interactive game WITH a visible GUI window.
# Same piped stdin/stdout architecture as start_game.sh, but renders
# the Godot window so screenshots can be captured.
#
# Usage: bash tools/start_game_gui.sh
# Then:  bash tools/play.sh "status"
#        bash tools/play.sh "screenshot"   # saves /tmp/condor_screenshot.png

cd "$(dirname "$0")/.."

# Kill any existing game process
pkill -f "interactive_demo" 2>/dev/null
sleep 1

# Clean pipes
echo '' > /tmp/condor_input
echo '' > /tmp/condor_output

# Start game with GUI (no --headless) fully detached from terminal
nohup bash -c 'tail -f /tmp/condor_input | godot-mono --path . scenes/demos/interactive_demo.tscn 2>&1 | tee /tmp/condor_output' > /dev/null 2>&1 &
disown

echo "Game starting with GUI window (PID: $!)..."
echo "Wait ~20 seconds for initialization, then use: bash tools/play.sh \"status\""
echo "Take screenshots with: bash tools/play.sh \"screenshot\""
