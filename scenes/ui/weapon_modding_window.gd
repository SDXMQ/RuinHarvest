# res://scenes/ui/weapon_modding_window.gd
extends Control

## 타르코프 & 배그 하이브리드 총기 모딩 UI 윈도우

signal window_closed

var player_inv: Inventory
var stash_inv: Inventory
var current_weapon: Dictionary = {} # 모딩 중인 무기 데이터

# UI 노드
var receiver_option_btn: OptionButton
var slots_container: VBoxContainer
var stats_container: VBoxContainer
var name_label: Label
var assemble_btn: Button
var disassemble_btn: Button
var close_btn: Button

func setup(p_inv: Inventory, s_inv: Inventory = null, initial_weapon: Dictionary = {}) -> void:
	player_inv = p_inv
	stash_inv = s_inv
	
	if initial_weapon.is_empty():
		current_weapon = WeaponPartsDatabase.create_default_weapon("M9_리시버")
	else:
		current_weapon = initial_weapon.duplicate(true)
		
	_build_ui()
	_refresh_all()

func _build_ui() -> void:
	# 전체 반투명 배경
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.custom_minimum_size = Vector2(760, 520)
	main_panel.position = -Vector2(380, 260)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 0.8, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(vbox)
	
	# 1. 헤더 (타이틀 + 닫기)
	var header = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "🔧 총기 커스텀 모딩 워크벤치 (Weapon Modding)"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	# 2. 본문 (좌측: 슬롯 모딩 / 우측: 실시간 스탯 비교)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	vbox.add_child(body)
	
	# 좌측: 리시버 및 슬롯 관리
	var left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 10)
	body.add_child(left_box)
	
	var r_box = HBoxContainer.new()
	var r_lbl = Label.new()
	r_lbl.text = "기본 프레임(리시버):"
	r_box.add_child(r_lbl)
	
	receiver_option_btn = OptionButton.new()
	receiver_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r_keys = WeaponPartsDatabase.RECEIVERS.keys()
	for k in r_keys:
		var r_data = WeaponPartsDatabase.RECEIVERS[k]
		receiver_option_btn.add_item(r_data["name"])
	receiver_option_btn.item_selected.connect(_on_receiver_selected)
	r_box.add_child(receiver_option_btn)
	left_box.add_child(r_box)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_container = VBoxContainer.new()
	slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_container.add_theme_constant_override("separation", 8)
	scroll.add_child(slots_container)
	left_box.add_child(scroll)
	
	# 우측: 스탯 패널
	var right_box = VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(280, 0)
	right_box.add_theme_constant_override("separation", 10)
	body.add_child(right_box)
	
	var stats_title = Label.new()
	stats_title.text = "📊 무기 종합 성능 (Stats)"
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	right_box.add_child(stats_title)
	
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 6)
	right_box.add_child(stats_container)
	
	# 3. 하단 버튼 바 (조립 완료, 분해)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	
	assemble_btn = Button.new()
	assemble_btn.text = "💾 무기 조립 및 장착"
	assemble_btn.custom_minimum_size = Vector2(160, 36)
	assemble_btn.pressed.connect(_on_assemble_pressed)
	footer.add_child(assemble_btn)
	
	disassemble_btn = Button.new()
	disassemble_btn.text = "📦 전체 부품 분해"
	disassemble_btn.custom_minimum_size = Vector2(140, 36)
	disassemble_btn.pressed.connect(_on_disassemble_pressed)
	footer.add_child(disassemble_btn)
	
	vbox.add_child(footer)

func _refresh_all() -> void:
	var rec_id = current_weapon.get("receiver", "M9_리시버")
	var r_keys = WeaponPartsDatabase.RECEIVERS.keys()
	var idx = r_keys.find(rec_id)
	if idx != -1:
		receiver_option_btn.selected = idx
		
	_refresh_slots()
	_refresh_stats()

