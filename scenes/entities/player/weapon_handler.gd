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
var preferred_ammo_type: String = ""

var attack_cooldown_timer: float = 0.0
var recoil_offset: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0
var is_jammed: bool = false

@onready var player = get_parent()

func _process(delta: float) -> void:
	recoil_offset = lerp(recoil_offset, 0.0, delta * 15.0)
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()
	elif not get_tree().paused and player and player.hp > 0:
		# 연사 총기(RPM >= 300)는 좌클릭 유지 시 자동 사격 지원
		if Input.is_action_pressed("attack") and not equipped_weapon_data.is_empty() and active_weapon_slot != "throwable":
			var rpm = equipped_weapon_data.get("computed_stats", {}).get("rpm", 150)
			if rpm >= 300 and attack_cooldown_timer <= 0:
				try_attack(Vector2.RIGHT.rotated(player.rotation), player.global_position)

func switch_weapon_slot(slot_name: String) -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
	is_jammed = false
		
	active_weapon_slot = slot_name
	var weapon_dict = equipment.get(slot_name, {})
	
	if weapon_dict.is_empty():
		equipped_weapon_data = {}
		equipped_weapon = "맨손"
		EventBus.event_logged.emit("✋ [%s] 슬롯: 비어있음 (맨손)" % get_slot_display_name(slot_name))
	elif slot_name == "throwable":
		var t_id = weapon_dict.get("id", "수류탄")
		equipped_weapon = weapon_dict.get("name", t_id)
		equipped_weapon_data = {
			"id": t_id, "name": equipped_weapon, "type": "throwable",
			"amount": weapon_dict.get("amount", 1),
			"computed_stats": {"damage": 145.0, "rpm": 60, "noise_radius": 800.0}
		}
		EventBus.event_logged.emit("💣 투척 무기: %s (x%d)" % [equipped_weapon, weapon_dict.get("amount", 1)])
	else:
		var rec_id = weapon_dict.get("id", "")
		if not weapon_dict.has("parts"):
			weapon_dict["parts"] = weapon_dict.get("attachments", {}).duplicate(true)
		weapon_dict["attachments"] = weapon_dict["parts"]
		equipped_weapon_data = WeaponPartsDatabase.compute_weapon_from_dict(weapon_dict)
		var w_name = str(weapon_dict.get("name", ""))
		if w_name == "" or w_name == rec_id:
			var resolved_rec = WeaponPartsDatabase.resolve_receiver_id(rec_id)
			if WeaponPartsDatabase.RECEIVERS.has(resolved_rec):
				w_name = str(WeaponPartsDatabase.RECEIVERS[resolved_rec].get("name", rec_id))
			else:
				var idata = ItemDatabase.get_item_data(rec_id)
				w_name = str(idata.get("name", rec_id))
		equipped_weapon = w_name
		equipped_weapon_data["name"] = w_name
		if weapon_dict.has("current_magazine_ammo"):
			equipped_weapon_data["current_magazine_ammo"] = weapon_dict["current_magazine_ammo"]
		if weapon_dict.has("durability"):
			equipped_weapon_data["durability"] = weapon_dict["durability"]
		if weapon_dict.has("max_durability"):
			equipped_weapon_data["max_durability"] = weapon_dict["max_durability"]
		EventBus.event_logged.emit("🔫 무기 전환: %s [%s]" % [w_name, get_slot_display_name(slot_name)])
			
	weapon_changed.emit()
	if player and player.has_signal("stats_changed"):
		player.stats_changed.emit()

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
		
	# 근접 무기(나이프, 파이프, 도끼, 야구방망이) 장착 여부 확인
	var w_id = equipped_weapon_data.get("id", "")
	var item_info = ItemDatabase.get_item_data(w_id)
	if item_info.get("weapon_type", "") == "melee" or w_id in ["나이프", "파이프", "도끼", "야구방망이"]:
		_melee_punch(aim_dir, spawn_pos, float(item_info.get("damage", 24.0)))
		return

	if is_jammed:
		attack_cooldown_timer = 0.28
		recoil_offset = 1.5
		var jam_muzzle = spawn_pos + aim_dir.normalized() * 18.0
		var jam_ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
		if jam_ps:
			jam_ps.emit("smoke", jam_muzzle.x, jam_muzzle.y, 2, aim_dir.angle())
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("[JAMMED - 철컥!]", Color(1.0, 0.4, 0.2))
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 총기 노리쇠가 걸려있습니다! [R 키로 탄걸림 제거]")
		if SoundManager: SoundManager.play("dry_fire")
		return
		
	# 무기 내구도 0 도달 시 고장(BROKEN)으로 격발 불가
	var max_dur = float(equipped_weapon_data.get("max_durability", 100.0))
	var cur_dur = float(equipped_weapon_data.get("durability", max_dur))
	if cur_dur <= 0.0:
		attack_cooldown_timer = 0.35
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("[BROKEN]", Color(1.0, 0.25, 0.25))
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 총기 내구도가 0이 되어 격발할 수 없습니다! (작업대 수리 필요)")
		if SoundManager: SoundManager.play("dry_fire")
		return

	# 저내구도(<40%) 총기 사격 시 5% 확률로 잼(탄걸림) 발생
	if cur_dur <= 40.0 and randf() < 0.05:
		is_jammed = true
		attack_cooldown_timer = 0.35
		var jam_pos = spawn_pos + aim_dir.normalized() * 18.0
		var jam_ps2 = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
		if jam_ps2:
			jam_ps2.emit("smoke", jam_pos.x, jam_pos.y, 2, aim_dir.angle())
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("[JAMMED]", Color(1.0, 0.4, 0.2))
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 총기 기능고장(Jam) 발생! 탄피가 걸렸습니다. [R 키로 조치]")
		if SoundManager: SoundManager.play("dry_fire")
		return

	var stats = equipped_weapon_data.get("computed_stats", {})
	var rpm = stats.get("rpm", 150)
	attack_cooldown_timer = 60.0 / float(max(45, rpm))
	
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	if cur_mag <= 0:
		if get_available_ammo_count() <= 0 and player and player.has_method("show_floating_text"):
			player.show_floating_text("[NO AMMO]", Color(1.0, 0.35, 0.35))
		start_reload()
		return
		
	equipped_weapon_data["current_magazine_ammo"] = cur_mag - 1
	if equipment.has(active_weapon_slot) and not equipment[active_weapon_slot].is_empty():
		equipment[active_weapon_slot]["current_magazine_ammo"] = cur_mag - 1
	
	# 무기 내구도 실시간 차감 (발당 0.15) 및 장비 슬롯 동기화
	var prev_dur = cur_dur
	cur_dur = max(0.0, cur_dur - 0.15)
	equipped_weapon_data["durability"] = cur_dur
	if not equipped_weapon_data.has("max_durability"):
		equipped_weapon_data["max_durability"] = max_dur
	if equipment.has(active_weapon_slot) and not equipment[active_weapon_slot].is_empty():
		equipment[active_weapon_slot]["durability"] = cur_dur
		if not equipment[active_weapon_slot].has("max_durability"):
			equipment[active_weapon_slot]["max_durability"] = max_dur
	if player and "equipment" in player and player.equipment.has(active_weapon_slot) and not player.equipment[active_weapon_slot].is_empty():
		player.equipment[active_weapon_slot]["durability"] = cur_dur
		if not player.equipment[active_weapon_slot].has("max_durability"):
			player.equipment[active_weapon_slot]["max_durability"] = max_dur
	if prev_dur > 0.0 and cur_dur <= 0.0 and player and player.has_method("show_floating_text"):
		player.show_floating_text("[BROKEN]", Color(1.0, 0.25, 0.25))
	
	ammo_changed.emit()
	if player and player.has_signal("stats_changed"):
		player.stats_changed.emit()
	
	var recoil_val = get_effective_recoil()
	recoil_offset = recoil_val * 0.2
	if player and player.player_camera and player.player_camera.has_method("apply_recoil_punch"):
		player.player_camera.apply_recoil_punch(aim_dir, recoil_val)
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(clamp(recoil_val * 0.08, 1.2, 5.0), 0.12)
	
	if stats.get("muzzle_flash", true):
		if player.has_node("PlayerLighting"):
			player.get_node("PlayerLighting").trigger_muzzle_flash()
			
	var muzzle_pos = spawn_pos + aim_dir.normalized() * 18.0
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("muzzle", muzzle_pos.x, muzzle_pos.y, 4, aim_dir.angle())
		ps.emit("bullet_shell", spawn_pos.x, spawn_pos.y, 1, aim_dir.angle())
		
	EventBus.noise_created.emit(spawn_pos, stats.get("noise_radius", 600.0), "gunshot")
	
	var pellets = stats.get("pellets", 1)
	var dmg_per_pellet = stats.get("damage", 20.0)
	var accuracy = stats.get("accuracy", 75.0)
	var spread_max = deg_to_rad(max(0.8, (100.0 - accuracy) * 0.32))
	if player and player.player_camera and player.player_camera.is_aiming_ads:
		spread_max *= 0.45 # 정조준 시 집탄율 대폭 상승
	
	var eff_range = max(260.0, float(stats.get("range", 50.0)) * 12.0)
	var pen = int(stats.get("penetration", 10))
	
	for p in range(pellets):
		var spread = randf_range(-spread_max, spread_max)
		var pellet_dir = aim_dir.rotated(spread)
		var bullet = BulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.setup(muzzle_pos, pellet_dir, dmg_per_pellet, eff_range, pen, "player", 760.0)
		
	if SoundManager: SoundManager.play("hit_ranged")

