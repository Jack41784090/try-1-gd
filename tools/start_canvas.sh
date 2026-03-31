#!/bin/bash
# Start the CONDOR SVG Drawing Canvas with a visible GUI window.
# Same piped stdin/stdout architecture as start_game_gui.sh.
#
# Usage: bash tools/start_canvas.sh
# Then:  bash tools/play.sh "info"
#        bash tools/play.sh "screenshot"

cd "$(dirname "$0")/.."

# Kill any existing canvas process
pkill -f "canvas_demo" 2>/dev/null
sleep 1

# Clean pipes
echo '' > /tmp/condor_input
echo '' > /tmp/condor_output

# Start canvas with GUI fully detached from terminal
nohup bash -c 'tail -f /tmp/condor_input | godot-mono --path . scenes/demos/canvas_demo.tscn 2>&1 | tee /tmp/condor_output' > /dev/null 2>&1 &
disown

echo "Canvas starting with GUI window (PID: $!)..."
echo "Wait ~10 seconds for initialization, then use:"
echo "  bash tools/play.sh \"info\""
echo "  bash tools/play.sh \"screenshot\""
echo "  bash tools/play.sh \"rig landsknecht\""
