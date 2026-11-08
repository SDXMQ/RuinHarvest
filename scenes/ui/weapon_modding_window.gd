# res://scenes/ui/weapon_modding_window.gd
extends Control

## 총기 조립/개조 UI 창 (실제 인벤토리 보유 부품 기반 장착/분리 및 탄약 보존)

signal window_closed

const SLOT_ORDER = ["barrel", "muzzle", "optic", "magazine", "stock", "grip", "rail"]
const SLOT_NAMES_KR = {
	"barrel": "총열 (Barrel)",
	"muzzle": "총구 (Muzzle)",
	"optic": "조준경 (Optic)",
	"magazine": "탄창 (Magazine)",
	"stock": "개머리판 (Stock)",
	"grip": "손잡이 (Grip)",
	"rail": "전술 레일 (Tactical Rail)"
}

const ShootingRangeScript = preload("res://scenes/ui/shooting_range_window.gd")

var current_receiver_id: String = "M9_리시버"
var current_weapon: Dictionary = {}
var original_attached_parts: Dictionary = {}
var original_magazine_ammo: int = 0
var player_inv: InventoryGrid = null
var stash_inv: InventoryGrid = null
var slot_buttons: Dictionary = {} # slot -> OptionButton
var stat_bars: Dictionary = {} # stat_key -> {bar: ProgressBar, lbl: Label}
var receiver_option_btn: OptionButton = null
var weapon_title_lbl: Label = null
var special_tags_lbl: Label = null
var slots_container: VBoxContainer = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func setup(p_inv: InventoryGrid, s_inv: InventoryGrid = null, initial_weapon: Dictionary = {}) -> void:
	player_inv = p_inv
	stash_inv = s_inv
	if not initial_weapon.is_empty() and initial_weapon.has("id"):
		current_receiver_id = WeaponPartsDatabase.resolve_receiver_id(initial_weapon["id"])
		current_weapon = initial_weapon.duplicate(true)
		if not current_weapon.has("parts"):
			current_weapon["parts"] = current_weapon.get("attachments", {}).duplicate(true)
		current_weapon["attachments"] = current_weapon["parts"]
		original_attached_parts = current_weapon["parts"].duplicate(true)
		original_magazine_ammo = int(current_weapon.get("current_magazine_ammo", 0))
	else:
		current_receiver_id = "M9_리시버"
		current_weapon = WeaponPartsDatabase.create_default_weapon(current_receiver_id)
		current_weapon["parts"] = {}
		current_weapon["attachments"] = current_weapon["parts"]
		current_weapon["current_magazine_ammo"] = 0
		original_attached_parts = {}
		original_magazine_ammo = 0
	_populate_receivers()
	if receiver_option_btn:
		receiver_option_btn.disabled = true
	_refresh_slots_for_receiver()
	_recompute_and_update_ui()

func _has_part_in_inventories(part_id: String) -> bool:
	if part_id == "":
		return true
	if player_inv and player_inv.has_item(part_id, 1):
		return true
	if stash_inv and stash_inv.has_item(part_id, 1):
		return true
	return false

func _consume_part_from_inventories(part_id: String) -> bool:
	if part_id == "":
		return true
	if player_inv and player_inv.has_item(part_id, 1):
		player_inv.remove_item(part_id, 1)
		return true
	if stash_inv and stash_inv.has_item(part_id, 1):
		stash_inv.remove_item(part_id, 1)
		return true
	return false

