import os

os.makedirs("scenes/ui", exist_ok=True)

scripts = {
    "vicinity_panel.gd": "extends Control\nclass_name VicinityPanel\n\nfunc setup():\n\tpass\n",
    "inventory_grid_panel.gd": "extends Control\nclass_name InventoryGridPanel\n\nfunc setup():\n\tpass\n",
    "character_panel.gd": "extends Control\nclass_name CharacterPanel\n\nfunc setup():\n\tpass\n",
    "weapons_panel.gd": "extends Control\nclass_name WeaponsPanel\n\nfunc setup():\n\tpass\n",
    "drag_drop_manager.gd": "extends Node\nclass_name DragDropManager\n\nfunc setup():\n\tpass\n"
}

for filename, content in scripts.items():
    with open(f"scenes/ui/{filename}", "w", encoding="utf-8") as f:
        f.write(content)

tscn_path = "scenes/ui/inventory_window.tscn"
if os.path.exists(tscn_path):
    with open(tscn_path, "r", encoding="utf-8") as f:
        content = f.read()

    res_idx = content.rfind('[ext_resource')
    end_res_idx = content.find('\n', res_idx) + 1

    new_exts = """[ext_resource type="Script" path="res://scenes/ui/vicinity_panel.gd" id="vp_gd"]
[ext_resource type="Script" path="res://scenes/ui/inventory_grid_panel.gd" id="igp_gd"]
[ext_resource type="Script" path="res://scenes/ui/character_panel.gd" id="cp_gd"]
[ext_resource type="Script" path="res://scenes/ui/weapons_panel.gd" id="wp_gd"]
[ext_resource type="Script" path="res://scenes/ui/drag_drop_manager.gd" id="ddm_gd"]
"""
    content = content[:end_res_idx] + new_exts + content[end_res_idx:]

    new_nodes = """
[node name="DragDropManager" type="Node" parent="."]
script = ExtResource("ddm_gd")

[node name="VicinityPanel" type="Control" parent="."]
layout_mode = 1
script = ExtResource("vp_gd")

[node name="InventoryGridPanel" type="Control" parent="."]
layout_mode = 1
script = ExtResource("igp_gd")

[node name="CharacterPanel" type="Control" parent="."]
layout_mode = 1
script = ExtResource("cp_gd")

[node name="WeaponsPanel" type="Control" parent="."]
layout_mode = 1
script = ExtResource("wp_gd")
"""
    content += new_nodes

    with open(tscn_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Updated inventory_window.tscn and created scripts")
else:
    print(f"File not found: {tscn_path}")
