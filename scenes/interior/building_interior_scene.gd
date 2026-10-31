# res://scenes/interior/building_interior_scene.gd
extends Node2D

## 건물 내부 씬 (외부 월드와 동일한 전술 HUD/채널링/퀵슬롯/피격 아크/조준원/장비 동기화 지원)

@onready var floor_layer: TileMapLayer = $TileMapLayer
@onready var object_layer: TileMapLayer = $ObjectsLayer
@onready var entities_layer: Node2D = $Entities
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var exit_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ExitBtn
@onready var interact_prompt: Label = $UI/HUD/InteractPrompt
@onready var hp_bar: ProgressBar = $UI/HUD/Panel/VBox/HPBar
@onready var stamina_bar: ProgressBar = $UI/HUD/Panel/VBox/StaminaBar
@onready var hunger_bar: ProgressBar = $UI/HUD/Panel/VBox/HungerBar
@onready var thirst_bar: ProgressBar = $UI/HUD/Panel/VBox/ThirstBar
@onready var status_label: Label = $UI/HUD/Panel/VBox/StatusLabel
@onready var raid_timer_label: Label = $UI/HUD/RaidTimerPanel/RaidTimerLabel
@onready var building_title_label: Label = $UI/HUD/BuildingTitle
@onready var event_log_vbox: VBoxContainer = $UI/HUD/EventLog

# 통합 전술 HUD 위젯 참조
var status_badges_container: HBoxContainer = null
var badge_bleed: PanelContainer = null
var badge_fracture: PanelContainer = null
var badge_biohazard: PanelContainer = null
var channeling_bar: ProgressBar = null
var channeling_label: Label = null
var quickslot_bar: PanelContainer = null
var quickslot_hbox: HBoxContainer = null
var weapon_panel: Panel = null
var weapon_icon: TextureRect = null
var weapon_name_label: Label = null
var ammo_label: Label = null
var weapon_durability_bar: ProgressBar = null
var crosshair_overlay: Control = null
var crosshair_spread: float = 12.0
var hit_arc_overlay: Control = null
var hit_arcs: Array = []

const PlayerScene = preload("res://scenes/entities/player/player.tscn")
const EnemyScene = preload("res://scenes/entities/enemies/enemy.tscn")
const InventoryWindowScene = preload("res://scenes/ui/inventory_window.tscn")
const CraftingWindowScene = preload("res://scenes/ui/crafting_window.tscn")
const PostProcessLayerScene = preload("res://graphics/post_process_layer.tscn")

var player: CharacterBody2D
var current_inventory_window: Control = null
var current_crafting_window: Control = null
var container_inventories: Dictionary = {}
var exit_tile_pos: Vector2i = Vector2i(7, 10)
var raid_time_remaining: float = 300.0
var building_data: Dictionary = {}
var particle_system: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if entities_layer:
		entities_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.visible = false
		
	resume_btn.pressed.connect(_on_resume_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# 포스트프로세싱 및 파티클
	var pp = PostProcessLayerScene.instantiate()
	add_child(pp)
	
	var ps_script = load("res://systems/particle_system.gd")
	particle_system = Node2D.new()
	particle_system.name = "ParticleSystem"
	particle_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	particle_system.set_script(ps_script)
	add_child(particle_system)
	
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.connect(_on_event_logged)
		
	_ensure_tactical_hud_widgets()
	
	# 타일셋 설정
	var ts = TileManager.get_tileset()
	floor_layer.tile_set = ts
	object_layer.tile_set = ts
	
	# 건물 데이터 로드 및 생성
	var b_type = "house"
	var b_seed = randi()
	if GameManager and GameManager.current_world_data.has("current_interior"):
		var info = GameManager.current_world_data["current_interior"]
		b_type = info.get("type", "house")
		b_seed = info.get("seed", randi())
		
	if GameManager and GameManager.current_world_data.has("raid_time_remaining"):
		raid_time_remaining = GameManager.current_world_data["raid_time_remaining"]
		
	var type_names = {
		"house": "🏠 폐가 내부",
		"shop": "🏪 상점 내부",
		"hospital": "🏥 폐병원 내부",
		"military": "🪖 군사시설 내부"
	}
	if building_title_label:
		building_title_label.text = type_names.get(b_type, "🏢 버려진 건물 내부")
		
	var gen_script = load("res://world/interior/building_interior.gd")
	building_data = gen_script.generate(b_type, b_seed)
	exit_tile_pos = building_data["exit"]
	
	_render_interior()
	_spawn_entities()
	
	# 동적 조준원(Dynamic Crosshair) 및 피격 방향 아크(Hit Arc) 오버레이
	crosshair_overlay = Control.new()
	crosshair_overlay.name = "DynamicCrosshair"
	crosshair_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_overlay.draw.connect(_on_crosshair_draw)
	$UI/HUD.add_child(crosshair_overlay)
	
	hit_arc_overlay = Control.new()
	hit_arc_overlay.name = "HitArcOverlay"
	hit_arc_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_arc_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_arc_overlay.draw.connect(_on_hit_arc_draw)
	$UI/HUD.add_child(hit_arc_overlay)
	
	if EventBus.has_signal("player_hit_direction"):
		EventBus.player_hit_direction.connect(_on_player_hit_direction)
	
	if ResponsiveManager:
		ResponsiveManager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		ResponsiveManager.window_resized.connect(_on_responsive_window_resized)
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, ResponsiveManager.current_viewport_size)

