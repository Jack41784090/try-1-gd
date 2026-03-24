#!/usr/bin/env python3
"""Generate extracted .tres files for Goetz scenario locations and goods."""
import os

BASE = "resources/scenarios/goetz-official"
GOODS_DIR = f"{BASE}/goods"
LOC_DIR = f"{BASE}/locations"

THING_SCRIPT = 'uid="uid://ducmw8b2bkj4x" path="res://src/economy/thing.gd"'
LOCATION_SCRIPT = 'uid="uid://bn7qr1j0qoawu" path="res://src/strategy/core/town/_script.gd"'
CONN_SCRIPT = 'uid="uid://6qv6kwo7x3vm" path="res://src/strategy/core/town/connection.gd"'
CONNS_SCRIPT = 'uid="uid://vgwgx2k2ibcn" path="res://src/strategy/core/town/connections.gd"'
SHOP_SCRIPT = 'uid="uid://b136kr6rocls5" path="res://src/strategy/core/shop/shop.gd"'
STOCK_ENTRY_SCRIPT = 'path="res://src/economy/stock_entry.gd"'
INV_SCRIPT = 'uid="uid://sp4ar6jpaygh" path="res://src/economy/location_inventory.gd"'
POPCONFIG_SCRIPT = 'path="res://src/economy/population_config.gd"'
POPGROUP_SCRIPT = 'path="res://src/economy/population_group.gd"'

GOODS = [
    ("food", "Provisions", 0, 5.0, "Food and basic supplies for the road."),
    ("cloth", "Cloth", 1, 8.0, "Fine cloth and textiles."),
    ("tools", "Travel Tools", 2, 12.0, "Rope, oil, and tools for the road."),
    ("luxury", "Fine Goods", 3, 25.0, "Spices, wine, and other luxuries."),
]

def write_thing_tres(thing_id, thing_name, thing_type, base_price, description):
    content = f'''[gd_resource type="Resource" script_class="Thing" load_steps=2 format=3]

[ext_resource type="Script" {THING_SCRIPT} id="1_thing"]

[resource]
script = ExtResource("1_thing")
thing_id = "{thing_id}"
thing_name = "{thing_name}"
thing_type = {thing_type}
base_price = {base_price}
description = "{description}"
'''
    path = f"{GOODS_DIR}/{thing_id}.tres"
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Created {path}")

