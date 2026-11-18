extends CharacterBody2D
class_name Player

signal stats_changed
signal interact_prompt(can_interact: bool, prompt_text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)
signal channel_started(duration: float, item_name: String)
signal channel_progress(current: float, total: float)
signal channel_completed()
signal channel_cancelled()

@export var walk_speed: float = 120.0
@export var sprint_speed: float = 210.0
@export var crouch_speed: float = 60.0
@export var acceleration: float = 1200.0
@export var friction: float = 900.0

var is_crouching: bool = false
var is_sprinting: bool = false
var _overweight_tier: int = 0

var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_duration: float = 0.0
var channel_item_name: String = ""
var channel_on_complete: Callable = Callable()

var inventory_grid: InventoryGrid

@onready var survival_stats = $SurvivalStats
@onready var weapon_handler = $WeaponHandler
@onready var interaction_detector = $InteractionDetector
@onready var player_lighting = $PlayerLighting
@onready var player_camera = $PlayerCamera
@onready var player_visuals = $Visuals

func _stats() -> Node:
	return survival_stats if survival_stats else get_node_or_null("SurvivalStats")

func _weapons() -> Node:
	return weapon_handler if weapon_handler else get_node_or_null("WeaponHandler")

func _lighting() -> Node:
	return player_lighting if player_lighting else get_node_or_null("PlayerLighting")

# 외부 호환성을 위한 프록시 프로퍼티들
var hp: float:
	get:
		var s = _stats()
		return s.hp if s else 100.0
	set(v):
		var s = _stats()
		if s: s.hp = v
var stamina: float:
	get:
		var s = _stats()
		return s.stamina if s else 100.0
	set(v):
		var s = _stats()
		if s: s.stamina = v
var hunger: float:
	get:
		var s = _stats()
		return s.hunger if s else 100.0
	set(v):
		var s = _stats()
		if s: s.hunger = v
var thirst: float:
	get:
		var s = _stats()
		return s.thirst if s else 100.0
	set(v):
		var s = _stats()
		if s: s.thirst = v
var is_god_mode: bool:
	get:
		var s = _stats()
		return s.is_god_mode if s else false
	set(v):
		var s = _stats()
		if s: s.is_god_mode = v

var is_bleeding: bool:
	get:
		var s = _stats()
		return s.is_bleeding if s else false
	set(v):
		var s = _stats()
		if s: s.is_bleeding = v
var is_infected: bool:
	get:
		var s = _stats()
		return s.is_infected if s else false
	set(v):
		var s = _stats()
		if s: s.is_infected = v
var is_fractured: bool:
	get:
		var s = _stats()
		return s.is_fractured if s else false
	set(v):
		var s = _stats()
		if s: s.is_fractured = v
var is_exhausted: bool:
	get:
		var s = _stats()
		return s.is_exhausted if s else false
	set(v):
		var s = _stats()
		if s: s.is_exhausted = v

var max_hp: float:
	get:
		var s = _stats()
		return s.max_hp if s else 100.0
	set(v):
		var s = _stats()
		if s: s.max_hp = v
var max_stamina: float:
	get:
		var s = _stats()
		return s.max_stamina if s else 100.0
	set(v):
		var s = _stats()
		if s: s.max_stamina = v
var max_hunger: float:
	get:
		var s = _stats()
		return s.max_hunger if s else 100.0
	set(v):
		var s = _stats()
		if s: s.max_hunger = v
var max_thirst: float:
	get:
		var s = _stats()
		return s.max_thirst if s else 100.0
	set(v):
		var s = _stats()
		if s: s.max_thirst = v
var armor_defense: float:
	get:
		var s = _stats()
		return s.armor_defense if s else 0.0
	set(v):
		var s = _stats()
		if s: s.armor_defense = v

var equipment: Dictionary:
	get:
		var w = _weapons()
		return w.equipment if w else {}
	set(v):
		var w = _weapons()
		if w: w.equipment = v