func _ensure_tactical_hud_widgets() -> void:
	var hud = $UI/HUD
	var vbox = get_node_or_null("UI/HUD/Panel/VBox")
	if vbox:
		status_badges_container = vbox.get_node_or_null("StatusBadgesContainer")
		if not status_badges_container:
			status_badges_container = HBoxContainer.new()
			status_badges_container.name = "StatusBadgesContainer"
			status_badges_container.add_theme_constant_override("separation", 4)
			vbox.add_child(status_badges_container)
			
			badge_bleed = _create_status_badge("BleedBadge", "🩸 BLEED", Color(1, 0.25, 0.25))
			badge_fracture = _create_status_badge("FractureBadge", "🦴 FRACTURE", Color(1, 0.6, 0.15))
			badge_biohazard = _create_status_badge("BiohazardBadge", "☣ BIO-HAZARD", Color(0.25, 1, 0.35))
			status_badges_container.add_child(badge_bleed)
			status_badges_container.add_child(badge_fracture)
			status_badges_container.add_child(badge_biohazard)
		else:
			badge_bleed = status_badges_container.get_node_or_null("BleedBadge")
			badge_fracture = status_badges_container.get_node_or_null("FractureBadge")
			badge_biohazard = status_badges_container.get_node_or_null("BiohazardBadge")

	channeling_bar = hud.get_node_or_null("ChannelingBar")
	if not channeling_bar:
		channeling_bar = ProgressBar.new()
		channeling_bar.name = "ChannelingBar"
		channeling_bar.visible = false
		channeling_bar.set_anchors_preset(Control.PRESET_CENTER)
		channeling_bar.offset_left = -150.0
		channeling_bar.offset_top = 75.0
		channeling_bar.offset_right = 150.0
		channeling_bar.offset_bottom = 100.0
		channeling_bar.max_value = 1.0
		channeling_bar.show_percentage = false
		channeling_label = Label.new()
		channeling_label.name = "Label"
		channeling_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		channeling_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		channeling_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		channeling_label.add_theme_font_size_override("font_size", 13)
		channeling_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
		channeling_bar.add_child(channeling_label)
		hud.add_child(channeling_bar)
	else:
		channeling_label = channeling_bar.get_node_or_null("Label")

	weapon_panel = hud.get_node_or_null("WeaponPanel")
	if not weapon_panel:
		weapon_panel = Panel.new()
		weapon_panel.name = "WeaponPanel"
		weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		weapon_panel.offset_left = 20.0
		weapon_panel.offset_top = -100.0
		weapon_panel.offset_right = 260.0
		weapon_panel.offset_bottom = -20.0
		var wp_hbox = HBoxContainer.new()
		wp_hbox.name = "HBox"
		wp_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		wp_hbox.offset_left = 10.0
		wp_hbox.offset_top = 8.0
		wp_hbox.offset_right = -10.0
		wp_hbox.offset_bottom = -8.0
		wp_hbox.add_theme_constant_override("separation", 12)
		weapon_panel.add_child(wp_hbox)
		weapon_icon = TextureRect.new()
		weapon_icon.name = "WeaponIcon"
		weapon_icon.custom_minimum_size = Vector2(48, 48)
		weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wp_hbox.add_child(weapon_icon)
		var wp_vbox = VBoxContainer.new()
		wp_vbox.name = "VBox"
		wp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wp_vbox.add_theme_constant_override("separation", 3)
		wp_hbox.add_child(wp_vbox)
		weapon_name_label = Label.new()
		weapon_name_label.name = "WeaponNameLabel"
		weapon_name_label.add_theme_font_size_override("font_size", 14)
		weapon_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		wp_vbox.add_child(weapon_name_label)
		ammo_label = Label.new()
		ammo_label.name = "AmmoLabel"
		ammo_label.add_theme_font_size_override("font_size", 15)
		ammo_label.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
		wp_vbox.add_child(ammo_label)
		weapon_durability_bar = ProgressBar.new()
		weapon_durability_bar.name = "DurabilityBar"
		weapon_durability_bar.custom_minimum_size = Vector2(0, 6)
		weapon_durability_bar.show_percentage = false
		wp_vbox.add_child(weapon_durability_bar)
		hud.add_child(weapon_panel)

	quickslot_bar = hud.get_node_or_null("QuickslotBar")
	if not quickslot_bar:
		quickslot_bar = PanelContainer.new()
		quickslot_bar.name = "QuickslotBar"
		quickslot_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		quickslot_bar.offset_left = -225.0
		quickslot_bar.offset_top = -68.0
		quickslot_bar.offset_right = 225.0
		quickslot_bar.offset_bottom = -12.0
		quickslot_hbox = HBoxContainer.new()
		quickslot_hbox.name = "HBox"
		quickslot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		quickslot_hbox.add_theme_constant_override("separation", 4)
		quickslot_bar.add_child(quickslot_hbox)
		for s_name in ["Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6", "Slot7", "SlotN"]:
			var b = Button.new()
			b.name = s_name
			b.custom_minimum_size = Vector2(52, 52)
			quickslot_hbox.add_child(b)
		hud.add_child(quickslot_bar)
	else:
		quickslot_hbox = quickslot_bar.get_node_or_null("HBox")

