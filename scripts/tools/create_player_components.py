import os

os.makedirs("scenes/entities/player", exist_ok=True)

# 1. survival_stats.gd
survival_stats = """extends Node
class_name SurvivalStats

signal stats_changed

@export var max_hp: float = 100.0
var hp: float = 100.0
@export var max_stamina: float = 100.0
var stamina: float = 100.0
@export var max_hunger: float = 100.0
var hunger: float = 100.0
@export var max_thirst: float = 100.0
var thirst: float = 100.0

var is_bleeding: bool = false
var is_infected: bool = false
var is_fractured: bool = false
var is_exhausted: bool = false
var is_god_mode: bool = false

var armor_defense: float = 0.0

func _process(delta: float) -> void:
	if is_god_mode:
		hunger = max_hunger
		thirst = max_thirst
		hp = max_hp
		stamina = max_stamina
		stats_changed.emit()
		return
		
	hunger -= 0.15 * delta
	thirst -= 0.25 * delta
	
	if is_bleeding: hp -= 1.0 * delta
	if is_infected: hp -= 0.5 * delta
	if hunger <= 0: hp -= 0.5 * delta
	if thirst <= 0: hp -= 1.0 * delta
	
	hunger = clamp(hunger, 0.0, max_hunger)
	thirst = clamp(thirst, 0.0, max_thirst)
	hp = clamp(hp, 0.0, max_hp)
	
	if hp <= 0:
		EventBus.player_died.emit()
		
	stats_changed.emit()

func regen_stamina(delta: float, multiplier: float) -> void:
	if hunger > 20.0 and thirst > 20.0:
		stamina += 10.0 * multiplier * delta
	stamina = clamp(stamina, 0.0, max_stamina)
	if is_exhausted and stamina >= 25.0:
		is_exhausted = false

func consume_stamina(amount: float) -> void:
	stamina -= amount
	if stamina <= 0.0:
		is_exhausted = true

func take_damage(amount: float, source: String) -> void:
	if is_god_mode: return
	var dmg_reduction = armor_defense / (armor_defense + 100.0)
	var actual_damage = max(1.0, amount * (1.0 - dmg_reduction))
	hp -= actual_damage
	if source == "zombie" and randf() < 0.3:
		is_infected = true
	elif source == "gunfire" and randf() < 0.5:
		is_bleeding = true
	stats_changed.emit()
"""

