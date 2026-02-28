#!/usr/bin/env python3
"""
Migrates EventChain .tres files from old Dialogue-based format to new
timeline-based CinematicInstruction format.

Old format:
  - Sub-resources reference dialogue.gd
  - Root resource has `dialogues = [SubResource(...), ...]`

New format:
  - Sub-resources reference instruction subtypes (dialogue_instruction.gd, gate_instruction.gd, etc.)
  - Root resource has `timeline = [SubResource(...), ...]` and `setting = []`
  - Each old Dialogue becomes: [DialogueInstruction] + [GateInstruction(wait_for_typewriter=true)]
  - Stage directions (walk_to, face_direction, behavior) become separate CharacterInstruction entries

Usage:
  python3 migrate_event_chains.py
"""
import os
import re
import glob

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DIALOGUE_SCRIPT_PATH = 'res://src/strategy/ui/vn/dialogue.gd'
DIALOGUE_INSTRUCTION_PATH = 'res://src/strategy/ui/vn/instructions/dialogue_instruction.gd'
GATE_INSTRUCTION_PATH = 'res://src/strategy/ui/vn/instructions/gate_instruction.gd'
CHARACTER_INSTRUCTION_PATH = 'res://src/strategy/ui/vn/instructions/character_instruction.gd'
CAMERA_INSTRUCTION_PATH = 'res://src/strategy/ui/vn/instructions/camera_instruction.gd'
STAGE_POSITION_PATH = 'res://src/strategy/ui/vn/instructions/stage_position.gd'

# Fields that move from Dialogue to DialogueInstruction
DIALOGUE_FIELDS = {'speaker_name', 'line_spoken', 'keep_previous_bubbles', 'expression_override'}
# Fields that are dropped (consumed into separate instructions or no longer needed)
DROPPED_FIELDS = {'id', 'on_screen_character_ids', 'background_id', 'camera_target',
                  'delay_ms', 'after_id', 'duration_ms', 'interrupt_by_id', 'interrupt_on_word',
                  'walk_to', 'behavior', 'face_direction', 'triggers'}


def find_tres_files():
    """Find all EventChain .tres files in the project."""
    patterns = [
        os.path.join(PROJECT_ROOT, 'resources', 'event_chains', '*.tres'),
        os.path.join(PROJECT_ROOT, 'resources', 'scenarios', '**', 'event-chains', '*.tres'),
        os.path.join(PROJECT_ROOT, 'resources', 'test-event-chain.tres'),
    ]
    files = []
    for pattern in patterns:
        files.extend(glob.glob(pattern, recursive=True))
    return files


def is_event_chain_file(content):
    """Check if a .tres file is an EventChain resource."""
    return 'script_class="EventChain"' in content or 'event_chain.gd' in content


def parse_sub_resources(content):
    """Parse all sub_resource blocks from a .tres file."""
    resources = []
    # Split on sub_resource headers
    parts = re.split(r'\[sub_resource type="Resource" id="([^"]+)"\]\n', content)
    # parts[0] = header, then alternating: id, body, id, body, ...
    i = 1
    while i < len(parts) - 1:
        res_id = parts[i]
        body = parts[i + 1]
        # Body extends until the next [sub_resource or [resource block
        body = re.split(r'\n\[(?:sub_resource|resource)\]', body)[0].strip()
        resources.append({'id': res_id, 'body': body})
        i += 2
    return resources


def parse_fields(body):
    """Parse key=value fields from a sub_resource body."""
    fields = {}
    for line in body.split('\n'):
        line = line.strip()
        if not line or line.startswith('script'):
            continue
        match = re.match(r'^(\w+)\s*=\s*(.+)$', line)
        if match:
            fields[match.group(1)] = match.group(2)
    return fields


def has_stage_direction(fields):
    """Check if a dialogue has any stage directions that need separate instructions."""
    if 'walk_to' in fields and fields['walk_to'] != 'Vector2(0, 0)':
        return True
    if 'face_direction' in fields and fields['face_direction'] not in ('0',):
        return True
    if 'behavior' in fields and fields['behavior'] not in ('""', ''):
        return True
    if 'camera_target' in fields and fields['camera_target'] not in ('""', ''):
        return True
    return False


