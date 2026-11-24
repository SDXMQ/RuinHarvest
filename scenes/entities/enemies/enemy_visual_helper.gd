# res://scenes/entities/enemies/enemy_visual_helper.gd
extends RefCounted

## 적 엔티티의 픽셀 스프라이트 레이어, 히트 피드백, 오버레이 드로잉 및 전술 시야 가시성 헬퍼

const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")

static func format_hit_feedback(dmg: float, armor_mult: float = 1.0) -> Dictionary:
	var dmg_int: int = max(1, int(round(dmg)))
	if armor_mult < 0.85:
		var absorb_pct: int = int(round((1.0 - armor_mult) * 100.0))
		return {
			"text": "-%d [방탄 흡수 -%d%%]" % [dmg_int, absorb_pct],
			"color": Color(0.55, 0.78, 0.98),
			"absorbed": true
		}
	elif armor_mult < 0.999:
		var absorb_pct2: int = int(round((1.0 - armor_mult) * 100.0))
		return {
			"text": "-%d [방탄 -%d%%]" % [dmg_int, absorb_pct2],
			"color": Color(0.75, 0.82, 0.92),
			"absorbed": true
		}
	else:
		return {
			"text": "-%d" % dmg_int,
			"color": Color(1.0, 0.92, 0.32) if dmg >= 30.0 else Color(1.0, 0.98, 0.92),
			"absorbed": false
		}

static func spawn_hit_feedback_label(enemy: Node2D, fb: Dictionary) -> void:
	if not enemy or not enemy.is_inside_tree() or enemy.get_parent() == null:
		return
	var lbl := Label.new()
	lbl.text = String(fb.get("text", ""))
	lbl.add_theme_font_size_override("font_size", 11 if bool(fb.get("absorbed", false)) else 13)
	lbl.add_theme_color_override("font_color", fb.get("color", Color.WHITE))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 45
	lbl.global_position = enemy.global_position + Vector2(randf_range(-14.0, 14.0), -28.0)
	enemy.get_parent().add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 26.0, 0.65)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.chain().tween_callback(lbl.queue_free)

static func setup_pixel_layers(visuals: Node2D, glow_cb: Callable, hud_cb: Callable) -> Dictionary:
	var result: Dictionary = {}
	if not visuals:
		return result
	var enemies_tex: CanvasTexture = PixelAssetManager.get_canvas_texture("entities/enemies") if PixelAssetManager else null
	var parts_tex: CanvasTexture = PixelAssetManager.get_canvas_texture("entities/player_parts") if PixelAssetManager else null

	var shadow_spr := Sprite2D.new()
	shadow_spr.name = "ContactShadow"
	shadow_spr.centered = true
	shadow_spr.region_enabled = true
	shadow_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_spr.use_parent_material = false
	shadow_spr.z_index = -2
	if parts_tex:
		shadow_spr.texture = parts_tex
	shadow_spr.region_rect = Rect2(0, 0, 32, 32)
	shadow_spr.modulate = Color(1.0, 1.0, 1.0, 0.72)
	visuals.add_child(shadow_spr)

	var boot_left_spr := Sprite2D.new()
	boot_left_spr.name = "BootLeft"
	boot_left_spr.centered = true
	boot_left_spr.region_enabled = true
	boot_left_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boot_left_spr.use_parent_material = true
	boot_left_spr.z_index = -1
	if enemies_tex:
		boot_left_spr.texture = enemies_tex
	boot_left_spr.region_rect = Rect2(0, 48, 48, 48)
	visuals.add_child(boot_left_spr)

	var boot_right_spr := Sprite2D.new()
	boot_right_spr.name = "BootRight"
	boot_right_spr.centered = true
	boot_right_spr.region_enabled = true
	boot_right_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boot_right_spr.use_parent_material = true
	boot_right_spr.z_index = -1
	if enemies_tex:
		boot_right_spr.texture = enemies_tex
	boot_right_spr.region_rect = Rect2(0, 48, 48, 48)
	visuals.add_child(boot_right_spr)

	var body_spr := Sprite2D.new()
	body_spr.name = "BodySprite"
	body_spr.centered = true
	body_spr.region_enabled = true
	body_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_spr.use_parent_material = true
	body_spr.z_index = 0
	if enemies_tex:
		body_spr.texture = enemies_tex
	visuals.add_child(body_spr)

	var blood_spr := Sprite2D.new()
	blood_spr.name = "BloodOverlay"
	blood_spr.centered = true
	blood_spr.region_enabled = true
	blood_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blood_spr.use_parent_material = true
	blood_spr.z_index = 1
	if enemies_tex:
		blood_spr.texture = enemies_tex
	blood_spr.region_rect = Rect2(7 * 48, 0, 48, 48)
	blood_spr.visible = false
	visuals.add_child(blood_spr)

	var glow_overlay := Node2D.new()
	glow_overlay.name = "GlowOverlay"
	glow_overlay.z_index = 2
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow_overlay.material = unshaded
	if glow_cb.is_valid():
		glow_overlay.draw.connect(glow_cb)
	visuals.add_child(glow_overlay)

	var hud_overlay := Node2D.new()
	hud_overlay.name = "HudOverlay"
	hud_overlay.z_index = 5
	hud_overlay.use_parent_material = false
	if hud_cb.is_valid():
		hud_overlay.draw.connect(hud_cb)
	visuals.add_child(hud_overlay)

	return {
		"enemies_tex": enemies_tex,
		"shadow_spr": shadow_spr,
		"boot_left_spr": boot_left_spr,
		"boot_right_spr": boot_right_spr,
		"body_spr": body_spr,
		"blood_spr": blood_spr,
		"glow_overlay": glow_overlay,
		"hud_overlay": hud_overlay
	}

