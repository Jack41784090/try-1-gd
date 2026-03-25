#!/bin/bash
# AI Play Helper — Send commands to the interactive CONDOR terminal game
# and read filtered game output.
#
# === SETUP (run once per session) ===
#
#   echo "" > /tmp/condor_input
#   tail -f /tmp/condor_input | godot-mono --headless --path . \
#     scenes/demos/interactive_demo.tscn 2>&1 | tee /tmp/condor_output &
#   sleep 20  # wait for game init
#
# === USAGE ===
#
#   bash tools/play.sh "<command>" [wait_seconds]
#
# Examples:
#   bash tools/play.sh "status"
#   bash tools/play.sh "rest" 6
#   bash tools/play.sh "travel oehringen" 15
#   bash tools/play.sh "look" 2
#
# Default wait is 4 seconds. Use longer waits for travel (15s) and
# activities (6s) that trigger the full turn pipeline.

CMD="$1"
WAIT="${2:-4}"
OUTPUT_FILE="${CONDOR_OUTPUT:-/tmp/condor_output}"
INPUT_FILE="${CONDOR_INPUT:-/tmp/condor_input}"

if [ -z "$CMD" ]; then
    echo "Usage: bash tools/play.sh \"<command>\" [wait_seconds]"
    echo ""
    echo "Commands: status, look, warriors, travel <id>, rest, forage, drill,"
    echo "  patrol, heal, buy, mercenary, mass, attack <id>, contacts,"
    echo "  missions, events, notifications, economy, map, help, quit"
    exit 1
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Game not running. Start it first:"
    echo "  echo '' > /tmp/condor_input"
    echo "  tail -f /tmp/condor_input | godot-mono --headless --path . scenes/demos/interactive_demo.tscn 2>&1 | tee /tmp/condor_output &"
    echo "  sleep 20"
    exit 1
fi

BEFORE=$(wc -l < "$OUTPUT_FILE")
echo "$CMD" >> "$INPUT_FILE"
sleep "$WAIT"
tail -n +$((BEFORE + 1)) "$OUTPUT_FILE" \
    | grep -vE "^\s*(WARNING|ERROR|at:|GDScript|backtrace|\[0\]|\[1\]|\[2\]|\[3\]|\[4\]|\[5\]|\[6\]|push_warning|variant_|scenario\.gd|presenter\.gd|_collect|_load_|_setup|initialize|\\\\=>| => |TriggerCon|❎|✅|\[Squad\]|\[Activity\]|Godot Engine|Scenario setup|CombatController|new scenario|Manual INIT|Should follow)" \
    | grep -vE "^\s*$"
