# res://scenes/entities/enemies/enemy_data.gd
extends RefCounted

## 적 타입별 스탯 프리셋, 스케일, 사망 메타, 전리품 테이블 및 시체 전리품 상자 생성 모듈

static func get_stats_preset(enemy_type: int) -> Dictionary:
	match enemy_type:
		0: # ZOMBIE
			return {
				"max_hp": 32.0, "speed": 62.0, "damage": 8.0,
				"armor_tier": 0, "armor_value": 0.0, "attack_cooldown": 1.0,
				"detection_radius": 200.0, "attack_radius": 28.0,
				"is_ranged_human": false, "max_mag_ammo": 8
			}
		1: # RUNNER
			return {
				"max_hp": 20.0, "speed": 115.0, "damage": 6.0,
				"armor_tier": 0, "armor_value": 0.0, "attack_cooldown": 1.0,
				"detection_radius": 220.0, "attack_radius": 26.0,
				"is_ranged_human": false, "max_mag_ammo": 8
			}
		2: # TANK
			return {
				"max_hp": 90.0, "speed": 40.0, "damage": 16.0,
				"armor_tier": 1, "armor_value": 10.0, "attack_cooldown": 1.0,
				"detection_radius": 190.0, "attack_radius": 34.0,
				"is_ranged_human": false, "max_mag_ammo": 8
			}
		3: # SCAV
			return {
				"max_hp": 42.0, "speed": 72.0, "damage": 7.0,
				"armor_tier": 1, "armor_value": 10.0, "attack_cooldown": 1.25,
				"detection_radius": 250.0, "attack_radius": 200.0,
				"is_ranged_human": true, "max_mag_ammo": 8
			}
		4: # RAIDER
			return {
				"max_hp": 72.0, "speed": 82.0, "damage": 10.0,
				"armor_tier": 2, "armor_value": 20.0, "attack_cooldown": 0.72,
				"detection_radius": 290.0, "attack_radius": 240.0,
				"is_ranged_human": true, "max_mag_ammo": 15
			}
		5: # BOSS
			return {
				"max_hp": 190.0, "speed": 80.0, "damage": 12.0,
				"armor_tier": 3, "armor_value": 32.0, "attack_cooldown": 0.45,
				"detection_radius": 290.0, "attack_radius": 225.0,
				"is_ranged_human": true, "max_mag_ammo": 30
			}
		6: # NIGHT_STALKER
			return {
				"max_hp": 65.0, "speed": 130.0, "damage": 13.0,
				"armor_tier": 1, "armor_value": 14.0, "attack_cooldown": 0.85,
				"detection_radius": 300.0, "attack_radius": 30.0,
				"is_ranged_human": false, "max_mag_ammo": 8
			}
		_:
			return get_stats_preset(0)

static func get_type_scale(enemy_type: int) -> float:
	match enemy_type:
		2: # TANK
			return 1.25
		1: # RUNNER
			return 0.88
		4: # RAIDER
			return 1.06
		5: # BOSS
			return 1.24
		6: # NIGHT_STALKER
			return 1.06
		_:
			return 1.0

static func get_death_meta(enemy_type: int) -> Dictionary:
	match enemy_type:
		1:
			return {"type_str": "runner", "faction_str": "infected", "log_msg": ""}
		2:
			return {"type_str": "tank", "faction_str": "infected", "log_msg": ""}
		3:
			return {"type_str": "scav", "faction_str": "scav", "log_msg": ""}
		4:
			return {"type_str": "raider", "faction_str": "raider", "log_msg": ""}
		5:
			return {
				"type_str": "boss",
				"faction_str": "raider",
				"log_msg": "[icon:star] [icon:skull] [보스 처치] 구역 지휘관 '강철의 보스'를 사살했습니다! 최고급 전리품을 확인하십시오!"
			}
		6:
			return {
				"type_str": "night_stalker",
				"faction_str": "infected",
				"log_msg": "[icon:moon] [변이체 처치] 어둠 속의 '야간 추격자'를 사살했습니다!"
			}
		_:
			return {"type_str": "zombie", "faction_str": "infected", "log_msg": ""}

