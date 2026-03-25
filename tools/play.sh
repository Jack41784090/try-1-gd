#!/bin/bash
# AI Play Helper — Send commands to the interactive CONDOR terminal game
# and read filtered game output.
#
# === SETUP (run once per session) ===
#
#   bash tools/start_game.sh
#   sleep 20  # wait for game init
#
# === USAGE ===
#
#   bash tools/play.sh "<command>" [wait_seconds] [--verbose]
#
# Examples:
#   bash tools/play.sh "status"
#   bash tools/play.sh "rest" 6
#   bash tools/play.sh "travel oehringen" 15
#   bash tools/play.sh "look" 2
#   bash tools/play.sh "rest" 6 --verbose   # includes engine Log.* lines
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
OUTPUT_FILE="${CONDOR_OUTPUT:-/tmp/condor_output}"
INPUT_FILE="${CONDOR_INPUT:-/tmp/condor_input}"

# Parse args: cmd [wait] [--verbose]
for arg in "$@"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
        VERBOSE=true
    elif [[ -z "$CMD" ]]; then
        CMD="$arg"
    else
        WAIT="$arg"
    fi
done

if [ -z "$CMD" ]; then
    echo "Usage: bash tools/play.sh \"<command>\" [wait_seconds] [--verbose]"
    echo ""
    echo "Commands: status, look, warriors, travel <id>, rest, forage, drill,"
    echo "  patrol, heal, buy, mercenary, mass, attack <id>, contacts,"
    echo "  missions, events, notifications, economy, map, help, quit"
    echo ""
    echo "GOD mode: god_squads (gs), god_contacts (gc), god_lock (gl) <id>, god_economy (ge)"
    echo ""
    echo "Flags: --verbose/-v  Show engine Log.* lines for deep debugging"
    exit 1
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Game not running. Start with: bash tools/start_game.sh && sleep 20"
    exit 1
fi

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
