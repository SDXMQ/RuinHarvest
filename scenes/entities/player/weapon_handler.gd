extends Node
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