func _create_status_badge(node_name: String, text_str: String, col: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	pc.name = node_name
	pc.visible = false
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	pc.add_child(lbl)
	return pc

func _on_responsive_breakpoint_changed(new_bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	_apply_responsive_layout(new_bp, vp_size)

func _on_responsive_window_resized(vp_size: Vector2) -> void:
	if ResponsiveManager:
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, vp_size)

func _apply_responsive_layout(_bp: ResponsiveManager.Breakpoint, _vp_size: Vector2) -> void:
	pass

func _render_interior() -> void:
	var w = building_data["width"]
	var h = building_data["height"]
	var tiles = building_data["tiles"]
	
	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x, y)
			var t = tiles[y][x]
			
			floor_layer.set_cell(pos, 0, TileManager.TILE_FLOOR_WOOD)
			
			if t == 1:
				object_layer.set_cell(pos, 0, TileManager.WALL_BRICK)
			elif t == 2:
				object_layer.set_cell(pos, 0, TileManager.OBJ_DOOR_CLOSED)
			elif t == 3:
				object_layer.set_cell(pos, 0, TileManager.OBJ_CRATE)
			elif t == 4:
				object_layer.set_cell(pos, 0, TileManager.OBJ_FURNITURE)
			elif t == 5:
				object_layer.set_cell(pos, 0, TileManager.OBJ_DOOR_OPEN)