# 2. weapon_handler.gd
weapon_handler = """extends Node
class_name WeaponHandler

signal weapon_changed
signal ammo_changed

const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
const WEAPON_SLOT_ORDER: Array[String] = ["primary1", "primary2", "sidearm", "throwable"]

var equipped_weapon: String = "맨손"
var equipped_weapon_data: Dictionary = {}
var active_weapon_slot: String = "primary1"
var equipment: Dictionary = {}

var attack_cooldown_timer: float = 0.0
var recoil_offset: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0

@onready var player = get_parent()

func _process(delta: float) -> void:
	recoil_offset = lerp(recoil_offset, 0.0, delta * 15.0)
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()

func switch_weapon_slot(slot_name: String) -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		
	active_weapon_slot = slot_name
	var weapon_dict = equipment.get(slot_name, {})
	
	if weapon_dict.is_empty():
		equipped_weapon_data = {}
		equipped_weapon = "맨손"
		EventBus.event_logged.emit("✋ [%s] 슬롯: 비어있음 (맨손)" % _get_slot_display_name(slot_name))
	elif slot_name == "throwable":
		var t_id = weapon_dict.get("id", "수류탄")
		equipped_weapon = weapon_dict.get("name", t_id)
		equipped_weapon_data = {
			"id": t_id, "name": equipped_weapon, "type": "throwable",
			"amount": weapon_dict.get("amount", 1),
			"computed_stats": {"damage": 120.0, "rpm": 60, "noise_radius": 800.0}
		}
		EventBus.event_logged.emit("💣 투척 무기: %s (x%d)" % [equipped_weapon, weapon_dict.get("amount", 1)])
	else:
		var rec_id = weapon_dict.get("id", "")
		if not weapon_dict.has("attachments"): weapon_dict["attachments"] = {}
		equipped_weapon_data = WeaponPartsDatabase.compute_weapon_from_dict(weapon_dict)
		var w_name = weapon_dict.get("name", "")
		if w_name == "":
			var idata = ItemDatabase.get_item_data(rec_id)
			w_name = idata.get("name", rec_id)
		equipped_weapon = w_name
		if weapon_dict.has("current_magazine_ammo"):
			equipped_weapon_data["current_magazine_ammo"] = weapon_dict["current_magazine_ammo"]
		EventBus.event_logged.emit("🔫 무기 전환: %s [%s]" % [w_name, _get_slot_display_name(slot_name)])
			
	weapon_changed.emit()

func cycle_weapon(direction: int) -> void:
	var cur_idx = WEAPON_SLOT_ORDER.find(active_weapon_slot)
	if cur_idx == -1: cur_idx = 0
	var new_idx = (cur_idx + direction) % WEAPON_SLOT_ORDER.size()
	if new_idx < 0: new_idx = WEAPON_SLOT_ORDER.size() - 1
	switch_weapon_slot(WEAPON_SLOT_ORDER[new_idx])

func try_attack(aim_dir: Vector2, spawn_pos: Vector2) -> void:
	if attack_cooldown_timer > 0 or is_reloading: return
	
	if equipped_weapon_data.is_empty():
		_melee_punch(aim_dir, spawn_pos)
		return
		
	if equipped_weapon_data.get("type", "") == "throwable" or active_weapon_slot == "throwable":
		_throw_grenade(aim_dir, spawn_pos)
		return
		
	var stats = equipped_weapon_data.get("computed_stats", {})
	var rpm = stats.get("rpm", 150)
	attack_cooldown_timer = 60.0 / float(max(60, rpm))
	
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	if cur_mag <= 0:
		start_reload()
		return
		
	equipped_weapon_data["current_magazine_ammo"] = cur_mag - 1
	if equipment.has(active_weapon_slot) and not equipment[active_weapon_slot].is_empty():
		equipment[active_weapon_slot]["current_magazine_ammo"] = cur_mag - 1
	ammo_changed.emit()
	
	var recoil_val = stats.get("recoil", 20.0)
	recoil_offset = recoil_val * 0.2
	
	if stats.get("muzzle_flash", true):
		if player.has_node("PlayerLighting"):
			player.get_node("PlayerLighting").trigger_muzzle_flash()
			
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("muzzle", spawn_pos.x, spawn_pos.y, 4, aim_dir.angle())
		ps.emit("bullet_shell", spawn_pos.x, spawn_pos.y, 1, aim_dir.angle())
		
	EventBus.noise_created.emit(spawn_pos, stats.get("noise_radius", 600.0), "gunshot")
	
	var pellets = stats.get("pellets", 1)
	var dmg_per_pellet = stats.get("damage", 20.0)
	var accuracy = stats.get("accuracy", 75.0)
	var spread_max = deg_to_rad(max(1.0, (100.0 - accuracy) * 0.35))
	
	for p in range(pellets):
		var spread = randf_range(-spread_max, spread_max)
		var pellet_dir = aim_dir.rotated(spread)
		var bullet = BulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.setup(spawn_pos, pellet_dir, dmg_per_pellet)
		
	if SoundManager: SoundManager.play("hit_ranged")

func _melee_punch(aim_dir: Vector2, spawn_pos: Vector2) -> void:
	attack_cooldown_timer = 0.4
	recoil_offset = 6.0
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.setup(spawn_pos, aim_dir, 15.0)
	if SoundManager: SoundManager.play("hit_melee")
	EventBus.noise_created.emit(spawn_pos, 80.0, "punch")

func _throw_grenade(aim_dir: Vector2, spawn_pos: Vector2) -> void:
	var amt = equipped_weapon_data.get("amount", 1)
	if amt <= 0: return
	attack_cooldown_timer = 0.8
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.setup(spawn_pos, aim_dir, 120.0)
	
	amt -= 1
	equipped_weapon_data["amount"] = amt
	if equipment.has("throwable") and not equipment["throwable"].is_empty():
		if amt <= 0: equipment["throwable"] = {}
		else: equipment["throwable"]["amount"] = amt
			
	if SoundManager: SoundManager.play("menu_select")
	EventBus.noise_created.emit(spawn_pos, 200.0, "grenade_throw")
	ammo_changed.emit()

func start_reload() -> void:
	if is_reloading or equipped_weapon_data.is_empty() or active_weapon_slot == "throwable": return
	var stats = equipped_weapon_data.get("computed_stats", {})
	if equipped_weapon_data.get("current_magazine_ammo", 0) >= stats.get("magazine_size", 15): return
	
	if get_available_ammo_count() <= 0:
		EventBus.event_logged.emit("⚠️ 장전할 수 있는 호환 탄약이 없습니다!")
		if SoundManager: SoundManager.play("hit_melee")
		return
		
	is_reloading = true
	reload_timer = stats.get("reload_speed", 1.8)
	EventBus.event_logged.emit("🔄 재장전 중... (%.1f초)" % reload_timer)
	if SoundManager: SoundManager.play("menu_select")

func _finish_reload() -> void:
	is_reloading = false
	if equipped_weapon_data.is_empty() or not player.has_node("InventoryGrid"): return
	
	var stats = equipped_weapon_data.get("computed_stats", {})
	var mag_size = stats.get("magazine_size", 15)
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	var needed = mag_size - cur_mag
	var ammo_types = _get_compatible_ammo_types()
	
	var loaded = 0
	var inv_grid = player.get_node("InventoryGrid")
	for it in inv_grid.items.duplicate():
		var it_id = it.get("id", "")
		var is_match = false
		for a_type in ammo_types:
			if it_id == a_type or it_id.contains(a_type) or (a_type == "9mm" and it_id == "탄약"):
				is_match = true
				break
		if is_match:
			var amt = it.get("amount", 1)
			var take = min(amt, needed - loaded)
			loaded += take
			if amt - take <= 0:
				inv_grid.remove_item_by_uid(it.get("uid", ""))
			else:
				it["amount"] -= take
				inv_grid.grid_changed.emit()
			if loaded >= needed: break
				
	equipped_weapon_data["current_magazine_ammo"] = cur_mag + loaded
	if equipment.has(active_weapon_slot) and not equipment[active_weapon_slot].is_empty():
		equipment[active_weapon_slot]["current_magazine_ammo"] = cur_mag + loaded
		
	ammo_changed.emit()
	EventBus.event_logged.emit("✅ 재장전 완료! (%d/%d)" % [equipped_weapon_data["current_magazine_ammo"], mag_size])

func _get_compatible_ammo_types() -> Array:
	if not equipped_weapon_data.is_empty():
		var stats = equipped_weapon_data.get("computed_stats", {})
		if stats.has("ammo_types"): return stats["ammo_types"]
		return [equipped_weapon_data.get("loaded_ammo", "9mm"), "탄약"]
	return ["9mm", "탄약"]

func get_available_ammo_count() -> int:
	if not player.has_node("InventoryGrid"): return 0
	var ammo_types = _get_compatible_ammo_types()
	var total = 0
	for it in player.get_node("InventoryGrid").items:
		var it_id = it.get("id", "")
		for a_type in ammo_types:
			if it_id == a_type or it_id.contains(a_type) or (a_type == "9mm" and it_id == "탄약"):
				total += it.get("amount", 1)
				break
	return total

func _get_slot_display_name(slot_name: String) -> String:
	match slot_name:
		"primary1": return "주무기 1"
		"primary2": return "주무기 2"
		"sidearm": return "권총/보조무기"
		"throwable": return "투척무기"
		_: return slot_name
"""

