# res://scenes/interior/building_interior_scene.gd
extends Node2D

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var objects_layer: TileMapLayer = $ObjectsLayer
@onready var entities_layer: Node2D = $Entities
@onready var hud_title: Label = $UI/HUD/BuildingTitle
@onready var interact_prompt: Label = $UI/HUD/InteractPrompt

# HUD 게이지 노드
@onready var hp_bar: ProgressBar = $UI/HUD/Panel/VBox/HPBar
@onready var stamina_bar: ProgressBar = $UI/HUD/Panel/VBox/StaminaBar
@onready var hunger_bar: ProgressBar = $UI/HUD/Panel/VBox/HungerBar
@onready var thirst_bar: ProgressBar = $UI/HUD/Panel/VBox/ThirstBar
@onready var status_label: Label = $UI/HUD/Panel/VBox/StatusLabel
@onready var raid_timer_label: Label = $UI/HUD/RaidTimerPanel/RaidTimerLabel
@onready var event_log_vbox: VBoxContainer = $UI/HUD/EventLog

# 일시정지 메뉴
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var exit_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ExitBtn

const PlayerScene = preload("res://scenes/entities/player/player.tscn")
const InventoryWindowScene = preload("res://scenes/ui/inventory_window.tscn")
const CraftingWindowScene = preload("res://scenes/ui/crafting_window.tscn")

var player: CharacterBody2D
var player_inventory: InventoryGrid
var interior_data: Dictionary = {}
var furniture_inventories: Dictionary = {} # Vector2i -> Inventory
var current_loot_window: Control = null
var current_crafting_window: Control = null

var raid_time_remaining: float = 300.0