func _spawn_entities() -> void:
	player = PlayerScene.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2(exit_tile_pos.x * 32 + 16, (exit_tile_pos.y - 1) * 32 + 16)
	entities_layer.add_child(player)
	
	# 플레이어 스탯 및 인벤토리/장비 복원 (add_child 이후에 적용)
	if GameManager and GameManager.current_world_data.has("player_stats"):
		var s = GameManager.current_world_data["player_stats"]
		player.hp = s.get("hp", player.max_hp)
		player.stamina = s.get("stamina", player.max_stamina)
		player.hunger = s.get("hunger", player.max_hunger)
		player.thirst = s.get("thirst", player.max_thirst)
		player.is_bleeding = s.get("is_bleeding", false)
		player.is_fractured = s.get("is_fractured", false)
		player.is_infected = s.get("is_infected", false)
		player.set_flashlight(s.get("flashlight_enabled", true))
		
	if GameManager and not GameManager.current_world_data.is_empty():
		var p_data = GameManager.current_world_data.get("player", {})
		var saved_items = p_data.get("inventory", [])
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
		
	player.stats_changed.connect(_on_player_stats_changed)
	player.interact_prompt.connect(_on_interact_prompt)
	player.object_interacted.connect(_on_object_interacted)
	if player.has_signal("channel_started"):
		player.channel_started.connect(_on_player_channel_started)
	if player.has_signal("channel_progress"):
		player.channel_progress.connect(_on_player_channel_progress)
	if player.has_signal("channel_completed"):
		player.channel_completed.connect(_on_player_channel_finished)
	if player.has_signal("channel_cancelled"):
		player.channel_cancelled.connect(_on_player_channel_finished)
	if player.inventory_grid:
		player.inventory_grid.grid_changed.connect(_on_player_stats_changed)
		player.inventory_grid.grid_changed.connect(_update_quickslot_bar)
	if player.weapon_handler:
		if player.weapon_handler.has_signal("weapon_changed"):
			player.weapon_handler.weapon_changed.connect(_update_quickslot_bar)
		if player.weapon_handler.has_signal("ammo_changed"):
			player.weapon_handler.ammo_changed.connect(_update_quickslot_bar)
	_setup_quickslot_bar()
	_on_player_stats_changed()
	
	# 내부 좀비 스폰
	for z_info in building_data.get("zombies", []):
		var enemy = EnemyScene.instantiate()
		enemy.position = Vector2(z_info["x"] * 32 + 16, z_info["y"] * 32 + 16)
		enemy.enemy_type = z_info.get("type", 0)
		entities_layer.add_child(enemy)
		
	# 루팅 상자 인벤토리 구성
	for c_info in building_data.get("containers", []):
		var c_pos = Vector2i(c_info["x"], c_info["y"])
		var inv = Inventory.new()
		inv.max_slots = 8
		add_child(inv)
		for it in c_info.get("items", []):
			inv.add_item(it["id"], it["amount"])
		container_inventories[c_pos] = inv

