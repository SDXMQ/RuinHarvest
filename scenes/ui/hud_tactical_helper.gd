# res://scenes/ui/hud_tactical_helper.gd
class_name HudTacticalHelper
extends RefCounted

## 외부 월드(main_world.gd)와 건물 내부(building_interior_scene.gd) 공용 HUD 및 52x52 아이콘 퀵슬롯 헬퍼

static func _on_quickslot_decor_draw(decor: Control) -> void:
	if not is_instance_valid(decor):
		return
	var is_active: bool = bool(decor.get_meta("is_active", false))
	var is_available: bool = bool(decor.get_meta("is_available", true))
	var active_col: Color = decor.get_meta("active_color", Color(1.0, 0.82, 0.25))
	var sz := decor.size
	if sz.x <= 4.0 or sz.y <= 4.0:
		sz = Vector2(52.0, 52.0)

	# 1. 좌상단 픽셀 키캡 박스 (13x12)
	var kc_rect := Rect2(2.0, 2.0, 13.0, 12.0)
	var kc_bg := Color(0.18, 0.14, 0.06, 0.95) if is_active else Color(0.04, 0.05, 0.07, 0.92)
	var kc_border := active_col if is_active else Color(0.28, 0.34, 0.42, 0.9)
	decor.draw_rect(kc_rect, kc_bg, true)
	decor.draw_rect(kc_rect, kc_border, false, 1.0)

	# 2. 우상단 3x3 픽셀 상태 LED 도트
	var led_col := active_col if is_active else (Color(0.24, 0.78, 0.42, 0.85) if is_available else Color(0.22, 0.25, 0.30, 0.7))
	decor.draw_rect(Rect2(sz.x - 6.0, 3.0, 3.0, 3.0), led_col, true)
	if is_active:
		decor.draw_rect(Rect2(sz.x - 5.0, 4.0, 1.0, 1.0), Color(1.0, 0.98, 0.9, 0.95), true)

	# 3. 4모서리 도트 L-브래킷
	var br_col := active_col if is_active else (Color(0.42, 0.50, 0.62, 0.85) if is_available else Color(0.22, 0.25, 0.30, 0.6))
	var arm := 4.0
	decor.draw_rect(Rect2(1.0, sz.y - 2.0, arm, 1.0), br_col, true)
	decor.draw_rect(Rect2(1.0, sz.y - 1.0 - arm, 1.0, arm), br_col, true)
	decor.draw_rect(Rect2(sz.x - 1.0 - arm, sz.y - 2.0, arm, 1.0), br_col, true)
	decor.draw_rect(Rect2(sz.x - 2.0, sz.y - 1.0 - arm, 1.0, arm), br_col, true)