const PostProcessLayerScene = preload("res://graphics/post_process_layer.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 후처리 셰이더 추가
	var pp = PostProcessLayerScene.instantiate()
	add_child(pp)
	
	resume_btn.pressed.connect(_toggle_pause)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.connect(_on_event_logged)
	
	# 남은 레이드 시간 복원
	if GameManager and GameManager.current_world_data.has("raid_time_remaining"):
		raid_time_remaining = GameManager.current_world_data["raid_time_remaining"]
		
	# 건물 내부 데이터 가져오기
	var b_type = "house"
	var seed_val = randi()
	if GameManager and GameManager.current_world_data.has("current_interior"):
		var info = GameManager.current_world_data["current_interior"]
		b_type = info.get("type", "house")
		seed_val = info.get("seed", randi())
		
	interior_data = BuildingInterior.generate_interior(b_type, seed_val)
	hud_title.text = "🏢 " + interior_data["title"]
	
	_setup_tilemap()
	_setup_furnitures()
	_setup_enemies()
	_setup_player()

const EnemyScene = preload("res://scenes/entities/enemies/enemy.tscn")

func _setup_tilemap() -> void:
	if TileManager.tileset:
		tile_map.tile_set = TileManager.tileset
		objects_layer.tile_set = TileManager.tileset
		
	var w = interior_data["width"]
	var h = interior_data["height"]
	var tiles = interior_data["tiles"]
	
	for y in range(h):
		for x in range(w):
			var t_type = tiles[y * w + x]
			var pos = Vector2i(x, y)
			if t_type == 0: # 벽
				tile_map.set_cell(pos, 0, TileManager.TILE_CONCRETE)
				objects_layer.set_cell(pos, 0, TileManager.OBJ_WALL)
			elif t_type == 1: # 바닥
				tile_map.set_cell(pos, 0, TileManager.TILE_FLOOR_WOOD)
			elif t_type == 2: # 출구 문
				tile_map.set_cell(pos, 0, TileManager.TILE_FLOOR_WOOD)
				objects_layer.set_cell(pos, 0, TileManager.OBJ_DOOR_OPEN)
			elif t_type == 3: # 창문
				tile_map.set_cell(pos, 0, TileManager.TILE_CONCRETE)
				objects_layer.set_cell(pos, 0, TileManager.OBJ_WINDOW)
			elif t_type == 4: # 조명 스위치
				tile_map.set_cell(pos, 0, TileManager.TILE_CONCRETE)
				objects_layer.set_cell(pos, 0, TileManager.OBJ_LIGHT_SWITCH)

func _setup_furnitures() -> void:
	for f in interior_data.get("furnitures", []):
		var pos = f["pos"]
		var f_type = f["type"]
		
		var obj_coord = TileManager.OBJ_CRATE
		if f_type == "무기함" or f_type == "금고":
			obj_coord = TileManager.OBJ_CRATE
		elif f_type == "냉장고":
			obj_coord = TileManager.OBJ_FRIDGE
		elif f_type == "약품장" or f_type == "선반":
			obj_coord = TileManager.OBJ_BARREL
			
		objects_layer.set_cell(pos, 0, obj_coord)
		
		var inv = Inventory.new()
		inv.max_slots = 8
		add_child(inv)
		for item in f["loot"]:
			inv.add_item(item["id"], item["amount"])
		furniture_inventories[pos] = {"type": f_type, "inv": inv}

func _setup_enemies() -> void:
	for e in interior_data.get("enemies", []):
		var z = EnemyScene.instantiate()
		var z_pos = e["pos"]
		z.position = Vector2((z_pos.x + 0.5) * 32.0, (z_pos.y + 0.5) * 32.0)
		z.enemy_type = e.get("type", 0)
		entities_layer.add_child(z)

func _setup_player() -> void:
	player = PlayerScene.instantiate()
	var exit_pos = interior_data["exit_pos"]
	player.position = Vector2((exit_pos.x + 0.5) * 32.0, (exit_pos.y - 1.5) * 32.0)
	entities_layer.add_child(player)
	
	# 플레이어 생존 스탯 복원
	if GameManager and GameManager.current_world_data.has("player_stats"):
		var s = GameManager.current_world_data["player_stats"]
		player.hp = s.get("hp", 100.0)
		player.stamina = s.get("stamina", 100.0)
		player.hunger = s.get("hunger", 100.0)
		player.thirst = s.get("thirst", 100.0)
		player.is_bleeding = s.get("is_bleeding", false)
		player.is_fractured = s.get("is_fractured", false)
		player.is_infected = s.get("is_infected", false)
		player.set_flashlight(s.get("flashlight_enabled", true))
		
	player_inventory = player.inventory_grid
	if GameManager and not GameManager.current_world_data.is_empty():
		var p_data = GameManager.current_world_data.get("player", {})
		var p_items = p_data.get("inventory", [])
		if p_data.has("equipment") and not p_data["equipment"].is_empty():
			player.equipment = p_data["equipment"].duplicate(true)
		if player.has_method("apply_backpack_grid_size"):
			player.apply_backpack_grid_size()
		if player_inventory:
			if player_inventory.has_method("load_items"):
				player_inventory.load_items(p_items)
			else:
				for s_item in p_items:
					if s_item and not s_item.is_empty():
						player_inventory.auto_add_item(s_item.get("id", ""), s_item.get("amount", 1), s_item)
				
	if player.has_method("refresh_equipped_weapon"):
		player.refresh_equipped_weapon(true)
	player.stats_changed.connect(_on_player_stats_changed)
	player.interact_prompt.connect(_on_interact_prompt)
	player.object_interacted.connect(_on_object_interacted)
	if player_inventory:
		player_inventory.grid_changed.connect(_on_player_stats_changed)
	_on_player_stats_changed()

func _process(delta: float) -> void:
	if raid_time_remaining > 0:
		raid_time_remaining -= delta
		var minutes = int(raid_time_remaining / 60.0)
		var seconds = int(raid_time_remaining) % 60
		if raid_timer_label:
			raid_timer_label.text = "탈출 시간: %02d:%02d" % [minutes, seconds]
			if raid_time_remaining < 60:
				raid_timer_label.add_theme_color_override("font_color", Color.RED)
		if raid_time_remaining <= 0:
			GameManager.end_raid("mia")

func _on_player_stats_changed() -> void:
	if not player: return
	if hp_bar:
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp
		hp_bar.get_node("Label").text = "HP: %d/%d" % [int(player.hp), int(player.max_hp)]
	if stamina_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.stamina
		stamina_bar.get_node("Label").text = "STAMINA: %d/%d" % [int(player.stamina), int(player.max_stamina)]
	if hunger_bar:
		hunger_bar.value = player.hunger
	if thirst_bar:
		thirst_bar.value = player.thirst
		
	if status_label:
		var statuses = []
		if player.is_bleeding: statuses.append("출혈")
		if player.is_fractured: statuses.append("골절")
		if player.is_infected: statuses.append("감염")
		var status_str = ", ".join(statuses) if statuses.size() > 0 else "정상"
		var cur_mag = player.equipped_weapon_data.get("current_magazine_ammo", 0) if "equipped_weapon_data" in player else 0
		var reserve_ammo = player._get_available_ammo_count() if player.has_method("_get_available_ammo_count") else 0
		status_label.text = "상태: %s  |  🔫 %s [%d / %d발]" % [status_str, player.equipped_weapon if "equipped_weapon" in player else "무기", cur_mag, reserve_ammo]

func _unhandled_input(event: InputEvent) -> void:
	if current_loot_window != null or current_crafting_window != null:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed):
		_open_loot_window(null, "내 배낭")
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("crafting") or (event is InputEventKey and event.physical_keycode == KEY_C and event.pressed):
		_open_crafting_window()
		get_viewport().set_input_as_handled()