func _return_part_to_inventories(part_id: String) -> void:
	if part_id == "":
		return
	var rem = 1
	if player_inv:
		rem = player_inv.auto_add_item(part_id, 1)
	if rem > 0 and stash_inv:
		rem = stash_inv.auto_add_item(part_id, rem)
	if rem > 0 and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("⚠️ 인벤토리 공간이 부족하여 [%s] 회수에 실패했습니다." % part_id)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(920, 580)
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.offset_left = -460
	main_panel.offset_top = -290
	main_panel.offset_right = 460
	main_panel.offset_bottom = 290
	add_child(main_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vbox)

	# 상단 헤더
	var header = HBoxContainer.new()
	root_vbox.add_child(header)

	var title = Label.new()
	title.text = "🔧 무기 개조 작업대 (WEAPON MODDING WORKBENCH)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "닫기 [ESC]"
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# 메인 본문 (좌: 리시버 & 슬롯 8개 / 우: 실시간 스탯 게이지 & 총기 요약)
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 20)
	root_vbox.add_child(body_hbox)

	# --- 좌측: 리시버 & 8개 부품 슬롯 ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_vbox)

	var rec_hbox = HBoxContainer.new()
	left_vbox.add_child(rec_hbox)
	var rec_lbl = Label.new()
	rec_lbl.text = "총기 본체 (Receiver):"
	rec_lbl.custom_minimum_size = Vector2(170, 0)
	rec_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	rec_hbox.add_child(rec_lbl)

	receiver_option_btn = OptionButton.new()
	receiver_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	receiver_option_btn.disabled = true
	receiver_option_btn.item_selected.connect(_on_receiver_selected)
	rec_hbox.add_child(receiver_option_btn)

	left_vbox.add_child(HSeparator.new())

	var slots_scroll = ScrollContainer.new()
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(slots_scroll)

	slots_container = VBoxContainer.new()
	slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_container.add_theme_constant_override("separation", 6)
	slots_scroll.add_child(slots_container)

	# --- 우측: 스탯 비교 및 조립 정보 ---
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(380, 0)
	body_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	weapon_title_lbl = Label.new()
	weapon_title_lbl.text = "조립 총기 명칭"
	weapon_title_lbl.add_theme_font_size_override("font_size", 18)
	weapon_title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	right_vbox.add_child(weapon_title_lbl)

	special_tags_lbl = Label.new()
	special_tags_lbl.text = "특수 효과: 없음"
	special_tags_lbl.add_theme_font_size_override("font_size", 12)
	special_tags_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	special_tags_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(special_tags_lbl)

	right_vbox.add_child(HSeparator.new())

	var stat_defs = [
		{"key": "damage", "label": "피해량 (Damage)", "max": 150.0},
		{"key": "accuracy", "label": "명중률 (Accuracy)", "max": 100.0},
		{"key": "recoil", "label": "반동 (Recoil - 낮을수록 좋음)", "max": 100.0},
		{"key": "ergonomics", "label": "인체공학 (Ergonomics)", "max": 100.0},
		{"key": "range", "label": "유효 사거리 (Range)", "max": 150.0},
		{"key": "rpm", "label": "연사속도 (RPM)", "max": 1000.0},
		{"key": "noise_radius", "label": "발포 소음 반경 (Noise)", "max": 1200.0}
	]

	for sd in stat_defs:
		var svbox = VBoxContainer.new()
		svbox.add_theme_constant_override("separation", 2)
		right_vbox.add_child(svbox)

		var shbox = HBoxContainer.new()
		svbox.add_child(shbox)

		var n_lbl = Label.new()
		n_lbl.text = sd["label"]
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.add_theme_font_size_override("font_size", 12)
		shbox.add_child(n_lbl)

		var v_lbl = Label.new()
		v_lbl.text = "0"
		v_lbl.add_theme_font_size_override("font_size", 12)
		v_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		shbox.add_child(v_lbl)

		var pbar = ProgressBar.new()
		pbar.max_value = sd["max"]
		pbar.custom_minimum_size = Vector2(0, 10)
		pbar.show_percentage = false
		svbox.add_child(pbar)

		stat_bars[sd["key"]] = {"bar": pbar, "lbl": v_lbl}

	# 하단 액션 버튼
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	root_vbox.add_child(footer)

	var disassemble_btn = Button.new()
	disassemble_btn.text = "장착 부품 모두 분리 (Detach All)"
	disassemble_btn.custom_minimum_size = Vector2(210, 40)
	disassemble_btn.pressed.connect(_on_disassemble_pressed)
	footer.add_child(disassemble_btn)

	var shooting_range_btn = Button.new()
	shooting_range_btn.text = "🎯 사격장 테스트 (Shooting Range)"
	shooting_range_btn.custom_minimum_size = Vector2(210, 40)
	shooting_range_btn.pressed.connect(_on_open_shooting_range)
	footer.add_child(shooting_range_btn)

	var apply_btn = Button.new()
	apply_btn.text = "개조 적용 및 장착 (Apply)"
	apply_btn.custom_minimum_size = Vector2(210, 40)
	apply_btn.pressed.connect(_on_assemble_pressed)
	footer.add_child(apply_btn)