# 3. interaction_detector.gd
interaction_detector = """extends Node
class_name InteractionDetector

signal interact_prompt(show: bool, text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

var interactable_tile_pos: Vector2i = Vector2i(-1, -1)
var interactable_type: Vector2i = Vector2i(-1, -1)
var interact_cooldown: float = 0.0
var vault_timer: float = 0.0
const VAULT_DURATION: float = 1.0

@onready var player = get_parent()

func _process(delta: float) -> void:
	if interact_cooldown > 0:
		interact_cooldown -= delta
	_update_interaction(delta)

func _update_interaction(delta: float) -> void:
	var interact_dist = 32.0
	var check_pos = player.global_position + Vector2.RIGHT.rotated(player.rotation) * interact_dist
	
	var object_layer: TileMapLayer = null
	var chunk_manager = player.get_node_or_null("/root/MainWorld/ChunkManager")
	if chunk_manager and chunk_manager.object_layer:
		object_layer = chunk_manager.object_layer
	else:
		var cur_scene = get_tree().current_scene
		if cur_scene and cur_scene.has_node("ObjectsLayer"):
			object_layer = cur_scene.get_node("ObjectsLayer")
		elif player.get_parent() and player.get_parent().get_parent() and player.get_parent().get_parent().has_node("ObjectsLayer"):
			object_layer = player.get_parent().get_parent().get_node("ObjectsLayer")
	
	interactable_type = Vector2i(-1, -1)
	interactable_tile_pos = Vector2i(-1, -1)
	var can_interact = false
	var prompt_text = ""
	
	# 바닥 아이템
	var nearby_ground_items = get_tree().get_nodes_in_group("ground_items")
	var closest_ground_item = null
	var min_ground_dist = 45.0
	
	for g in nearby_ground_items:
		if is_instance_valid(g):
			var dist = player.global_position.distance_to(g.global_position)
			if dist < min_ground_dist:
				min_ground_dist = dist
				closest_ground_item = g
				
	if closest_ground_item:
		can_interact = true
		var idata = ItemDatabase.get_item_data(closest_ground_item.item_id)
		prompt_text = "[E] %s 줍기" % idata.get("name", closest_ground_item.item_id)
		if Input.is_action_just_pressed("interact") or (Input.is_physical_key_pressed(KEY_E) and interact_cooldown <= 0.0):
			interact_cooldown = 0.3
			var rem = 0
			if player.has_node("InventoryGrid"):
				rem = player.get_node("InventoryGrid").auto_add_item(closest_ground_item.item_id, closest_ground_item.amount, closest_ground_item.custom_data)
			elif player.inventory:
				rem = player.inventory.add_item(closest_ground_item.item_id, closest_ground_item.amount)
				
			if rem <= 0:
				closest_ground_item.queue_free()
				if SoundManager: SoundManager.play("menu_select")
				EventBus.event_logged.emit("📦 %s x%d 획득!" % [idata.get("name", closest_ground_item.item_id), closest_ground_item.amount])
			else:
				closest_ground_item.amount = rem
				closest_ground_item.update_visuals()
				EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
		interact_prompt.emit(true, prompt_text)
		return

	# 엔티티 상호작용
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = check_pos
	query.collision_mask = 1 | 2
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	var found_entity = false
	
	for res in results:
		var collider = res["collider"]
		if collider and collider.get("interactable_type") != null:
			var i_type = collider.get("interactable_type")
			if typeof(i_type) == TYPE_VECTOR2I and i_type == Vector2i(5, 1):
				can_interact = true
				prompt_text = "[E] 폐차 트렁크 열기"
				interactable_type = i_type
				if object_layer:
					interactable_tile_pos = object_layer.local_to_map(collider.global_position)
				else:
					interactable_tile_pos = Vector2i(int(collider.global_position.x / 32), int(collider.global_position.y / 32))
				found_entity = true
				break
				
	# 타일맵 상호작용
	if not found_entity and object_layer:
		var t_pos = object_layer.local_to_map(check_pos)
		var tile_coords = object_layer.get_cell_atlas_coords(t_pos)
		
		var texts = {
			Vector2i(3,1): "[E] 수색하기", Vector2i(4,1): "[E] 가구 수색하기",
			Vector2i(5,1): "[E] 잔해물 뒤지기", Vector2i(6,1): "[E] 문 열기",
			Vector2i(7,1): "[E] 문 닫기", Vector2i(1,2): "[E] 창문 깨기",
			Vector2i(2,2): "[E 꾹 누르기] 창문 넘어가기", Vector2i(5,2): "[E] 조명 스위치 작동"
		}
		if texts.has(tile_coords):
			can_interact = true
			prompt_text = texts[tile_coords]
			interactable_tile_pos = t_pos
			interactable_type = tile_coords
	
	# 창문 넘어가기 홀드 처리
	if can_interact and interactable_type == Vector2i(2, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("interact"):
			vault_timer += delta
			if player.has_node("PlayerVisuals"): player.get_node("PlayerVisuals").queue_redraw()
			if vault_timer >= VAULT_DURATION:
				player.global_position += Vector2.RIGHT.rotated(player.rotation) * 44.0
				vault_timer = 0.0
				interact_cooldown = 0.4
				EventBus.noise_created.emit(player.global_position, 120.0, "vault")
				EventBus.event_logged.emit("🏃 창문을 뛰어넘었습니다.")
				if SoundManager: SoundManager.play("footstep")
				return
		else:
			if vault_timer > 0:
				vault_timer = 0.0
				if player.has_node("PlayerVisuals"): player.get_node("PlayerVisuals").queue_redraw()
	else:
		if vault_timer > 0:
			vault_timer = 0.0
			if player.has_node("PlayerVisuals"): player.get_node("PlayerVisuals").queue_redraw()
	
	interact_prompt.emit(can_interact, prompt_text)
	
	if can_interact and interact_cooldown <= 0.0 and interactable_type != Vector2i(2, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_just_pressed("interact"):
			interact_cooldown = 0.35
			object_interacted.emit(check_pos, interactable_tile_pos, interactable_type)
"""

