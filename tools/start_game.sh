#!/bin/bash
# Start the CONDOR interactive game as a fully detached background process.
# This avoids issues with VSCode terminal management.
#
# Usage: bash tools/start_game.sh
# Then:  bash tools/play.sh "status"

cd "$(dirname "$0")/.."

# Kill any existing game process
pkill -f "interactive_demo" 2>/dev/null
sleep 1

# Clean pipes
echo '' > /tmp/condor_input
echo '' > /tmp/condor_output

# Start game fully detached from terminal
nohup bash -c 'tail -f /tmp/condor_input | godot-mono --headless --path . scenes/demos/interactive_demo.tscn 2>&1 | tee /tmp/condor_output' > /dev/null 2>&1 &
disown

echo "Game starting in background (PID: $!)..."
echo "Wait ~20 seconds for initialization, then use: bash tools/play.sh \"status\""