static func style_quickslot_button(
	btn: Button,
	key_str: String,
	icon_id: String,
	count_str: String,
	tooltip_str: String,
	is_active: bool,
	is_available: bool = true,
	active_color: Color = Color(1.0, 0.82, 0.25)
) -> void:
	if not btn:
		return
	btn.custom_minimum_size = Vector2(52, 52)
	btn.size = Vector2(52, 52)
	btn.text = ""
	btn.tooltip_text = tooltip_str
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE

	var sb: StyleBox = null
	var sb_pressed: StyleBox = null
	if PixelAssetManager:
		var slice_key := "quickslot_active" if is_active else ("quickslot_normal" if is_available else "quickslot_unavailable")
		var tint := active_color if (is_active and not active_color.is_equal_approx(Color(1.0, 0.82, 0.25))) else Color.WHITE
		sb = PixelAssetManager.get_pixel_stylebox(slice_key, 4.0, 4.0, 4.0, 4.0, 4, tint)
		sb_pressed = PixelAssetManager.get_pixel_stylebox(slice_key, 4.0, 5.0, 4.0, 3.0, 4, tint)
	if sb != null:
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
	if sb_pressed != null:
		btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sweep_overlay: ColorRect = btn.get_node_or_null("SweepOverlay")
	if not sweep_overlay:
		sweep_overlay = ColorRect.new()
		sweep_overlay.name = "SweepOverlay"
		sweep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep_overlay.color = Color(0.2, 0.85, 1.0, 0.45)
		sweep_overlay.visible = false
		btn.add_child(sweep_overlay)

	var icon_rect: TextureRect = btn.get_node_or_null("IconRect")
	if not icon_rect:
		icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.set_anchors_preset(Control.PRESET_CENTER)
		icon_rect.offset_left = -15
		icon_rect.offset_top = -13
		icon_rect.offset_right = 15
		icon_rect.offset_bottom = 17
		btn.add_child(icon_rect)

	if icon_id != "" and ItemIconManager:
		icon_rect.texture = ItemIconManager.get_icon(icon_id)
		icon_rect.visible = true
		icon_rect.modulate = Color(1, 1, 1, 1.0 if is_available else 0.35)
	else:
		icon_rect.texture = null
		icon_rect.visible = false

	var pixel_decor: Control = btn.get_node_or_null("PixelDecor")
	if not pixel_decor:
		pixel_decor = Control.new()
		pixel_decor.name = "PixelDecor"
		pixel_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
		pixel_decor.draw.connect(_on_quickslot_decor_draw.bind(pixel_decor))
		btn.add_child(pixel_decor)
	pixel_decor.set_meta("is_active", is_active)
	pixel_decor.set_meta("is_available", is_available)
	pixel_decor.set_meta("active_color", active_color)
	pixel_decor.queue_redraw()

	var key_lbl: Label = btn.get_node_or_null("KeyBadge")
	if not key_lbl:
		key_lbl = Label.new()
		key_lbl.name = "KeyBadge"
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.position = Vector2(5, 1)
		if PixelAssetManager:
			key_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		key_lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(key_lbl)
	key_lbl.text = key_str
	key_lbl.add_theme_color_override("font_color", active_color if is_active else Color(0.78, 0.83, 0.90))

	var cnt_lbl: Label = btn.get_node_or_null("CountBadge")
	if not cnt_lbl:
		cnt_lbl = Label.new()
		cnt_lbl.name = "CountBadge"
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cnt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cnt_lbl.offset_left = 2
		cnt_lbl.offset_top = -15
		cnt_lbl.offset_right = -4
		cnt_lbl.offset_bottom = -1
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if PixelAssetManager:
			cnt_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
		cnt_lbl.add_theme_font_size_override("font_size", 10)
		cnt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		cnt_lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(cnt_lbl)
	cnt_lbl.text = count_str
	cnt_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0) if is_available else Color(0.55, 0.58, 0.62))