static func roll_loot_drops(enemy_type: int) -> Array:
	var drops: Array = []
	match enemy_type:
		0, 1: # ZOMBIE, RUNNER
			if randf() < 0.55:
				var pool: Array = [
					{"id": "천", "amount": randi_range(1, 2)},
					{"id": "붕대", "amount": 1},
					{"id": "고철", "amount": 1},
					{"id": "마른 빵", "amount": 1},
					{"id": "9mm", "amount": randi_range(5, 12)}
				]
				drops.append(pool.pick_random())
		2: # TANK
			var pool: Array = [
				{"id": "구급상자", "amount": 1},
				{"id": "진통제", "amount": 1},
				{"id": "화약", "amount": randi_range(1, 2)},
				{"id": "12게이지_벅샷", "amount": randi_range(4, 8)}
			]
			drops.append(pool.pick_random())
		3: # SCAV
			drops.append({"id": "Scav 인식표", "amount": 1})
			var ammo_pool: Array = [
				{"id": "9mm", "amount": randi_range(12, 24)},
				{"id": ".45ACP", "amount": randi_range(10, 20)},
				{"id": "12게이지_벅샷", "amount": randi_range(6, 12)}
			]
			drops.append(ammo_pool.pick_random())
			if randf() < 0.60:
				var scav_guns: Array = ["M9_리시버", "레밍턴_리시버", "MP5_리시버"]
				var g_id: String = str(scav_guns.pick_random())
				drops.append({"id": g_id, "amount": 1, "custom_data": WeaponPartsDatabase.create_loot_weapon(g_id, 0.05)})
			if randf() < 0.75:
				var gear_pool: Array = [
					{"id": "붕대", "amount": 1},
					{"id": "진통제", "amount": 1},
					{"id": "생수", "amount": 1},
					{"id": "식량통조림", "amount": 1},
					{"id": "레드닷_사이트", "amount": 1},
					{"id": "수직_포어그립", "amount": 1}
				]
				drops.append(gear_pool.pick_random())
		4: # RAIDER
			drops.append({"id": "Scav 인식표", "amount": 1})
			var ammo_pool: Array = [
				{"id": "5.56mm", "amount": randi_range(18, 30)},
				{"id": "7.62mm", "amount": randi_range(18, 30)},
				{"id": "12게이지_슬러그", "amount": randi_range(8, 14)}
			]
			drops.append(ammo_pool.pick_random())
			if randf() < 0.80:
				var raider_guns: Array = ["AK_리시버", "M4_리시버", "MP5_리시버", "레버액션_리시버"]
				var r_id: String = str(raider_guns.pick_random())
				drops.append({"id": r_id, "amount": 1, "custom_data": WeaponPartsDatabase.create_loot_weapon(r_id, 0.10)})
			var high_pool: Array = [
				{"id": "구급상자", "amount": 1},
				{"id": "고급 치료킷", "amount": 1},
				{"id": "수류탄", "amount": 1},
				{"id": "2레벨_방탄복", "amount": 1},
				{"id": "2레벨_헬멧", "amount": 1},
				{"id": "2배율_조준경", "amount": 1},
				{"id": "대용량_확장_탄창", "amount": 1},
				{"id": "소음기", "amount": 1}
			]
			drops.append(high_pool.pick_random())
			if randf() < 0.32:
				drops.append({"id": "보안 키카드" if randf() < 0.35 else "무기고 열쇠", "amount": 1})
		6: # NIGHT_STALKER
			var night_pool: Array = [
				{"id": "고급 치료킷", "amount": 1},
				{"id": "암호화된 SSD", "amount": 1},
				{"id": "금시계", "amount": 1}
			]
			drops.append(night_pool.pick_random())
			if randf() < 0.35:
				drops.append({"id": "보안 키카드" if randf() < 0.5 else "무기고 열쇠", "amount": 1})
		5: # BOSS
			drops.append({"id": "Scav 인식표", "amount": 2})
			var boss_parts: Dictionary = {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "RK-1_인체공학_그립",
				"magazine": "50발_드럼_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
			var boss_stats: Dictionary = WeaponPartsDatabase.compute_weapon_stats("M4_리시버", boss_parts, "5.56mm")
			var boss_wep_custom: Dictionary = {
				"id": "M4_리시버",
				"receiver": "M4_리시버",
				"name": "보스 특제 M4A1 전술소총",
				"parts": boss_parts,
				"attachments": boss_parts,
				"computed_stats": boss_stats,
				"current_magazine_ammo": int(boss_stats.get("magazine_size", 50)),
				"loaded_ammo": "5.56mm",
				"durability": 100.0
			}
			drops.append({"id": "M4_리시버", "amount": 1, "custom_data": boss_wep_custom})
			drops.append({"id": "3레벨_방탄복", "amount": 1})
			drops.append({"id": "3레벨_헬멧", "amount": 1})
			drops.append({"id": "고급 치료킷", "amount": 1})
			drops.append({"id": "암호화된 SSD", "amount": 1})
			drops.append({"id": "장거리 무전기", "amount": 1})
			drops.append({"id": "보안 키카드", "amount": 1})
			drops.append({"id": "무기고 열쇠", "amount": 1})
	return drops

static func spawn_corpse_loot_box(enemy: Node2D, enemy_type: int, drops: Array, corpse_box_script: Script) -> void:
	if not enemy or not enemy.get_parent() or drops.is_empty():
		return
	var scene: Node = enemy.get_tree().current_scene if (enemy.is_inside_tree() and enemy.get_tree()) else null
	if scene == null or not ("container_inventories" in scene):
		var p: Node = enemy.get_parent()
		while p != null:
			if "container_inventories" in p:
				scene = p
				break
			p = p.get_parent()

	var base_tile: Vector2i = Vector2i(int(floor(enemy.global_position.x / 32.0)), int(floor(enemy.global_position.y / 32.0)))
	var chosen_tile: Vector2i = base_tile
	if scene and "container_inventories" in scene:
		var c_dict: Dictionary = scene.container_inventories
		if c_dict.has(chosen_tile):
			var found_free: bool = false
			for rad in range(1, 5):
				for dy in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						var cand: Vector2i = base_tile + Vector2i(dx, dy)
						if not c_dict.has(cand):
							chosen_tile = cand
							found_free = true
							break
					if found_free:
						break
				if found_free:
					break

	var title: String = "[icon:backpack] 스캐브 유품 가방"
	var rank: int = 3
	if enemy_type == 4: # RAIDER
		title = "[icon:backpack] 정예 레이더 군장 상자"
		rank = 4
	elif enemy_type == 5: # BOSS
		title = "[icon:skull] 보스 지휘관 특수 군장함"
		rank = 5

	var inv := Inventory.new()
	inv.max_slots = 12 if enemy_type == 5 else 8
	inv.clear()
	inv.set_meta("custom_title", title)
	if scene:
		scene.add_child(inv)
	else:
		enemy.get_parent().add_child(inv)

	var corpse_equipment: Dictionary = {
		"primary1": {},
		"helmet": {},
		"vest": {},
		"backpack": {}
	}
	var bag_drops: Array = []
	for d in drops:
		if not (d is Dictionary):
			continue
		var item_id: String = String(d.get("id", ""))
		if item_id == "":
			continue
		var amt: int = maxi(1, int(d.get("amount", 1)))
		var c_data: Dictionary = d.get("custom_data", {}).duplicate(true)
		if c_data.is_empty() and WeaponPartsDatabase.RECEIVERS.has(item_id):
			c_data = WeaponPartsDatabase.create_loot_weapon(item_id, 0.06)
		var sz: Vector2i = ItemDatabase.get_item_grid_size(item_id)
		var clean_cd: Dictionary = InventoryGrid.sanitize_custom_data(c_data)
		var item_dict: Dictionary = {
			"uid": InventoryGrid.next_uid(),
			"id": item_id,
			"amount": amt,
			"w": sz.x,
			"h": sz.y,
			"custom_data": clean_cd.duplicate(true)
		}
		for pk in InventoryGrid.PRESERVED_CUSTOM_KEYS:
			if clean_cd.has(pk):
				item_dict[pk] = clean_cd[pk]
		InventoryGrid.ensure_container_defaults(item_dict)

		var equip_slot: String = ItemDatabase.get_item_equip_slot(item_id)
		if equip_slot in ["primary", "sidearm"] and corpse_equipment["primary1"].is_empty():
			corpse_equipment["primary1"] = item_dict
		elif equip_slot == "helmet" and corpse_equipment["helmet"].is_empty():
			corpse_equipment["helmet"] = item_dict
		elif equip_slot == "vest" and corpse_equipment["vest"].is_empty():
			corpse_equipment["vest"] = item_dict
		elif equip_slot == "backpack" and corpse_equipment["backpack"].is_empty():
			corpse_equipment["backpack"] = item_dict
		else:
			bag_drops.append(item_dict)

	if corpse_equipment["vest"].is_empty():
		var vest_chance: float = 0.35 if enemy_type == 3 else (0.55 if enemy_type == 4 else 1.0)
		if randf() < vest_chance:
			var vest_id: String = "1레벨_방탄복" if enemy_type == 3 else ("2레벨_방탄복" if enemy_type == 4 else "3레벨_방탄복")
			var vsz: Vector2i = ItemDatabase.get_item_grid_size(vest_id)
			var v_item: Dictionary = {"uid": InventoryGrid.next_uid(), "id": vest_id, "amount": 1, "w": vsz.x, "h": vsz.y, "custom_data": {}}
			InventoryGrid.ensure_container_defaults(v_item)
			corpse_equipment["vest"] = v_item

	if corpse_equipment["backpack"].is_empty() and not bag_drops.is_empty():
		var bp_id: String = "3레벨_가방" if enemy_type == 5 else ("2레벨_가방" if enemy_type == 4 else "1레벨_가방")
		var bsz: Vector2i = ItemDatabase.get_item_grid_size(bp_id)
		var bp_item: Dictionary = {"uid": InventoryGrid.next_uid(), "id": bp_id, "amount": 1, "w": bsz.x, "h": bsz.y, "custom_data": {}}
		InventoryGrid.ensure_container_defaults(bp_item)
		corpse_equipment["backpack"] = bp_item

	var overflow_drops: Array = []
	var bp_slot: Dictionary = corpse_equipment.get("backpack", {})
	if not bp_slot.is_empty() and not bag_drops.is_empty():
		var spec: Dictionary = InventoryGrid.get_container_spec(bp_slot)
		var gw: int = maxi(1, int(spec.get("grid_w", 4)))
		var gh: int = maxi(1, int(spec.get("grid_h", 4)))
		var tmp_grid := InventoryGrid.new()
		tmp_grid.grid_width = gw
		tmp_grid.grid_height = gh
		tmp_grid._init_grid_map()
		for bd in bag_drops:
			var b_id: String = str(bd.get("id", ""))
			var b_amt: int = int(bd.get("amount", 1))
			var rem: int = tmp_grid.auto_add_item(b_id, b_amt, bd)
			if rem > 0:
				var ov: Dictionary = (bd as Dictionary).duplicate(true)
				ov["amount"] = rem
				overflow_drops.append(ov)
		for git in tmp_grid.items:
			if git is Dictionary and not git.is_empty():
				git["unsearched"] = true
				if not (git.get("custom_data", null) is Dictionary):
					git["custom_data"] = {}
				git["custom_data"]["unsearched"] = true
		InventoryGrid.sync_container_item_contents(bp_slot, tmp_grid)
		tmp_grid.free()
	else:
		overflow_drops = bag_drops

	inv.set_meta("is_corpse", true)
	inv.set_meta("corpse_equipment", corpse_equipment)
	for ov_item in overflow_drops:
		if ov_item is Dictionary:
			inv.add_item(String(ov_item.get("id", "")), int(ov_item.get("amount", 1)), ov_item)

	if scene and "container_inventories" in scene:
		scene.container_inventories[chosen_tile] = inv
		if "container_titles" in scene and scene.container_titles is Dictionary:
			scene.container_titles[chosen_tile] = title

	var box := StaticBody2D.new()
	box.set_script(corpse_box_script)
	box.global_position = enemy.global_position
	box.call("setup_corpse_box", chosen_tile, inv, title, rank)
	enemy.get_parent().call_deferred("add_child", box)
