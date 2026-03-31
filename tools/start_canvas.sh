#!/bin/bash
# Start a CONDOR SVG Drawing Canvas instance with a visible GUI window.
# Multiple instances can run simultaneously — each gets its own pipe pair.
#
# Usage: bash tools/start_canvas.sh [session_id]
# Then:  CONDOR_SESSION=<id> bash tools/play.sh "info"
#        CONDOR_SESSION=<id> bash tools/play.sh "screenshot"
#
# If session_id is omitted, defaults to "canvas".
# Each session uses /tmp/condor_input_<id> and /tmp/condor_output_<id>.

cd "$(dirname "$0")/.."

SESSION="${1:-canvas}"
INPUT_FILE="/tmp/condor_input_${SESSION}"
OUTPUT_FILE="/tmp/condor_output_${SESSION}"
PLAY_LOCK="/tmp/condor_play_${SESSION}.lock"

# Clean pipes for this session
echo '' > "$INPUT_FILE"
echo '' > "$OUTPUT_FILE"

# Start canvas with GUI fully detached from terminal
nohup bash -c "tail -f '$INPUT_FILE' | godot-mono --path . scenes/demos/canvas_demo.tscn 2>&1 | tee '$OUTPUT_FILE'" > /dev/null 2>&1 &
CANVAS_PID=$!
disown

echo "Canvas starting (session: $SESSION, PID: $CANVAS_PID)..."
echo "Wait ~10 seconds for initialization, then use:"
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"info\""
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"screenshot\""
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"rig landsknecht\""