LOCATIONS = [
    {
        "id": "hornberg_castle",
        "name": "Hornberg Castle",
        "type": 3,
        "development": 70,
        "stability": 110.0,
        "connections": [("oehringen", 3)],
        "shop": None,
        "inventory": [("food", 30.0), ("cloth", 5.0), ("tools", 3.0)],
        "activities": [0, 1, 3, 5, 10, 11],
        "population": [(7, 0, 5, 0.0), (4, 0, 4, 1.0), (2, 2, 2, 80.0)],
    },
    {
        "id": "oehringen",
        "name": "\u00d6hringen",
        "type": 1,
        "development": 50,
        "stability": 85.0,
        "connections": [("hornberg_castle", 3), ("heilbronn", 2), ("schwaebisch_hall", 3)],
        "shop": ("\u00d6hringen Market", ["food", "cloth"]),
        "inventory": [("food", 40.0), ("cloth", 10.0)],
        "activities": [0, 2, 3, 4, 5, 7, 10, 11, 14],
        "population": [(30, 0, 0, 1.0), (5, 1, 3, 5.0), (3, 1, 1, 8.0), (1, 2, 2, 30.0)],
    },
    {
        "id": "heilbronn",
        "name": "Heilbronn",
        "type": 0,
        "development": 75,
        "stability": 60.0,
        "connections": [("oehringen", 2), ("schwaebisch_hall", 2)],
        "shop": ("Heilbronn Grand Market", ["food", "cloth", "tools", "luxury"]),
        "inventory": [("food", 80.0), ("cloth", 20.0), ("tools", 10.0), ("luxury", 5.0)],
        "activities": [0, 2, 3, 4, 5, 6, 10, 11, 14],
        "population": [(30, 0, 0, 2.0), (22, 1, 3, 10.0), (15, 1, 1, 15.0), (4, 2, 2, 50.0), (15, 0, 4, 1.0)],
    },
    {
        "id": "schwaebisch_hall",
        "name": "Schw\u00e4bisch Hall",
        "type": 1,
        "development": 55,
        "stability": 90.0,
        "connections": [("oehringen", 3), ("heilbronn", 2), ("rothenburg", 3)],
        "shop": ("Schw\u00e4bisch Hall Traders", ["food", "cloth"]),
        "inventory": [("food", 35.0), ("cloth", 8.0)],
        "activities": [0, 2, 3, 4, 7, 10, 14],
        "population": [(33, 0, 0, 1.0), (5, 1, 3, 5.0), (3, 1, 1, 8.0), (1, 2, 2, 30.0)],
    },
    {
        "id": "rothenburg",
        "name": "Rothenburg ob der Tauber",
        "type": 1,
        "development": 60,
        "stability": 85.0,
        "connections": [("schwaebisch_hall", 3), ("nuremberg", 3)],
        "shop": ("Rothenburg Merchants", ["food", "cloth", "tools"]),
        "inventory": [("food", 45.0), ("cloth", 12.0), ("tools", 5.0)],
        "activities": [0, 2, 3, 4, 7, 10, 14],
        "population": [(36, 0, 0, 1.0), (6, 1, 3, 5.0), (3, 1, 1, 8.0), (1, 2, 2, 30.0)],
    },
    {
        "id": "nuremberg",
        "name": "N\u00fcrnberg",
        "type": 0,
        "development": 85,
        "stability": 75.0,
        "connections": [("rothenburg", 3), ("bamberg", 2)],
        "shop": ("N\u00fcrnberg Grand Bazaar", ["food", "cloth", "tools", "luxury"]),
        "inventory": [("food", 100.0), ("cloth", 30.0), ("tools", 15.0), ("luxury", 10.0)],
        "activities": [0, 2, 3, 4, 5, 6, 10, 11, 14],
        "population": [(34, 0, 0, 2.0), (25, 1, 3, 10.0), (17, 1, 1, 15.0), (5, 2, 2, 50.0), (17, 0, 4, 1.0)],
    },
    {
        "id": "bamberg",
        "name": "Bamberg",
        "type": 0,
        "development": 70,
        "stability": 50.0,
        "connections": [("nuremberg", 2)],
        "shop": ("Bamberg Marketplace", ["food", "cloth", "tools"]),
        "inventory": [("food", 60.0), ("cloth", 15.0), ("tools", 8.0), ("luxury", 3.0)],
        "activities": [0, 2, 3, 4, 5, 6, 10, 11, 14],
        "population": [(28, 0, 0, 2.0), (21, 1, 3, 10.0), (14, 1, 1, 15.0), (4, 2, 2, 50.0), (14, 0, 4, 1.0)],
    },
]