func _on_open_shooting_range() -> void:
	if ShootingRangeScript:
		var sr = Control.new()
		sr.set_script(ShootingRangeScript)
		sr.setup(current_weapon)
		sr.window_closed.connect(func():
			sr.queue_free()
		)
		add_child(sr)
		if SoundManager: SoundManager.play("menu_select")

func _populate_receivers() -> void:
	if not receiver_option_btn:
		return
	receiver_option_btn.clear()
	var resolved = WeaponPartsDatabase.resolve_receiver_id(current_receiver_id)
	if WeaponPartsDatabase.RECEIVERS.has(resolved):
		var rdata = WeaponPartsDatabase.RECEIVERS[resolved]
		receiver_option_btn.add_item(rdata["name"], 0)
		receiver_option_btn.set_item_metadata(0, resolved)
		receiver_option_btn.select(0)
	receiver_option_btn.disabled = true

func _on_receiver_selected(idx: int) -> void:
	var rec_id = receiver_option_btn.get_item_metadata(idx)
	if rec_id and rec_id != current_receiver_id:
		current_receiver_id = rec_id
		_refresh_slots_for_receiver()
		_recompute_and_update_ui()
		if SoundManager: SoundManager.play("menu_select")

func _refresh_slots_for_receiver() -> void:
	if not slots_container:
		return
	for c in slots_container.get_children():
		c.queue_free()
	slot_buttons.clear()

	var rec_data = WeaponPartsDatabase.RECEIVERS.get(current_receiver_id, {})
	var slots_dict: Dictionary = rec_data.get("slots", {})
	var cur_parts: Dictionary = current_weapon.get("parts", current_weapon.get("attachments", {}))

	for slot_name in SLOT_ORDER:
		if slot_name == "rail":
			var rail_count = int(slots_dict.get("rail", 1))
			if not slots_dict.has("rail"):
				var row = HBoxContainer.new()
				slots_container.add_child(row)
				var slbl = Label.new()
				slbl.text = SLOT_NAMES_KR.get("rail", "rail")
				slbl.custom_minimum_size = Vector2(170, 0)
				row.add_child(slbl)

				var opt = OptionButton.new()
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				opt.add_item("장착 불가 (슬롯 없음)", 0)
				opt.set_item_metadata(0, "")
				opt.disabled = true
				row.add_child(opt)
				slot_buttons["rail"] = opt
			else:
				var raw_rails = cur_parts.get("rail", [])
				var cur_rails: Array = raw_rails if (raw_rails is Array) else ([str(raw_rails)] if str(raw_rails) != "" else [])

				for r_i in range(rail_count):
					var row = HBoxContainer.new()
					slots_container.add_child(row)
					var slbl = Label.new()
					slbl.text = ("전술 레일 %d (Rail %d)" % [r_i + 1, r_i + 1]) if rail_count > 1 else SLOT_NAMES_KR.get("rail", "rail")
					slbl.custom_minimum_size = Vector2(170, 0)
					row.add_child(slbl)

					var opt = OptionButton.new()
					opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					opt.add_item("--- 미장착 (기본) ---", 0)
					opt.set_item_metadata(0, "")

					var available_parts = _get_available_parts_for_slot("rail")
					var item_idx = 1
					var selected_idx = 0
					var cur_r_id = cur_rails[r_i] if r_i < cur_rails.size() else ""

					for p_id in available_parts:
						var p_data = WeaponPartsDatabase.PARTS[p_id]
						var orig_rails = original_attached_parts.get("rail", [])
						var is_attached = (p_id in orig_rails) if (orig_rails is Array) else (p_id == str(orig_rails))
						var suffix = " [장착중]" if is_attached else " [보유중]"
						opt.add_item(p_data.get("name", p_id) + suffix, item_idx)
						opt.set_item_metadata(item_idx, p_id)
						if p_id == cur_r_id:
							selected_idx = item_idx
						item_idx += 1

					opt.select(selected_idx)
					var capture_ri = r_i
					opt.item_selected.connect(func(idx): _on_rail_selected(capture_ri, idx))
					row.add_child(opt)
					slot_buttons["rail_%d" % r_i] = opt
					if r_i == 0:
						slot_buttons["rail"] = opt
		else:
			var row = HBoxContainer.new()
			slots_container.add_child(row)

			var slbl = Label.new()
			slbl.text = SLOT_NAMES_KR.get(slot_name, slot_name)
			slbl.custom_minimum_size = Vector2(170, 0)
			row.add_child(slbl)

			var opt = OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			if not slots_dict.has(slot_name):
				opt.add_item("장착 불가 (슬롯 없음)", 0)
				opt.set_item_metadata(0, "")
				opt.disabled = true
			else:
				opt.disabled = false
				opt.add_item("--- 미장착 (기본) ---", 0)
				opt.set_item_metadata(0, "")

				var available_parts = _get_available_parts_for_slot(slot_name)
				var item_idx = 1
				var selected_idx = 0
				var equipped_part_val = cur_parts.get(slot_name, "")
				var equipped_part_id = equipped_part_val[0] if (equipped_part_val is Array and not equipped_part_val.is_empty()) else String(equipped_part_val)

				for p_id in available_parts:
					var p_data = WeaponPartsDatabase.PARTS[p_id]
					var orig_val = original_attached_parts.get(slot_name, "")
					var is_attached = (p_id in orig_val) if (orig_val is Array) else (p_id == String(orig_val))
					var suffix = " [장착중]" if is_attached else " [보유중]"
					opt.add_item(p_data.get("name", p_id) + suffix, item_idx)
					opt.set_item_metadata(item_idx, p_id)
					if p_id == equipped_part_id:
						selected_idx = item_idx
					item_idx += 1

				opt.select(selected_idx)
				var s_capture = slot_name
				opt.item_selected.connect(func(idx): _on_part_selected(s_capture, idx))

			row.add_child(opt)
			slot_buttons[slot_name] = opt

