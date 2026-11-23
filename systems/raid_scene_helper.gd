# res://systems/raid_scene_helper.gd
class_name RaidSceneHelper
extends RefCounted

## 야외 월드(MainWorld)와 건물 내부(BuildingInteriorScene)가 공유하는 레이드 HUD·퀵슬롯·모달·상태 복원 헬퍼

static func restore_player_from_world_data(player: Node, erase_stats: bool = false) -> void:
	if not player or not GameManager or not (GameManager.current_world_data is Dictionary):
		return
	var w_data: Dictionary = GameManager.current_world_data
	if w_data.has("player_stats") and w_data["player_stats"] is Dictionary:
		var s: Dictionary = w_data["player_stats"]
		player.hp = s.get("hp", player.max_hp)
		player.stamina = s.get("stamina", player.max_stamina)
		player.hunger = s.get("hunger", player.max_hunger)
		player.thirst = s.get("thirst", player.max_thirst)
		player.is_bleeding = s.get("is_bleeding", false)
		player.is_fractured = s.get("is_fractured", false)
		player.is_infected = s.get("is_infected", false)
		player.painkiller_timer = float(s.get("painkiller_timer", 0.0))
		player.painkiller_damage_reduction = float(s.get("painkiller_damage_reduction", 0.0))
		player.set_flashlight(s.get("flashlight_enabled", true))
		if erase_stats:
			w_data.erase("player_stats")

	if not w_data.is_empty():
		var p_data: Dictionary = w_data.get("player", {})
		var saved_items: Array = p_data.get("inventory", [])
		if p_data.has("equipment") and not p_data["equipment"].is_empty():
			player.equipment = p_data["equipment"].duplicate(true)
		if player.has_method("apply_backpack_grid_size"):
			player.apply_backpack_grid_size()
		if player.inventory_grid:
			if player.inventory_grid.has_method("load_items"):
				player.inventory_grid.load_items(saved_items)
			else:
				for s_item in saved_items:
					if s_item and not s_item.is_empty():
						player.inventory_grid.auto_add_item(s_item.get("id", ""), s_item.get("amount", 1), s_item)

	if player.has_method("refresh_equipped_weapon"):
		player.refresh_equipped_weapon(true)

static func connect_player_raid_signals(scene: Node, player: Node) -> void:
	if not scene or not player:
		return
	if player.has_signal("stats_changed") and scene.has_method("_on_player_stats_changed"):
		if not player.stats_changed.is_connected(Callable(scene, "_on_player_stats_changed")):
			player.stats_changed.connect(Callable(scene, "_on_player_stats_changed"))
	if player.has_signal("interact_prompt") and scene.has_method("_on_interact_prompt"):
		if not player.interact_prompt.is_connected(Callable(scene, "_on_interact_prompt")):
			player.interact_prompt.connect(Callable(scene, "_on_interact_prompt"))
	if player.has_signal("object_interacted") and scene.has_method("_on_object_interacted"):
		if not player.object_interacted.is_connected(Callable(scene, "_on_object_interacted")):
			player.object_interacted.connect(Callable(scene, "_on_object_interacted"))
	if player.has_signal("channel_started") and scene.has_method("_on_player_channel_started"):
		if not player.channel_started.is_connected(Callable(scene, "_on_player_channel_started")):
			player.channel_started.connect(Callable(scene, "_on_player_channel_started"))
	if player.has_signal("channel_progress") and scene.has_method("_on_player_channel_progress"):
		if not player.channel_progress.is_connected(Callable(scene, "_on_player_channel_progress")):
			player.channel_progress.connect(Callable(scene, "_on_player_channel_progress"))
	if player.has_signal("channel_completed") and scene.has_method("_on_player_channel_finished"):
		if not player.channel_completed.is_connected(Callable(scene, "_on_player_channel_finished")):
			player.channel_completed.connect(Callable(scene, "_on_player_channel_finished"))
	if player.has_signal("channel_cancelled") and scene.has_method("_on_player_channel_finished"):
		if not player.channel_cancelled.is_connected(Callable(scene, "_on_player_channel_finished")):
			player.channel_cancelled.connect(Callable(scene, "_on_player_channel_finished"))
	if player.inventory_grid:
		if scene.has_method("_on_player_stats_changed") and not player.inventory_grid.grid_changed.is_connected(Callable(scene, "_on_player_stats_changed")):
			player.inventory_grid.grid_changed.connect(Callable(scene, "_on_player_stats_changed"))
		if scene.has_method("_update_quickslot_bar") and not player.inventory_grid.grid_changed.is_connected(Callable(scene, "_update_quickslot_bar")):
			player.inventory_grid.grid_changed.connect(Callable(scene, "_update_quickslot_bar"))
	if player.weapon_handler and scene.has_method("_update_quickslot_bar"):
		var qs_cb := Callable(scene, "_update_quickslot_bar")
		if player.weapon_handler.has_signal("weapon_changed") and not player.weapon_handler.weapon_changed.is_connected(qs_cb):
			player.weapon_handler.weapon_changed.connect(qs_cb)
		if player.weapon_handler.has_signal("ammo_changed") and not player.weapon_handler.ammo_changed.is_connected(qs_cb):
			player.weapon_handler.ammo_changed.connect(qs_cb)