def write_location_tres(loc):
    needed_things = set()
    for thing_id, _ in loc["inventory"]:
        needed_things.add(thing_id)
    if loc["shop"]:
        for thing_id in loc["shop"][1]:
            needed_things.add(thing_id)
    needed_things = sorted(needed_things)

    ext_resources = []
    ext_id_counter = [0]
    def next_id(suffix):
        ext_id_counter[0] += 1
        return f"{ext_id_counter[0]}_{suffix}"

    loc_ext_id = next_id("loc")
    ext_resources.append(f'[ext_resource type="Script" {LOCATION_SCRIPT} id="{loc_ext_id}"]')

    conn_ext_id = next_id("conn")
    ext_resources.append(f'[ext_resource type="Script" {CONN_SCRIPT} id="{conn_ext_id}"]')

    conns_ext_id = next_id("conns")
    ext_resources.append(f'[ext_resource type="Script" {CONNS_SCRIPT} id="{conns_ext_id}"]')

    thing_ext_ids = {}
    for thing_id in needed_things:
        tid = next_id(thing_id)
        thing_ext_ids[thing_id] = tid
        ext_resources.append(f'[ext_resource type="Resource" path="res://resources/scenarios/goetz-official/goods/{thing_id}.tres" id="{tid}"]')

    se_ext_id = next_id("se")
    ext_resources.append(f'[ext_resource type="Script" {STOCK_ENTRY_SCRIPT} id="{se_ext_id}"]')

    inv_ext_id = next_id("inv")
    ext_resources.append(f'[ext_resource type="Script" {INV_SCRIPT} id="{inv_ext_id}"]')

    shop_ext_id = None
    if loc["shop"]:
        shop_ext_id = next_id("shop")
        ext_resources.append(f'[ext_resource type="Script" {SHOP_SCRIPT} id="{shop_ext_id}"]')

    thing_script_ext_id = next_id("thing_script")
    ext_resources.append(f'[ext_resource type="Script" {THING_SCRIPT} id="{thing_script_ext_id}"]')

    popconfig_ext_id = next_id("popconfig")
    ext_resources.append(f'[ext_resource type="Script" {POPCONFIG_SCRIPT} id="{popconfig_ext_id}"]')

    popgroup_ext_id = next_id("popgroup")
    ext_resources.append(f'[ext_resource type="Script" {POPGROUP_SCRIPT} id="{popgroup_ext_id}"]')

    sub_resources = []

    conn_sub_ids = []
    for to_id, travel_time in loc["connections"]:
        sub_id = f"conn_{loc['id']}_to_{to_id}"
        conn_sub_ids.append(sub_id)
        sub_resources.append(f'''[sub_resource type="Resource" id="{sub_id}"]
script = ExtResource("{conn_ext_id}")
from_location_id = "{loc['id']}"
to_location_id = "{to_id}"
travel_time = {travel_time}''')

    conns_sub_id = f"conns_{loc['id']}"
    conn_refs = ", ".join(f'SubResource("{c}")' for c in conn_sub_ids)
    sub_resources.append(f'''[sub_resource type="Resource" id="{conns_sub_id}"]
script = ExtResource("{conns_ext_id}")
tt = Array[ExtResource("{conn_ext_id}")]([{conn_refs}])''')

    se_sub_ids = []
    for thing_id, amount in loc["inventory"]:
        sub_id = f"se_{loc['id']}_{thing_id}"
        se_sub_ids.append(sub_id)
        sub_resources.append(f'''[sub_resource type="Resource" id="{sub_id}"]
script = ExtResource("{se_ext_id}")
thing = ExtResource("{thing_ext_ids[thing_id]}")
amount = {amount}''')

    inv_sub_id = f"inv_{loc['id']}"
    se_refs = ", ".join(f'SubResource("{s}")' for s in se_sub_ids)
    sub_resources.append(f'''[sub_resource type="Resource" id="{inv_sub_id}"]
script = ExtResource("{inv_ext_id}")
initial_stocks = Array[ExtResource("{se_ext_id}")]([{se_refs}])''')

    shop_sub_id = None
    if loc["shop"]:
        shop_name, shop_items = loc["shop"]
        shop_sub_id = f"shop_{loc['id']}"
        item_refs = ", ".join(f'ExtResource("{thing_ext_ids[t]}")' for t in shop_items)
        sub_resources.append(f'''[sub_resource type="Resource" id="{shop_sub_id}"]
script = ExtResource("{shop_ext_id}")
shop_name = "{shop_name}"
items = Array[ExtResource("{thing_script_ext_id}")]([{item_refs}])''')

    popgroup_sub_ids = []
    for i, (count, social_class, job, money) in enumerate(loc["population"]):
        sub_id = f"popgroup_{loc['id']}_{i}"
        popgroup_sub_ids.append(sub_id)
        sub_resources.append(f'''[sub_resource type="Resource" id="{sub_id}"]
script = ExtResource("{popgroup_ext_id}")
count = {count}
social_class = {social_class}
job = {job}
starting_money = {money}''')

    popconfig_sub_id = f"popconfig_{loc['id']}"
    pg_refs = ", ".join(f'SubResource("{p}")' for p in popgroup_sub_ids)
    sub_resources.append(f'''[sub_resource type="Resource" id="{popconfig_sub_id}"]
script = ExtResource("{popconfig_ext_id}")
groups = Array[ExtResource("{popgroup_ext_id}")]([{pg_refs}])''')

    load_steps = len(ext_resources) + len(sub_resources) + 1

    resource_lines = [
        f'script = ExtResource("{loc_ext_id}")',
        f'location_id = "{loc["id"]}"',
        f'location_name = "{loc["name"]}"',
        f'type = {loc["type"]}',
    ]
    if loc["development"] != 50:
        resource_lines.append(f'development = {loc["development"]}')
    resource_lines.append(f'stability = {loc["stability"]}')
    resource_lines.append(f'connections = SubResource("{conns_sub_id}")')

    act_str = ", ".join(str(a) for a in loc["activities"])
    resource_lines.append(f'available_activity_types = Array[int]([{act_str}])')

    if shop_sub_id:
        resource_lines.append(f'shop = SubResource("{shop_sub_id}")')

    resource_lines.append(f'inventory = SubResource("{inv_sub_id}")')
    resource_lines.append(f'population_config = SubResource("{popconfig_sub_id}")')

    header = f'[gd_resource type="Resource" script_class="Location" load_steps={load_steps} format=3]'

    parts = [header, ""]
    parts.extend(ext_resources)
    parts.append("")
    for sr in sub_resources:
        parts.append(sr)
        parts.append("")
    parts.append("[resource]")
    parts.extend(resource_lines)
    parts.append("")

    path = f"{LOC_DIR}/{loc['id']}.tres"
    with open(path, 'w') as f:
        f.write("\n".join(parts))
    print(f"  Created {path}")