static func update_quickslot_bar(quickslot_hbox: HBoxContainer, player: Node) -> void:
	if not quickslot_hbox or not player:
		return

	var cur_w_slot = player.active_weapon_slot if "active_weapon_slot" in player else "primary1"

	# Slot 1 ~ 3 (Weapons)
	var weapon_slots = [
		{"node": "Slot1", "key": "1", "slot": "primary1", "fallback_name": "주무기 1"},
		{"node": "Slot2", "key": "2", "slot": "primary2", "fallback_name": "주무기 2"},
		{"node": "Slot3", "key": "3", "slot": "sidearm", "fallback_name": "보조무기"}
	]
	for ws in weapon_slots:
		var btn: Button = quickslot_hbox.get_node_or_null(ws["node"])
		if btn:
			var eq: Dictionary = player.equipment.get(ws["slot"], {})
			var has_w = not eq.is_empty()
			var w_id = String(eq.get("id", ""))
			var w_name = String(eq.get("name", ws["fallback_name"])) if has_w else "빈 슬롯"
			var mag_str = str(int(eq.get("current_magazine_ammo", 0))) if has_w and eq.has("current_magazine_ammo") else ""
			style_quickslot_button(
				btn,
				ws["key"],
				w_id,
				mag_str,
				"[%s] %s" % [ws["key"], w_name],
				cur_w_slot == ws["slot"],
				has_w
			)

	# Slot 4 (Throwable)
	var slot4: Button = quickslot_hbox.get_node_or_null("Slot4")
	if slot4:
		var eq4: Dictionary = player.equipment.get("throwable", {})
		var has_t = not eq4.is_empty()
		var amt4 = int(eq4.get("amount", 1)) if has_t else 0
		var w4_id = String(eq4.get("id", "수류탄")) if has_t else ""
		var w4_name = String(eq4.get("name", "투척무기")) if has_t else "빈 슬롯"
		style_quickslot_button(
			slot4,
			"4",
			w4_id,
			("x%d" % amt4) if amt4 > 0 else "",
			"[4] %s" % w4_name,
			cur_w_slot == "throwable",
			has_t and amt4 > 0
		)

	# Slot 5 (Bleed), Slot 6 (Heal), Slot 7 (Ration), Slot U (Radio) — 단일 패스(Single-pass) 인벤토리 순회
	var count5: int = 0
	var name5: String = "붕대"
	var icon5: String = "붕대"
	var count6: int = 0
	var name6: String = "구급상자"
	var icon6: String = "구급상자"
	var count7: int = 0
	var name7: String = "식량/생수"
	var icon7: String = "식량통조림"
	var has_radio: bool = false

	if player.inventory_grid:
		for it in player.inventory_grid.items:
			var id: String = String(it.get("id", ""))
			if id == "":
				continue
			var amt: int = int(it.get("amount", 1))
			if id in ["장거리 무전기", "군용 무전기", "무전기"] or id.contains("무전기"):
				has_radio = true
			var d: Dictionary = ItemDatabase.get_item_data(id)
			var cat: int = int(d.get("category", -1))
			var eff: Dictionary = d.get("effects", {}) if d.get("effects") is Dictionary else {}
			if cat == ItemDatabase.ItemCategory.MEDICAL:
				if eff.get("cures_bleeding", false) or id.contains("붕대") or id.contains("지혈"):
					count5 += amt
					name5 = String(d.get("name", id))
					icon5 = id
				if eff.get("hp", 0) > 0 or eff.get("cures_fracture", false) or eff.get("cures_infection", false) or id.contains("구급") or id.contains("키트") or id.contains("부목"):
					count6 += amt
					name6 = String(d.get("name", id))
					icon6 = id
			if cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or eff.has("hunger") or eff.has("thirst"):
				count7 += amt
				name7 = String(d.get("name", id))
				icon7 = id

	var slot5: Button = quickslot_hbox.get_node_or_null("Slot5")
	if slot5:
		style_quickslot_button(slot5, "5", icon5, "x%d" % count5, "[5] %s (%d)" % [name5, count5], false, count5 > 0)

	var slot6: Button = quickslot_hbox.get_node_or_null("Slot6")
	if slot6:
		style_quickslot_button(slot6, "6", icon6, "x%d" % count6, "[6] %s (%d)" % [name6, count6], false, count6 > 0)

	var slot7: Button = quickslot_hbox.get_node_or_null("Slot7")
	if slot7:
		style_quickslot_button(slot7, "7", icon7, "x%d" % count7, "[7] %s (%d)" % [name7, count7], false, count7 > 0)

	# Slot N (NVG)
	var slotN: Button = quickslot_hbox.get_node_or_null("SlotN")
	if slotN:
		var nvg_active = player.player_lighting.nvg_enabled if ("player_lighting" in player and player.player_lighting) else false
		style_quickslot_button(
			slotN,
			"N",
			"고배율_망원경",
			"ON" if nvg_active else "OFF",
			"[N] 전술 야간투시경 (NVG)",
			nvg_active,
			true,
			Color(0.25, 1.0, 0.4)
		)

	# Slot U (Radio)
	var slotU: Button = quickslot_hbox.get_node_or_null("SlotU")
	if not slotU:
		slotU = Button.new()
		slotU.name = "SlotU"
		quickslot_hbox.add_child(slotU)
	style_quickslot_button(
		slotU,
		"U",
		"장거리 무전기",
		"RADIO" if has_radio else "OFF",
		"[U] 무전 호출 가능 (드론 보급/풀턴 회수/스캔)" if has_radio else "[U] 전술 무전기 미보유",
		has_radio,
		has_radio,
		Color(0.3, 0.9, 1.0)
	)