func _get_available_parts_for_slot(slot_name: String) -> Array:
	var list = []
	var rec_data = WeaponPartsDatabase.RECEIVERS.get(current_receiver_id, {})
	var rec_cat = String(rec_data.get("category", "")).to_lower()
	var orig_val = original_attached_parts.get(slot_name, "")
	var attached_id = orig_val[0] if (orig_val is Array and not orig_val.is_empty()) else String(orig_val)
	var cur_val = current_weapon.get("parts", {}).get(slot_name, "")
	var selected_id = cur_val[0] if (cur_val is Array and not cur_val.is_empty()) else String(cur_val)
	for part_id in WeaponPartsDatabase.PARTS.keys():
		var p = WeaponPartsDatabase.PARTS[part_id]
		if p.get("slot", "") != slot_name:
			continue
		var compat_cats: Array = p.get("compatible_categories", [])
		var is_compat = false
		if compat_cats.is_empty() or "all" in compat_cats or "ALL" in compat_cats:
			is_compat = true
		elif rec_cat != "" and (rec_cat in compat_cats or rec_cat.to_lower() in compat_cats):
			is_compat = true
		elif current_receiver_id in p.get("compatible", []) or "ALL" in p.get("compatible", []):
			is_compat = true

		if not is_compat:
			continue

		var is_attached = (part_id in orig_val) if (orig_val is Array) else (part_id == attached_id)
		var is_selected = (part_id in cur_val) if (cur_val is Array) else (part_id == selected_id)
		if is_attached or is_selected or _has_part_in_inventories(part_id):
			list.append(part_id)
	return list