def write_world_tres():
    ext_resources = []
    ext_resources.append(f'[ext_resource type="Script" {LOCATION_SCRIPT} id="1_location"]')
    ext_resources.append(f'[ext_resource type="PackedScene" uid="uid://dbyqyxsk02a1r" path="res://resources/scenarios/goetz-official/map.tscn" id="2_map"]')
    ext_resources.append(f'[ext_resource type="Script" uid="uid://c7nmmrwqy6hlh" path="res://src/strategy/core/world.gd" id="3_world"]')
    ext_resources.append(f'[ext_resource type="Script" {THING_SCRIPT} id="4_thing"]')

    goods_ids = {}
    for i, (thing_id, _, _, _, _) in enumerate(GOODS):
        eid = f"good_{thing_id}"
        goods_ids[thing_id] = eid
        ext_resources.append(f'[ext_resource type="Resource" path="res://resources/scenarios/goetz-official/goods/{thing_id}.tres" id="{eid}"]')

    loc_ids = {}
    for loc in LOCATIONS:
        eid = f"loc_{loc['id']}"
        loc_ids[loc["id"]] = eid
        ext_resources.append(f'[ext_resource type="Resource" path="res://resources/scenarios/goetz-official/locations/{loc["id"]}.tres" id="{eid}"]')

    load_steps = len(ext_resources) + 1

    loc_refs = ", ".join(f'ExtResource("{loc_ids[l["id"]]}")' for l in LOCATIONS)
    goods_refs = ", ".join(f'ExtResource("{goods_ids[g[0]]}")' for g in GOODS)

    content = f'''[gd_resource type="Resource" script_class="World" load_steps={load_steps} format=3 uid="uid://d2nqlnrp74a5h"]

{chr(10).join(ext_resources)}

[resource]
script = ExtResource("3_world")
locations = Array[ExtResource("1_location")]([{loc_refs}])
map_scene = ExtResource("2_map")
goods = Array[ExtResource("4_thing")]([{goods_refs}])
metadata/_custom_type_script = "uid://c7nmmrwqy6hlh"
'''

    path = f"{BASE}/world.tres"
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Updated {path}")


if __name__ == "__main__":
    os.chdir("/home/ikec/Documents/Code/Godot/try-1-gd")
    print("Generating goods .tres files...")
    for g in GOODS:
        write_thing_tres(*g)

    print("Generating location .tres files...")
    for loc in LOCATIONS:
        write_location_tres(loc)

    print("Updating world.tres...")
    write_world_tres()

    print("Done!")