var equipped_weapon: String:
	get:
		var w = _weapons()
		return w.equipped_weapon if w else "맨손"
	set(v):
		var w = _weapons()
		if w: w.equipped_weapon = v
var equipped_weapon_data: Dictionary:
	get:
		var w = _weapons()
		return w.equipped_weapon_data if w else {}
	set(v):
		var w = _weapons()
		if w: w.equipped_weapon_data = v
var active_weapon_slot: String:
	get:
		var w = _weapons()
		return w.active_weapon_slot if w else "primary1"
	set(v):
		var w = _weapons()
		if w: w.active_weapon_slot = v

var flashlight_enabled: bool:
	get:
		var l = _lighting()
		return l.flashlight_enabled if l else true
	set(v):
		var l = _lighting()
		if l: l.set_flashlight(v)

func _ready() -> void:
	add_to_group("player")
	if not has_node("InventoryGrid"):
		inventory_grid = InventoryGrid.new()
		inventory_grid.name = "InventoryGrid"
		inventory_grid.has_secure_container = true
		inventory_grid.resize_grid(6, 5)
		add_child(inventory_grid)
	else:
		inventory_grid = get_node("InventoryGrid")
		inventory_grid.has_secure_container = true


	# 컴포넌트 시그널 릴레이
	if survival_stats:
		survival_stats.stats_changed.connect(func(): stats_changed.emit())
	if interaction_detector:
		interaction_detector.interact_prompt.connect(func(can, text): interact_prompt.emit(can, text))
		interaction_detector.object_interacted.connect(func(pos, tile, type): object_interacted.emit(pos, tile, type))

	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_death)

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

func _physics_process(delta: float) -> void:
	if hp <= 0: return
	_handle_movement(delta)
	_handle_channeling(delta)

func _unhandled_input(event: InputEvent) -> void:
	if hp <= 0: return
	
	if event.is_action_pressed("flashlight"):
		player_lighting.toggle_flashlight()
		if SoundManager: SoundManager.play("menu_select")
		
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var r_code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if r_code == KEY_R and event.alt_pressed:
			if weapon_handler and weapon_handler.has_method("cycle_ammo_type"):
				weapon_handler.cycle_ammo_type()
			get_viewport().set_input_as_handled()
			return
		
	if event.is_action_pressed("reload"):
		weapon_handler.start_reload()
		
	if event.is_action_pressed("attack"):
		if is_channeling:
			cancel_channeling()
		weapon_handler.try_attack(Vector2.RIGHT.rotated(rotation), global_position)
		
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if is_channeling:
				cancel_channeling()
			weapon_handler.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_channeling:
				cancel_channeling()
			weapon_handler.cycle_weapon(1)
			
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_1 or code == KEY_KP_1:
			if is_channeling: cancel_channeling()
			weapon_handler.switch_weapon_slot("primary1")
		elif code == KEY_2 or code == KEY_KP_2:
			if is_channeling: cancel_channeling()
			weapon_handler.switch_weapon_slot("primary2")
		elif code == KEY_3 or code == KEY_KP_3:
			if is_channeling: cancel_channeling()
			weapon_handler.switch_weapon_slot("sidearm")
		elif code == KEY_4 or code == KEY_KP_4:
			if is_channeling: cancel_channeling()
			weapon_handler.switch_weapon_slot("throwable")
		elif code == KEY_5 or code == KEY_KP_5: _use_quickslot_item("bleed")
		elif code == KEY_6 or code == KEY_KP_6: _use_quickslot_item("heal")
		elif code == KEY_7 or code == KEY_KP_7: _use_quickslot_item("ration")
		elif code == KEY_N or event.keycode == KEY_N or event.physical_keycode == KEY_N:
			var l = _lighting()
			if l and l.has_method("toggle_nvg"):
				l.toggle_nvg()
				if SoundManager: SoundManager.play("menu_select")
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🥽 야간투시경(NVG): %s" % ("ON" if l.nvg_enabled else "OFF"))