static func update_channeling_sweep(quickslot_hbox: HBoxContainer, slot_key: String, ratio: float) -> void:
	if not quickslot_hbox:
		return
	var target_slot_names: Array = []
	if slot_key == "5" or slot_key == "bleed": target_slot_names = ["Slot5"]
	elif slot_key == "6" or slot_key == "heal": target_slot_names = ["Slot6"]
	elif slot_key == "7" or slot_key == "ration": target_slot_names = ["Slot7"]
	elif slot_key == "clear": target_slot_names = []
	else:
		var candidate = "Slot" + slot_key
		if quickslot_hbox.has_node(candidate):
			target_slot_names = [candidate]

	for s_name in ["Slot5", "Slot6", "Slot7"]:
		var b: Button = quickslot_hbox.get_node_or_null(s_name)
		if not b: continue
		var sw: ColorRect = b.get_node_or_null("SweepOverlay")
		if not sw: continue
		if s_name in target_slot_names and ratio > 0.0 and ratio < 1.0:
			sw.visible = true
			var h = 52.0 * clamp(ratio, 0.0, 1.0)
			sw.size = Vector2(52, h)
			sw.position = Vector2(0, 52.0 - h)
		else:
			sw.visible = false

static func style_hud_bars(hp_bar: ProgressBar, stamina_bar: ProgressBar, hunger_bar: ProgressBar, thirst_bar: ProgressBar) -> void:
	var bg_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("progress_bg", 2.0, 2.0, 2.0, 2.0, 3) if PixelAssetManager else null
	if hp_bar:
		if bg_sb != null: hp_bar.add_theme_stylebox_override("background", bg_sb)
		InventoryUIHelper.apply_dynamic_tint(hp_bar, "fill", Color(0.88, 0.24, 0.26, 0.98))
	if stamina_bar:
		if bg_sb != null: stamina_bar.add_theme_stylebox_override("background", bg_sb)
		InventoryUIHelper.apply_dynamic_tint(stamina_bar, "fill", Color(0.24, 0.70, 0.92, 0.98))
	if hunger_bar:
		if bg_sb != null: hunger_bar.add_theme_stylebox_override("background", bg_sb)
		InventoryUIHelper.apply_dynamic_tint(hunger_bar, "fill", Color(0.90, 0.60, 0.18, 0.98))
	if thirst_bar:
		if bg_sb != null: thirst_bar.add_theme_stylebox_override("background", bg_sb)
		InventoryUIHelper.apply_dynamic_tint(thirst_bar, "fill", Color(0.22, 0.80, 0.72, 0.98))

static func style_status_badges(badges: Array) -> void:
	var badge_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("toast", 6.0, 3.0, 6.0, 3.0, 3) if PixelAssetManager else null
	for b in badges:
		if is_instance_valid(b) and b is Control:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.focus_mode = Control.FOCUS_NONE
			if badge_sb != null:
				b.add_theme_stylebox_override("panel", badge_sb)

static func make_event_toast_stylebox(accent_col: Color = Color(1.0, 0.8, 0.2)) -> StyleBox:
	if PixelAssetManager:
		var tint := Color(accent_col.r, accent_col.g, accent_col.b, 0.96).lerp(Color.WHITE, 0.25)
		return PixelAssetManager.get_pixel_stylebox("toast", 10.0, 6.0, 10.0, 6.0, 4, tint)
	return StyleBoxEmpty.new()

