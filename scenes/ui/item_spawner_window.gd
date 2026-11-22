# res://scenes/ui/item_spawner_window.gd
extends Control

## 샌드박스/크리에이티브 모드 전용 아이템 스포너 & 치트 관리자

signal window_closed

@onready var search_input: LineEdit = $Center/Panel/VBox/SearchHBox/SearchInput
@onready var category_opt: OptionButton = $Center/Panel/VBox/SearchHBox/CategoryOpt
@onready var amount_spin: SpinBox = $Center/Panel/VBox/SearchHBox/AmountSpin
@onready var item_grid: GridContainer = $Center/Panel/VBox/Scroll/ItemGrid
@onready var close_btn: Button = $Center/Panel/BottomHBox/CloseBtn

# 치트 툴바 노드
@onready var add_money_10k_btn: Button = $Center/Panel/VBox/CheatToolbar/AddMoney10kBtn
@onready var add_money_100k_btn: Button = $Center/Panel/VBox/CheatToolbar/AddMoney100kBtn
@onready var heal_all_btn: Button = $Center/Panel/VBox/CheatToolbar/HealAllBtn
@onready var cure_all_btn: Button = $Center/Panel/VBox/CheatToolbar/CureAllBtn
@onready var god_mode_check: CheckBox = $Center/Panel/VBox/CheatToolbar/GodModeCheck
@onready var add_time_btn: Button = $Center/Panel/VBox/CheatToolbar/AddTimeBtn
@onready var clear_inv_btn: Button = $Center/Panel/VBox/CheatToolbar/ClearInvBtn

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
	
	# 치트 버튼 시그널 연결 및 UI 아이콘 바인딩
	add_money_10k_btn.pressed.connect(func(): _add_money(10000))
	add_money_100k_btn.pressed.connect(func(): _add_money(100000))
	heal_all_btn.pressed.connect(_heal_all_stats)
	cure_all_btn.pressed.connect(_cure_all_conditions)
	god_mode_check.toggled.connect(_toggle_god_mode)
	add_time_btn.pressed.connect(_add_raid_time)
	clear_inv_btn.pressed.connect(_clear_inventory)

	if UiIconManager:
		var title_lbl := get_node_or_null("Center/Panel/Title") as Label
		if title_lbl: UiIconManager.set_label_icon(title_lbl, "sandbox", "", 18, 6)
		UiIconManager.apply_button_icon(add_money_10k_btn, "money", "", 14)
		UiIconManager.apply_button_icon(add_money_100k_btn, "money", "", 14)
		UiIconManager.apply_button_icon(heal_all_btn, "heart", "", 14)
		UiIconManager.apply_button_icon(cure_all_btn, "bandage", "", 14)
		UiIconManager.apply_button_icon(god_mode_check, "shield_green", "", 14)
		UiIconManager.apply_button_icon(add_time_btn, "hourglass", "", 14)
		UiIconManager.apply_button_icon(clear_inv_btn, "trash", "", 14)
		var hint_lbl := get_node_or_null("Center/Panel/BottomHBox/HintLabel") as Label
		if hint_lbl: UiIconManager.set_label_icon(hint_lbl, "tip", "", 14, 5)
	
	# 현재 무적 상태 동기화
	var player = _get_player()
	if player and "is_god_mode" in player:
		god_mode_check.button_pressed = player.is_god_mode
		
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
		var caliber_name = r_data.get("default_ammo", "9mm")
		all_spawnable_items.append({
			"id": r_id,
			"name": r_data["name"],
			"category": "receiver",
			"cat_idx": 1,
			"data": {
				"name": r_data["name"],
				"category": "총기",
				"description": "%s 규격 총기 리시버. 모딩 가능." % caliber_name,
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
	btn.custom_minimum_size = Vector2(140, 68)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(30, 30)
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
			tooltip.display_item({"id": item_id, "amount": int(amount_spin.value)}, item_data)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			var req_amount = int(amount_spin.value)
			if event.button_index == MOUSE_BUTTON_RIGHT:
				req_amount = item_data.get("max_stack", 30)
			_spawn_item_to_player(item_id, item_data, req_amount)
	)
	
	item_grid.add_child(btn)

func _spawn_item_to_player(item_id: String, item_data: Dictionary, amount: int) -> void:
	var cur_scene = get_tree().current_scene
	var spawned_successfully = false
	
	# 아이템 딕셔너리 구성 (총기인 경우 기본 부품이 세팅된 완제품 무기로 생성)
	var custom_dict = {"id": item_id, "amount": amount}
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(item_id)
	if WeaponPartsDatabase.RECEIVERS.has(rec_id):
		custom_dict = WeaponPartsDatabase.create_default_weapon(rec_id)
		custom_dict["amount"] = 1
		
	# 1. 은신처 씬 (Hideout) 에서 스폰 (창고 우선, 가득 차면 배낭에 추가)
	if cur_scene and "stash_grid_mgr" in cur_scene and cur_scene.stash_grid_mgr:
		var rem = cur_scene.stash_grid_mgr.auto_add_item(item_id, amount, custom_dict)
		if rem <= 0:
			spawned_successfully = true
		elif "player_grid_mgr" in cur_scene and cur_scene.player_grid_mgr:
			var rem2 = cur_scene.player_grid_mgr.auto_add_item(item_id, rem, custom_dict)
			if rem2 < rem:
				spawned_successfully = true
				
		if spawned_successfully:
			if cur_scene.has_method("_on_grid_changed"):
				cur_scene._on_grid_changed()
			if cur_scene.has_method("_refresh_workbench_ui"):
				cur_scene._refresh_workbench_ui()
				
	# 2. 인게임 씬 (MainWorld / Player 2D Grid) 에서 스폰
	elif cur_scene and "player" in cur_scene and cur_scene.player:
		var p = cur_scene.player
		if "inventory_grid" in p and p.inventory_grid:
			var rem = p.inventory_grid.auto_add_item(item_id, amount, custom_dict)
			if rem < amount:
				spawned_successfully = true
		elif "grid_inventory" in p and p.grid_inventory:
			var rem = p.grid_inventory.auto_add_item(item_id, amount, custom_dict)
			if rem < amount:
				spawned_successfully = true
		elif "inventory" in p and p.inventory:
			if p.inventory.has_method("auto_add_item"):
				var rem = p.inventory.auto_add_item(item_id, amount, custom_dict)
				if rem < amount: spawned_successfully = true
			elif p.inventory.has_method("add_item"):
				var added = p.inventory.add_item(item_id, amount)
				if added <= 0: spawned_successfully = true
				
	# 3. 폴백 (구버전 1D 인벤토리)
	if not spawned_successfully:
		var p_inv = _get_player_inventory()
		if p_inv and p_inv.has_method("add_item"):
			var added = p_inv.add_item(item_id, amount)
			if added: spawned_successfully = true

	if spawned_successfully:
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:stars] [치트/스폰] %s x%d 지급 완료 (창고/가방)" % [item_data.get("name", item_id), amount])
	else:
		if SoundManager: SoundManager.play("hit_melee")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 인벤토리/창고 공간이 부족하거나 대상을 찾을 수 없습니다.")

# ============================================================
# 치트 / 크리에이티브 관리자 기능
# ============================================================
func _add_money(amount: int) -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager and not GameManager.current_world_data.is_empty():
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		var cur_rubles = GameManager.current_world_data["player"].get("rubles", 0)
		cur_rubles += amount
		GameManager.current_world_data["player"]["rubles"] = cur_rubles
		
		# 은신처 UI 갱신 (열려있다면)
		var cur_scene = get_tree().current_scene
		if cur_scene and "money_label" in cur_scene and cur_scene.money_label:
			cur_scene.money_label.text = "자금: %d RUB" % cur_rubles
			
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:money] 자금 치트: +%d RUB (총 %d RUB)" % [amount, cur_rubles])

