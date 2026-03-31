#!/bin/bash
# AI Play Helper — Send commands to the interactive CONDOR terminal game
# and read filtered game output.
#
# Auto-starts a dedicated game instance per agent session.
# No manual setup required — just call play.sh and it handles everything.
#
# === USAGE ===
#
#   bash tools/play.sh "<command>" [wait_seconds] [--verbose] [--gui] [--stop]
#
# Examples:
#   bash tools/play.sh "status"
#   bash tools/play.sh "rest" 6
#   bash tools/play.sh "travel oehringen" 15
#   bash tools/play.sh "look" 2
#   bash tools/play.sh "rest" 6 --verbose   # includes engine Log.* lines
#   bash tools/play.sh "screenshot" 4 --gui  # needs GUI for screenshots
#   bash tools/play.sh --stop                # stop game for this session
#
# Session isolation:
#   Each agent gets a dedicated game instance via CONDOR_SESSION.
#   If CONDOR_SESSION is not set, a unique session ID is auto-generated.
#   Set CONDOR_SESSION for persistence across calls:
#     export CONDOR_SESSION=myagent
#     bash tools/play.sh "status"
#
# Default wait is 4 seconds. Use longer waits for travel (15s) and
# activities (6s) that trigger the full turn pipeline.
#
# Output includes a structured Turn Report after each activity showing:
#   - What the player and AI squads did
#   - Stat deltas (morale/food/gold/tools)
#   - Contact intel changes
#   - Events and missions triggered
#   - Caravan spawns/deliveries
#   - Combat outcomes
#   - World state changes (squad movements, eliminations)

CMD=""
WAIT=4
VERBOSE=false
GUI=false
STOP=false
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Parse args: cmd [wait] [--verbose] [--gui] [--stop]
for arg in "$@"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
        VERBOSE=true
    elif [[ "$arg" == "--gui" ]]; then
        GUI=true
    elif [[ "$arg" == "--stop" ]]; then
        STOP=true
    elif [[ -z "$CMD" ]]; then
        CMD="$arg"
    else
        WAIT="$arg"
    fi
done

# Auto-generate session ID if not set
if [ -z "$CONDOR_SESSION" ]; then
    CONDOR_SESSION="auto_$(head -c4 /dev/urandom | xxd -p)"
    echo "CONDOR_SESSION=$CONDOR_SESSION" >&2
    echo "Export it for subsequent calls:  export CONDOR_SESSION=$CONDOR_SESSION" >&2
fi

# Session-specific paths
OUTPUT_FILE="/tmp/condor_output_${CONDOR_SESSION}"
INPUT_FILE="/tmp/condor_input_${CONDOR_SESSION}"
PID_FILE="/tmp/condor_pid_${CONDOR_SESSION}"
PLAY_LOCK="/tmp/condor_play_${CONDOR_SESSION}.lock"

# Check if game is running for this session
_game_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

# Start game for this session
_start_game() {
    echo '' > "$INPUT_FILE"
    echo '' > "$OUTPUT_FILE"

    local MODE_FLAG="--headless"
    [ "$GUI" = true ] && MODE_FLAG=""

    nohup setsid bash -c "tail -f '$INPUT_FILE' | godot-mono $MODE_FLAG --path '$PROJECT_DIR' scenes/demos/interactive_demo.tscn 2>&1 | tee '$OUTPUT_FILE'" > /dev/null 2>&1 &
    local GAME_PID=$!
    echo $GAME_PID > "$PID_FILE"
    disown

    echo "Starting CONDOR game (session: $CONDOR_SESSION, PID: $GAME_PID, mode: ${GUI:+gui}${GUI:-headless})..." >&2

    # Wait for game initialization (poll for "Game ready!" marker)
    local TIMEOUT=45
    local ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if grep -q "Game ready!" "$OUTPUT_FILE" 2>/dev/null; then
            echo "Game ready." >&2
            return 0
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    echo "WARNING: Game did not report ready within ${TIMEOUT}s (may still be loading)" >&2
    return 1
}

# Stop game for this session
_stop_game() {
    if _game_running; then
        local GAME_PID
        GAME_PID=$(cat "$PID_FILE" 2>/dev/null)
        # Kill the process group (setsid gives it its own group)
        kill -TERM -- "-$GAME_PID" 2>/dev/null || kill -TERM "$GAME_PID" 2>/dev/null
        echo "Game stopped (session: $CONDOR_SESSION, PID: $GAME_PID)" >&2
    else
        echo "No game running for session: $CONDOR_SESSION" >&2
    fi
    rm -f "$PID_FILE" "$INPUT_FILE" "$OUTPUT_FILE" "$PLAY_LOCK"
}

# Handle --stop
if [ "$STOP" = true ]; then
    _stop_game
    exit 0
fi

if [ -z "$CMD" ]; then
    echo "Usage: bash tools/play.sh \"<command>\" [wait_seconds] [--verbose] [--gui] [--stop]"
    echo ""
    echo "Commands: status, look, warriors, travel <id>, rest, forage, drill,"
    echo "  patrol, heal, buy, mercenary, mass, attack <id>, contacts,"
    echo "  missions, events, notifications, economy, map, help, quit"
    echo ""
    echo "GOD mode: god_squads (gs), god_contacts (gc), god_lock (gl) <id>, god_economy (ge)"
    echo ""
    echo "Flags: --verbose/-v  Show engine Log.* lines for deep debugging"
    echo "       --gui         Start with visible window (required for screenshots)"
    echo "       --stop        Stop the game instance for this session"
    exit 1
fi

# Auto-start game if not running for this session
if ! _game_running; then
    _start_game
fi

# Serialize command+read as an atomic operation across parallel agents.
# flock -w 30: wait up to 30s for the lock (covers longest expected wait).
(
    flock -w 30 201 || { echo "Timed out waiting for play lock"; exit 1; }

    BEFORE=$(wc -l < "$OUTPUT_FILE")
    echo "$CMD" >> "$INPUT_FILE"
    sleep "$WAIT"

    if [ "$VERBOSE" = true ]; then
        # Verbose: show everything except low-level Godot engine noise
        tail -n +$((BEFORE + 1)) "$OUTPUT_FILE" \
            | grep -vE "^(  at: |  <[A-Z])" \
            | grep -vE "(backtrace|variant_iter)" \
            | grep -vE "^\s*$"
    else
        # Normal: show game output, hide engine internals
        tail -n +$((BEFORE + 1)) "$OUTPUT_FILE" \
            | grep -vE "^(WARNING:|ERROR:|USER WARNING:|USER ERROR:|  at: |  <[A-Z])" \
            | grep -vE "^(Godot Engine )" \
            | grep -vE "(\.gd:[0-9]+|\.cs:[0-9]+|backtrace|variant_)" \
            | grep -vE "^\[" \
            | grep -vE "^\s*$"
    fi
) 201>"$PLAY_LOCK"