func _refresh_slots() -> void:
	for c in slots_container.get_children():
		c.queue_free()
		
	var rec_id = current_weapon.get("receiver", "M9_리시버")
	var receiver = WeaponPartsDatabase.RECEIVERS.get(rec_id, WeaponPartsDatabase.RECEIVERS["M9_리시버"])
	var parts = current_weapon.get("parts", {})
	
	var slot_display_names = {
		"barrel": "총열 (Barrel)",
		"muzzle": "총구 (Muzzle)",
		"optic": "조준경 (Optic)",
		"magazine": "탄창 (Magazine)",
		"stock": "개머리판 (Stock)",
		"grip": "손잡이 (Grip)",
		"rail": "레일 부착물 (Rail)"
	}
	
	for slot_name in receiver.get("slots", {}).keys():
		var slot_row = HBoxContainer.new()
		var slot_lbl = Label.new()
		slot_lbl.text = slot_display_names.get(slot_name, slot_name) + ":"
		slot_lbl.custom_minimum_size = Vector2(120, 0)
		slot_row.add_child(slot_lbl)
		
		var cur_val = parts.get(slot_name, "")
		
		if slot_name == "rail":
			# 다중 레일 부착물
			var rail_vbox = VBoxContainer.new()
			rail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var max_rails = receiver["slots"]["rail"]
			var cur_rails: Array = cur_val if cur_val is Array else []
			
			for r_idx in range(max_rails):
				var r_opt = OptionButton.new()
				r_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r_opt.add_item("(미장착)")
				
				var cur_p = cur_rails[r_idx] if r_idx < cur_rails.size() else ""
				var opt_idx = 0
				var rail_parts = _get_available_parts_for_slot("rail", receiver["category"])
				
				for p_key in rail_parts:
					var p_data = WeaponPartsDatabase.PARTS[p_key]
					r_opt.add_item("%s [%s]" % [p_data["name"], p_data.get("tier", "")])
					if p_key == cur_p:
						opt_idx = r_opt.item_count - 1
						
				r_opt.selected = opt_idx
				var rail_index_capture = r_idx
				r_opt.item_selected.connect(func(sel): _on_rail_selected(rail_index_capture, sel, rail_parts))
				rail_vbox.add_child(r_opt)
			slot_row.add_child(rail_vbox)
		else:
			# 단일 슬롯
			var opt = OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt.add_item("(미장착)")
			
			var avail_parts = _get_available_parts_for_slot(slot_name, receiver["category"])
			var sel_idx = 0
			
			for p_key in avail_parts:
				var p_data = WeaponPartsDatabase.PARTS[p_key]
				opt.add_item("%s [%s]" % [p_data["name"], p_data.get("tier", "")])
				if p_key == cur_val:
					sel_idx = opt.item_count - 1
					
			opt.selected = sel_idx
			opt.item_selected.connect(func(sel): _on_part_selected(slot_name, sel, avail_parts))
			slot_row.add_child(opt)
			
		slots_container.add_child(slot_row)

func _get_available_parts_for_slot(slot_name: String, cat: String) -> Array:
	var list = []
	for p_key in WeaponPartsDatabase.PARTS.keys():
		var p_data = WeaponPartsDatabase.PARTS[p_key]
		if p_data.get("slot") == slot_name:
			var comps = p_data.get("compatible_categories", ["all"])
			if "all" in comps or cat in comps:
				list.append(p_key)
	return list

func _refresh_stats() -> void:
	for c in stats_container.get_children():
		c.queue_free()
		
	var rec_id = current_weapon.get("receiver", "M9_리시버")
	var parts = current_weapon.get("parts", {})
	var ammo = current_weapon.get("loaded_ammo", "9mm")
	var stats = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, ammo)
	current_weapon["computed_stats"] = stats
	
	_add_stat_row("💥 데미지", "%.1f" % stats["damage"], Color(1.0, 0.4, 0.4))
	_add_stat_row("🎯 정확도", "%d%%" % int(stats["accuracy"]), Color(0.4, 1.0, 0.4))
	_add_stat_row("⚡ 연사력 (RPM)", "%d" % stats["rpm"], Color(1.0, 0.8, 0.3))
	_add_stat_row("🔄 반동", "%.1f" % stats["recoil"], Color(1.0, 0.6, 0.2))
	_add_stat_row("🔭 유효 사거리", "%.1f m" % stats["range"], Color(0.4, 0.8, 1.0))
	_add_stat_row("🔍 조준경 줌", "%.1f x" % stats["zoom"], Color(0.8, 0.5, 1.0))
	_add_stat_row("📦 탄창 용량", "%d 발" % stats["magazine_size"], Color(0.9, 0.9, 0.9))
	_add_stat_row("🔊 사격 소음 반경", "%d px" % int(stats["noise_radius"]), Color(0.8, 0.8, 0.8))
	_add_stat_row("⚖️ 총기 무게", "%.2f kg" % stats["weight"], Color(0.7, 0.7, 0.7))

