#!/usr/bin/env python3
"""Generate the Faust Ch.1 parliament cutscene + per-character rig2 configs.

Outputs:
  - resources/animation/configs/rig2/rig2_<char>.tres  (class textures + warrior_rig_2 sizing)
  - scenes/demos/warrior_rig_2_cutscene.tres           (the CinematicGroup cutscene)

The .tres files remain the editable source-of-truth artifacts; this script just
lets us regenerate them deterministically. Run:  python3 tools/build_parliament_cutscene.py
"""
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# --- Script UIDs (from *.gd.uid) ---------------------------------------------
UID_GROUP = "uid://bsif2cicby5dq"
UID_DIALOGUE = "uid://deeibdh2glf6b"
UID_CAMERA = "uid://balbj1g85dkh8"
UID_CHARACTER = "uid://dv3iev4uomqcy"

PATH_GROUP = "res://src/strategy/ui/vn/instructions/cinematic_group.gd"
PATH_DIALOGUE = "res://src/strategy/ui/vn/instructions/dialogue_instruction.gd"
PATH_CAMERA = "res://src/strategy/ui/vn/instructions/camera_instruction.gd"
PATH_CHARACTER = "res://src/strategy/ui/vn/instructions/character_instruction.gd"

# warrior_rig_2 sizing block (matches the demo's inline rachelle config).
SIZING_BLOCK = """head_size = Vector3(50, 50, 0)
torso_size = Vector3(40, 40, 0)
hips_size = Vector3(28, 28, 1)
left_arm_size = Vector3(30, 30, 1)
left_forearm_size = Vector3(30, 30, 1)
left_hand_size = Vector3(14, 14, 1)
right_arm_size = Vector3(30, 30, -1)
right_forearm_size = Vector3(30, 30, -1)
left_leg_size = Vector3(45, 30, 0)
left_shin_size = Vector3(30, 30, 0)
left_foot_size = Vector3(20, 20, 0)
right_leg_size = Vector3(45, 30, 0)
right_shin_size = Vector3(30, 30, 0)
"""

# character_id -> source class config under resources/animation/configs/
CONFIG_SOURCES = {
    "Chairman": "gelehrter",
    "Burgomaster": "arquebusier",
    "Bishop": "feldprediger",
    "Merchant": "crossbowman",
    "Feustel": "landsknecht",
    "Delegate": "pikeman",
    "Courier": "healer",
}


def build_configs():
    out_dir = os.path.join(ROOT, "resources/animation/configs/rig2")
    os.makedirs(out_dir, exist_ok=True)
    for char_id, cls in CONFIG_SOURCES.items():
        src_path = os.path.join(ROOT, "resources/animation/configs", cls + ".tres")
        with open(src_path, "r", encoding="utf-8") as f:
            text = f.read()
        # Strip the source uid so the copy gets a fresh one on import (no collision).
        text = re.sub(r'\s+uid="uid://[^"]+"', "", text, count=1)
        if not text.endswith("\n"):
            text += "\n"
        text += SIZING_BLOCK
        out_path = os.path.join(out_dir, "rig2_%s.tres" % char_id.lower())
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
        print("wrote", os.path.relpath(out_path, ROOT))


# --- Cutscene authoring -------------------------------------------------------
# Each entry produces one instruction sub-resource. Beats group them; every beat
# is auto_gate=true so the player advances with SPACE/click.

class Instr:
    def __init__(self, kind, props):
        self.kind = kind  # "dlg" | "cam" | "chr"
        self.props = props
        self.sid = None


def say(speaker, text):
    return Instr("dlg", {"speaker_name": speaker, "line_spoken": text})


def cam_focus(target, dur=0.5):
    return Instr("cam", {"action": 0, "target_character_id": target, "duration": dur})


def cam_include(ids, dur=0.5):
    return Instr("cam", {"action": 1, "include_character_ids": ids, "duration": dur})


def cam_reset(dur=0.6):
    return Instr("cam", {"action": 4, "duration": dur})


def beh(char, behavior):
    return Instr("chr", {"action": 2, "character_id": char, "behavior": behavior})


