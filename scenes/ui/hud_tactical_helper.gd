# res://scenes/ui/hud_tactical_helper.gd
class_name HudTacticalHelper
extends RefCounted

## 외부 월드(main_world.gd)와 건물 내부(building_interior_scene.gd) 공용 HUD 및 52x52 아이콘 퀵슬롯 헬퍼

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

	var style: StyleBoxFlat
	if btn.has_theme_stylebox_override("normal"):
		style = btn.get_theme_stylebox("normal") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

	style.bg_color = Color(0.11, 0.14, 0.19, 0.94) if is_active else Color(0.06, 0.08, 0.11, 0.88)
	var b_w = 2 if is_active else 1
	style.border_width_left = b_w
	style.border_width_top = b_w
	style.border_width_right = b_w
	style.border_width_bottom = b_w
	style.border_color = active_color if is_active else (Color(0.28, 0.34, 0.42, 0.85) if is_available else Color(0.18, 0.20, 0.24, 0.65))

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

	var key_lbl: Label = btn.get_node_or_null("KeyBadge")
	if not key_lbl:
		key_lbl = Label.new()
		key_lbl.name = "KeyBadge"
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.position = Vector2(4, 2)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		key_lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(key_lbl)
	key_lbl.text = key_str
	key_lbl.add_theme_color_override("font_color", active_color if is_active else Color(0.75, 0.80, 0.88))

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
