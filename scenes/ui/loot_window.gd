# res://scenes/ui/loot_window.gd
extends Control

## 인벤토리, 루팅, 총기 모딩 통합 윈도우

signal window_closed

var player_inv: Inventory = null
var loot_inv: Inventory = null

@onready var loot_panel: Panel = $Center/HBox/LootPanel
@onready var player_panel: Panel = $Center/HBox/PlayerPanel
@onready var weapon_mod_panel: Panel = $Center/HBox/WeaponModPanel

@onready var loot_title: Label = $Center/HBox/LootPanel/Title
@onready var loot_grid: GridContainer = $Center/HBox/LootPanel/Grid

@onready var player_grid: GridContainer = $Center/HBox/PlayerPanel/Grid

# 총기 모딩 UI 노드
@onready var receiver_opt: OptionButton = $Center/HBox/WeaponModPanel/VBox/ReceiverHBox/ReceiverOpt
@onready var slots_container: VBoxContainer = $Center/HBox/WeaponModPanel/VBox/Scroll/SlotsContainer
@onready var stats_grid: GridContainer = $Center/HBox/WeaponModPanel/VBox/StatsPanel/StatsGrid
@onready var apply_btn: Button = $Center/HBox/WeaponModPanel/VBox/ButtonsHBox/ApplyBtn
@onready var disassemble_btn: Button = $Center/HBox/WeaponModPanel/VBox/ButtonsHBox/DisassembleBtn

var tooltip: PanelContainer = null
var item_use_cooldown: float = 0.0
const ITEM_USE_COOLDOWN_TIME: float = 1.5

# 모딩 중인 무기 데이터
var current_modding_weapon: Dictionary = {}

func _ready() -> void:
	var tooltip_scene = preload("res://scenes/ui/item_tooltip.tscn")
	tooltip = tooltip_scene.instantiate()
	add_child(tooltip)
	tooltip.hide()
	
	_setup_modding_receivers()
	receiver_opt.item_selected.connect(_on_receiver_selected)
	apply_btn.pressed.connect(_on_apply_weapon_modding)
	disassemble_btn.pressed.connect(_on_disassemble_modding)

func _process(delta: float) -> void:
	if item_use_cooldown > 0:
		item_use_cooldown -= delta

func setup(p_inv: Inventory, l_inv: Inventory = null, title: String = "루팅 상자") -> void:
	player_inv = p_inv
	loot_inv = l_inv
	
	if loot_title:
		loot_title.text = title
		
	if loot_inv == null:
		loot_panel.visible = false
	else:
		loot_panel.visible = true
		
	# 플레이어의 현재 장착 무기 데이터 로드
	_load_player_weapon_for_modding()
	_refresh_ui()

func _load_player_weapon_for_modding() -> void:
	var player = _get_player()
	if player and player.equipped_weapon_data and not player.equipped_weapon_data.is_empty():
		current_modding_weapon = player.equipped_weapon_data.duplicate(true)
	elif player and player.equipped_weapon != "":
		current_modding_weapon = WeaponPartsDatabase.create_default_weapon(player.equipped_weapon)
	else:
		current_modding_weapon = WeaponPartsDatabase.create_default_weapon("M9_리시버")
		
	_sync_receiver_ui()
	_refresh_modding_slots()
	_refresh_modding_stats()

func _setup_modding_receivers() -> void:
	receiver_opt.clear()
	for r_id in WeaponPartsDatabase.RECEIVERS.keys():
		var r_data = WeaponPartsDatabase.RECEIVERS[r_id]
		var caliber_name = r_data.get("default_ammo", "9mm")
		receiver_opt.add_item("%s (%s)" % [r_data["name"], caliber_name])

func _sync_receiver_ui() -> void:
	var rec_id = current_modding_weapon.get("receiver", "M9_리시버")
	var r_keys = WeaponPartsDatabase.RECEIVERS.keys()
	var idx = r_keys.find(rec_id)
	if idx != -1:
		receiver_opt.selected = idx

func _on_receiver_selected(index: int) -> void:
	var r_keys = WeaponPartsDatabase.RECEIVERS.keys()
	if index < 0 or index >= r_keys.size(): return
	var rec_id = r_keys[index]
	current_modding_weapon = WeaponPartsDatabase.create_default_weapon(rec_id)
	_refresh_modding_slots()
	_refresh_modding_stats()