static func ensure_pause_settings_button(pause_menu: Control, exit_btn: Button, on_settings_pressed: Callable, half_height: float = 170.0) -> void:
	if not pause_menu:
		return
	var pause_center := pause_menu.get_node_or_null("CenterPanel") as Control
	var pause_vbox := pause_menu.get_node_or_null("CenterPanel/VBoxContainer") as VBoxContainer
	if pause_center:
		pause_center.offset_top = -half_height
		pause_center.offset_bottom = half_height
	if pause_vbox and not pause_vbox.has_node("SettingsBtn"):
		var p_sett_btn := Button.new()
		p_sett_btn.name = "SettingsBtn"
		p_sett_btn.custom_minimum_size = Vector2(0, 44)
		p_sett_btn.add_theme_font_size_override("font_size", 16)
		if UiIconManager:
			UiIconManager.set_button(p_sett_btn, "settings", "설정 (Settings)", 16)
		else:
			p_sett_btn.text = "설정 (Settings)"
		if on_settings_pressed.is_valid():
			p_sett_btn.pressed.connect(on_settings_pressed)
		pause_vbox.add_child(p_sett_btn)
		if exit_btn and exit_btn.get_parent() == pause_vbox:
			pause_vbox.move_child(p_sett_btn, exit_btn.get_index())

static func update_tactical_frame(
	player: Node,
	delta: float,
	crosshair_overlay: Control,
	current_spread: float,
	hit_arcs: Array,
	hit_arc_overlay: Control,
	badge_bleed: Control,
	badge_fracture: Control,
	badge_biohazard: Control
) -> float:
	var next_spread := current_spread
	if not player:
		return next_spread
	if crosshair_overlay:
		var w_stats: Dictionary = player.equipped_weapon_data.get("computed_stats", {}) if not player.equipped_weapon_data.is_empty() else {}
		var acc := float(w_stats.get("accuracy", 78.0))
		var base_spread := maxf(5.0, (100.0 - acc) * 0.45)
		var move_penalty := player.velocity.length() * 0.075
		var recoil_pen := (player.weapon_handler.recoil_offset * 1.8) if player.weapon_handler else 0.0
		var target_spread := base_spread + move_penalty + recoil_pen
		if player.player_camera and player.player_camera.is_aiming_ads:
			target_spread *= 0.48
		elif player.is_crouching:
			target_spread *= 0.72
		next_spread = lerpf(current_spread, target_spread, clampf(delta * 14.0, 0.0, 1.0))
		crosshair_overlay.queue_redraw()

	if hit_arcs.size() > 0:
		for i in range(hit_arcs.size() - 1, -1, -1):
			hit_arcs[i]["timer"] -= delta
			if hit_arcs[i]["timer"] <= 0.0:
				hit_arcs.remove_at(i)
		if hit_arc_overlay:
			hit_arc_overlay.queue_redraw()

	var pulse_alpha := 0.675 + 0.325 * sin(Time.get_ticks_msec() * 0.008)
	if badge_bleed and badge_bleed.visible:
		badge_bleed.modulate.a = pulse_alpha
	if badge_fracture and badge_fracture.visible:
		badge_fracture.modulate.a = pulse_alpha
	if badge_biohazard and badge_biohazard.visible:
		badge_biohazard.modulate.a = pulse_alpha
	return next_spread