static func spawn_event_toast(owner_node: Node, event_log_vbox: VBoxContainer, msg: String) -> void:
	if not is_instance_valid(event_log_vbox) or not is_instance_valid(owner_node):
		return
	var max_logs: int = GameSettings.max_event_logs if GameSettings else 3
	var accent_col := Color(1.0, 0.8, 0.2)
	var font_col := Color(0.92, 0.94, 0.96)
	if msg.begins_with("★"):
		accent_col = Color(1.0, 0.8, 0.2)
		font_col = Color(1.0, 0.9, 0.4)
	elif msg.begins_with("✓") or msg.begins_with("📦") or msg.begins_with("💊") or msg.begins_with("🔓"):
		accent_col = Color(0.3, 0.9, 0.4)
		font_col = Color(0.6, 1.0, 0.6)
	elif msg.begins_with("✗") or msg.begins_with("💀") or msg.begins_with("⚠️") or msg.begins_with("🔒"):
		accent_col = Color(0.9, 0.3, 0.3)
		font_col = Color(1.0, 0.5, 0.5)
	elif msg.begins_with("🌦️") or msg.begins_with("🌅") or msg.begins_with("📻") or msg.begins_with("💡"):
		accent_col = Color(0.3, 0.7, 1.0)
		font_col = Color(0.6, 0.85, 1.0)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_event_toast_stylebox(accent_col))
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", font_col)
	panel.add_child(lbl)
	event_log_vbox.add_child(panel)

	while event_log_vbox.get_child_count() > max_logs:
		var oldest := event_log_vbox.get_child(0)
		oldest.queue_free()
		event_log_vbox.remove_child(oldest)

	if owner_node.is_inside_tree():
		var tween := owner_node.create_tween()
		tween.tween_interval(5.0)
		tween.tween_property(panel, "modulate:a", 0.0, 1.0)
		tween.tween_callback(panel.queue_free)