func _add_stat_row(lbl_text: String, val_text: String, col: Color) -> void:
	var row = HBoxContainer.new()
	var l = Label.new()
	l.text = lbl_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	
	var v = Label.new()
	v.text = val_text
	v.add_theme_color_override("font_color", col)
	row.add_child(v)
	stats_container.add_child(row)

func _on_receiver_selected(index: int) -> void:
	var r_keys = WeaponPartsDatabase.RECEIVERS.keys()
	if index < 0 or index >= r_keys.size(): return
	var rec_id = r_keys[index]
	current_weapon = WeaponPartsDatabase.create_default_weapon(rec_id)
	_refresh_all()

func _on_part_selected(slot_name: String, sel_index: int, avail_parts: Array) -> void:
	if not current_weapon.has("parts"):
		current_weapon["parts"] = {}
		
	if sel_index == 0:
		current_weapon["parts"].erase(slot_name)
	else:
		var p_key = avail_parts[sel_index - 1]
		current_weapon["parts"][slot_name] = p_key
		
	_refresh_stats()

func _on_rail_selected(rail_idx: int, sel_index: int, rail_parts: Array) -> void:
	if not current_weapon.has("parts"): current_weapon["parts"] = {}
	if not current_weapon["parts"].has("rail") or not (current_weapon["parts"]["rail"] is Array):
		current_weapon["parts"]["rail"] = []
		
	var arr: Array = current_weapon["parts"]["rail"]
	while arr.size() <= rail_idx:
		arr.append("")
		
	if sel_index == 0:
		arr[rail_idx] = ""
	else:
		arr[rail_idx] = rail_parts[sel_index - 1]
		
	# 빈 문자열 정리
	var cleaned = []
	for p in arr:
		if p != "": cleaned.append(p)
	current_weapon["parts"]["rail"] = cleaned
	_refresh_stats()

func _on_assemble_pressed() -> void:
	var rec_id = current_weapon.get("receiver", "M9_리시버")
	var stats = current_weapon.get("computed_stats", {})
	current_weapon["name"] = WeaponPartsDatabase.RECEIVERS[rec_id]["name"] + " (모딩)"
	current_weapon["current_magazine_ammo"] = stats.get("magazine_size", 15)
	
	var cur_scene = get_tree().current_scene
	if cur_scene and "player" in cur_scene and cur_scene.player:
		cur_scene.player.equipped_weapon_data = current_weapon.duplicate(true)
		cur_scene.player.equipped_weapon = rec_id
		cur_scene.player.stats_changed.emit()
		
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔫 [%s] 조립 및 장착 완료!" % current_weapon["name"])
	if SoundManager: SoundManager.play("menu_select")
	_on_close_pressed()

func _on_disassemble_pressed() -> void:
	var parts = current_weapon.get("parts", {})
	var rec_id = current_weapon.get("receiver", "M9_리시버")
	
	if player_inv:
		# 리시버 지급
		player_inv.add_item(rec_id, 1)
		# 부품 지급
		for s in parts.keys():
			var v = parts[s]
			if v is Array:
				for p in v:
					if p != "": player_inv.add_item(p, 1)
			elif v is String and v != "":
				player_inv.add_item(v, 1)
				
	current_weapon = WeaponPartsDatabase.create_default_weapon(rec_id)
	_refresh_all()
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📦 무기가 모든 개별 부품으로 분해되었습니다.")
	if SoundManager: SoundManager.play("menu_select")

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