static func append_hit_arc(player: Node, attacker_pos: Vector2, hit_arcs: Array, hit_arc_overlay: Control) -> void:
	if not player:
		return
	var diff: Vector2 = attacker_pos - player.global_position
	var angle: float = diff.angle() if diff.length() > 0.001 else 0.0
	hit_arcs.append({"angle": angle, "timer": 0.4, "max_time": 0.4})
	if EventBus and EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(4.0, 0.2)
	if hit_arc_overlay:
		hit_arc_overlay.queue_redraw()

static func bind_quickslot_buttons(scene: Node, quickslot_hbox: Control) -> void:
	if not scene or not quickslot_hbox:
		return
	var bindings := {
		"Slot1": "_on_quickslot_1_pressed",
		"Slot2": "_on_quickslot_2_pressed",
		"Slot3": "_on_quickslot_3_pressed",
		"Slot4": "_on_quickslot_4_pressed",
		"Slot5": "_on_quickslot_5_pressed",
		"Slot6": "_on_quickslot_6_pressed",
		"Slot7": "_on_quickslot_7_pressed",
		"Slot8": "_on_quickslot_8_pressed",
		"SlotN": "_on_quickslot_N_pressed",
	}
	for node_name in bindings.keys():
		var btn := quickslot_hbox.get_node_or_null(node_name) as Button
		var method_name: String = bindings[node_name]
		if btn and scene.has_method(method_name):
			var cb := Callable(scene, method_name)
			if not btn.pressed.is_connected(cb):
				btn.pressed.connect(cb)

static func refresh_quickslot_bar(scene: Node, quickslot_hbox: Control, player: Node) -> void:
	if not quickslot_hbox or not player:
		return
	HudTacticalHelper.update_quickslot_bar(quickslot_hbox, player)
	if scene:
		var slot8 := quickslot_hbox.get_node_or_null("Slot8") as Button
		if slot8 and scene.has_method("_on_quickslot_8_pressed"):
			var cb8 := Callable(scene, "_on_quickslot_8_pressed")
			if not slot8.pressed.is_connected(cb8):
				slot8.pressed.connect(cb8)
		var slotU := quickslot_hbox.get_node_or_null("SlotU") as Button
		if slotU and scene.has_method("_on_quickslot_U_pressed"):
			var cbU := Callable(scene, "_on_quickslot_U_pressed")
			if not slotU.pressed.is_connected(cbU):
				slotU.pressed.connect(cbU)

static func switch_quickslot_weapon(player: Node, slot_name: String, refresh_cb: Callable) -> void:
	if player and player.weapon_handler:
		if player.is_channeling:
			player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot(slot_name)
		if refresh_cb.is_valid():
			refresh_cb.call()

static func on_channel_started(channeling_bar: ProgressBar, channeling_label: Label, duration: float, item_name: String) -> void:
	if channeling_bar:
		channeling_bar.visible = true
		channeling_bar.max_value = duration
		channeling_bar.value = 0.0
		if channeling_label:
			channeling_label.text = "%s 사용 중... (%.1f초)" % [item_name, duration]