func get_effective_max_stamina() -> float:
	var s = _stats()
	return s.get_effective_max_stamina() if (s and s.has_method("get_effective_max_stamina")) else max_stamina

func apply_medical_effects(item_id: String) -> bool:
	var d := ItemDatabase.get_item_data(item_id)
	var effects: Dictionary = d.get("effects", {})
	var cured := false
	if effects.has("hp"):
		hp = min(max_hp, hp + float(effects["hp"]))
		cured = true
	if effects.get("cures_bleeding", false) and is_bleeding:
		is_bleeding = false
		cured = true
	if effects.get("cures_fracture", false) and is_fractured:
		is_fractured = false
		cured = true
	if (effects.get("cures_infection", false) or int(effects.get("infection", 0)) < 0 or item_id in ["항생제", "고급 치료킷", "수술 키트"]) and is_infected:
		is_infected = false
		cured = true
	stats_changed.emit()
	return cured

func static_get_channeling_duration(item_id: String, item_data: Dictionary = {}) -> float:
	return get_channeling_duration_for(item_id, item_data)

static func get_channeling_duration_for(item_id: String, item_data: Dictionary = {}) -> float:
	var cat = item_data.get("category", -1)
	var eff = item_data.get("effects", {})
	if item_id.contains("붕대") or item_id.contains("지혈") or item_id == "bandage":
		return 1.5
	elif item_id.contains("구급") or item_id.contains("수술") or item_id.contains("키트") or item_id.contains("부목") or item_id == "medkit":
		return 3.0
	elif cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or eff.has("hunger") or eff.has("thirst") or item_id.contains("통조림") or item_id.contains("식량") or item_id.contains("생수") or item_id.contains("음료") or item_id == "canned_beef":
		return 2.0
	elif cat == ItemDatabase.ItemCategory.MEDICAL:
		return 2.0
	return 2.0

func start_channeling(duration: float, item_name: String, on_complete_callable: Callable) -> void:
	if is_channeling:
		cancel_channeling()
	is_channeling = true
	channel_duration = max(0.1, duration)
	channel_timer = 0.0
	channel_item_name = item_name
	channel_on_complete = on_complete_callable
	channel_started.emit(channel_duration, item_name)
	channel_progress.emit(0.0, channel_duration)

func cancel_channeling() -> void:
	if not is_channeling:
		return
	is_channeling = false
	channel_timer = 0.0
	channel_duration = 0.0
	channel_on_complete = Callable()
	var prev_name = channel_item_name
	channel_item_name = ""
	channel_cancelled.emit()
	if EventBus.has_signal("event_logged") and prev_name != "":
		EventBus.event_logged.emit("❌ [%s] 사용이 취소되었습니다." % prev_name)

func complete_channeling() -> void:
	if not is_channeling:
		return
	is_channeling = false
	channel_timer = 0.0
	channel_duration = 0.0
	channel_item_name = ""
	var cb = channel_on_complete
	channel_on_complete = Callable()
	if cb.is_valid():
		cb.call()
	channel_completed.emit()

func _handle_channeling(delta: float) -> void:
	if not is_channeling:
		return
	channel_timer += delta
	channel_progress.emit(channel_timer, channel_duration)
	if channel_timer >= channel_duration:
		complete_channeling()

