#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "mcp[cli]",
# ]
# ///
"""
CONDOR Game Screenshot MCP Server

Provides tools for Copilot Agent to capture and view screenshots of the
running CONDOR Godot game instance (requires GUI mode via start_game_gui.sh).

Tools:
  - screenshot_game: Send a command + capture a screenshot of the game window
  - view_screenshot: View the most recent screenshot without sending a command
"""

import base64
import os
import time
from pathlib import Path

from mcp.server.fastmcp import FastMCP

SCREENSHOT_PATH = "/tmp/condor_screenshot.jpg"
INPUT_PIPE = os.environ.get("CONDOR_INPUT", "/tmp/condor_input")
OUTPUT_PIPE = os.environ.get("CONDOR_OUTPUT", "/tmp/condor_output")

mcp = FastMCP("condor-screenshot")


def _send_command(cmd: str, wait: float = 2.0) -> str:
    if not Path(OUTPUT_PIPE).exists():
        return "ERROR: Game not running. Start with: bash tools/start_game_gui.sh"

    before = 0
    if Path(OUTPUT_PIPE).exists():
        with open(OUTPUT_PIPE, "r") as f:
            before = sum(1 for _ in f)

    with open(INPUT_PIPE, "a") as f:
        f.write(cmd + "\n")

    time.sleep(wait)

    lines = []
    with open(OUTPUT_PIPE, "r") as f:
        all_lines = f.readlines()
        lines = all_lines[before:]

    filtered = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("WARNING:", "ERROR:", "  at: ", "  <")):
            continue
        if stripped.startswith("Godot Engine "):
            continue
        if not stripped:
            continue
        filtered.append(stripped)

    return "\n".join(filtered)


def _read_screenshot() -> tuple[bytes | None, str]:
    path = Path(SCREENSHOT_PATH)
    if not path.exists():
        return None, "No screenshot file found at " + SCREENSHOT_PATH
    data = path.read_bytes()
    if len(data) < 100:
        return None, "Screenshot file is too small / corrupt"
    return data, ""


@mcp.tool()
def screenshot_game(
    command: str = "",
    wait: float = 4.0,
) -> list:
    """
    Send a command to the CONDOR game and capture a screenshot.

    If command is empty, just captures a screenshot of the current state.
    The game must be running in GUI mode (tools/start_game_gui.sh).

    Args:
        command: Game command to execute before screenshot (e.g. "status", "travel oehringen"). Empty = just screenshot.
        wait: Seconds to wait after command before screenshot (default 4). Use 6+ for activities, 15 for travel.

    Returns:
        Game text output (if command given) + PNG screenshot image.
    """
    result_parts = []

    if command.strip():
        text_output = _send_command(command.strip(), wait=max(wait, 2.0))
        if text_output:
            result_parts.append({"type": "text", "text": text_output})
        time.sleep(0.5)

    ss_output = _send_command("screenshot", wait=3.0)

    if "SCREENSHOT_SAVED:" in ss_output:
        img_data, err = _read_screenshot()
        if img_data:
            b64 = base64.standard_b64encode(img_data).decode("ascii")
            result_parts.append({
                "type": "image",
                "data": b64,
                "mimeType": "image/jpeg",
            })
        else:
            result_parts.append({"type": "text", "text": "Screenshot capture failed: " + err})
    elif "ERROR:" in ss_output:
        result_parts.append({"type": "text", "text": ss_output})
    else:
        result_parts.append({
            "type": "text",
            "text": "Screenshot command did not produce expected output. Game may be in headless mode.\nOutput: " + ss_output,
        })

    if not result_parts:
        result_parts.append({"type": "text", "text": "No output captured."})

    return result_parts


@mcp.tool()
def view_screenshot() -> list:
    """
    View the most recent CONDOR game screenshot without sending any command.

    Returns the last captured PNG screenshot. Use screenshot_game first to capture a fresh one.
    """
    img_data, err = _read_screenshot()
    if img_data:
        b64 = base64.standard_b64encode(img_data).decode("ascii")
        return [
            {
                "type": "image",
                "data": b64,
                "mimeType": "image/jpeg",
            }
        ]
    return [{"type": "text", "text": err}]


@mcp.tool()
def game_command(command: str, wait: float = 4.0) -> str:
    """
    Send a command to the running CONDOR game and return the text output.
    No screenshot is taken. Use this for quick queries like "status", "look", "contacts".

    Args:
        command: Game command (e.g. "status", "look", "warriors", "god_squads").
        wait: Seconds to wait for output (default 4). Use 6+ for activities, 15 for travel.
    """
    if not command.strip():
        return "ERROR: No command provided."
    return _send_command(command.strip(), wait=max(wait, 2.0))


if __name__ == "__main__":
    mcp.run()