func _refresh_modding_slots() -> void:
	for c in slots_container.get_children():
		c.queue_free()
		
	var rec_id = current_modding_weapon.get("receiver", "M9_리시버")
	var receiver = WeaponPartsDatabase.RECEIVERS.get(rec_id, WeaponPartsDatabase.RECEIVERS["M9_리시버"])
	var parts = current_modding_weapon.get("parts", {})
	
	var slot_display_names = {
		"barrel": "총열 (Barrel)",
		"muzzle": "총구 (Muzzle)",
		"optic": "조준경 (Optic)",
		"magazine": "탄창 (Mag)",
		"stock": "개머리판 (Stock)",
		"grip": "손잡이 (Grip)",
		"rail": "전술 레일 (Rail)"
	}
	
	for slot_name in receiver.get("slots", {}).keys():
		var slot_row = HBoxContainer.new()
		var slot_lbl = Label.new()
		slot_lbl.text = slot_display_names.get(slot_name, slot_name) + ":"
		slot_lbl.custom_minimum_size = Vector2(90, 0)
		slot_lbl.add_theme_font_size_override("font_size", 13)
		slot_row.add_child(slot_lbl)
		
		var cur_val = parts.get(slot_name, "")
		
		if slot_name == "rail":
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

func _on_part_selected(slot_name: String, sel_index: int, avail_parts: Array) -> void:
	if not current_modding_weapon.has("parts"):
		current_modding_weapon["parts"] = {}
		
	if sel_index == 0:
		current_modding_weapon["parts"].erase(slot_name)
	else:
		var p_key = avail_parts[sel_index - 1]
		current_modding_weapon["parts"][slot_name] = p_key
		
	_refresh_modding_stats()

func _on_rail_selected(rail_idx: int, sel_index: int, rail_parts: Array) -> void:
	if not current_modding_weapon.has("parts"): current_modding_weapon["parts"] = {}
	if not current_modding_weapon["parts"].has("rail") or not (current_modding_weapon["parts"]["rail"] is Array):
		current_modding_weapon["parts"]["rail"] = []
		
	var arr: Array = current_modding_weapon["parts"]["rail"]
	while arr.size() <= rail_idx:
		arr.append("")
		
	if sel_index == 0:
		arr[rail_idx] = ""
	else:
		arr[rail_idx] = rail_parts[sel_index - 1]
		
	var cleaned = []
	for p in arr:
		if p != "": cleaned.append(p)
	current_modding_weapon["parts"]["rail"] = cleaned
	_refresh_modding_stats()

func _refresh_modding_stats() -> void:
	for c in stats_grid.get_children():
		c.queue_free()
		
	var rec_id = current_modding_weapon.get("receiver", "M9_리시버")
	var parts = current_modding_weapon.get("parts", {})
	var ammo = current_modding_weapon.get("loaded_ammo", "9mm")
	var stats = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, ammo)
	current_modding_weapon["computed_stats"] = stats
	
	_add_stat_cell("데미지", "%.1f" % stats["damage"], Color(1.0, 0.4, 0.4))
	_add_stat_cell("명중률", "%d%%" % int(stats["accuracy"]), Color(0.4, 1.0, 0.4))
	_add_stat_cell("RPM", "%d" % stats["rpm"], Color(1.0, 0.8, 0.3))
	_add_stat_cell("반동", "%.1f" % stats["recoil"], Color(1.0, 0.6, 0.2))
	_add_stat_cell("사거리", "%.1f m" % stats["range"], Color(0.4, 0.8, 1.0))
	_add_stat_cell("배율", "%.1f x" % stats["zoom"], Color(0.8, 0.5, 1.0))
	_add_stat_cell("탄창", "%d 발" % stats["magazine_size"], Color(0.9, 0.9, 0.9))
	_add_stat_cell("소음반경", "%d px" % int(stats["noise_radius"]), Color(0.8, 0.8, 0.8))

func _add_stat_cell(stat_name: String, stat_val: String, col: Color) -> void:
	var l = Label.new()
	l.text = "%s: %s" % [stat_name, stat_val]
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	stats_grid.add_child(l)

func _on_apply_weapon_modding() -> void:
	var rec_id = current_modding_weapon.get("receiver", "M9_리시버")
	var stats = current_modding_weapon.get("computed_stats", {})
	current_modding_weapon["name"] = WeaponPartsDatabase.RECEIVERS[rec_id]["name"] + " (모딩)"
	current_modding_weapon["current_magazine_ammo"] = stats.get("magazine_size", 15)
	
	var player = _get_player()
	if player:
		player.equipped_weapon_data = current_modding_weapon.duplicate(true)
		player.equipped_weapon = rec_id
		player.stats_changed.emit()
		
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔫 [%s] 조립 및 장착 완료!" % current_modding_weapon["name"])
	if SoundManager: SoundManager.play("menu_select")