func use_consumable_item(item: Dictionary, item_data: Dictionary = {}, log_prefix: String = "") -> bool:
	if item.is_empty():
		return false
	var item_id := String(item.get("id", ""))
	var d: Dictionary = item_data if not item_data.is_empty() else (ItemDatabase.get_item_data(item_id) if ItemDatabase else {})
	var item_name := String(d.get("name", item_id))
	var duration := get_channeling_duration_for(item_id, d)
	var target_uid := String(item.get("uid", ""))
	var effects: Dictionary = d.get("effects", {}).duplicate(true)

	start_channeling(duration, item_name, func():
		if not is_instance_valid(self):
			return
		if effects.has("hp"):
			hp = min(max_hp, hp + float(effects["hp"]))
		if effects.has("hunger"):
			hunger = min(max_hunger, hunger + float(effects["hunger"]))
		if effects.has("thirst"):
			thirst = min(max_thirst, thirst + float(effects["thirst"]))
		if effects.has("stamina"):
			stamina = min(max_stamina, stamina + float(effects["stamina"]))
		if effects.get("cures_bleeding", false):
			is_bleeding = false
		if effects.get("cures_fracture", false):
			is_fractured = false
		if effects.get("cures_infection", false) or float(effects.get("infection", 0)) < 0.0:
			is_infected = false

		if inventory_grid:
			var cur_item: Dictionary = {}
			if target_uid != "":
				var uid_res := inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
					return String(it.get("uid", "")) == target_uid
				)
				if bool(uid_res.get("found", false)):
					cur_item = uid_res.get("item", {})
			if cur_item.is_empty():
				var id_res := inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
					return String(it.get("id", "")) == item_id
				)
				if bool(id_res.get("found", false)):
					cur_item = id_res.get("item", {})
			if not cur_item.is_empty():
				var amt := int(cur_item.get("amount", 1))
				if amt > 1:
					cur_item["amount"] = amt - 1
					inventory_grid.grid_changed.emit()
				else:
					inventory_grid.remove_item_by_uid_recursive(String(cur_item.get("uid", "")))
			elif target_uid != "":
				inventory_grid.remove_item_by_uid_recursive(target_uid)

		stats_changed.emit()
		if SoundManager:
			SoundManager.play("menu_select")
		if EventBus and EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("💊 %s%s 사용 완료!" % [log_prefix, item_name])
	)
	if SoundManager:
		SoundManager.play("menu_select")
	if EventBus and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("⏳ %s 사용 시작 (%.1f초)..." % [item_name, duration])
	return true

func _use_quickslot_item(slot_kind: String) -> void:
	if not inventory_grid:
		return
	var target_item: Dictionary = {}
	var target_data: Dictionary = {}
	for item in inventory_grid.get_all_items_flat(true):
		var id = item.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var cat = d.get("category", -1)
		var eff = d.get("effects", {})
		if slot_kind == "bleed" and cat == ItemDatabase.ItemCategory.MEDICAL and (eff.get("cures_bleeding", false) or id.contains("붕대") or id.contains("지혈")):
			target_item = item
			target_data = d
			break
		elif slot_kind == "heal" and cat == ItemDatabase.ItemCategory.MEDICAL and (eff.get("hp", 0) > 0 or eff.get("cures_fracture", false) or eff.get("cures_infection", false) or id.contains("구급") or id.contains("키트") or id.contains("부목")):
			target_item = item
			target_data = d
			break
		elif slot_kind == "ration" and (cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or eff.has("hunger") or eff.has("thirst")):
			target_item = item
			target_data = d
			break
	if target_item.is_empty():
		if EventBus.has_signal("event_logged"):
			var label_map = {"bleed": "지혈제/붕대 [5]", "heal": "구급상자/부목 [6]", "ration": "식량/생수 [7]"}
			EventBus.event_logged.emit("⚠️ 가방에 사용할 수 있는 %s 아이템이 없습니다." % label_map.get(slot_kind, "소비"))
		return

	use_consumable_item(target_item, target_data, "[퀵슬롯] ")