# 4. player_lighting.gd
player_lighting = """extends Node2D
class_name PlayerLighting

var flashlight: PointLight2D
var ambient_light: PointLight2D
var muzzle_light: PointLight2D
var flashlight_enabled: bool = true
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	ambient_light = PointLight2D.new()
	ambient_light.texture = _create_directional_ambient_texture(160, 0.6, 0.05)
	ambient_light.color = Color(1.0, 0.95, 0.8)
	ambient_light.energy = 0.85
	add_child(ambient_light)
	
	flashlight = PointLight2D.new()
	flashlight.texture = _create_flashlight_cone_texture(360, 260, 60.0)
	flashlight.offset = Vector2(180, 0)
	flashlight.color = Color(1.0, 0.98, 0.9)
	flashlight.energy = 1.6
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(flashlight)
	
	muzzle_light = PointLight2D.new()
	muzzle_light.texture = _create_flashlight_cone_texture(240, 180, 100.0)
	muzzle_light.offset = Vector2(120, 0)
	muzzle_light.color = Color(1.0, 0.85, 0.4)
	muzzle_light.energy = 0.0
	muzzle_light.enabled = false
	add_child(muzzle_light)
	
	set_flashlight(flashlight_enabled)

func _process(delta: float) -> void:
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0 and muzzle_light:
			muzzle_light.enabled = false
			muzzle_light.energy = 0.0

func trigger_muzzle_flash() -> void:
	muzzle_flash_timer = 0.06
	if muzzle_light:
		muzzle_light.enabled = true
		muzzle_light.energy = 1.4

func toggle_flashlight() -> void:
	set_flashlight(not flashlight_enabled)

func set_flashlight(enabled: bool) -> void:
	flashlight_enabled = enabled
	if flashlight: flashlight.enabled = flashlight_enabled
	if ambient_light: ambient_light.energy = 0.85 if flashlight_enabled else 0.15

func _create_directional_ambient_texture(size: int, front_alpha: float, back_alpha: float) -> ImageTexture:
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center = size / 2.0
	for y in range(size):
		for x in range(size):
			var dx = x - center; var dy = y - center; var dist = sqrt(dx * dx + dy * dy)
			if dist > center: continue
			var dist_factor = pow(1.0 - (dist / center), 1.4)
			var angle = atan2(dy, dx)
			var forward_bias = (cos(angle) + 1.0) / 2.0
			var alpha_target = lerp(back_alpha, front_alpha, forward_bias)
			var alpha = clamp(dist_factor * alpha_target, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

func _create_flashlight_cone_texture(width: int, height: int, cone_angle_deg: float) -> ImageTexture:
	var img = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var start_x = 0.0; var start_y = height / 2.0
	var half_angle_rad = deg_to_rad(cone_angle_deg / 2.0)
	var max_dist = float(width)
	for y in range(height):
		for x in range(width):
			var dx = x - start_x; var dy = y - start_y; var dist = sqrt(dx * dx + dy * dy)
			if dist <= 0.0 or dist > max_dist: continue
			var angle = abs(atan2(dy, dx))
			if angle > half_angle_rad: continue
			var dist_factor = pow(1.0 - (dist / max_dist), 1.5)
			var angle_factor = cos((angle / half_angle_rad) * (PI / 2.0))
			var alpha = clamp(dist_factor * angle_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
"""

