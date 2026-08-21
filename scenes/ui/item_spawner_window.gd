# res://scenes/ui/item_spawner_window.gd
extends Control

## 샌드박스/크리에이티브 모드 전용 아이템 및 무기 스포너

signal window_closed

@onready var search_input: LineEdit = $Center/Panel/VBox/SearchHBox/SearchInput
@onready var category_opt: OptionButton = $Center/Panel/VBox/SearchHBox/CategoryOpt
@onready var item_grid: GridContainer = $Center/Panel/VBox/Scroll/ItemGrid
@onready var close_btn: Button = $Center/Panel/BottomHBox/CloseBtn

var all_spawnable_items: Array[Dictionary] = []
var tooltip: PanelContainer = null

func _ready() -> void:
	var tooltip_scene = preload("res://scenes/ui/item_tooltip.tscn")
	tooltip = tooltip_scene.instantiate()
	add_child(tooltip)
	tooltip.hide()
	
	_setup_categories()
	_collect_all_items()
	
	search_input.text_changed.connect(func(_new_text): _filter_and_render_items())
	category_opt.item_selected.connect(func(_idx): _filter_and_render_items())
	
	_filter_and_render_items()

func _setup_categories() -> void:
	category_opt.clear()
	category_opt.add_item("전체 보기", 0)
	category_opt.add_item("총기 리시버 (Weapons)", 1)
	category_opt.add_item("무기 부품 (Parts)", 2)
	category_opt.add_item("탄약 (Ammo)", 3)
	category_opt.add_item("의료 / 회복 (Medical)", 4)
	category_opt.add_item("식량 / 음료 (Food & Drink)", 5)
	category_opt.add_item("생존 도구 / 재료 (Tools)", 6)
	category_opt.selected = 0

func _collect_all_items() -> void:
	all_spawnable_items.clear()
	
	# 1. 총기 리시버 수집
	for r_id in WeaponPartsDatabase.RECEIVERS.keys():
		var r_data = WeaponPartsDatabase.RECEIVERS[r_id]
		all_spawnable_items.append({
			"id": r_id,
			"name": r_data["name"],
			"category": "receiver",
			"cat_idx": 1,
			"data": {
				"name": r_data["name"],
				"category": "총기",
				"description": "%s 규격 총기 리시버. 모딩 가능." % r_data.get("default_ammo", "9mm"),
				"value": r_data.get("value", 8000),
				"weight": r_data.get("weight", 1.5)
			}
		})
		
	# 2. 무기 부품 수집
	for p_id in WeaponPartsDatabase.PARTS.keys():
		var p_data = WeaponPartsDatabase.PARTS[p_id]
		all_spawnable_items.append({
			"id": p_id,
			"name": p_data["name"],
			"category": "part",
			"cat_idx": 2,
			"data": {
				"name": p_data["name"],
				"category": "부품",
				"description": "%s 슬롯 장착용 [%s]" % [p_data.get("slot", ""), p_data.get("tier", "")],
				"value": p_data.get("value", 3000),
				"weight": p_data.get("weight", 0.3)
			}
		})
		
	# 3. 탄약 수집
	for a_id in WeaponPartsDatabase.AMMO_TYPES.keys():
		var a_data = WeaponPartsDatabase.AMMO_TYPES[a_id]
		all_spawnable_items.append({
			"id": a_id,
			"name": a_data["name"],
			"category": "ammo",
			"cat_idx": 3,
			"data": {
				"name": a_data["name"],
				"category": "탄약",
				"description": "%s 규격 탄약. (관통력 %d)" % [a_id, a_data.get("penetration", 1)],
				"max_stack": 60,
				"value": a_data.get("value_per_round", 50) * 30,
				"weight": 0.02
			}
		})
		
	# 4. 일반 데이터베이스 아이템 수집
	for i_id in ItemDatabase.items.keys():
		var i_data = ItemDatabase.items[i_id]
		var c_type = i_data.get("category", 0)
		var cat_idx = 6
		if c_type == ItemDatabase.ItemCategory.MEDICAL: cat_idx = 4
		elif c_type == ItemDatabase.ItemCategory.FOOD or c_type == ItemDatabase.ItemCategory.WATER: cat_idx = 5
		elif c_type == ItemDatabase.ItemCategory.WEAPON: cat_idx = 1
		
		# 중복 검사
		var exists = false
		for item in all_spawnable_items:
			if item["id"] == i_id:
				exists = true
				break
		if not exists:
			all_spawnable_items.append({
				"id": i_id,
				"name": i_data.get("name", i_id),
				"category": "general",
				"cat_idx": cat_idx,
				"data": i_data
			})

func _filter_and_render_items() -> void:
	for c in item_grid.get_children():
		c.queue_free()
		
	var search_text = search_input.text.strip_edges().to_lower()
	var selected_cat = category_opt.selected
	
	for item_info in all_spawnable_items:
		var item_id = item_info["id"]
		var item_name = item_info["name"].to_lower()
		var cat_idx = item_info["cat_idx"]
		
		if selected_cat != 0 and cat_idx != selected_cat:
			continue
			
		if search_text != "" and not item_name.contains(search_text) and not item_id.to_lower().contains(search_text):
			continue
			
		_create_item_button(item_info)

func _create_item_button(item_info: Dictionary) -> void:
	var item_id = item_info["id"]
	var item_data = item_info["data"]
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(130, 70)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if ItemIconManager:
		icon_rect.texture = ItemIconManager.get_icon(item_id)
	vbox.add_child(icon_rect)
	
	var lbl = Label.new()
	lbl.text = item_info["name"]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	
	btn.mouse_entered.connect(func():
		if tooltip:
			tooltip.display_item({"id": item_id, "amount": 1}, item_data)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_spawn_item_to_player(item_id, item_data, 1)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var amt = item_data.get("max_stack", 30)
				_spawn_item_to_player(item_id, item_data, amt)
	)
	
	item_grid.add_child(btn)

func _spawn_item_to_player(item_id: String, item_data: Dictionary, amount: int) -> void:
	var player_inv = _get_player_inventory()
	if player_inv:
		var added = player_inv.add_item(item_id, amount)
		if added:
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("✨ [크리에이티브] %s x%d 지급 완료" % [item_data.get("name", item_id), amount])
		else:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 인벤토리 공간이 부족합니다.")
	else:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 플레이어 인벤토리를 찾을 수 없습니다.")

func _get_player_inventory() -> Inventory:
	var cur_scene = get_tree().current_scene
	if cur_scene and "player_inventory" in cur_scene and cur_scene.player_inventory:
		return cur_scene.player_inventory
	elif cur_scene and "player" in cur_scene and cur_scene.player and cur_scene.player.inventory:
		return cur_scene.player.inventory
	return null

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1)):
		_close()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