static func on_channel_progress(player: Node, channeling_bar: ProgressBar, channeling_label: Label, quickslot_hbox: Control, current: float, total: float) -> void:
	if channeling_bar:
		channeling_bar.value = current
		if channeling_label and player:
			var rem := maxf(0.0, total - current)
			channeling_label.text = "%s (%.1f초)" % [player.channel_item_name, rem]
	if quickslot_hbox and player:
		var ratio := current / maxf(0.01, total)
		var item_str: String = String(player.channel_item_name)
		var slot_key := "6"
		if item_str.contains("붕대") or item_str.contains("지혈"):
			slot_key = "5"
		elif item_str.contains("구급") or item_str.contains("키트") or item_str.contains("부목"):
			slot_key = "6"
		elif item_str.contains("생수") or item_str.contains("물") or item_str.contains("음료") or item_str.contains("커피") or item_str.contains("드링크"):
			slot_key = "8"
		elif item_str.contains("식량") or item_str.contains("통조림") or item_str.contains("고기") or item_str.contains("빵") or item_str.contains("에너지바") or item_str.contains("농작물"):
			slot_key = "7"
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, slot_key, ratio)

static func on_channel_finished(channeling_bar: ProgressBar, quickslot_hbox: Control, refresh_cb: Callable) -> void:
	if channeling_bar:
		channeling_bar.visible = false
	if quickslot_hbox:
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, "clear", 0.0)
	if refresh_cb.is_valid():
		refresh_cb.call()

static func update_interact_prompt(interact_prompt: Label, visible_allowed: bool, can_interact: bool, text: String) -> void:
	if not interact_prompt:
		return
	if visible_allowed:
		if UiIconManager:
			var parsed := UiIconManager.parse_tagged_message(text)
			UiIconManager.set_label_icon(interact_prompt, String(parsed["icon_key"]), String(parsed["clean_text"]), 18, 6, true)
			UiIconManager.sync_label_row_visibility(interact_prompt, can_interact)
		else:
			interact_prompt.visible = can_interact
			interact_prompt.text = text
	else:
		if UiIconManager:
			UiIconManager.sync_label_row_visibility(interact_prompt, false)
		else:
			interact_prompt.visible = false

static func player_has_radio(player: Node) -> bool:
	if not player or not player.inventory_grid:
		return false
	if player.inventory_grid.has_item("장거리 무전기", 1) or player.inventory_grid.has_item("군용 무전기", 1) or player.inventory_grid.has_item("무전기", 1):
		return true
	var match_res: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
		return String(it.get("id", "")).contains("무전기")
	)
	return bool(match_res.get("found", false))

static func get_backpack_items(player: Node) -> Array:
	var items_arr: Array = []
	if player and player.inventory_grid:
		for item in player.inventory_grid.items:
			if item and not item.is_empty():
				items_arr.append(item.duplicate(true))
	return items_arr

static func sync_pause_exit_button(exit_btn: Button) -> void:
	if not exit_btn:
		return
	var is_sandbox := GameManager != null and GameManager.is_sandbox_mode()
	if is_sandbox:
		exit_btn.text = "은신처로 안전 복귀 (전리품 보존)"
		exit_btn.theme_type_variation = &"PrimaryButton"
	else:
		exit_btn.text = "작전 포기 및 탈주 (MIA - 전리품 유실)"
		exit_btn.theme_type_variation = &"DangerButton"

static func execute_pause_exit(scene: Node, player: Node) -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	if scene and scene.get_tree():
		scene.get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		if player and not player.equipment.is_empty():
			if not GameManager.current_world_data.has("player"):
				GameManager.current_world_data["player"] = {}
			GameManager.current_world_data["player"]["equipment"] = player.equipment.duplicate(true)
		var is_sandbox: bool = GameManager.is_sandbox_mode()
		var items := get_backpack_items(player)
		GameManager.end_raid("survived" if is_sandbox else "mia", items)