def migrate_file(filepath):
    """Migrate a single .tres file."""
    with open(filepath, 'r') as f:
        content = f.read()

    if not is_event_chain_file(content):
        return False

    print(f"  Migrating: {os.path.relpath(filepath, PROJECT_ROOT)}")

    sub_resources = parse_sub_resources(content)
    if not sub_resources:
        print(f"    No sub_resources found, skipping")
        return False

    # Check if already migrated
    if 'dialogue_instruction.gd' in content or 'gate_instruction.gd' in content:
        print(f"    Already migrated, skipping")
        return False

    # Collect dialogue sub-resources and their fields
    dialogue_data = []
    for sr in sub_resources:
        fields = parse_fields(sr['body'])
        dialogue_data.append({
            'old_id': sr['id'],
            'fields': fields,
        })

    # Build new sub-resources
    new_sub_resources = []
    sub_id_counter = 1
    timeline_refs = []
    # Track unique character_ids for setting generation
    character_set = set()

    # Parse character_ids from root resource
    root_match = re.search(r'\[resource\]\n(.*)', content, re.DOTALL)
    root_body = root_match.group(1) if root_match else ''
    char_ids_match = re.search(r'character_ids\s*=\s*Array\[String\]\(\[(.*?)\]\)', root_body)
    if char_ids_match:
        raw_ids = char_ids_match.group(1)
        for cid in re.findall(r'"([^"]+)"', raw_ids):
            character_set.add(cid)

    for dd in dialogue_data:
        fields = dd['fields']

        # Extract character ids from on_screen_character_ids
        if 'on_screen_character_ids' in fields:
            ids_match = re.findall(r'"([^"]+)"', fields['on_screen_character_ids'])
            for cid in ids_match:
                character_set.add(cid)

        # 1) Character instructions (face, walk, behavior) — before dialogue
        if 'face_direction' in fields and fields['face_direction'] not in ('0',):
            speaker_name = fields.get('speaker_name', '""').strip('"')
            if speaker_name:
                char_inst_id = f"char_{sub_id_counter}"
                sub_id_counter += 1
                lines = [
                    f'script = ExtResource("script_character_instruction")',
                    f'action = 1',  # FACE = 1
                    f'character_id = {fields["speaker_name"]}' if 'speaker_name' in fields else '',
                    f'face_direction = {fields["face_direction"]}',
                ]
                lines = [l for l in lines if l]
                new_sub_resources.append({
                    'id': char_inst_id,
                    'body': '\n'.join(lines),
                })
                timeline_refs.append(char_inst_id)

        if 'walk_to' in fields and fields['walk_to'] != 'Vector2(0, 0)':
            speaker_name = fields.get('speaker_name', '""').strip('"')
            if speaker_name:
                char_inst_id = f"char_{sub_id_counter}"
                sub_id_counter += 1
                lines = [
                    f'script = ExtResource("script_character_instruction")',
                    f'action = 0',  # MOVE = 0
                    f'character_id = {fields["speaker_name"]}' if 'speaker_name' in fields else '',
                    f'target_position = {fields["walk_to"]}',
                    f'duration = 0.8',
                ]
                new_sub_resources.append({
                    'id': char_inst_id,
                    'body': '\n'.join(lines),
                })
                timeline_refs.append(char_inst_id)

        if 'behavior' in fields and fields['behavior'] not in ('""', ''):
            speaker_name = fields.get('speaker_name', '""').strip('"')
            if speaker_name:
                char_inst_id = f"char_{sub_id_counter}"
                sub_id_counter += 1
                lines = [
                    f'script = ExtResource("script_character_instruction")',
                    f'action = 2',  # BEHAVIOR = 2
                    f'character_id = {fields["speaker_name"]}' if 'speaker_name' in fields else '',
                    f'behavior = {fields["behavior"]}',
                ]
                new_sub_resources.append({
                    'id': char_inst_id,
                    'body': '\n'.join(lines),
                })
                timeline_refs.append(char_inst_id)

        # 2) Camera instruction if camera_target is set
        if 'camera_target' in fields and fields['camera_target'] not in ('""', ''):
            cam_inst_id = f"cam_{sub_id_counter}"
            sub_id_counter += 1
            lines = [
                f'script = ExtResource("script_camera_instruction")',
                f'action = 0',  # FOCUS_CHARACTER = 0
                f'target_character_id = {fields["camera_target"]}',
                f'zoom_level = 1.8',
            ]
            new_sub_resources.append({
                'id': cam_inst_id,
                'body': '\n'.join(lines),
            })
            timeline_refs.append(cam_inst_id)

        # 3) DialogueInstruction
        dlg_id = f"dlg_{sub_id_counter}"
        sub_id_counter += 1
        dlg_lines = [
            f'script = ExtResource("script_dialogue_instruction")',
        ]
        if 'speaker_name' in fields:
            dlg_lines.append(f'speaker_name = {fields["speaker_name"]}')
        if 'line_spoken' in fields:
            dlg_lines.append(f'line_spoken = {fields["line_spoken"]}')
        if 'keep_previous_bubbles' in fields and fields['keep_previous_bubbles'] != 'false':
            dlg_lines.append(f'keep_previous_bubbles = {fields["keep_previous_bubbles"]}')
        if 'expression_override' in fields and fields['expression_override'] not in ('""', ''):
            dlg_lines.append(f'expression_override = {fields["expression_override"]}')

        new_sub_resources.append({
            'id': dlg_id,
            'body': '\n'.join(dlg_lines),
        })
        timeline_refs.append(dlg_id)

        # 4) GateInstruction after each dialogue (click-to-advance)
        gate_id = f"gate_{sub_id_counter}"
        sub_id_counter += 1
        gate_lines = [
            f'script = ExtResource("script_gate_instruction")',
            f'wait_for_typewriter = true',
        ]
        new_sub_resources.append({
            'id': gate_id,
            'body': '\n'.join(gate_lines),
        })
        timeline_refs.append(gate_id)

    # Build setting sub-resources
    setting_refs = []
    char_list = sorted(character_set)
    spread = 150.0
    for i, cid in enumerate(char_list):
        pos_id = f"pos_{sub_id_counter}"
        sub_id_counter += 1
        target_x = (i - (len(char_list) - 1) * 0.5) * spread
        face = -1 if i == len(char_list) - 1 and len(char_list) > 1 else 1
        lines = [
            f'script = ExtResource("script_stage_position")',
            f'character_id = "{cid}"',
            f'position = Vector2({target_x}, 50)',
            f'face_direction = {face}',
        ]
        new_sub_resources.append({
            'id': pos_id,
            'body': '\n'.join(lines),
        })
        setting_refs.append(pos_id)

    # Count total load_steps: 1 (root script) + ext_resources (scripts) + sub_resources
    num_ext_scripts = 5  # event_chain, dialogue_instruction, gate_instruction, character_instruction, camera_instruction, stage_position
    # Only include scripts that are actually used
    used_scripts = {'script_event_chain', 'script_dialogue_instruction', 'script_gate_instruction'}
    if setting_refs:
        used_scripts.add('script_stage_position')
    for sr in new_sub_resources:
        if 'script_character_instruction' in sr['body']:
            used_scripts.add('script_character_instruction')
        if 'script_camera_instruction' in sr['body']:
            used_scripts.add('script_camera_instruction')

    ext_resource_count = len(used_scripts)
    load_steps = 1 + ext_resource_count + len(new_sub_resources)

    # Get original UID
    uid_match = re.search(r'uid="(uid://[^"]+)"', content.split('\n')[0])
    uid_str = f' uid="{uid_match.group(1)}"' if uid_match else ''

    # Build output
    out_lines = []
    out_lines.append(f'[gd_resource type="Resource" script_class="EventChain" load_steps={load_steps} format=3{uid_str}]')
    out_lines.append('')

    # Ext resources
    ext_id_counter = 1
    ext_id_map = {}

    def add_ext(script_key, path, uid=None):
        nonlocal ext_id_counter
        uid_part = f' uid="{uid}"' if uid else ''
        ext_id_map[script_key] = f"{ext_id_counter}_{script_key}"
        out_lines.append(f'[ext_resource type="Script"{uid_part} path="{path}" id="{ext_id_counter}_{script_key}"]')
        ext_id_counter += 1

    add_ext('script_event_chain', 'res://src/strategy/ui/vn/event_chain.gd', 'uid://dui3bco6g4nk4')
    add_ext('script_dialogue_instruction', DIALOGUE_INSTRUCTION_PATH)
    add_ext('script_gate_instruction', GATE_INSTRUCTION_PATH)
    if 'script_character_instruction' in used_scripts:
        add_ext('script_character_instruction', CHARACTER_INSTRUCTION_PATH)
    if 'script_camera_instruction' in used_scripts:
        add_ext('script_camera_instruction', CAMERA_INSTRUCTION_PATH)
    if 'script_stage_position' in used_scripts:
        add_ext('script_stage_position', STAGE_POSITION_PATH)

    out_lines.append('')

    # Sub resources
    for sr in new_sub_resources:
        out_lines.append(f'[sub_resource type="Resource" id="{sr["id"]}"]')
        # Replace script references with ext_resource references
        body = sr['body']
        for script_key in ext_id_map:
            body = body.replace(f'ExtResource("{script_key}")', f'ExtResource("{ext_id_map[script_key]}")')
        out_lines.append(body)
        out_lines.append('')

    # Root resource
    out_lines.append('[resource]')
    out_lines.append(f'script = ExtResource("{ext_id_map["script_event_chain"]}")')

    # Extract chain_id, chain_name from original
    chain_id_match = re.search(r'chain_id\s*=\s*"([^"]*)"', root_body)
    chain_name_match = re.search(r'chain_name\s*=\s*"([^"]*)"', root_body)
    if chain_id_match:
        out_lines.append(f'chain_id = "{chain_id_match.group(1)}"')
    if chain_name_match:
        out_lines.append(f'chain_name = "{chain_name_match.group(1)}"')

    # Character IDs
    if char_list:
        ids_str = ', '.join(f'"{c}"' for c in char_list)
        out_lines.append(f'character_ids = Array[String]([{ids_str}])')

    # Setting
    if setting_refs:
        refs_str = ', '.join(f'SubResource("{r}")' for r in setting_refs)
        out_lines.append(f'setting = [{refs_str}]')

    # Timeline
    if timeline_refs:
        refs_str = ', '.join(f'SubResource("{r}")' for r in timeline_refs)
        out_lines.append(f'timeline = [{refs_str}]')

    out_lines.append('')

    # Write output
    output = '\n'.join(out_lines)
    with open(filepath, 'w') as f:
        f.write(output)

    print(f"    => {len(dialogue_data)} dialogues -> {len(timeline_refs)} timeline entries, {len(setting_refs)} setting positions")
    return True


def main():
    files = find_tres_files()
    print(f"Found {len(files)} potential EventChain .tres files")
    migrated = 0
    for f in files:
        if migrate_file(f):
            migrated += 1
    print(f"\nMigrated {migrated} files")


if __name__ == '__main__':
    main()