def hide(char):
    return Instr("chr", {"action": 5, "character_id": char})


def show(char):
    return Instr("chr", {"action": 4, "character_id": char})


def move(char, x, y, dur=1.0):
    return Instr("chr", {"action": 0, "character_id": char,
                         "target_position": (x, y), "duration": dur})


def narr(text):
    return say("", text)


def beats():
    B = []

    B.append(("opening", [
        hide("Courier"), hide("Gretchen"), cam_reset(),
        narr("Wide white stone chamber. Tiered seats curve around a central floor. "
             "Floating sigil-panels hover above the delegates — city crests, ducal eagles, "
             "bishopric suns, merchant seals. A soft, constant magical hum runs beneath it all."),
    ]))
    B.append(("ambient_open", [cam_reset(), narr(
        "The river tolls must be guaranteed.\n"
        "Without episcopal consent, this is irregular.\n"
        "The Free Cities will not be lectured by the nobilities of other dukedoms.")]))

    B.append(("chair_order", [cam_focus("Chairman"), beh("Chairman", "gesturing"),
                              say("Chairman", "Order. Order in the parliament.")]))
    B.append(("chair_quiet", [narr("The murmur and ambience die down.")]))
    B.append(("chair_rules", [cam_focus("Chairman"), say("Chairman",
        "The chair will proceed by petitioned priority. No delegate will exceed his allotted time.")]))
    B.append(("chair_matter", [say("Chairman",
        "As a reminder, the matter before us is — the question of coordinated response in the "
        "western districts, against the oncoming West Frankish incursion.")]))
    B.append(("chair_recog_burg", [beh("Chairman", "gesturing"),
        say("Chairman", "The chair recognises the Burgomaster of Wiederberg.")]))

    B.append(("burg_thanks", [cam_focus("Burgomaster"), beh("Burgomaster", "gesturing"),
        say("Burgomaster", "With gratitude to the chair.")]))
    B.append(("burg_levy", [say("Burgomaster",
        "I must reiterate that the city of Wiederberg cannot entertain levy adjustments. "
        "Mobilisation must be linked to enforceable trade indemnities and a secure source of "
        "fine linen, as previously entered into the record.")]))
    B.append(("burg_credit", [say("Burgomaster",
        "It would be fiscally unserious to demand extraordinary burdens from the free peoples "
        "while supply guarantees remain conjectural. We cannot be expected to defend the Rhine "
        "while our own credit basis is left to pious assumption.")]))

    B.append(("chair_point", [cam_focus("Chairman"), say("Chairman", "The point is entered.")]))
    B.append(("chair_recog_bishop", [beh("Chairman", "gesturing"),
        say("Chairman", "The chair recognises the episcopal envoy of Mainz.")]))

    B.append(("bishop_1", [cam_focus("Bishop"), beh("Bishop", "gesturing"),
        say("Bishop", "H-he hail the Emperor.")]))
    B.append(("bishop_2", [say("Bishop",
        "B-Before any s-secular instrument is entertained, the— the chamber must... first clarify,")]))
    B.append(("bishop_3", [say("Bishop",
        "Whether em-emergency transit, r-rrequisition, q-quartering across ecclesiastical lands... "
        "what I mean.")]))
    B.append(("bishop_4", [say("Bishop",
        "is... con-constitutes... temporary ne-ne-ne-necessity or actionable encroachment. "
        "The distinction is not—")]))

    B.append(("chair_recog_duchess", [cam_focus("Chairman"),
        say("Chairman", "Noted. The chair recognises the Duchess of Altenau.")]))

    B.append(("duchess_blink", [cam_focus("Duchess"), beh("Duchess", "idle"),
        narr("The Duchess blinks and looks about the chamber, caught unawares.")]))
    B.append(("chair_prompt_duchess", [cam_focus("Chairman"),
        say("Chairman", "... Duchess of Altenau.")]))
    B.append(("duchess_oh", [cam_focus("Duchess"), beh("Duchess", "gesturing"),
        say("Duchess", "Oh? Oh, yes. Ahem.")]))
    B.append(("duchess_paper1", [narr("She raises a paper and reads it off, quickly.")]))
    B.append(("duchess_read1", [say("Duchess",
        "The marches will not be maneuvered into unilateral exposure by rhetoric masquerading as "
        "common cause. No estate here has furnished a binding formula for reciprocal obligation, "
        "still less a timetable for restitution once troops have crossed.")]))
    B.append(("duchess_read2", [say("Duchess",
        "We are asked, in effect, to ratify liability before competence has even been defined. "
        "My answer, for the moment, is no.")]))

    B.append(("chair_recog_merchant", [cam_focus("Chairman"), say("Chairman",
        "... the objection stands recorded. The chair recognises the merchant deputy of Speyer.")]))

    B.append(("merch_1", [cam_focus("Merchant"), beh("Merchant", "gesturing"),
        say("Merchant", "Panic is a disaster, frankly. A total disaster.")]))
    B.append(("merch_2", [say("Merchant",
        "You talk about collapse — and many people are saying it — and suddenly the caravans stop. "
        "The warehouses seal up. Beautiful warehouses, completely shut.")]))
    B.append(("merch_3", [say("Merchant",
        "We're creating the shortage ourselves, okay? So no emergency talk. None. Not until we get "
        "the credit sorted out. Disorder costs a lot of money, gentlemen. Believe me.")]))

    B.append(("chair_prudent", [cam_focus("Chairman"),
        say("Chairman", "Very prudent. The chair reminds the assembly that speculative alarm is not policy.")]))
    B.append(("chair_petition", [say("Chairman",
        "There remains a petition from the legal bench. Master Fredrich Feustel.")]))

    B.append(("chair_three", [cam_focus("Chairman"),
        say("Chairman", "You have petitioned the floor three times. You now possess it.")]))
    B.append(("feustel_uhm", [cam_focus("Feustel"), say("Feustel", "Well, uhm.")]))
    B.append(("chair_recog_feustel", [cam_focus("Chairman"),
        say("Chairman", "The chair recognises Master Fredrich Feustel of the legal bench.")]))

    B.append(("feustel_rise", [cam_focus("Feustel"), beh("Feustel", "gesturing"),
        say("Feustel", "Honourable Chairman.")]))
    B.append(("feustel_thanks", [say("Feustel",
        "Ladies and gentlemen of the chamber, I thank you for the floor.")]))
    B.append(("feustel_brief", [say("Feustel", "I shall be brief.")]))
    B.append(("map_occupied", [narr(
        "Above the floor the great map brightens — the left bank of the Rhine shown occupied by "
        "revolutionary Frankish forces.")]))
    B.append(("feustel_system", [say("Feustel",
        "The west bank has been occupied; the Frankish administration does not advance as a raid "
        "but as a system, and whatever its language of liberation, it leaves lesser room for "
        "traditions, estate, and altar.")]))
    B.append(("feustel_duke", [say("Feustel",
        "Duke Van der Wiele, despite his valiant efforts, has had his estates stripped from him "
        "and been forced into collaboration.")]))
    B.append(("murmur_assent", [narr("A few delegates murmur assent. One or two nod.")]))
    B.append(("feustel_danger", [say("Feustel", "No one here, I believe, mistakes the danger.")]))
    B.append(("feustel_stake", [say("Feustel",
        "No one here doubts what is at stake if the Franks pressed further.")]))
    B.append(("feustel_jackboots", [say("Feustel",
        "And no one here, certainly, wishes to see the Heiliger Mittlereich stepped on by foreign jackboots.")]))
    B.append(("crowd_approve", [narr("The crowd murmurs in approval.")]))
    B.append(("feustel_manner", [say("Feustel",
        "For that very reason, I beg leave to speak not of our intentions — but of our manner of meeting them.")]))
    B.append(("room_stills", [narr("A small pause. The room stills a little.")]))
    B.append(("feustel_heard", [say("Feustel",
        "We have heard so much this morning of... indemnities, exemptions, the proper forms to wage "
        "a righteous defensive war.")]))
    B.append(("feustel_necessary", [beh("Feustel", "gesturing"), say("Feustel",
        "All necessary things, no doubt. All respectable things. And yet—")]))
    B.append(("feustel_glance", [beh("Feustel", "idle"), narr("Feustel glances at the map.")]))
    B.append(("feustel_guns", [say("Feustel", "—while you count votes, he counts guns.")]))

    B.append(("overhaul_shot", [cam_reset(),
        narr("The view pulls back across the whole podium, and holds there for a moment.")]))
    B.append(("feustel_procedure", [cam_focus("Feustel"),
        say("Feustel", "What I mean... is that... Procedure... is not defence.")]))
    B.append(("delegate_what", [cam_include(["Feustel", "Delegate"]),
        say("Delegate", "What is that supposed to mean?")]))
    B.append(("feustel_wording", [say("Feustel",
        "It means, if we here insist first on the perfect wording, then we may achieve excellent "
        "order in our minutes but still lose land.")]))
    B.append(("feustel_flush", [beh("Feustel", "idle"), beh("Delegate", "gesturing"),
        narr("Feustel flushes. The Delegate turns away from him, lifting a hand.")]))
    B.append(("feustel_govern", [cam_focus("Feustel"), say("Feustel",
        "Listen. We can talk all day about fairness, caution — such admirable regard for forms, "
        "yes — but by the time agreement is reached, there is nothing left to govern.")]))
    B.append(("chamber_discomfort", [cam_reset(), narr("Murmurs now. Not assent. Discomfort.")]))
    B.append(("chair_confine", [cam_focus("Chairman"),
        say("Chairman", "Master Fredrich Feustel will confine himself to the question.")]))
    B.append(("delegate_emperor", [cam_include(["Chairman", "Delegate"]),
        say("Delegate", "And what does that make you, huh? You are just as bad as the Emperor!")]))
    B.append(("feustel_atquestion", [cam_include(["Chairman", "Delegate", "Feustel"]),
        say("Feustel", "I am at the question, Excellency.")]))
    B.append(("feustel_committee", [say("Feustel",
        "The question is whether this chamber means to answer force with anything other than "
        "another committee meeting.")]))
    B.append(("ambient_outraged", [narr(
        "Outrageous.\nHe accuses the estates.\nThe chair must discipline this.")]))
    B.append(("feustel_provided", [cam_focus("Feustel"), say("Feustel",
        "Every man to defend the fatherland, provided first his jurisdiction isn't violated, "
        "his dignity observed, his liability shared...")]))
    B.append(("room_breaks", [cam_reset(),
        narr("The room breaks. Shouts from different tiers. Several sigils flare at once.")]))
    B.append(("ambient_shame", [narr("Shame!\nInsolence!\nTake that back!")]))
    B.append(("chair_warn", [cam_focus("Chairman"), say("Chairman", "Master Fredrich Feustel—")]))
    B.append(("feustel_throw", [cam_focus("Feustel"), beh("Feustel", "attacking"),
        narr("Feustel hurls his papers into the air. Others do the same.")]))
    B.append(("feustel_curse", [say("Feustel", "Lick my ass.")]))
    B.append(("sigils_flash", [narr("A ring of sigils flashes.")]))
    B.append(("mute_vote", [say("System", "MUTE VOTE PASSED")]))
    B.append(("ambient_censure", [narr(
        "Slander!\nHe has insulted the Reich!\nCensure him!\nOff the floor!")]))

    B.append(("courier_enter", [show("Courier"), move("Courier", -180.0, 90.0, 1.1),
        cam_focus("Courier"), say("Courier", "Dispatch from the western roads!")]))
    B.append(("courier_desc", [narr(
        "He is mud-streaked, half-blooded, a cracked tube under one arm. He does not bow. "
        "He barely stops moving.")]))
    B.append(("courier_report", [say("Courier",
        "The line is broken at dawn. Two crossings lost. Refugees at the lower gate. "
        "They are moving faster than forecast.")]))
    B.append(("map_flares", [cam_reset(), narr(
        "Above the chamber, the great map flares. One city-sigil goes dark. Then another. "
        "For one frozen second nobody speaks. Then everyone does.")]))
    B.append(("ambient_chaos", [narr(
        "Source?\nAuthenticate that dispatch!\nThis cannot be entered without seal review!\n"
        "Close the river ledgers!\nWhere is the military assessor?\nOrder — order —")]))
    B.append(("chair_lost", [cam_focus("Chairman"),
        say("Chairman", "The chair has not recognized— the chair has not recognized—")]))
    B.append(("feustel_mute", [cam_focus("Feustel"), show("Gretchen"), narr(
        "Nobody is listening now. Feustel stands mute, pulse hammering, staring across the chamber.")]))
    B.append(("gretchen_gaze", [cam_include(["Feustel", "Gretchen"]), beh("Gretchen", "idle"), narr(
        "Gretchen-Rachelle is already looking at him. Not warmly. Not kindly. Precisely.")]))

    return B


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def fmt_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"%s"' % esc(v)
    if isinstance(v, tuple):  # Vector2
        return "Vector2(%s, %s)" % (v[0], v[1])
    if isinstance(v, list):  # Array[String]
        return "Array[String]([%s])" % ", ".join('"%s"' % esc(x) for x in v)
    raise TypeError(v)