func _play_surface_footstep() -> void:
	if not SoundManager:
		return
	var sfx = "footstep_grass"
	var chunk_mgr = get_node_or_null("/root/MainWorld/ChunkManager")
	if chunk_mgr and chunk_mgr.ground_layer:
		var t_pos = chunk_mgr.ground_layer.local_to_map(global_position)
		var atlas = chunk_mgr.ground_layer.get_cell_atlas_coords(t_pos)
		if TileManager.is_road_asphalt(atlas) or TileManager.is_sidewalk_tile(atlas):
			sfx = "footstep_concrete"
		elif atlas == TileManager.TILE_FLOOR_WOOD:
			sfx = "footstep_wood"
		elif atlas == TileManager.TILE_FLOOR_TILE:
			sfx = "footstep_concrete"
		elif atlas == Vector2i(7, 2):
			sfx = "footstep_water"
	SoundManager.play(sfx)
	if is_sprinting and EventBus.has_signal("noise_created"):
		EventBus.noise_created.emit(global_position, 140.0, "footstep")

func show_floating_text(text: String, color: Color = Color(1.0, 0.9, 0.4), duration: float = 0.8) -> void:
	var vis = player_visuals if player_visuals else get_node_or_null("Visuals")
	if vis and vis.has_method("show_floating_text"):
		vis.show_floating_text(text, color, duration)

func get_total_weight() -> float:
	var total = inventory_grid.get_total_weight() if inventory_grid else 0.0
	for slot in ["primary1", "primary2", "sidearm", "throwable", "helmet", "vest", "backpack"]:
		var eq: Dictionary = equipment.get(slot, {})
		if not eq.is_empty():
			total += InventoryGrid.get_item_total_weight(eq)
	return total

func _handle_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	if input_vector.x == 0: input_vector.x = int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	input_vector.y = Input.get_axis("move_up", "move_down")
	if input_vector.y == 0: input_vector.y = int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	input_vector = input_vector.normalized()
	
	is_crouching = Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_CTRL)
	is_sprinting = Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	if is_channeling:
		is_sprinting = false
	
	# 무게 과적(Overweight) 단계별 페널티 (35kg 주의: 스태미나 소모 1.3배 / 50kg 초과: 질주 불가 및 이속 -35%)
	var total_weight = get_total_weight()
	var cur_overweight_tier = 2 if total_weight > 50.0 else (1 if total_weight >= 35.0 else 0)
	if cur_overweight_tier > _overweight_tier:
		show_floating_text("[OVERWEIGHT]", Color(1.0, 0.3, 0.3) if cur_overweight_tier == 2 else Color(1.0, 0.8, 0.25))
	_overweight_tier = cur_overweight_tier
	
	if cur_overweight_tier >= 2:
		is_sprinting = false
	
	var target_speed = walk_speed
	var speed_mult = 1.0
	var stamina_drain_mult = 1.3 if cur_overweight_tier >= 1 else 1.0
	
	if cur_overweight_tier >= 2:
		speed_mult *= 0.65
	if is_channeling:
		speed_mult *= 0.45
	if is_fractured: speed_mult *= 0.6
	if equipment.has("backpack") and not equipment["backpack"].is_empty():
		speed_mult -= 0.1
		
	var w_data = weapon_handler.equipped_weapon_data if weapon_handler else {}
	if not w_data.is_empty() and w_data.has("computed_stats"):
		var w_weight = w_data["computed_stats"].get("weight", 3.0)
		speed_mult -= min(0.3, w_weight * 0.05)
	speed_mult = max(0.25, speed_mult)
		
	if is_crouching:
		target_speed = crouch_speed * speed_mult
		if survival_stats: survival_stats.regen_stamina(delta, 1.5)
	elif is_sprinting and not is_exhausted and input_vector.length() > 0:
		target_speed = sprint_speed * speed_mult
		if survival_stats: survival_stats.consume_stamina(15.0 * stamina_drain_mult * delta)
	else:
		target_speed = walk_speed * speed_mult
		if input_vector.length() == 0:
			if survival_stats: survival_stats.regen_stamina(delta, 2.0)
		else:
			if survival_stats: survival_stats.regen_stamina(delta, 0.5)
			
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * target_speed, acceleration * delta)
		if randf() < (0.08 if is_sprinting else 0.045):
			_play_surface_footstep()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	if player_camera:
		player_camera.is_aiming_ads = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_sprinting
		if player_camera.is_aiming_ads:
			velocity *= 0.5
		
	move_and_slide()