func _on_rail_selected(r_idx: int, idx: int) -> void:
	var opt_key = "rail_%d" % r_idx
	if not slot_buttons.has(opt_key): return
	var opt: OptionButton = slot_buttons[opt_key]
	var part_id = opt.get_item_metadata(idx)
	if not current_weapon.has("parts"):
		current_weapon["parts"] = {}
	var raw_w_rails = current_weapon["parts"].get("rail", [])
	var cur_rails: Array = raw_w_rails if (raw_w_rails is Array) else ([str(raw_w_rails)] if str(raw_w_rails) != "" else [])

	while cur_rails.size() <= r_idx:
		cur_rails.append("")

	cur_rails[r_idx] = part_id if (part_id != null and part_id != "") else ""

	var compact_rails: Array = []
	for p in cur_rails:
		if p != null and String(p) != "":
			compact_rails.append(String(p))

	if compact_rails.is_empty():
		current_weapon["parts"].erase("rail")
	else:
		current_weapon["parts"]["rail"] = compact_rails
	current_weapon["attachments"] = current_weapon["parts"]

	_recompute_and_update_ui()
	if SoundManager: SoundManager.play("menu_select")

func _on_part_selected(slot_name: String, idx: int) -> void:
	if not slot_buttons.has(slot_name): return
	var opt: OptionButton = slot_buttons[slot_name]
	var part_id = opt.get_item_metadata(idx)
	if not current_weapon.has("parts"):
		current_weapon["parts"] = {}
	if part_id == "" or part_id == null:
		current_weapon["parts"].erase(slot_name)
	else:
		current_weapon["parts"][slot_name] = part_id
	current_weapon["attachments"] = current_weapon["parts"]

	_recompute_and_update_ui()
	if SoundManager: SoundManager.play("menu_select")

func _recompute_and_update_ui() -> void:
	current_weapon["id"] = current_receiver_id
	if not current_weapon.has("parts"):
		current_weapon["parts"] = current_weapon.get("attachments", {}).duplicate(true)
	current_weapon["attachments"] = current_weapon["parts"]
	current_weapon = WeaponPartsDatabase.compute_weapon_from_dict(current_weapon)
	var stats = current_weapon.get("computed_stats", {})

	if weapon_title_lbl:
		weapon_title_lbl.text = "🔫 %s (총 무게: %.1fkg)" % [current_weapon.get("name", ""), stats.get("weight", 1.0)]

	var tags = []
	if stats.get("suppressed", false): tags.append("🔇 소음기 적용")
	if stats.get("zoom", 1.0) > 1.05: tags.append("🔭 조준 배율 x%.1f" % stats.get("zoom", 1.0))
	if stats.get("laser_sight", false): tags.append("🔴 레이저 조준기")
	if stats.get("tac_flashlight", false): tags.append("🔦 전술 라이트")
	tags.append("탄창 용량: %d발" % stats.get("magazine_size", 15))
	tags.append("관통 등급: Lv.%d" % stats.get("penetration", 1))

	if special_tags_lbl:
		special_tags_lbl.text = " | ".join(tags)

	for key in stat_bars.keys():
		var val = stats.get(key, 0)
		stat_bars[key]["bar"].value = val
		stat_bars[key]["lbl"].text = str(snapped(val, 0.1))

func _sync_to_equipped_player_weapon() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return
	if "equipment" in player_node and player_node.equipment is Dictionary:
		for s_key in ["primary1", "primary2", "sidearm"]:
			var eq = player_node.equipment.get(s_key, {})
			if not eq.is_empty():
				var eq_id = WeaponPartsDatabase.resolve_receiver_id(String(eq.get("id", "")))
				if eq_id == current_receiver_id:
					player_node.equipment[s_key]["parts"] = current_weapon.get("parts", {}).duplicate(true)
					player_node.equipment[s_key]["attachments"] = player_node.equipment[s_key]["parts"]
					player_node.equipment[s_key]["name"] = current_weapon.get("name", "")
					player_node.equipment[s_key]["computed_stats"] = current_weapon.get("computed_stats", {}).duplicate(true)
					player_node.equipment[s_key]["current_magazine_ammo"] = current_weapon.get("current_magazine_ammo", 0)
		if player_node.has_method("refresh_equipped_weapon"):
			player_node.refresh_equipped_weapon(false)
		elif player_node.has_method("switch_weapon_slot") and "active_weapon_slot" in player_node:
			player_node.switch_weapon_slot(player_node.active_weapon_slot)

