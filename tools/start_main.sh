#!/bin/bash
# Start a CONDOR Systems-layer (main.tscn) interactive instance as a fully
# detached background process. Same piped stdin/stdout architecture as
# start_game.sh, but runs scenes/demos/interactive_main.tscn — the Systems
# composition root with the prototype alpha/beta scenario.
#
# Usage: bash tools/start_main.sh [session_id]
# Then:  CONDOR_SESSION=<id> bash tools/play.sh "status"
#        CONDOR_SESSION=<id> bash tools/play.sh "/travel commander beta"
#        CONDOR_SESSION=<id> bash tools/play.sh "tick 3"
#
# If session_id is omitted, defaults to "main".
# Note: play.sh auto-starts a game if needed, so this script is optional —
# but it marks the session so play.sh restarts into the same scene.

cd "$(dirname "$0")/.."

SESSION="${1:-main}"
INPUT_FILE="/tmp/condor_input_${SESSION}"
OUTPUT_FILE="/tmp/condor_output_${SESSION}"
PID_FILE="/tmp/condor_pid_${SESSION}"

# Stop existing game for THIS session only (if any)
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill -TERM -- "-$OLD_PID" 2>/dev/null || kill -TERM "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi

# Clean pipes
echo '' > "$INPUT_FILE"
echo '' > "$OUTPUT_FILE"

# Write type marker so play.sh knows to restart as interactive_main if the session dies
TYPE_FILE="/tmp/condor_type_${SESSION}"
echo "main" > "$TYPE_FILE"

# Start game fully detached from terminal
nohup setsid bash -c "tail -f '$INPUT_FILE' | godot-mono --headless --path '$(pwd)' scenes/demos/interactive_main.tscn 2>&1 | tee '$OUTPUT_FILE'" > /dev/null 2>&1 &
GAME_PID=$!
echo $GAME_PID > "$PID_FILE"
disown

echo "Systems-layer game starting in background (session: $SESSION, PID: $GAME_PID)..."
echo "Wait ~15 seconds for initialization, then use:"
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"status\""
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"/travel commander beta\""
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"tick 3\""