func _process(delta: float) -> void:
	if player:
		if crosshair_overlay:
			var w_stats = player.equipped_weapon_data.get("computed_stats", {}) if not player.equipped_weapon_data.is_empty() else {}
			var acc = float(w_stats.get("accuracy", 78.0))
			var base_spread = max(5.0, (100.0 - acc) * 0.45)
			var move_penalty = player.velocity.length() * 0.075
			var recoil_pen = (player.weapon_handler.recoil_offset * 1.8) if player.weapon_handler else 0.0
			var target_spread = base_spread + move_penalty + recoil_pen
			if player.player_camera and player.player_camera.is_aiming_ads:
				target_spread *= 0.48
			elif player.is_crouching:
				target_spread *= 0.72
			crosshair_spread = lerp(crosshair_spread, target_spread, clamp(delta * 14.0, 0.0, 1.0))
			crosshair_overlay.queue_redraw()
			
		if hit_arcs.size() > 0:
			for i in range(hit_arcs.size() - 1, -1, -1):
				hit_arcs[i]["timer"] -= delta
				if hit_arcs[i]["timer"] <= 0.0:
					hit_arcs.remove_at(i)
			if hit_arc_overlay:
				hit_arc_overlay.queue_redraw()
				
		var pulse_alpha = 0.675 + 0.325 * sin(Time.get_ticks_msec() * 0.008)
		if badge_bleed and badge_bleed.visible:
			badge_bleed.modulate.a = pulse_alpha
		if badge_fracture and badge_fracture.visible:
			badge_fracture.modulate.a = pulse_alpha
		if badge_biohazard and badge_biohazard.visible:
			badge_biohazard.modulate.a = pulse_alpha

	if not get_tree().paused and raid_time_remaining > 0:
		raid_time_remaining -= delta
		var minutes = int(raid_time_remaining / 60.0)
		var seconds = int(raid_time_remaining) % 60
		if raid_timer_label:
			raid_timer_label.text = "탈출 시간: %02d:%02d" % [minutes, seconds]
			if raid_time_remaining < 60:
				raid_timer_label.add_theme_color_override("font_color", Color.RED)
		if raid_time_remaining <= 0:
			EventBus.event_logged.emit("탈출 시간 초과. 작전 실패.")
			if GameManager:
				if player and not player.equipment.is_empty():
					if not GameManager.current_world_data.has("player"):
						GameManager.current_world_data["player"] = {}
					GameManager.current_world_data["player"]["equipment"] = player.equipment.duplicate(true)
				GameManager.end_raid("mia", get_backpack_items())

func _on_crosshair_draw() -> void:
	if not crosshair_overlay or not player or get_tree().paused:
		return
	var m_pos = crosshair_overlay.get_local_mouse_position()
	var gap = clamp(crosshair_spread, 4.0, 48.0)
	var line_len = 7.0
	var is_ads = player.player_camera.is_aiming_ads if player.player_camera else false
	var col = Color(0.25, 1.0, 0.45, 0.88) if is_ads else Color(1.0, 0.96, 0.82, 0.82)
	var shadow_col = Color(0.0, 0.0, 0.0, 0.65)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p1 = m_pos + d * gap
		var p2 = m_pos + d * (gap + line_len)
		crosshair_overlay.draw_line(p1, p2, shadow_col, 3.0)
		crosshair_overlay.draw_line(p1, p2, col, 1.6)
	crosshair_overlay.draw_circle(m_pos, 1.8, col)

func _on_player_hit_direction(attacker_pos: Vector2) -> void:
	if not player: return
	var diff = attacker_pos - player.global_position
	var angle = diff.angle() if diff.length() > 0.001 else 0.0
	hit_arcs.append({"angle": angle, "timer": 0.4, "max_time": 0.4})
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(4.0, 0.2)
	if hit_arc_overlay:
		hit_arc_overlay.queue_redraw()

func _on_hit_arc_draw() -> void:
	if not hit_arc_overlay or hit_arcs.is_empty():
		return
	var center = hit_arc_overlay.size * 0.5
	var arc_radius = 130.0
	var arc_width = 3.5
	var arc_spread = deg_to_rad(38.0)
	for arc_data in hit_arcs:
		var alpha = clamp(arc_data["timer"] / arc_data["max_time"], 0.0, 1.0)
		var arc_angle = arc_data["angle"]
		var col = Color(1.0, 0.15, 0.15, 0.85 * alpha)
		var shadow_col = Color(0.1, 0.0, 0.0, 0.45 * alpha)
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, shadow_col, arc_width + 2.0)
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, col, arc_width)
		var tip_dir = Vector2.RIGHT.rotated(arc_angle)
		var tip_pos = center + tip_dir * (arc_radius + 6.0)
		var p_left = center + Vector2.RIGHT.rotated(arc_angle - 0.09) * (arc_radius + 1.0)
		var p_right = center + Vector2.RIGHT.rotated(arc_angle + 0.09) * (arc_radius + 1.0)
		hit_arc_overlay.draw_colored_polygon(PackedVector2Array([tip_pos, p_left, p_right]), col)