static func sync_pixel_layers(enemy: Node2D, visuals: Node2D, layers: Dictionary, last_synced_type: int) -> int:
	var e_type: int = int(enemy.get("enemy_type"))
	var scale_f: float = EnemyData.get_type_scale(e_type)
	var shadow_spr: Sprite2D = layers.get("shadow_spr") as Sprite2D
	var boot_left_spr: Sprite2D = layers.get("boot_left_spr") as Sprite2D
	var boot_right_spr: Sprite2D = layers.get("boot_right_spr") as Sprite2D
	var body_spr: Sprite2D = layers.get("body_spr") as Sprite2D
	var blood_spr: Sprite2D = layers.get("blood_spr") as Sprite2D

	if last_synced_type != e_type:
		last_synced_type = e_type
		var col_idx: int = clampi(e_type, 0, 6)
		if body_spr:
			body_spr.region_rect = Rect2(col_idx * 48, 0, 48, 48)
		if shadow_spr:
			shadow_spr.scale = Vector2(scale_f * 1.05, scale_f * 1.15)
		if boot_left_spr and boot_right_spr:
			var bscale := Vector2(scale_f * 0.9, scale_f * 0.9)
			boot_left_spr.scale = bscale
			boot_right_spr.scale = bscale
			boot_left_spr.position = Vector2(0.0, -5.0 * scale_f)
			boot_right_spr.position = Vector2(0.0, 5.0 * scale_f)
		if visuals and visuals.material:
			var oc: Color = Color(0.05, 0.06, 0.08, 0.95)
			if e_type == 5: # BOSS
				oc = Color(0.95, 0.75, 0.15, 0.98)
			elif e_type == 6: # NIGHT_STALKER
				oc = Color(0.45, 0.22, 0.75, 0.92)
			visuals.material.set_shader_parameter("outline_color", oc)

	if blood_spr:
		var hp_val: float = float(enemy.get("hp"))
		var max_hp_val: float = float(enemy.get("max_hp"))
		var hp_ratio: float = hp_val / maxf(max_hp_val, 1.0)
		blood_spr.visible = hp_ratio < 0.7
		if blood_spr.visible:
			blood_spr.modulate.a = 0.95 if hp_ratio < 0.4 else 0.72
			blood_spr.scale = Vector2(scale_f, scale_f)

	if visuals and visuals.material:
		if e_type == 6: # NIGHT_STALKER
			var ns_alpha: float = float(enemy.call("get_night_stalker_body_alpha"))
			visuals.material.set_shader_parameter("stealth_dissolve", clampf(1.0 - ns_alpha, 0.0, 0.72))
		else:
			visuals.material.set_shader_parameter("stealth_dissolve", 0.0)

	return last_synced_type