func _on_disassemble_modding() -> void:
	var parts = current_modding_weapon.get("parts", {})
	var rec_id = current_modding_weapon.get("receiver", "M9_리시버")
	
	if player_inv:
		player_inv.add_item(rec_id, 1)
		for s in parts.keys():
			var v = parts[s]
			if v is Array:
				for p in v:
					if p != "": player_inv.add_item(p, 1)
			elif v is String and v != "":
				player_inv.add_item(v, 1)
				
	current_modding_weapon = WeaponPartsDatabase.create_default_weapon(rec_id)
	_refresh_modding_slots()
	_refresh_modding_stats()
	_refresh_ui()
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📦 무기 부품이 배낭으로 모두 분해되었습니다.")
	if SoundManager: SoundManager.play("menu_select")

func _get_player() -> Node:
	var cur_scene = get_tree().current_scene
	if cur_scene and "player" in cur_scene and cur_scene.player:
		return cur_scene.player
	elif get_node_or_null("/root/MainWorld") and get_node("/root/MainWorld").player:
		return get_node("/root/MainWorld").player
	return get_tree().get_first_node_in_group("player")

# ============================================================
# 인벤토리 / 루팅 그리드 UI 렌더링
# ============================================================
func _refresh_ui() -> void:
	if player_inv:
		_populate_grid(player_grid, player_inv, true)
	if loot_inv:
		_populate_grid(loot_grid, loot_inv, false)

func _populate_grid(grid: GridContainer, inv: Inventory, is_player: bool) -> void:
	for c in grid.get_children():
		c.queue_free()
		
	for i in range(inv.max_slots):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(52, 52)
		slot_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var item = inv.items[i]
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			var icon_tex = ItemIconManager.get_icon(item["id"]) if ItemIconManager else null
			
			if icon_tex:
				slot_btn.icon = icon_tex
				slot_btn.expand_icon = true
				slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				slot_btn.text = data.get("name", item["id"]).left(3)
			
			slot_btn.mouse_entered.connect(func():
				if tooltip and item:
					tooltip.display_item(item, data)
					tooltip.update_position(get_global_mouse_position())
			)
			slot_btn.mouse_exited.connect(func():
				if tooltip: tooltip.hide()
			)
			
			if item["amount"] > 1:
				var amt_lbl = Label.new()
				amt_lbl.text = "x%d" % item["amount"]
				amt_lbl.add_theme_font_size_override("font_size", 11)
				amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
				amt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
				amt_lbl.add_theme_constant_override("shadow_offset_x", 1)
				amt_lbl.add_theme_constant_override("shadow_offset_y", 1)
				amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				amt_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
				amt_lbl.offset_right = -4
				amt_lbl.offset_bottom = -2
				slot_btn.add_child(amt_lbl)
				
			var max_dur = data.get("max_durability", 0)
			if max_dur > 0:
				var cur_dur = item.get("durability", max_dur)
				var dur_mini_bar = ProgressBar.new()
				dur_mini_bar.show_percentage = false
				dur_mini_bar.custom_minimum_size = Vector2(44, 4)
				dur_mini_bar.max_value = max_dur
				dur_mini_bar.value = cur_dur
				dur_mini_bar.position = Vector2(4, 44)
				dur_mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				var fill_style = StyleBoxFlat.new()
				var ratio = float(cur_dur) / float(max_dur)
				if ratio > 0.6: fill_style.bg_color = Color(0.2, 0.8, 0.3)
				elif ratio > 0.3: fill_style.bg_color = Color(0.9, 0.7, 0.1)
				else: fill_style.bg_color = Color(0.9, 0.2, 0.2)
				dur_mini_bar.add_theme_stylebox_override("fill", fill_style)
				
				var bg_style = StyleBoxFlat.new()
				bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
				dur_mini_bar.add_theme_stylebox_override("background", bg_style)
				slot_btn.add_child(dur_mini_bar)
		else:
			slot_btn.text = ""
			
		# 드래그 앤 드롭
		slot_btn.set_drag_forwarding(
			func(_at_pos): return _get_slot_drag_data(i, is_player),
			func(_at_pos, data): return _can_slot_drop_data(data),
			func(_at_pos, data): _on_slot_drop_data(data, i, is_player)
		)
		
		# 우클릭 사용 / 좌클릭 빠른이동
		slot_btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_on_slot_right_clicked(i, is_player)
				elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					_on_slot_clicked(i, is_player)
		)
		
		slot_btn.pressed.connect(func(): _on_slot_clicked(i, is_player))
		grid.add_child(slot_btn)