func _unhandled_input(event: InputEvent) -> void:
	if current_inventory_window != null or current_crafting_window != null:
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
		_open_inventory_window()
		get_viewport().set_input_as_handled()
		
	if event.is_action_pressed("crafting") or (event is InputEventKey and event.physical_keycode == KEY_C and event.pressed):
		_open_crafting_window()
		get_viewport().set_input_as_handled()
		
	if event is InputEventKey and event.physical_keycode == KEY_B and event.pressed:
		_open_weapon_modding_window()
		get_viewport().set_input_as_handled()

func _open_weapon_modding_window() -> void:
	var modding_script = load("res://scenes/ui/weapon_modding_window.gd")
	if modding_script:
		get_tree().paused = true
		var win = modding_script.new()
		$UI.add_child(win)
		var cur_w = player.equipped_weapon_data if player else {}
		var inv_target = player.inventory_grid if player else null
		win.setup(inv_target, null, cur_w)
		win.window_closed.connect(func(): _on_player_stats_changed())

func _open_crafting_window() -> void:
	get_tree().paused = true
	current_crafting_window = CraftingWindowScene.instantiate()
	$UI.add_child(current_crafting_window)
	var inv_target = player.inventory_grid if player else null
	current_crafting_window.setup(inv_target)
	current_crafting_window.window_closed.connect(func():
		current_crafting_window = null
		_on_player_stats_changed()
	)

func _open_inventory_window(target_inv: Inventory = null, title: String = "") -> void:
	if current_inventory_window != null: return
	get_tree().paused = true
	current_inventory_window = InventoryWindowScene.instantiate()
	$UI.add_child(current_inventory_window)
	current_inventory_window.setup(player, player.inventory_grid, player.equipment, target_inv, title)
	current_inventory_window.window_closed.connect(func():
		current_inventory_window = null
		_on_player_stats_changed()
	)

func _open_loot_window(target_inv: Inventory = null, title: String = "") -> void:
	_open_inventory_window(target_inv, title)

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
		
	var has_status = player.is_bleeding or player.is_fractured or player.is_infected
	if badge_bleed:
		badge_bleed.visible = player.is_bleeding
	if badge_fracture:
		badge_fracture.visible = player.is_fractured
	if badge_biohazard:
		badge_biohazard.visible = player.is_infected
		
	if status_label:
		var statuses = []
		if player.is_bleeding: statuses.append("출혈")
		if player.is_fractured: statuses.append("골절")
		if player.is_infected: statuses.append("감염")
		status_label.text = "상태이상: " + (", ".join(statuses) if statuses.size() > 0 else "없음")
		status_label.visible = not has_status
		
	if weapon_panel:
		var eq_wep = player.equipped_weapon
		var wep_data = ItemDatabase.get_item_data(player.equipped_weapon_data.get("id", eq_wep))
		var slot_disp = player._get_slot_display_name(player.active_weapon_slot) if player.has_method("_get_slot_display_name") else ""
		if weapon_name_label:
			weapon_name_label.text = "[%s] %s" % [slot_disp, eq_wep]
		if weapon_icon and ItemIconManager:
			weapon_icon.texture = ItemIconManager.get_icon(player.equipped_weapon_data.get("id", eq_wep))
		if ammo_label:
			if player.equipped_weapon_data.is_empty():
				ammo_label.text = "👊 맨손 (주먹)"
				ammo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			elif player.active_weapon_slot == "throwable" or player.equipped_weapon_data.get("type", "") == "throwable":
				var amt = player.equipped_weapon_data.get("amount", 1)
				ammo_label.text = "💣 수량: %d개" % amt
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			else:
				var cur_mag = player.equipped_weapon_data.get("current_magazine_ammo", 0)
				var stats = player.equipped_weapon_data.get("computed_stats", {})
				var mag_size = stats.get("magazine_size", 15)
				var reserve_ammo = player._get_available_ammo_count() if player.has_method("_get_available_ammo_count") else 0
				var cal = player._get_compatible_ammo_types()[0] if player.has_method("_get_compatible_ammo_types") and player._get_compatible_ammo_types().size() > 0 else "탄약"
				ammo_label.text = "🔫 %d / %d  [%s: %d]" % [cur_mag, mag_size, cal, reserve_ammo]
				ammo_label.add_theme_color_override("font_color", Color.RED if cur_mag == 0 else Color(0.4, 1.0, 0.6))
		if weapon_durability_bar:
			var max_dur = wep_data.get("max_durability", 100.0)
			var cur_dur = player.equipped_weapon_data.get("durability", max_dur)
			weapon_durability_bar.max_value = max_dur
			weapon_durability_bar.value = cur_dur
			var fill_style: StyleBoxFlat = weapon_durability_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if not fill_style:
				fill_style = StyleBoxFlat.new()
				weapon_durability_bar.add_theme_stylebox_override("fill", fill_style)
			var ratio = float(cur_dur) / max(1.0, float(max_dur))
			var target_fill_col = Color(0.2, 0.8, 0.3) if ratio > 0.6 else (Color(0.9, 0.7, 0.1) if ratio > 0.3 else Color(0.9, 0.2, 0.2))
			if fill_style.bg_color != target_fill_col:
				fill_style.bg_color = target_fill_col