static func update_player_hud(
	player: Node,
	hp_bar: ProgressBar,
	stamina_bar: ProgressBar,
	hunger_bar: ProgressBar,
	thirst_bar: ProgressBar,
	status_label: Label,
	badge_bleed: Control,
	badge_fracture: Control,
	badge_biohazard: Control,
	weapon_panel: Control,
	weapon_icon: TextureRect,
	weapon_name_label: Label,
	ammo_label: Label,
	weapon_durability_bar: ProgressBar,
	has_radio: bool = false
) -> void:
	if not is_instance_valid(player):
		return
	if hp_bar:
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp
		var hp_lbl := hp_bar.get_node_or_null("Label") as Label
		if hp_lbl:
			hp_lbl.text = "HP: %d/%d" % [int(player.hp), int(player.max_hp)]
	if stamina_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.stamina
		var st_lbl := stamina_bar.get_node_or_null("Label") as Label
		if st_lbl:
			st_lbl.text = "STAMINA: %d/%d" % [int(player.stamina), int(player.max_stamina)]
	if hunger_bar:
		hunger_bar.value = player.hunger
	if thirst_bar:
		thirst_bar.value = player.thirst

	var pk_timer: float = float(player.get("painkiller_timer")) if player.get("painkiller_timer") != null else 0.0
	var pk_red: float = float(player.get("painkiller_damage_reduction")) if player.get("painkiller_damage_reduction") != null else 0.0
	var has_status: bool = bool(player.is_bleeding or player.is_fractured or player.is_infected or pk_timer > 0.0)
	if badge_bleed:
		badge_bleed.visible = player.is_bleeding
	if badge_fracture:
		badge_fracture.visible = player.is_fractured
	if badge_biohazard:
		badge_biohazard.visible = player.is_infected

	var badges_parent := badge_bleed.get_parent() if is_instance_valid(badge_bleed) else null
	if badges_parent:
		var pk_badge := badges_parent.get_node_or_null("PainkillerBadge") as PanelContainer
		if pk_timer > 0.0:
			if not pk_badge:
				pk_badge = PanelContainer.new()
				pk_badge.name = "PainkillerBadge"
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(0.08, 0.22, 0.24, 0.92)
				sb.set_border_width_all(1)
				sb.border_color = Color(0.28, 0.90, 0.78, 0.90)
				sb.set_corner_radius_all(3)
				sb.content_margin_left = 6
				sb.content_margin_right = 6
				sb.content_margin_top = 2
				sb.content_margin_bottom = 2
				pk_badge.add_theme_stylebox_override("panel", sb)
				var pk_lbl := Label.new()
				pk_lbl.name = "Label"
				pk_lbl.add_theme_font_size_override("font_size", 10)
				pk_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.85))
				pk_badge.add_child(pk_lbl)
				badges_parent.add_child(pk_badge)
			pk_badge.visible = true
			var lbl := pk_badge.get_node_or_null("Label") as Label
			if lbl:
				lbl.text = "💊 진통제 %ds (-%d%%)" % [ceili(pk_timer), int(round(pk_red * 100.0))]
		elif pk_badge:
			pk_badge.visible = false

	if status_label:
		var statuses: Array[String] = []
		if player.is_bleeding: statuses.append("출혈")
		if player.is_fractured: statuses.append("골절")
		if player.is_infected: statuses.append("감염")
		if pk_timer > 0.0: statuses.append("진통제(%ds)" % ceili(pk_timer))
		status_label.text = "상태이상: " + (", ".join(statuses) if statuses.size() > 0 else "없음")
		status_label.visible = not has_status

	if weapon_panel:
		var radio_badge: Label = weapon_panel.get_node_or_null("RadioHudBadge") as Label
		if not radio_badge:
			radio_badge = Label.new()
			radio_badge.name = "RadioHudBadge"
			radio_badge.text = "📡 [U] 무전 호출 가능"
			radio_badge.add_theme_font_size_override("font_size", 11)
			radio_badge.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
			radio_badge.position = Vector2(6, -20)
			weapon_panel.add_child(radio_badge)
		radio_badge.visible = has_radio

		var eq_wep: String = str(player.equipped_weapon)
		var wep_data: Dictionary = ItemDatabase.get_item_data(str(player.equipped_weapon_data.get("id", eq_wep)))
		var slot_disp: String = player._get_slot_display_name(player.active_weapon_slot) if player.has_method("_get_slot_display_name") else ""
		var disp_name: String = str(player.equipped_weapon_data.get("name", eq_wep))
		if weapon_name_label:
			weapon_name_label.text = "[%s] %s" % [slot_disp, disp_name]
		if weapon_icon and ItemIconManager:
			weapon_icon.texture = ItemIconManager.get_icon(str(player.equipped_weapon_data.get("id", eq_wep)))

		if ammo_label:
			if player.equipped_weapon_data.is_empty():
				ammo_label.text = "👊 맨손 (주먹)"
				ammo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			elif player.active_weapon_slot == "throwable" or str(player.equipped_weapon_data.get("type", "")) == "throwable":
				var amt: int = int(player.equipped_weapon_data.get("amount", 1))
				ammo_label.text = "💣 수량: %d개" % amt
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			elif not WeaponHandler.is_firearm_dict(player.equipped_weapon_data):
				ammo_label.text = "🗡️ 근접 무기 (좌클릭 타격)"
				ammo_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			else:
				var cur_mag: int = int(player.equipped_weapon_data.get("current_magazine_ammo", 0))
				var stats: Dictionary = player.equipped_weapon_data.get("computed_stats", {})
				var mag_size: int = int(stats.get("magazine_size", 15))
				var reserve_ammo: int = player._get_available_ammo_count() if player.has_method("_get_available_ammo_count") else 0
				var compat_list: Array = player._get_compatible_ammo_types() if player.has_method("_get_compatible_ammo_types") else []
				var cal: String = str(compat_list[0]) if compat_list.size() > 0 else "9mm"
				var cal_disp: String = "9mm 탄약" if cal in ["9mm", "탄약"] else cal.replace("_", " ")
				ammo_label.text = "🔫 %d / %d  [%s: %d]" % [cur_mag, mag_size, cal_disp, reserve_ammo]
				ammo_label.add_theme_color_override("font_color", Color.RED if cur_mag == 0 else Color(0.4, 1.0, 0.6))

		if weapon_durability_bar:
			var max_dur: float = float(player.equipped_weapon_data.get("max_durability", wep_data.get("max_durability", 100.0)))
			var cur_dur: float = float(player.equipped_weapon_data.get("durability", max_dur))
			weapon_durability_bar.max_value = max_dur
			weapon_durability_bar.value = cur_dur
			var ratio: float = cur_dur / maxf(1.0, max_dur)
			var target_fill_col := Color(0.2, 0.8, 0.3) if ratio > 0.6 else (Color(0.9, 0.7, 0.1) if ratio > 0.3 else Color(0.9, 0.2, 0.2))
			InventoryUIHelper.apply_dynamic_tint(weapon_durability_bar, "fill", target_fill_col)