func _heal_all_stats() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var player = _get_player()
	if player:
		player.hp = player.max_hp
		player.stamina = player.max_stamina
		player.hunger = player.max_hunger
		player.thirst = player.max_thirst
		player.stats_changed.emit()
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:heart] 플레이어 체력/스태미너/허기/갈증 100% 완충 완료!")

func _cure_all_conditions() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var player = _get_player()
	if player:
		player.is_bleeding = false
		player.is_fractured = false
		player.is_infected = false
		player.stats_changed.emit()
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:bandage] 모든 부상(출혈, 골절, 감염) 치료 완료!")

func _toggle_god_mode(enabled: bool) -> void:
	if SoundManager: SoundManager.play("menu_select")
	var player = _get_player()
	if player:
		player.is_god_mode = enabled
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:shield_green] 무적 모드 (God Mode): %s" % ("활성화" if enabled else "비활성화"))

func _add_raid_time() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var cur_scene = get_tree().current_scene
	if cur_scene and "raid_time_remaining" in cur_scene:
		cur_scene.raid_time_remaining += 600.0 # +10분
		if GameManager:
			GameManager.raid_duration_minutes += 10.0
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:hourglass] 레이드 시간 10분 연장 완료!")

func _clear_inventory() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var cur_scene = get_tree().current_scene
	var cleared = false
	
	if cur_scene and "player_grid_mgr" in cur_scene and cur_scene.player_grid_mgr:
		cur_scene.player_grid_mgr.clear()
		cleared = true
		if cur_scene.has_method("_on_grid_changed"): cur_scene._on_grid_changed()
	elif cur_scene and "player" in cur_scene and cur_scene.player:
		var p = cur_scene.player
		if "inventory_grid" in p and p.inventory_grid:
			p.inventory_grid.clear()
			cleared = true
		elif "grid_inventory" in p and p.grid_inventory:
			p.grid_inventory.clear()
			cleared = true
			
	var p_inv = _get_player_inventory()
	if p_inv and "max_slots" in p_inv:
		for i in range(p_inv.max_slots):
			p_inv.remove_item_at(i, 999)
		cleared = true
		
	if cleared and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:trash] 가방 인벤토리를 모두 비웠습니다.")

# ============================================================
# 플레이어 & 인벤토리 참조 헬퍼
# ============================================================
func _get_player() -> Node:
	var cur_scene = get_tree().current_scene
	if cur_scene and "player" in cur_scene and cur_scene.player:
		return cur_scene.player
	elif get_node_or_null("/root/MainWorld") and get_node("/root/MainWorld").player:
		return get_node("/root/MainWorld").player
	return get_tree().get_first_node_in_group("player")

func _get_player_inventory() -> Inventory:
	var cur_scene = get_tree().current_scene
	if cur_scene and "player_inventory" in cur_scene and cur_scene.player_inventory:
		return cur_scene.player_inventory
	elif cur_scene and "player" in cur_scene and cur_scene.player and cur_scene.player.inventory:
		return cur_scene.player.inventory
	elif cur_scene and "player_inv" in cur_scene and cur_scene.player_inv:
		return cur_scene.player_inv
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