func _melee_punch(aim_dir: Vector2, spawn_pos: Vector2, melee_dmg: float = 18.0) -> void:
	attack_cooldown_timer = 0.38
	recoil_offset = 7.0
	var dir_norm = aim_dir.normalized()
	var reach = 54.0
	var hit_any = false
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var to_enemy = enemy.global_position - spawn_pos
			var dist = to_enemy.length()
			if dist <= reach and (dist < 18.0 or to_enemy.normalized().dot(dir_norm) >= 0.42):
				enemy.take_damage(melee_dmg, dir_norm * 1.4)
				hit_any = true
				
	# 전방 창문 타일 타격 시 창문 파괴
	var chunk_mgr = get_node_or_null("/root/MainWorld/ChunkManager")
	var obj_layer: TileMapLayer = chunk_mgr.object_layer if chunk_mgr and chunk_mgr.object_layer else get_tree().current_scene.get_node_or_null("ObjectsLayer")
	if obj_layer:
		var check_tile = obj_layer.local_to_map(spawn_pos + dir_norm * 28.0)
		var w_coords: Vector2i = obj_layer.get_cell_atlas_coords(check_tile)
		if TileManager.is_window(w_coords):
			obj_layer.set_cell(check_tile, 0, TileManager.get_window_broken_tile(w_coords))
			EventBus.noise_created.emit(spawn_pos, 350.0, "break")
			EventBus.window_broken.emit(check_tile)
			EventBus.event_logged.emit("💥 근접 타격으로 창문을 깼습니다!")
			hit_any = true
			
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		var swing_pos = spawn_pos + dir_norm * 26.0
		ps.emit("hit" if hit_any else "dust", swing_pos.x, swing_pos.y, 4)
		
	if SoundManager: SoundManager.play("hit_melee")
	EventBus.noise_created.emit(spawn_pos, 90.0, "punch")