static func update_cached_laser_end(enemy: Node2D) -> Vector2:
	var e_type: int = int(enemy.get("enemy_type"))
	var is_ranged: bool = bool(enemy.get("is_ranged_human"))
	var cur_state: int = int(enemy.get("current_state"))
	var reload_t: float = float(enemy.get("reload_timer"))
	var attack_rad: float = float(enemy.get("attack_radius"))
	var tele_timer: float = float(enemy.get("boss_telegraph_timer"))
	if not is_ranged or not (e_type == 4 or e_type == 5) or cur_state != 2 or reload_t > 0.0: # 2 = State.CHASE
		return Vector2(145.0, 1.0)
	var is_boss_lockon: bool = (e_type == 5 and tele_timer > 0.0)
	var muzzle_start := Vector2(28.0, 1.0)
	var laser_end := Vector2(attack_rad if is_boss_lockon else 145.0, 1.0)
	if enemy.is_inside_tree():
		var world_2d: World2D = enemy.get_world_2d()
		if world_2d != null and world_2d.direct_space_state:
			var q := PhysicsRayQueryParameters2D.create(enemy.to_global(muzzle_start), enemy.to_global(laser_end), 1, [enemy])
			var hit: Dictionary = world_2d.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				laser_end = enemy.to_local(hit["position"])
	return laser_end

static func draw_glow_overlay(enemy: Node2D, glow_overlay: Node2D, enemies_tex: CanvasTexture) -> void:
	if not enemy or not glow_overlay:
		return
	var active_grenades: Array = enemy.get("active_boss_grenades") if enemy.get("active_boss_grenades") is Array else []
	for g_info in active_grenades:
		var local_g: Vector2 = glow_overlay.to_local(g_info["pos"])
		var g_rad: float = float(g_info.get("radius", 120.0))
		var g_ratio: float = 1.0 - clampf(float(g_info.get("timer", 0.0)) / float(g_info.get("max_time", 1.8)), 0.0, 1.0)
		glow_overlay.draw_circle(local_g, g_rad, Color(0.95, 0.15, 0.15, 0.14 + 0.18 * g_ratio))
		glow_overlay.draw_arc(local_g, g_rad, 0, TAU, 32, Color(1.6, 0.3, 0.2, 0.88), 2.0)
		if enemies_tex:
			glow_overlay.draw_texture_rect_region(enemies_tex, Rect2(local_g - Vector2(24, 24), Vector2(48, 48)), Rect2(3 * 48, 48, 48, 48))
		else:
			glow_overlay.draw_circle(local_g, 5.0, Color(0.2, 0.25, 0.2, 0.95))

	var visuals: Node2D = enemy.get_node_or_null("Visuals") as Node2D
	if visuals and visuals.modulate.a < 0.05:
		return

	var e_type: int = int(enemy.get("enemy_type"))
	var is_ranged: bool = bool(enemy.get("is_ranged_human"))
	var cur_state: int = int(enemy.get("current_state"))
	var reload_t: float = float(enemy.get("reload_timer"))
	var tele_timer: float = float(enemy.get("boss_telegraph_timer"))

	if is_ranged:
		if e_type == 5: # BOSS
			glow_overlay.draw_rect(Rect2(2.5, -4.5, 4.0, 9.0), Color(2.2, 0.28, 0.22, 0.92))
		elif e_type == 4: # RAIDER
			glow_overlay.draw_rect(Rect2(4.0, -3.5, 3.0, 2.5), Color(0.28, 2.0, 0.50, 0.88))
			glow_overlay.draw_rect(Rect2(4.0, 1.0, 3.0, 2.5), Color(0.28, 2.0, 0.50, 0.88))

		if (e_type == 4 or e_type == 5) and cur_state == 2 and reload_t <= 0.0: # 2 = CHASE
			var is_boss_lockon: bool = (e_type == 5 and tele_timer > 0.0)
			var laser_col: Color = Color(2.2, 1.5, 0.22, 0.62) if e_type == 5 else Color(2.2, 0.24, 0.24, 0.52)
			var laser_w: float = 1.2
			var muzzle_start := Vector2(28.0, 1.0)
			var laser_end: Vector2 = enemy.get("_cached_laser_end") if enemy.get("_cached_laser_end") is Vector2 else Vector2(145.0, 1.0)
			if is_boss_lockon:
				var pulse: float = 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.025)
				laser_col = Color(2.6, 0.32 + 0.9 * pulse, 0.18, 0.94)
				laser_w = 2.6
				glow_overlay.draw_arc(Vector2.ZERO, 26.0 + 4.0 * pulse, 0.0, TAU, 24, Color(2.4, 0.28, 0.18, 0.25 + 0.72 * pulse), 2.0)
			glow_overlay.draw_line(muzzle_start, laser_end, laser_col, laser_w)
	else:
		if e_type == 6: # NIGHT_STALKER
			var ns_alpha: float = float(enemy.call("get_night_stalker_body_alpha"))
			var aura_a: float = 0.28 if ns_alpha < 0.5 else 0.14
			glow_overlay.draw_circle(Vector2(5.5, -2.5), 3.2, Color(0.35, 1.6, 2.0, aura_a))
			glow_overlay.draw_circle(Vector2(5.5, 2.5), 3.2, Color(0.35, 1.6, 2.0, aura_a))
			glow_overlay.draw_rect(Rect2(4.5, -3.5, 2.0, 2.0), Color(0.5, 2.4, 2.6, 0.98))
			glow_overlay.draw_rect(Rect2(4.5, 1.5, 2.0, 2.0), Color(0.5, 2.4, 2.6, 0.98))
		else:
			var eye_x: float = 6.0 if e_type == 2 else 4.0
			var eye_y: float = 3.2 if e_type == 2 else 2.4
			glow_overlay.draw_rect(Rect2(eye_x, -eye_y - 1.0, 2.0, 2.0), Color(2.2, 0.22, 0.22, 0.95))
			glow_overlay.draw_rect(Rect2(eye_x, eye_y - 1.0, 2.0, 2.0), Color(2.2, 0.22, 0.22, 0.95))