static func draw_hit_arcs(hit_arc_overlay: Control, hit_arcs: Array) -> void:
	if not is_instance_valid(hit_arc_overlay) or hit_arcs.is_empty():
		return
	var center: Vector2 = (hit_arc_overlay.size * 0.5).floor()
	var arc_radius: float = 130.0
	var arc_width: float = 3.5
	var arc_spread: float = deg_to_rad(38.0)
	for arc_data in hit_arcs:
		var alpha: float = clampf(float(arc_data["timer"]) / float(arc_data["max_time"]), 0.0, 1.0)
		var arc_angle: float = float(arc_data["angle"])
		var col := Color(1.0, 0.15, 0.15, 0.85 * alpha)
		var shadow_col := Color(0.1, 0.0, 0.0, 0.45 * alpha)
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, shadow_col, arc_width + 2.0)
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, col, arc_width)
		var tip_dir := Vector2.RIGHT.rotated(arc_angle)
		var tip_pos := center + tip_dir * (arc_radius + 6.0)
		var p_left := center + Vector2.RIGHT.rotated(arc_angle - 0.09) * (arc_radius + 1.0)
		var p_right := center + Vector2.RIGHT.rotated(arc_angle + 0.09) * (arc_radius + 1.0)
		hit_arc_overlay.draw_colored_polygon(PackedVector2Array([tip_pos, p_left, p_right]), col)

static func draw_pixel_crosshair(ctrl: Control, m_pos: Vector2, spread: float, is_ads: bool, is_jammed: bool) -> void:
	if not ctrl:
		return
	var cx := floorf(m_pos.x)
	var cy := floorf(m_pos.y)
	var gap := floorf(clampf(spread, 4.0, 48.0))
	var bar_len := 7.0
	var col := Color(0.25, 1.0, 0.45, 0.92) if is_ads else Color(1.0, 0.96, 0.82, 0.88)
	var shadow_col := Color(0.0, 0.0, 0.0, 0.82)

	# 상/하/좌/우 정수 스냅 픽셀 레티클 바 (1px 다크 아웃라인 + 2px 코어)
	# Top
	ctrl.draw_rect(Rect2(cx - 2.0, cy - gap - bar_len - 1.0, 4.0, bar_len + 2.0), shadow_col, true)
	ctrl.draw_rect(Rect2(cx - 1.0, cy - gap - bar_len, 2.0, bar_len), col, true)
	# Bottom
	ctrl.draw_rect(Rect2(cx - 2.0, cy + gap - 1.0, 4.0, bar_len + 2.0), shadow_col, true)
	ctrl.draw_rect(Rect2(cx - 1.0, cy + gap, 2.0, bar_len), col, true)
	# Left
	ctrl.draw_rect(Rect2(cx - gap - bar_len - 1.0, cy - 2.0, bar_len + 2.0, 4.0), shadow_col, true)
	ctrl.draw_rect(Rect2(cx - gap - bar_len, cy - 1.0, bar_len, 2.0), col, true)
	# Right
	ctrl.draw_rect(Rect2(cx + gap - 1.0, cy - 2.0, bar_len + 2.0, 4.0), shadow_col, true)
	ctrl.draw_rect(Rect2(cx + gap, cy - 1.0, bar_len, 2.0), col, true)

	# 정중앙 2x2 도트 포인트
	ctrl.draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 4.0), shadow_col, true)
	ctrl.draw_rect(Rect2(cx - 1.0, cy - 1.0, 2.0, 2.0), col, true)

	if is_jammed and floori(float(Time.get_ticks_msec()) / 250.0) % 2 == 0:
		var jam_pos := Vector2(cx + 16.0, cy + 16.0)
		ctrl.draw_string(ThemeDB.fallback_font, jam_pos + Vector2(1, 1), "[JAM - Press R]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.9))
		ctrl.draw_string(ThemeDB.fallback_font, jam_pos, "[JAM - Press R]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.2, 0.2, 1.0))