# 5. player_camera.gd
player_camera = """extends Node
class_name PlayerCamera

var base_camera_pos: Vector2 = Vector2.ZERO
var target_cam_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var walk_bob: float = 0.0
var is_aiming_ads: bool = false

@onready var player = get_parent()
@onready var camera = player.get_node_or_null("Camera2D")

func _ready() -> void:
	if camera: base_camera_pos = camera.position
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(request_shake)

func _process(delta: float) -> void:
	if not camera: return
	
	if player.velocity.length() > 10.0:
		walk_bob += delta * 12.0
	else:
		walk_bob = lerp(walk_bob, 0.0, delta * 10.0)
		
	if shake_timer > 0:
		shake_timer -= delta
		camera.position = base_camera_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity * (shake_timer / 0.5)
	else:
		if not is_aiming_ads: camera.position = base_camera_pos

	_update_zoom(delta)

func request_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

func _update_zoom(delta: float) -> void:
	if not camera: return
	
	var zoom_factor = 1.0
	var has_telescope = false
	var telescope_mult = 1.0
	
	var inv = player.get_node_or_null("InventoryGrid")
	if inv:
		for it in inv.items:
			if it and it.get("id") == "고배율_망원경":
				has_telescope = true
				telescope_mult = 10.0
				break
			elif it and it.get("id") == "망원경":
				has_telescope = true
				telescope_mult = 5.0
				
	var scope_zoom = 1.0
	if player.has_node("WeaponHandler"):
		var w_data = player.get_node("WeaponHandler").equipped_weapon_data
		if not w_data.is_empty():
			scope_zoom = w_data.get("computed_stats", {}).get("zoom", 1.0)
			
	if is_aiming_ads:
		zoom_factor = max(scope_zoom, telescope_mult if has_telescope else 1.0)
		
	var target_zoom_val = 1.0 / sqrt(zoom_factor)
	var target_zoom = Vector2(target_zoom_val, target_zoom_val)
	
	if is_aiming_ads and zoom_factor > 1.0:
		var mouse_offset = player.get_global_mouse_position() - player.global_position
		target_cam_offset = mouse_offset.limit_length(180.0 * (zoom_factor / 2.0))
	else:
		target_cam_offset = Vector2.ZERO
		
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 6.0)
	camera.position = camera.position.lerp(base_camera_pos + target_cam_offset, delta * 6.0)
"""