func _get_slot_drag_data(index: int, is_player: bool) -> Variant:
	var src_inv = player_inv if is_player else loot_inv
	if src_inv == null or src_inv.items[index] == null:
		return null
		
	var item = src_inv.items[index]
	var preview = TextureRect.new()
	preview.texture = ItemIconManager.get_icon(item["id"]) if ItemIconManager else null
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate = Color(1, 1, 1, 0.75)
	
	var control = Control.new()
	control.add_child(preview)
	preview.position = -Vector2(24, 24)
	set_drag_preview(control)
	
	return {
		"src_index": index,
		"src_is_player": is_player,
		"item": item
	}

func _can_slot_drop_data(data: Variant) -> bool:
	return data is Dictionary and data.has("src_index")

func _on_slot_drop_data(data: Variant, target_index: int, target_is_player: bool) -> void:
	if not _can_slot_drop_data(data):
		return
		
	var src_index = data["src_index"]
	var src_is_player = data["src_is_player"]
	
	var src_inv = player_inv if src_is_player else loot_inv
	var dest_inv = player_inv if target_is_player else loot_inv
	
	if src_inv == null or dest_inv == null:
		return
		
	src_inv.move_item(src_index, target_index, dest_inv)
	if SoundManager: SoundManager.play("menu_select")
	_refresh_ui()

func _on_slot_right_clicked(index: int, is_player: bool) -> void:
	var src_inv = player_inv if is_player else loot_inv
	if src_inv == null or src_inv.items[index] == null:
		return
		
	var item_id = src_inv.items[index]["id"]
	var data = ItemDatabase.get_item_data(item_id)
	_use_item(index, item_id, data)

func _on_slot_clicked(index: int, is_player: bool) -> void:
	var src_inv = player_inv if is_player else loot_inv
	var dest_inv = loot_inv if is_player else player_inv
	
	if src_inv == null or src_inv.items[index] == null:
		return
		
	var item_id = src_inv.items[index]["id"]
	var data = ItemDatabase.get_item_data(item_id)
	
	# 루팅 모드가 아닐 때 (배낭만 열었을 때) 아이템 사용
	if dest_inv == null:
		_use_item(index, item_id, data)
		return
		
	# 루팅 모드일 때 빠른 이동
	var max_stack = data.get("max_stack", 1)
	var target_index = -1
	for i in range(dest_inv.max_slots):
		var slot = dest_inv.items[i]
		if slot and slot["id"] == item_id and slot["amount"] < max_stack:
			target_index = i
			break
			
	if target_index == -1:
		for i in range(dest_inv.max_slots):
			if dest_inv.items[i] == null:
				target_index = i
				break
				
	if target_index != -1:
		src_inv.move_item(index, target_index, dest_inv)
		if not is_player and EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("📦 획득: %s" % data.get("name", item_id))
		_refresh_ui()

func _use_item(index: int, item_id: String, data: Dictionary) -> void:
	if item_use_cooldown > 0:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⏳ 아이템 사용 쿨다운 중입니다 (%.1f초)" % item_use_cooldown)
		return
		
	var player = _get_player()
	var effects = data.get("effects", {})
	var used = false
	var effect_descriptions: Array = []
	
	if player:
		if effects.has("hunger"):
			player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
			used = true
			effect_descriptions.append("허기 +%d" % effects["hunger"])
		if effects.has("thirst"):
			player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
			used = true
			effect_descriptions.append("갈증 +%d" % effects["thirst"])
		if effects.has("hp"):
			player.hp = min(player.max_hp, player.hp + effects["hp"])
			used = true
			effect_descriptions.append("체력 +%d" % effects["hp"])
		if effects.get("cures_bleeding", false):
			player.is_bleeding = false
			used = true
			effect_descriptions.append("출혈 치료")
		if effects.get("cures_fracture", false):
			player.is_fractured = false
			used = true
			effect_descriptions.append("골절 치료")
		if effects.has("stamina"):
			player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
			used = true
			effect_descriptions.append("스태미너 +%d" % effects["stamina"])
			
		if used:
			item_use_cooldown = ITEM_USE_COOLDOWN_TIME
			player.stats_changed.emit()
			player_inv.remove_item_at(index, 1)
			if SoundManager:
				SoundManager.play("menu_select")
				
			var item_name = data.get("name", item_id)
			var desc_str = ", ".join(effect_descriptions)
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("✨ [%s] 사용 (%s)" % [item_name, desc_str])
				
			_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		_close()
		get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	_close()

func _close() -> void:
	_on_apply_weapon_modding()
	get_tree().paused = false
	queue_free()
	window_closed.emit()