func _open_crafting_window() -> void:
	get_tree().paused = true
	current_crafting_window = CraftingWindowScene.instantiate()
	$UI.add_child(current_crafting_window)
	var inv_target = player.inventory_grid if player and player.inventory_grid else player_inventory
	current_crafting_window.setup(inv_target)
	current_crafting_window.window_closed.connect(func():
		current_crafting_window = null
		_on_player_stats_changed()
	)

func _toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	if pause_menu:
		pause_menu.visible = is_paused

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		GameManager.end_raid("survived")

func _on_interact_prompt(can_interact: bool, text: String) -> void:
	if interact_prompt and current_loot_window == null:
		interact_prompt.visible = can_interact
		interact_prompt.text = text
	elif interact_prompt:
		interact_prompt.visible = false

func _on_event_logged(msg: String) -> void:
	if not event_log_vbox: return
	
	var max_logs = GameSettings.max_event_logs if GameSettings else 3
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	style.border_width_left = 4
	style.border_color = Color(1.0, 0.8, 0.2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	
	if msg.begins_with("★"):
		style.border_color = Color(1.0, 0.8, 0.2)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	elif msg.begins_with("✓") or msg.begins_with("📦") or msg.begins_with("💊"):
		style.border_color = Color(0.3, 0.9, 0.4)
		lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	elif msg.begins_with("✗") or msg.begins_with("💀") or msg.begins_with("⚠️"):
		style.border_color = Color(0.9, 0.3, 0.3)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif msg.begins_with("🌦️") or msg.begins_with("🌅"):
		style.border_color = Color(0.3, 0.7, 1.0)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		
	panel.add_child(lbl)
	event_log_vbox.add_child(panel)
	
	while event_log_vbox.get_child_count() > max_logs:
		var oldest = event_log_vbox.get_child(0)
		oldest.queue_free()
		event_log_vbox.remove_child(oldest)
	
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)

