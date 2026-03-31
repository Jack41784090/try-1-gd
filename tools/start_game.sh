#!/bin/bash
# Start a CONDOR interactive game instance as a fully detached background process.
# Each session gets its own pipe pair — multiple instances can run simultaneously.
#
# Usage: bash tools/start_game.sh [session_id]
# Then:  CONDOR_SESSION=<id> bash tools/play.sh "status"
#
# If session_id is omitted, defaults to "default".
# Note: play.sh auto-starts a game if needed, so this script is optional.

cd "$(dirname "$0")/.."

SESSION="${1:-default}"
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

# Start game fully detached from terminal
nohup setsid bash -c "tail -f '$INPUT_FILE' | godot-mono --headless --path '$(pwd)' scenes/demos/interactive_demo.tscn 2>&1 | tee '$OUTPUT_FILE'" > /dev/null 2>&1 &
GAME_PID=$!
echo $GAME_PID > "$PID_FILE"
disown

echo "Game starting in background (session: $SESSION, PID: $GAME_PID)..."
echo "Wait ~20 seconds for initialization, then use:"
echo "  CONDOR_SESSION=$SESSION bash tools/play.sh \"status\""