func _on_assemble_pressed() -> void:
	var new_parts: Dictionary = current_weapon.get("parts", {}).duplicate(true)
	# 변경된 슬롯에 대해 인벤토리에서 새 부품 소모 및 기존 부품 회수 검증
	for slot_name in SLOT_ORDER:
		var old_val = original_attached_parts.get(slot_name, "")
		var old_list: Array = old_val if (old_val is Array) else ([String(old_val)] if String(old_val) != "" else [])
		var new_val = new_parts.get(slot_name, "")
		var new_list: Array = new_val if (new_val is Array) else ([String(new_val)] if String(new_val) != "" else [])

		var revert = false
		for np in new_list:
			if not (np in old_list):
				if not _consume_part_from_inventories(np):
					revert = true
					break
		if revert:
			if old_list.is_empty():
				new_parts.erase(slot_name)
			else:
				new_parts[slot_name] = old_val
			continue

		for op in old_list:
			if not (op in new_list):
				_return_part_to_inventories(op)

	current_weapon["parts"] = new_parts
	current_weapon["attachments"] = current_weapon["parts"]
	original_attached_parts = new_parts.duplicate(true)
	_recompute_and_update_ui()

	# 탄창 용량 변경 시 무료 탄약 충전 방지 (기존 장전 탄약만 유지하며 초과분은 가방으로 반환)
	var stats = current_weapon.get("computed_stats", {})
	var max_mag = int(stats.get("magazine_size", 15))
	var cur_ammo = int(current_weapon.get("current_magazine_ammo", original_magazine_ammo))
	if cur_ammo > max_mag:
		var excess = cur_ammo - max_mag
		var cal_list: Array = stats.get("ammo_types", ["9mm"])
		var cal_id = String(cal_list[0]) if cal_list.size() > 0 else "9mm"
		if player_inv:
			player_inv.auto_add_item(cal_id, excess)
		cur_ammo = max_mag
	current_weapon["current_magazine_ammo"] = clampi(cur_ammo, 0, max_mag)
	original_magazine_ammo = int(current_weapon["current_magazine_ammo"])

	_sync_to_equipped_player_weapon()
	_refresh_slots_for_receiver()
	if SoundManager: SoundManager.play("craft_success")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔧 [%s] 개조 적용 완료! (장전 탄약: %d/%d)" % [current_weapon.get("name", ""), current_weapon["current_magazine_ammo"], max_mag])

func _on_disassemble_pressed() -> void:
	if original_attached_parts.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 현재 총기에 분리할 수 있는 장착 부품이 없습니다.")
		return

	var detached_count = 0
	for slot_name in original_attached_parts.keys():
		var p_val = original_attached_parts[slot_name]
		if p_val is Array:
			for sub_p in p_val:
				if String(sub_p) != "":
					_return_part_to_inventories(String(sub_p))
					detached_count += 1
		elif p_val != null and String(p_val) != "":
			_return_part_to_inventories(String(p_val))
			detached_count += 1

	original_attached_parts.clear()
	current_weapon["parts"] = {}
	current_weapon["attachments"] = current_weapon["parts"]
	_recompute_and_update_ui()

	var stats = current_weapon.get("computed_stats", {})
	var max_mag = int(stats.get("magazine_size", 15))
	var cur_ammo = int(current_weapon.get("current_magazine_ammo", original_magazine_ammo))
	if cur_ammo > max_mag:
		var excess = cur_ammo - max_mag
		var cal_list: Array = stats.get("ammo_types", ["9mm"])
		var cal_id = String(cal_list[0]) if cal_list.size() > 0 else "9mm"
		if player_inv:
			player_inv.auto_add_item(cal_id, excess)
		cur_ammo = max_mag
	current_weapon["current_magazine_ammo"] = clampi(cur_ammo, 0, max_mag)
	original_magazine_ammo = int(current_weapon["current_magazine_ammo"])

	_sync_to_equipped_player_weapon()
	_refresh_slots_for_receiver()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔩 장착된 부품 %d개를 모두 분리하여 인벤토리로 회수했습니다." % detached_count)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	window_closed.emit()
	queue_free()