func _setup_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	var slot1 = quickslot_hbox.get_node_or_null("Slot1")
	var slot2 = quickslot_hbox.get_node_or_null("Slot2")
	var slot3 = quickslot_hbox.get_node_or_null("Slot3")
	var slot4 = quickslot_hbox.get_node_or_null("Slot4")
	var slot5 = quickslot_hbox.get_node_or_null("Slot5")
	var slot6 = quickslot_hbox.get_node_or_null("Slot6")
	var slot7 = quickslot_hbox.get_node_or_null("Slot7")
	var slotN = quickslot_hbox.get_node_or_null("SlotN")
	if slot1 and not slot1.pressed.is_connected(_on_quickslot_1_pressed): slot1.pressed.connect(_on_quickslot_1_pressed)
	if slot2 and not slot2.pressed.is_connected(_on_quickslot_2_pressed): slot2.pressed.connect(_on_quickslot_2_pressed)
	if slot3 and not slot3.pressed.is_connected(_on_quickslot_3_pressed): slot3.pressed.connect(_on_quickslot_3_pressed)
	if slot4 and not slot4.pressed.is_connected(_on_quickslot_4_pressed): slot4.pressed.connect(_on_quickslot_4_pressed)
	if slot5 and not slot5.pressed.is_connected(_on_quickslot_5_pressed): slot5.pressed.connect(_on_quickslot_5_pressed)
	if slot6 and not slot6.pressed.is_connected(_on_quickslot_6_pressed): slot6.pressed.connect(_on_quickslot_6_pressed)
	if slot7 and not slot7.pressed.is_connected(_on_quickslot_7_pressed): slot7.pressed.connect(_on_quickslot_7_pressed)
	if slotN and not slotN.pressed.is_connected(_on_quickslot_N_pressed): slotN.pressed.connect(_on_quickslot_N_pressed)
	_update_quickslot_bar()

func _on_quickslot_1_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("primary1")
		_update_quickslot_bar()

func _on_quickslot_2_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("primary2")
		_update_quickslot_bar()

func _on_quickslot_3_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("sidearm")
		_update_quickslot_bar()

func _on_quickslot_4_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("throwable")
		_update_quickslot_bar()

func _on_quickslot_5_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"): player._use_quickslot_item("bleed")

func _on_quickslot_6_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"): player._use_quickslot_item("heal")

func _on_quickslot_7_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"): player._use_quickslot_item("ration")

func _on_quickslot_N_pressed() -> void:
	if player and player.player_lighting and player.player_lighting.has_method("toggle_nvg"):
		player.player_lighting.toggle_nvg()
		if SoundManager: SoundManager.play("menu_select")
		_update_quickslot_bar()

func _update_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	HudTacticalHelper.update_quickslot_bar(quickslot_hbox, player)

func _on_player_channel_started(duration: float, item_name: String) -> void:
	if channeling_bar:
		channeling_bar.visible = true
		channeling_bar.max_value = duration
		channeling_bar.value = 0.0
		if channeling_label:
			channeling_label.text = "%s 사용 중... (%.1f초)" % [item_name, duration]