func set_flashlight(enabled: bool) -> void:
	var l = _lighting()
	if l:
		l.set_flashlight(enabled)

func refresh_equipped_weapon(prefer_first_available: bool = true) -> void:
	var w = _weapons()
	if w:
		if prefer_first_available:
			var cur_dict = equipment.get(active_weapon_slot, {})
			if cur_dict.is_empty():
				for slot in WeaponHandler.WEAPON_SLOT_ORDER:
					var d = equipment.get(slot, {})
					if not d.is_empty():
						active_weapon_slot = slot
						break
		w.switch_weapon_slot(active_weapon_slot)

func switch_weapon_slot(slot_name: String) -> void:
	if is_channeling:
		cancel_channeling()
	var w = _weapons()
	if w:
		w.switch_weapon_slot(slot_name)

func cycle_weapon(direction: int) -> void:
	if is_channeling:
		cancel_channeling()
	var w = _weapons()
	if w:
		w.cycle_weapon(direction)

func _get_available_ammo_count() -> int:
	var w = _weapons()
	return w.get_available_ammo_count() if w else 0

func _get_compatible_ammo_types() -> Array:
	var w = _weapons()
	return w.get_compatible_ammo_types() if w else ["9mm"]

func _get_slot_display_name(slot_name: String) -> String:
	var w = _weapons()
	return w.get_slot_display_name(slot_name) if w else slot_name

func apply_backpack_grid_size() -> void:
	if not inventory_grid: return
	var bp = equipment.get("backpack", {})
	var new_w = 6
	var new_h = 3
	if not bp.is_empty():
		var id = bp.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var b_grid = d.get("backpack_grid", Vector2i(6, 5))
		new_w = b_grid.x
		new_h = b_grid.y
	if inventory_grid.has_method("resize_grid"):
		inventory_grid.resize_grid(new_w, new_h)
	elif inventory_grid.has_method("resize"):
		inventory_grid.resize(new_w, new_h)

func apply_damage(amount: float, source: String = "unknown") -> void:
	_on_player_damaged(amount, source)

func take_damage(amount: float, source: String = "unknown") -> void:
	_on_player_damaged(amount, source)

var _hit_flash_tween: Tween = null
var _is_dying: bool = false

func _on_player_damaged(amount: float, source: String) -> void:
	if is_channeling:
		cancel_channeling()
	if survival_stats:
		survival_stats.take_damage(amount, source)
	if source != "status_effect":
		if SoundManager:
			SoundManager.play("hit_melee")
		if player_visuals and player_visuals.material:
			if _hit_flash_tween:
				_hit_flash_tween.kill()
			_hit_flash_tween = create_tween()
			player_visuals.material.set_shader_parameter("flash_color", Color(1.0, 0.25, 0.25, 1.0))
			player_visuals.material.set_shader_parameter("flash_modifier", 0.85)
			_hit_flash_tween.tween_property(player_visuals.material, "shader_parameter/flash_modifier", 0.0, 0.18)

func _on_death() -> void:
	if _is_dying: return
	_is_dying = true
	velocity = Vector2.ZERO
	if SoundManager: SoundManager.play("player_death")
	EventBus.event_logged.emit("☠️ 플레이어가 사망했습니다. (작전 실패)")
	var cur_items: Array = inventory_grid.items.duplicate(true) if inventory_grid else []
	var timer = get_tree().create_timer(1.2, true, false, true)
	timer.timeout.connect(func():
		get_tree().paused = false
		if GameManager:
			GameManager.is_paused = false
			GameManager.end_raid("kia", cur_items)
	)