static func draw_hud_overlay(enemy: Node2D, hud_overlay: Node2D) -> void:
	if not enemy or not hud_overlay:
		return
	var visuals: Node2D = enemy.get_node_or_null("Visuals") as Node2D
	if not visuals or visuals.modulate.a < 0.05:
		return

	var e_type: int = int(enemy.get("enemy_type"))
	var scale_f: float = EnemyData.get_type_scale(e_type)
	var is_ranged: bool = bool(enemy.get("is_ranged_human"))
	var reload_t: float = float(enemy.get("reload_timer"))
	var hp_val: float = float(enemy.get("hp"))
	var max_hp_val: float = float(enemy.get("max_hp"))
	var alert_t: float = float(enemy.get("alert_timer"))
	var alert_icon: String = String(enemy.get("alert_icon_type"))

	hud_overlay.draw_set_transform(Vector2(0.0, -visuals.position.y), -enemy.rotation - visuals.rotation, Vector2.ONE)

	if is_ranged and reload_t > 0.0:
		var r_w: float = 24.0
		var r_pos := Vector2(-r_w / 2.0, -18.0 * scale_f - 16.0)
		hud_overlay.draw_rect(Rect2(r_pos, Vector2(r_w, 3.0)), Color(0.15, 0.15, 0.2, 0.85))
		var r_ratio: float = clampf(1.0 - (reload_t / 1.9), 0.0, 1.0)
		hud_overlay.draw_rect(Rect2(r_pos, Vector2(r_w * r_ratio, 3.0)), Color(1.0, 0.85, 0.25))

	if (hp_val < max_hp_val or e_type == 5) and hp_val > 0.0:
		var bar_w: float = 38.0 if e_type == 5 else 26.0
		var bar_h: float = 5.0 if e_type == 5 else 4.0
		var bar_pos := Vector2(-bar_w / 2.0, -18.0 * scale_f - 10.0)
		hud_overlay.draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0.05, 0.05, 0.08, 0.9))
		hud_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.18))
		var fill_w: float = clampf(hp_val / maxf(max_hp_val, 1.0), 0.0, 1.0) * bar_w
		var bar_col: Color = Color(1.0, 0.75, 0.15) if e_type == 5 else Color(0.9, 0.2, 0.2)
		hud_overlay.draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_h)), bar_col)

	if alert_t > 0.0:
		var icon_pos := Vector2(0, -22.0 * scale_f - 12.0)
		var icon_col: Color = Color(1.0, 0.2, 0.2) if alert_icon == "!" else Color(1.0, 0.8, 0.2)
		var bg_alpha: float = clampf(alert_t, 0.0, 1.0)
		hud_overlay.draw_circle(icon_pos, 8.0, Color(0.1, 0.1, 0.1, 0.8 * bg_alpha))
		hud_overlay.draw_arc(icon_pos, 8.0, 0, TAU, 16, icon_col * Color(1, 1, 1, bg_alpha), 1.5)

		if alert_icon == "!":
			hud_overlay.draw_line(icon_pos + Vector2(0, -4), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.5)
			hud_overlay.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
		else:
			hud_overlay.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
			hud_overlay.draw_arc(icon_pos + Vector2(0, -2), 3.0, -PI, 0, 8, icon_col * Color(1, 1, 1, bg_alpha), 2.0)
			hud_overlay.draw_line(icon_pos + Vector2(3, -2), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.0)

	hud_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func update_tactical_visibility(enemy: Node2D, target_player: Node2D, delta: float, dist: float, visuals: Node2D, has_los: bool) -> void:
	if not is_instance_valid(target_player) or not visuals:
		return
	if not has_los:
		visuals.modulate.a = lerp(visuals.modulate.a, 0.0, clamp(delta * 14.0, 0.0, 1.0))
		return

	var p_forward: Vector2 = Vector2.RIGHT.rotated(target_player.rotation)
	var dir_from_p: Vector2 = target_player.global_position.direction_to(enemy.global_position)
	var dot_p: float = p_forward.dot(dir_from_p)

	var is_darkness: bool = false
	var current_scene: Node = enemy.get_tree().current_scene if enemy.get_tree() else null
	var day_night: Node = current_scene.get_node_or_null("DayNightModulate") if current_scene else null
	if day_night and day_night is CanvasModulate:
		if (day_night as CanvasModulate).color.v < 0.45:
			is_darkness = true
	elif current_scene and "Interior" in String(current_scene.name):
		is_darkness = true

	var target_alpha: float = 0.0
	var e_type: int = int(enemy.get("enemy_type"))

	if is_darkness:
		var flashlight_on: bool = false
		var nvg_on: bool = false
		if target_player.get("player_lighting") != null:
			var pl = target_player.get("player_lighting")
			flashlight_on = bool(pl.flashlight_enabled)
			nvg_on = bool(pl.nvg_enabled)
		elif target_player.get("flashlight_enabled") != null:
			flashlight_on = bool(target_player.get("flashlight_enabled"))
			if target_player.get("nvg_enabled") != null:
				nvg_on = bool(target_player.get("nvg_enabled"))

		var in_nvg: bool = nvg_on and (dot_p >= 0.34 or dist <= 85.0)
		var in_flashlight_cone: bool = flashlight_on and (dist <= 340.0) and (dot_p >= 0.85)
		var in_close_touch: bool = dist <= 35.0

		if in_nvg or in_flashlight_cone or in_close_touch:
			target_alpha = 1.0
		elif e_type == 6 and dist <= 180.0 and dot_p >= 0.35: # NIGHT_STALKER
			target_alpha = 0.35
		else:
			target_alpha = 0.0
	else:
		var in_fov: bool = dot_p >= 0.34
		var in_close: bool = dist <= 85.0
		target_alpha = 1.0 if (in_fov or in_close) else 0.0

	var prev_a: float = visuals.modulate.a
	visuals.modulate.a = lerp(visuals.modulate.a, target_alpha, clamp(delta * 14.0, 0.0, 1.0))
	if abs(visuals.modulate.a - prev_a) > 0.01:
		visuals.queue_redraw()