static func draw_tactical_compass(
	compass_bar: Control,
	player: Node2D,
	extraction_points_data: Array,
	airdrop_points_data: Array,
	boss_entity: Node2D,
	field_objectives: Array,
	landmark_objective: Node2D = null
) -> void:
	if not compass_bar or not player:
		return
	var w := compass_bar.size.x
	var h := compass_bar.size.y
	var center_x := floorf(w / 2.0)

	compass_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.04, 0.05, 0.075, 0.88), true)
	compass_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.24, 0.30, 0.38, 0.92), false, 1.0)
	InventoryUIHelper._draw_pixel_corner_brackets(compass_bar, Rect2(1, 1, w - 2, h - 2), Color(0.92, 0.65, 0.22, 0.85), 5.0, 1.0)

	var player_deg := rad_to_deg(player.rotation)
	if player_deg < 0:
		player_deg += 360.0

	var fov := 160.0
	var pixels_per_deg := w / fov

	for step_deg in range(0, 360, 15):
		if step_deg % 90 == 0:
			continue
		var s_diff := float(step_deg) - player_deg
		while s_diff < -180.0: s_diff += 360.0
		while s_diff > 180.0: s_diff -= 360.0
		if absf(s_diff) <= fov / 2.0:
			var sx := floorf(center_x + s_diff * pixels_per_deg)
			var tick_h := 4.0 if (step_deg % 45 == 0) else 2.0
			compass_bar.draw_rect(Rect2(sx, h - 1.0 - tick_h, 1.0, tick_h), Color(0.42, 0.48, 0.58, 0.75), true)

	var compass_font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else ThemeDB.fallback_font
	var cardinal_dirs := {0.0: "E", 90.0: "S", 180.0: "W", 270.0: "N"}
	for deg in cardinal_dirs.keys():
		var diff: float = float(deg) - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		if absf(diff) <= fov / 2.0:
			var x := floorf(center_x + diff * pixels_per_deg)
			compass_bar.draw_rect(Rect2(x - 1.0, h - 7.0, 2.0, 6.0), Color(0.92, 0.68, 0.22, 0.95), true)
			compass_bar.draw_string(compass_font, Vector2(x - 4, h - 9), cardinal_dirs[deg], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.3))

	for pt in extraction_points_data:
		var dir_to_pt := player.global_position.direction_to(pt["pos"])
		var pt_deg := rad_to_deg(dir_to_pt.angle())
		if pt_deg < 0: pt_deg += 360.0
		var diff := pt_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		if absf(diff) <= fov / 2.0:
			var x := floorf(center_x + diff * pixels_per_deg)
			var dist := player.global_position.distance_to(pt["pos"])
			var diamond := PackedVector2Array([Vector2(x, 4), Vector2(x + 4, 9), Vector2(x, 14), Vector2(x - 4, 9)])
			var pt_type := int(pt.get("type", 0))
			var pt_col := Color(0.2, 1.0, 0.3)
			var txt_col := Color(0.3, 1.0, 0.4)
			var lock_suffix := ""
			if pt_type == 1:
				var cur_rub := GameManager.get_player_rubles() if GameManager else 0
				if cur_rub < 3000:
					pt_col = Color(0.55, 0.55, 0.58, 0.55)
					txt_col = Color(0.95, 0.42, 0.42, 0.78)
					lock_suffix = " [잠김: 3,000R 필요]"
				else:
					pt_col = Color(1.0, 0.82, 0.15)
					txt_col = Color(1.0, 0.9, 0.3)
			elif pt_type == 2:
				var bunker_unlocked := GameManager.is_bunker_extraction_unlocked(field_objectives) if GameManager else false
				if not bunker_unlocked:
					pt_col = Color(0.55, 0.55, 0.58, 0.55)
					txt_col = Color(0.95, 0.42, 0.42, 0.78)
					lock_suffix = " [잠김: 단말기 미해킹]"
				else:
					pt_col = Color(0.2, 0.85, 1.0)
					txt_col = Color(0.4, 0.9, 1.0)
			compass_bar.draw_colored_polygon(diamond, pt_col)
			compass_bar.draw_string(compass_font, Vector2(x - 12, 22), "%.0fm%s" % [dist, lock_suffix], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, txt_col)

	for ad in airdrop_points_data:
		var dir_to_ad := player.global_position.direction_to(ad["pos"])
		var ad_deg := rad_to_deg(dir_to_ad.angle())
		if ad_deg < 0: ad_deg += 360.0
		var diff := ad_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		if absf(diff) <= fov / 2.0:
			var x := floorf(center_x + diff * pixels_per_deg)
			var dist := player.global_position.distance_to(ad["pos"])
			var ad_tex: Texture2D = UiIconManager.get_icon("airdrop") if UiIconManager else null
			if ad_tex:
				compass_bar.draw_texture_rect(ad_tex, Rect2(x - 5.0, 3.0, 10.0, 10.0), false)
			else:
				compass_bar.draw_rect(Rect2(x - 4.0, 5.0, 8.0, 8.0), Color(1.0, 0.45, 0.15), true)
			compass_bar.draw_string(compass_font, Vector2(x - 12, 22), "%.0fm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.65, 0.25))

	if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0:
		var dir_to_boss := player.global_position.direction_to(boss_entity.global_position)
		var boss_deg := rad_to_deg(dir_to_boss.angle())
		if boss_deg < 0: boss_deg += 360.0
		var b_diff := boss_deg - player_deg
		while b_diff < -180.0: b_diff += 360.0
		while b_diff > 180.0: b_diff -= 360.0
		if absf(b_diff) <= fov / 2.0:
			var bx := floorf(center_x + b_diff * pixels_per_deg)
			var b_dist := player.global_position.distance_to(boss_entity.global_position)
			var boss_tex: Texture2D = UiIconManager.get_icon("skull") if UiIconManager else null
			if boss_tex:
				compass_bar.draw_texture_rect(boss_tex, Rect2(bx - 5.0, 3.0, 10.0, 10.0), false)
			else:
				compass_bar.draw_rect(Rect2(bx - 4.0, 5.0, 8.0, 8.0), Color(0.95, 0.15, 0.2), true)
			compass_bar.draw_string(compass_font, Vector2(bx - 12, 22), "%.0fm" % b_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.35, 0.35))

	var objs_to_draw: Array = field_objectives if field_objectives.size() > 0 else ([landmark_objective] if is_instance_valid(landmark_objective) else [])
	for obj_ref in objs_to_draw:
		if is_instance_valid(obj_ref) and not bool(obj_ref.get("is_completed")):
			var dir_to_obj := player.global_position.direction_to(obj_ref.global_position)
			var obj_deg := rad_to_deg(dir_to_obj.angle())
			if obj_deg < 0: obj_deg += 360.0
			var o_diff := obj_deg - player_deg
			while o_diff < -180.0: o_diff += 360.0
			while o_diff > 180.0: o_diff -= 360.0
			if absf(o_diff) <= fov / 2.0:
				var ox := floorf(center_x + o_diff * pixels_per_deg)
				var o_dist := player.global_position.distance_to(obj_ref.global_position)
				var icon_key: String = obj_ref.get_compass_icon() if obj_ref.has_method("get_compass_icon") else "signal"
				var obj_tex: Texture2D = UiIconManager.get_icon(icon_key) if UiIconManager else null
				if obj_tex:
					compass_bar.draw_texture_rect(obj_tex, Rect2(ox - 5.0, 3.0, 10.0, 10.0), false)
				else:
					compass_bar.draw_rect(Rect2(ox - 3.0, 6.0, 6.0, 6.0), Color(0.2, 0.88, 1.0), true)
				compass_bar.draw_string(compass_font, Vector2(ox - 12, 22), "%.0fm" % o_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.92, 1.0))

	compass_bar.draw_rect(Rect2(center_x - 3.0, 1.0, 6.0, 2.0), Color(1.0, 0.85, 0.2), true)
	compass_bar.draw_rect(Rect2(center_x - 2.0, 3.0, 4.0, 2.0), Color(1.0, 0.85, 0.2), true)
	compass_bar.draw_rect(Rect2(center_x - 1.0, 5.0, 2.0, 2.0), Color(1.0, 0.85, 0.2), true)