func _on_player_channel_progress(current: float, total: float) -> void:
	if channeling_bar:
		channeling_bar.value = current
		if channeling_label:
			var rem = max(0.0, total - current)
			channeling_label.text = "%s (%.1f초)" % [player.channel_item_name, rem]
	if quickslot_hbox and player:
		var ratio = current / max(0.01, total)
		var item_str = player.channel_item_name
		var slot_key = "6"
		if item_str.contains("붕대") or item_str.contains("지혈"): slot_key = "5"
		elif item_str.contains("구급") or item_str.contains("키트") or item_str.contains("부목"): slot_key = "6"
		elif item_str.contains("식량") or item_str.contains("통조림") or item_str.contains("생수") or item_str.contains("물"): slot_key = "7"
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, slot_key, ratio)

func _on_player_channel_finished() -> void:
	if channeling_bar:
		channeling_bar.visible = false
	if quickslot_hbox:
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, "clear", 0.0)
	_update_quickslot_bar()

func _on_interact_prompt(can_interact: bool, text: String) -> void:
	if interact_prompt and current_inventory_window == null:
		interact_prompt.visible = can_interact
		var check_pos = player.global_position + Vector2.RIGHT.rotated(player.rotation) * 32.0
		var t_pos = object_layer.local_to_map(check_pos)
		if t_pos == exit_tile_pos:
			interact_prompt.text = "[E] 건물 밖으로 나가기"
		else:
			interact_prompt.text = text
	elif interact_prompt:
		interact_prompt.visible = false

func _on_object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i) -> void:
	if current_inventory_window != null: return
	
	if tile_pos == exit_tile_pos or (type == TileManager.OBJ_DOOR_OPEN and tile_pos.y >= building_data["height"] - 1):
		_exit_interior()
		return
		
	if type == TileManager.OBJ_DOOR_CLOSED:
		object_layer.set_cell(tile_pos, 0, TileManager.OBJ_DOOR_OPEN)
		EventBus.noise_created.emit(world_pos, 100.0, "door")
		if SoundManager: SoundManager.play("menu_select")
		return
	elif type == TileManager.OBJ_DOOR_OPEN:
		object_layer.set_cell(tile_pos, 0, TileManager.OBJ_DOOR_CLOSED)
		EventBus.noise_created.emit(world_pos, 100.0, "door")
		if SoundManager: SoundManager.play("menu_select")
		return
		
	if container_inventories.has(tile_pos):
		var inv = container_inventories[tile_pos]
		var title = "수납함" if type == TileManager.OBJ_FURNITURE else "보급 상자"
		_open_loot_window(inv, title)

func _exit_interior() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager:
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		GameManager.current_world_data["player"]["inventory"] = get_backpack_items()
		if player and not player.equipment.is_empty():
			GameManager.current_world_data["player"]["equipment"] = player.equipment.duplicate(true)
		GameManager.current_world_data["raid_time_remaining"] = raid_time_remaining
		if player:
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
	get_tree().change_scene_to_file("res://scenes/world/main_world.tscn")

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
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
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

func _toggle_pause() -> void:
	var next_pause_state = not get_tree().paused
	get_tree().paused = next_pause_state
	pause_menu.visible = next_pause_state
	if GameManager:
		GameManager.is_paused = next_pause_state

func _on_resume_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	_toggle_pause()

func get_backpack_items() -> Array:
	var items_arr = []
	if player and player.inventory_grid:
		for item in player.inventory_grid.items:
			if item and not item.is_empty():
				items_arr.append(item.duplicate(true))
	return items_arr

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		if player and not player.equipment.is_empty():
			if not GameManager.current_world_data.has("player"):
				GameManager.current_world_data["player"] = {}
			GameManager.current_world_data["player"]["equipment"] = player.equipment.duplicate(true)
		var is_sandbox = GameManager.current_world_data.get("world_settings", {}).get("mode", "") == "sandbox"
		if is_sandbox:
			GameManager.end_raid("survived", get_backpack_items())
		else:
			GameManager.end_raid("mia", get_backpack_items())