func _on_object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i) -> void:
	if current_loot_window != null: return
	
	if tile_pos == interior_data.get("exit_pos", Vector2i(-1, -1)) or type == TileManager.OBJ_DOOR_CLOSED or type == TileManager.OBJ_DOOR_OPEN:
		_exit_interior()
		return
		
	if type == TileManager.OBJ_LIGHT_SWITCH:
		# 조명 스위치 토글
		_toggle_indoor_lights()
		return
		
	if type == TileManager.OBJ_WINDOW:
		# 창문 깨기
		if has_node("ObjectsLayer"):
			get_node("ObjectsLayer").set_cell(tile_pos, 0, TileManager.OBJ_WINDOW_BROKEN)
		EventBus.noise_created.emit(world_pos, 400.0, "break")
		EventBus.window_broken.emit(tile_pos)
		EventBus.event_logged.emit("💥 실내 창문이 깨졌습니다!")
		if SoundManager: SoundManager.play("hit_melee")
		return
		
	if furniture_inventories.has(tile_pos):
		var f_data = furniture_inventories[tile_pos]
		_open_loot_window(f_data["inv"], f_data["type"])
	elif type == TileManager.OBJ_CRATE or type == TileManager.OBJ_BARREL or type == TileManager.OBJ_FRIDGE:
		var inv = Inventory.new()
		inv.max_slots = 6
		add_child(inv)
		var loot_items = ItemDatabase.generate_loot("residential", 2)
		for item in loot_items:
			inv.add_item(item["id"], item["amount"])
		furniture_inventories[tile_pos] = {"type": "보관함", "inv": inv}
		_open_loot_window(inv, "보관함")

func _open_loot_window(target_inv: Inventory = null, title: String = "") -> void:
	if current_loot_window != null: return
	get_tree().paused = true
	current_loot_window = InventoryWindowScene.instantiate()
	$UI.add_child(current_loot_window)
	current_loot_window.setup(player, player.inventory_grid if player and "inventory_grid" in player else null, player.equipment if player and "equipment" in player else {}, target_inv, title)
	current_loot_window.window_closed.connect(func():
		current_loot_window = null
		_on_player_stats_changed()
	)

func _exit_interior() -> void:
	# 플레이어 데이터, 배낭, 남은 시간 저장 후 야외로 복귀
	if GameManager and not GameManager.current_world_data.is_empty():
		var saved_items = []
		if player_inventory:
			for item in player_inventory.items:
				if item and typeof(item) == TYPE_DICTIONARY:
					saved_items.append(item.duplicate(true))
		GameManager.current_world_data["player"]["inventory"] = saved_items
		GameManager.current_world_data["raid_time_remaining"] = raid_time_remaining
		GameManager.current_world_data["player_stats"] = {
			"hp": player.hp,
			"stamina": player.stamina,
			"hunger": player.hunger,
			"thirst": player.thirst,
			"is_bleeding": player.is_bleeding,
			"is_fractured": player.is_fractured,
			"is_infected": player.is_infected,
			"flashlight_enabled": player.flashlight_enabled
		}
		
	if SoundManager: SoundManager.play("menu_select")
	TransitionManager.change_scene("res://scenes/world/main_world.tscn", "fade", 0.6)

var is_indoor_light_on: bool = false
var ceiling_light: PointLight2D = null

func _toggle_indoor_lights() -> void:
	is_indoor_light_on = not is_indoor_light_on
	
	if SoundManager: SoundManager.play("menu_select")
	
	if is_indoor_light_on:
		if ceiling_light == null:
			ceiling_light = PointLight2D.new()
			ceiling_light.name = "CeilingLight"
			var w = interior_data.get("width", 24) * 32.0
			var h = interior_data.get("height", 18) * 32.0
			ceiling_light.position = Vector2(w / 2.0, h / 2.0)
			
			var grad = Gradient.new()
			grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
			grad.offsets = PackedFloat32Array([0.0, 1.0])
			var tex = GradientTexture2D.new()
			tex.gradient = grad
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			tex.width = int(max(w, h) * 1.5)
			tex.height = int(max(w, h) * 1.5)
			
			ceiling_light.texture = tex
			ceiling_light.color = Color(1.0, 0.95, 0.8)
			ceiling_light.energy = 1.3
			ceiling_light.shadow_enabled = true
			ceiling_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
			add_child(ceiling_light)
		else:
			ceiling_light.enabled = true
			
		EventBus.event_logged.emit("💡 실내 조명을 켰습니다.")
	else:
		if ceiling_light:
			ceiling_light.enabled = false
		EventBus.event_logged.emit("💡 실내 조명을 껐습니다.")