func _throw_grenade(aim_dir: Vector2, spawn_pos: Vector2) -> void:
	var amt = equipped_weapon_data.get("amount", 1)
	if amt <= 0: return
	attack_cooldown_timer = 0.85
	
	var target_pos = player.get_global_mouse_position() if player else (spawn_pos + aim_dir * 200.0)
	var to_target = target_pos - spawn_pos
	var throw_dist = clamp(to_target.length(), 60.0, 280.0)
	var final_pos = spawn_pos + aim_dir.normalized() * throw_dist
	
	_spawn_grenade_entity(spawn_pos, final_pos, 145.0, 125.0)
	
	amt -= 1
	equipped_weapon_data["amount"] = amt
	if equipment.has("throwable") and not equipment["throwable"].is_empty():
		if amt <= 0:
			equipment["throwable"] = {}
			equipped_weapon_data = {}
			equipped_weapon = "맨손"
		else:
			equipment["throwable"]["amount"] = amt
			
	if SoundManager: SoundManager.play("menu_select")
	EventBus.noise_created.emit(spawn_pos, 180.0, "grenade_throw")
	ammo_changed.emit()
	if player and player.has_signal("stats_changed"):
		player.stats_changed.emit()

func _spawn_grenade_entity(start_pos: Vector2, target_pos: Vector2, blast_dmg: float, blast_radius: float) -> void:
	var scene_root = get_tree().current_scene
	if not scene_root: return
	
	var gren = Node2D.new()
	gren.name = "ThrownGrenade"
	gren.global_position = start_pos
	scene_root.add_child(gren)
	
	gren.draw.connect(func():
		gren.draw_circle(Vector2.ZERO, 5.5, Color(0.2, 0.35, 0.2))
		gren.draw_arc(Vector2.ZERO, 5.5, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.5)
		var blink = sin(Time.get_ticks_msec() * 0.035) > 0.0
		if blink:
			gren.draw_circle(Vector2(0, -2), 2.2, Color(1.0, 0.2, 0.2))
			gren.draw_arc(Vector2.ZERO, blast_radius, 0, TAU, 32, Color(1.0, 0.25, 0.15, 0.22), 1.5)
	)
	
	var tw = gren.create_tween()
	tw.tween_property(gren, "global_position", target_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fuse_timer = get_tree().create_timer(1.35)
	fuse_timer.timeout.connect(func():
		if not is_instance_valid(gren): return
		var g_pos = gren.global_position
		if SoundManager: SoundManager.play("explosion")
		EventBus.noise_created.emit(g_pos, 850.0, "explosion")
		if EventBus.has_signal("camera_shake_requested"):
			EventBus.camera_shake_requested.emit(10.0, 0.35)
			
		var ps = scene_root.get_node_or_null("ParticleSystem")
		if ps:
			ps.emit("muzzle", g_pos.x, g_pos.y, 18)
			ps.emit("spark", g_pos.x, g_pos.y, 20)
			ps.emit("smoke", g_pos.x, g_pos.y, 14)
			
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var d = g_pos.distance_to(enemy.global_position)
				if d <= blast_radius:
					var falloff = clamp(1.0 - (d / blast_radius) * 0.65, 0.35, 1.0)
					var dir = g_pos.direction_to(enemy.global_position)
					enemy.take_damage(blast_dmg * falloff, dir * 2.2)
					
		if is_instance_valid(player):
			var p_dist = g_pos.distance_to(player.global_position)
			if p_dist <= blast_radius * 0.85:
				var p_falloff = clamp(1.0 - (p_dist / (blast_radius * 0.85)), 0.2, 1.0)
				EventBus.player_damaged.emit(blast_dmg * 0.45 * p_falloff, "explosion")
				
		gren.queue_free()
	)

static func is_firearm_dict(w_dict: Dictionary) -> bool:
	if w_dict.is_empty():
		return false
	if String(w_dict.get("type", "")) == "throwable":
		return false
	var w_id := String(w_dict.get("id", ""))
	if w_id in ["나이프", "파이프", "도끼", "야구방망이", "수류탄"]:
		return false
	var idata := ItemDatabase.get_item_data(w_id) if ItemDatabase else {}
	var w_type := String(idata.get("type", ""))
	var weapon_type := String(idata.get("weapon_type", ""))
	if w_type == "melee" or weapon_type == "melee" or w_type == "ammo" or w_type == "throwable":
		return false
	var cat := int(idata.get("category", -1))
	if cat == ItemDatabase.ItemCategory.TOOL or cat == ItemDatabase.ItemCategory.MATERIAL or cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or cat == ItemDatabase.ItemCategory.MEDICAL or cat == ItemDatabase.ItemCategory.QUEST or cat == ItemDatabase.ItemCategory.MISC:
		if not WeaponPartsDatabase.RECEIVERS.has(WeaponPartsDatabase.resolve_receiver_id(w_id)):
			return false
	var stats = w_dict.get("computed_stats", {})
	if stats is Dictionary and stats.has("ammo_types"):
		return not stats["ammo_types"].is_empty()
	var res_id := WeaponPartsDatabase.resolve_receiver_id(String(w_dict.get("receiver", w_id)))
	if WeaponPartsDatabase.RECEIVERS.has(res_id):
		return true
	return w_type == "ranged" or w_type == "receiver" or w_type == "assembled_weapon"

func is_firearm_equipped() -> bool:
	if active_weapon_slot == "throwable":
		return false
	return is_firearm_dict(equipped_weapon_data)

func cycle_ammo_type() -> void:
	if is_reloading or not is_firearm_equipped():
		return
	if not player or not player.has_node("InventoryGrid"):
		return
	var inv_grid: InventoryGrid = player.get_node("InventoryGrid")
	var compat_types = get_compatible_ammo_types()
	var owned_ammo_options: Array[String] = []
	for a_type in compat_types:
		for it in inv_grid.items:
			var it_id = String(it.get("id", ""))
			if it_id == a_type or it_id.contains(a_type) or (a_type == "9mm" and it_id == "탄약"):
				if not (it_id in owned_ammo_options):
					owned_ammo_options.append(it_id)
	if owned_ammo_options.size() <= 0:
		if player.has_method("show_floating_text"):
			player.show_floating_text("[NO AMMO]", Color(1.0, 0.35, 0.35))
		return

	var cur_idx = owned_ammo_options.find(preferred_ammo_type)
	var next_idx = (cur_idx + 1) % owned_ammo_options.size()
	preferred_ammo_type = owned_ammo_options[next_idx]

	# 기존 탄창의 잔탄을 가방으로 회수 후 선택한 탄종으로 재장전 시작
	var cur_mag = int(equipped_weapon_data.get("current_magazine_ammo", 0))
	if cur_mag > 0:
		var return_cal = String(compat_types[0]) if compat_types.size() > 0 else "9mm"
		inv_grid.auto_add_item(return_cal, cur_mag)
		equipped_weapon_data["current_magazine_ammo"] = 0
		if equipment.has(active_weapon_slot) and not equipment[active_weapon_slot].is_empty():
			equipment[active_weapon_slot]["current_magazine_ammo"] = 0

	if player.has_method("show_floating_text"):
		player.show_floating_text("[AMMO: %s]" % preferred_ammo_type, Color(1.0, 0.88, 0.35))
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔄 [Alt+R] 탄종 선택: %s" % preferred_ammo_type)
	start_reload()

func start_reload() -> void:
	if is_reloading or not is_firearm_equipped(): return
	if is_jammed:
		is_jammed = false
		is_reloading = true
		reload_timer = 0.8
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("[CLEAR]", Color(0.4, 1.0, 0.5))
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🔧 탄걸림 기능고장 조치 완료! 노리쇠를 전진시켰습니다.")
		if SoundManager: SoundManager.play("menu_select")
		return

	var stats = equipped_weapon_data.get("computed_stats", {})
	if equipped_weapon_data.get("current_magazine_ammo", 0) >= stats.get("magazine_size", 15): return
	
	if get_available_ammo_count() <= 0:
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("[NO AMMO]", Color(1.0, 0.35, 0.35))
		EventBus.event_logged.emit("⚠️ 장전할 수 있는 호환 탄약이 없습니다!")
		if SoundManager: SoundManager.play("hit_melee")
		return
		
	is_reloading = true
	reload_timer = get_effective_reload_speed()
	if player and player.has_method("show_floating_text"):
		player.show_floating_text("[RELOADING...]", Color(0.4, 0.9, 1.0))
	EventBus.event_logged.emit("🔄 재장전 중... (%.1f초)" % reload_timer)
	if SoundManager: SoundManager.play("menu_select")

func get_current_weapon_mastery() -> Dictionary:
	var w_id := String(equipped_weapon_data.get("id", equipped_weapon_data.get("receiver", "")))
	var w_data: Dictionary = GameManager.current_world_data if GameManager and GameManager.current_world_data is Dictionary else {}
	return HideoutProgression.get_weapon_mastery_bonus(w_data, w_id)

func get_effective_reload_speed() -> float:
	var stats: Dictionary = equipped_weapon_data.get("computed_stats", {})
	var base_reload := float(stats.get("reload_speed", 1.8))
	var mastery := get_current_weapon_mastery()
	return base_reload * float(mastery.get("reload_speed_mult", 1.0))

func get_effective_recoil() -> float:
	var stats: Dictionary = equipped_weapon_data.get("computed_stats", {})
	var base_recoil := float(stats.get("recoil", 20.0))
	var mastery := get_current_weapon_mastery()
	return base_recoil * float(mastery.get("recoil_mult", 1.0))

func _finish_reload() -> void:
	is_reloading = false
	if equipped_weapon_data.is_empty() or not player.has_node("InventoryGrid"): return
	
	var stats = equipped_weapon_data.get("computed_stats", {})
	var mag_size = stats.get("magazine_size", 15)
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	var needed = mag_size - cur_mag
	var ammo_types = get_compatible_ammo_types().duplicate()
	if preferred_ammo_type != "" and preferred_ammo_type in ammo_types:
		ammo_types.erase(preferred_ammo_type)
		ammo_types.push_front(preferred_ammo_type)
	elif preferred_ammo_type != "":
		ammo_types.push_front(preferred_ammo_type)
	
	var loaded = 0
	var inv_grid = player.get_node("InventoryGrid")
	for a_type in ammo_types:
		if loaded >= needed:
			break
		for it in inv_grid.items.duplicate():
			var it_id = String(it.get("id", ""))
			var is_match = (it_id == a_type or it_id.contains(a_type) or (a_type == "9mm" and it_id == "탄약"))
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
	if player and player.has_signal("stats_changed"):
		player.stats_changed.emit()
	EventBus.event_logged.emit("✅ 재장전 완료! (%d/%d)" % [equipped_weapon_data["current_magazine_ammo"], mag_size])

func get_compatible_ammo_types() -> Array:
	if not is_firearm_equipped():
		return []
	var stats = equipped_weapon_data.get("computed_stats", {})
	if stats.has("ammo_types"):
		return stats["ammo_types"]
	var res_id := WeaponPartsDatabase.resolve_receiver_id(String(equipped_weapon_data.get("receiver", equipped_weapon_data.get("id", ""))))
	if WeaponPartsDatabase.RECEIVERS.has(res_id):
		return WeaponPartsDatabase.RECEIVERS[res_id].get("ammo_types", ["9mm"])
	return [String(equipped_weapon_data.get("loaded_ammo", "9mm"))]

func _get_compatible_ammo_types() -> Array:
	return get_compatible_ammo_types()

func get_available_ammo_count() -> int:
	if not player.has_node("InventoryGrid"): return 0
	var ammo_types = get_compatible_ammo_types()
	var total = 0
	for it in player.get_node("InventoryGrid").items:
		var it_id = it.get("id", "")
		for a_type in ammo_types:
			if it_id == a_type or it_id.contains(a_type) or (a_type == "9mm" and it_id == "탄약"):
				total += it.get("amount", 1)
				break
	return total

func get_slot_display_name(slot_name: String) -> String:
	match slot_name:
		"primary1": return "주무기 1"
		"primary2": return "주무기 2"
		"sidearm": return "권총/보조무기"
		"throwable": return "투척무기"
		_: return slot_name

func _get_slot_display_name(slot_name: String) -> String:
	return get_slot_display_name(slot_name)