def build_cutscene():
    all_beats = beats()
    instr_blocks = []
    group_blocks = []
    group_refs = []

    counters = {"dlg": 0, "cam": 0, "chr": 0}
    ext_id = {"grp": "1_grp", "dlg": "2_dlg", "cam": "3_cam", "chr": "4_chr"}

    def emit_instr(inst):
        counters[inst.kind] += 1
        sid = "%s_%d" % (inst.kind.capitalize(), counters[inst.kind])
        script_ext = {"dlg": "2_dlg", "cam": "3_cam", "chr": "4_chr"}[inst.kind]
        lines = ['[sub_resource type="Resource" id="%s"]' % sid,
                 'script = ExtResource("%s")' % script_ext]
        for k, v in inst.props.items():
            lines.append("%s = %s" % (k, fmt_value(v)))
        instr_blocks.append("\n".join(lines))
        return sid

    for gi, (gid, instrs) in enumerate(all_beats, start=1):
        child_sids = [emit_instr(i) for i in instrs]
        gsid = "Grp_%d" % gi
        glines = ['[sub_resource type="Resource" id="%s"]' % gsid,
                  'script = ExtResource("1_grp")',
                  'id = "%s"' % gid,
                  "auto_gate = true",
                  "children = [%s]" % ", ".join('SubResource("%s")' % s for s in child_sids)]
        group_blocks.append("\n".join(glines))
        group_refs.append(gsid)

    n_sub = len(instr_blocks) + len(group_blocks) + 1  # +1 for root [resource]
    load_steps = 4 + n_sub  # 4 ext_resources + sub_resources

    header = ['[gd_resource type="Resource" script_class="CinematicGroup" load_steps=%d format=3 uid="uid://b24vpipf4mjb1"]' % load_steps,
              "",
              '[ext_resource type="Script" uid="%s" path="%s" id="1_grp"]' % (UID_GROUP, PATH_GROUP),
              '[ext_resource type="Script" uid="%s" path="%s" id="2_dlg"]' % (UID_DIALOGUE, PATH_DIALOGUE),
              '[ext_resource type="Script" uid="%s" path="%s" id="3_cam"]' % (UID_CAMERA, PATH_CAMERA),
              '[ext_resource type="Script" uid="%s" path="%s" id="4_chr"]' % (UID_CHARACTER, PATH_CHARACTER),
              ""]

    root = ['[resource]',
            'script = ExtResource("1_grp")',
            'id = "parliament_ch1"',
            "children = [%s]" % ", ".join('SubResource("%s")' % s for s in group_refs)]

    body = "\n".join(header) + "\n" + "\n\n".join(instr_blocks) + "\n\n" + \
        "\n\n".join(group_blocks) + "\n\n" + "\n".join(root) + "\n"

    out_path = os.path.join(ROOT, "scenes/demos/warrior_rig_2_cutscene.tres")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(body)
    print("wrote", os.path.relpath(out_path, ROOT),
          "(%d beats, %d instructions)" % (len(all_beats), len(instr_blocks)))


if __name__ == "__main__":
    build_configs()
    build_cutscene()
