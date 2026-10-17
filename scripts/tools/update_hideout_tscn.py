import os

tscn_path = "scenes/hideout/hideout.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

res_idx = content.rfind('[ext_resource')
end_res_idx = content.find('\n', res_idx) + 1

new_exts = """[ext_resource type="Script" path="res://scenes/hideout/hideout_stash.gd" id="ho_stash"]
[ext_resource type="Script" path="res://scenes/hideout/hideout_trader.gd" id="ho_trd"]
[ext_resource type="Script" path="res://scenes/hideout/hideout_flea_market.gd" id="ho_flea"]
[ext_resource type="Script" path="res://scenes/hideout/hideout_workbench.gd" id="ho_wb"]
[ext_resource type="Script" path="res://scenes/hideout/raid_result.gd" id="ho_rr"]
"""

content = content[:end_res_idx] + new_exts + content[end_res_idx:]

new_nodes = """
[node name="HideoutStash" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("ho_stash")

[node name="HideoutTrader" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("ho_trd")

[node name="HideoutFleaMarket" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("ho_flea")

[node name="HideoutWorkbench" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("ho_wb")

[node name="RaidResult" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("ho_rr")
"""

content += new_nodes

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated hideout.tscn")
