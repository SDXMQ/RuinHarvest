import os

tscn_path = "scenes/entities/player/player.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# ext_resource 선언부 위치 찾기
res_idx = content.rfind('[ext_resource')
end_res_idx = content.find('\n', res_idx) + 1

new_exts = """[ext_resource type="Script" path="res://scenes/entities/player/survival_stats.gd" id="surv_st"]
[ext_resource type="Script" path="res://scenes/entities/player/weapon_handler.gd" id="weap_hnd"]
[ext_resource type="Script" path="res://scenes/entities/player/interaction_detector.gd" id="int_det"]
[ext_resource type="Script" path="res://scenes/entities/player/player_lighting.gd" id="plr_lgt"]
[ext_resource type="Script" path="res://scenes/entities/player/player_camera.gd" id="plr_cam"]
[ext_resource type="Script" path="res://scenes/entities/player/player_visuals.gd" id="plr_vis"]
"""

content = content[:end_res_idx] + new_exts + content[end_res_idx:]

new_nodes = """
[node name="SurvivalStats" type="Node" parent="."]
script = ExtResource("surv_st")

[node name="WeaponHandler" type="Node" parent="."]
script = ExtResource("weap_hnd")

[node name="InteractionDetector" type="Node" parent="."]
script = ExtResource("int_det")

[node name="PlayerLighting" type="Node2D" parent="."]
script = ExtResource("plr_lgt")

[node name="PlayerCamera" type="Node" parent="."]
script = ExtResource("plr_cam")

[node name="PlayerVisuals" type="Node2D" parent="Visuals"]
script = ExtResource("plr_vis")
"""

content += new_nodes

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated player.tscn")