# 6. player_visuals.gd
player_visuals = """extends Node2D
class_name PlayerVisuals

var hit_flash_tween: Tween
@onready var player = get_parent()

func _ready() -> void:
	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged)

func _process(delta: float) -> void:
	queue_redraw()

func _on_player_damaged(amount: float, source: String) -> void:
	if hit_flash_tween: hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	material.set_shader_parameter("flash_color", Color(1, 0, 0, 1))
	material.set_shader_parameter("flash_modifier", 1.0)
	hit_flash_tween.tween_property(material, "shader_parameter/flash_modifier", 0.0, 0.2)
	if player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").request_shake(8.0, 0.3)

func _draw() -> void:
	var bob_y = 0.0
	var bob_rot = 0.0
	var recoil_offset = 0.0
	var muzzle_flash_timer = 0.0
	var vault_timer = 0.0
	var equipped_weapon_data = {}
	
	if player.has_node("PlayerCamera"):
		bob_y = sin(player.get_node("PlayerCamera").walk_bob * 2.0) * 2.0
		bob_rot = sin(player.get_node("PlayerCamera").walk_bob) * 0.1
	if player.has_node("WeaponHandler"):
		recoil_offset = player.get_node("WeaponHandler").recoil_offset
		equipped_weapon_data = player.get_node("WeaponHandler").equipped_weapon_data
	if player.has_node("PlayerLighting"):
		muzzle_flash_timer = player.get_node("PlayerLighting").muzzle_flash_timer
	if player.has_node("InteractionDetector"):
		vault_timer = player.get_node("InteractionDetector").vault_timer
		
	position = Vector2(0, bob_y)
	rotation = bob_rot
	
	var skin_color = Color(0.9, 0.8, 0.7)
	
	var vest_points = PackedVector2Array([
		Vector2(-10, -12), Vector2(-10, 12),
		Vector2(2, 14), Vector2(12, 8),
		Vector2(12, -8), Vector2(2, -14)
	])
	
	var vest_colors = PackedColorArray()
	var vest_outline = PackedColorArray()
	for p in vest_points:
		vest_colors.append(Color(0.2, 0.3, 0.2))
		vest_outline.append(Color(0.1, 0.1, 0.1))
		
	var vest_outline_pts = PackedVector2Array()
	for p in vest_points:
		vest_outline_pts.append(p * 1.15)
		
	draw_polygon(vest_outline_pts, vest_outline)
	draw_polygon(vest_points, vest_colors)
	
	draw_rect(Rect2(Vector2(2, 3), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	draw_rect(Rect2(Vector2(2, -7), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	
	var head_radius = 8.0
	draw_circle(Vector2(2, 0), head_radius + 1.5, Color.BLACK)
	draw_circle(Vector2(2, 0), head_radius, skin_color)
	
	var hat_pts = PackedVector2Array([Vector2(2, -7), Vector2(2, 7), Vector2(12, 5), Vector2(12, -5)])
	draw_polygon(hat_pts, PackedColorArray([Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15)]))

	var weapon_recoil_pos = Vector2(-recoil_offset, 0)
	var right_shoulder = Vector2(0, 10)
	var right_hand = Vector2(12, 6) + weapon_recoil_pos
	draw_line(right_shoulder, right_hand, Color(0.25, 0.35, 0.25), 5.0)
	draw_circle(right_hand, 3.5, skin_color)
	
	var left_shoulder = Vector2(2, -10)
	var left_hand = Vector2(18, 0) + weapon_recoil_pos
	draw_line(left_shoulder, left_hand, Color(0.25, 0.35, 0.25), 5.0)
	draw_circle(left_hand, 3.5, skin_color)
	
	draw_rect(Rect2(right_hand + Vector2(-2, -2), Vector2(4, 6)), Color(0.1, 0.1, 0.1))
	var barrel_rect = Rect2(right_hand + Vector2(2, -3), Vector2(14, 4))
	draw_rect(barrel_rect, Color(0.15, 0.15, 0.15))
	
	if muzzle_flash_timer > 0.0:
		var flash_tip = right_hand + Vector2(16, -1)
		var flash_poly = PackedVector2Array([
			flash_tip + Vector2(0, -3), flash_tip + Vector2(8, 0),
			flash_tip + Vector2(0, 3), flash_tip + Vector2(12, 0)
		])
		draw_polygon(flash_poly, PackedColorArray([
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.7, 0.1, 0.8), 
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.8)
		]))

	if not equipped_weapon_data.is_empty():
		var stats = equipped_weapon_data.get("computed_stats", {})
		if stats.get("laser_sight", false):
			var laser_start = right_hand + Vector2(16, -1)
			var laser_end = laser_start + Vector2(350, 0)
			draw_line(laser_start, laser_end, Color(1.0, 0.15, 0.15, 0.65), 1.2)
			draw_circle(laser_end, 2.5, Color(1.0, 0.25, 0.25, 0.9))

	if vault_timer > 0.0:
		var ratio = clamp(vault_timer / 1.0, 0.0, 1.0)
		var bar_w = 36.0; var bar_h = 5.0
		var bar_pos = Vector2(-bar_w / 2.0, -26.0)
		draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0, 0, 0, 0.8))
		var fill_color = Color(1.0, 0.8, 0.2).lerp(Color(0.2, 0.9, 0.3), ratio)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color)
"""

import sys
if "--force-regenerate" not in sys.argv:
	print("[DEPRECATED] create_player_components.py is archived/isolated to prevent overwriting live player components.")
	sys.exit(0)

with open("scenes/entities/player/survival_stats.gd", "w", encoding="utf-8") as f: f.write(survival_stats)
with open("scenes/entities/player/weapon_handler.gd", "w", encoding="utf-8") as f: f.write(weapon_handler)
with open("scenes/entities/player/interaction_detector.gd", "w", encoding="utf-8") as f: f.write(interaction_detector)
with open("scenes/entities/player/player_lighting.gd", "w", encoding="utf-8") as f: f.write(player_lighting)
with open("scenes/entities/player/player_camera.gd", "w", encoding="utf-8") as f: f.write(player_camera)
with open("scenes/entities/player/player_visuals.gd", "w", encoding="utf-8") as f: f.write(player_visuals)

print("Created 6 component scripts for Player")
