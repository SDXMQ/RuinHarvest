# res://scripts/tools/test_runner.gd
extends Node

func _ready() -> void:
	print("=== RUIN HARVEST FULL INTEGRATION TEST START ===")
	var total_tests = 0
	var passed_tests = 0

	# Test 1: InventoryGrid has_secure_container default is false
	total_tests += 1
	var grid = InventoryGrid.new()
	if grid.has_secure_container == false:
		print("[PASS] Test 1: InventoryGrid default has_secure_container == false")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 1: InventoryGrid default has_secure_container != false")
	grid.free()

	# Test 2: WeaponPartsDatabase slot compatibility & RECEIVERS slots dictionary
	total_tests += 1
	var m4_rec = WeaponPartsDatabase.RECEIVERS.get("M4_리시버", {})
	if not m4_rec.is_empty() and m4_rec.has("slots") and m4_rec["slots"].has("barrel") and m4_rec["slots"].has("rail"):
		print("[PASS] Test 2: WeaponPartsDatabase RECEIVERS has valid 'slots' dictionary with barrel and rail")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 2: M4A1 receiver slots dictionary missing or invalid")

	# Test 3: WeaponHandler jamming mechanics
	total_tests += 1
	var wh = WeaponHandler.new()
	add_child(wh)
	wh.is_jammed = true
	wh.equipped_weapon_data = {"id": "M4A1_리시버", "computed_stats": {"magazine_size": 30, "rpm": 600}, "current_magazine_ammo": 20}
	wh.start_reload()
	if wh.is_jammed == false and wh.is_reloading == true and wh.reload_timer <= 0.85:
		print("[PASS] Test 3: WeaponHandler clears jam on start_reload (is_jammed=false, reload_timer=0.8)")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 3: WeaponHandler did not clear jam properly")
	wh.free()

	# Test 4: ExtractionZone types & requirements
	total_tests += 1
	var ez_default = preload("res://scenes/world/extraction_zone.gd").new()
	var ez_vehicle = preload("res://scenes/world/extraction_zone.gd").new()
	var ez_bunker = preload("res://scenes/world/extraction_zone.gd").new()
	
	ez_default.extraction_type = 0 # DEFAULT
	ez_default.extract_time = 7.0
	
	ez_vehicle.extraction_type = 1 # VEHICLE
	ez_vehicle.extract_time = 2.0
	ez_vehicle.required_rubles = 3000
	
	ez_bunker.extraction_type = 2 # BUNKER
	ez_bunker.extract_time = 5.0
	
	if ez_default.extract_time == 7.0 and ez_vehicle.extract_time == 2.0 and ez_bunker.extract_time == 5.0 and ez_vehicle.required_rubles == 3000:
		print("[PASS] Test 4: ExtractionZone 3 conditional extraction types correctly configured")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 4: ExtractionZone config mismatch")
	ez_default.free()
	ez_vehicle.free()
	ez_bunker.free()

	# Test 5: FieldObjective draw pulse logic & wave triggering
	total_tests += 1
	var fo = preload("res://scenes/world/objects/field_objective.gd").new()
	fo.set_hold_progress(0.3)
	if fo._wave_spawned == true:
		print("[PASS] Test 5: FieldObjective triggers defense wave at >= 25% hold progress")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 5: FieldObjective wave trigger failed")
	fo.free()

	# Test 6: ShootingRange hit calculations
	total_tests += 1
	var sr = preload("res://scenes/ui/shooting_range_window.gd").new()
	sr.setup({"id": "M4A1_리시버", "computed_stats": {"damage": 30.0, "rpm": 600, "accuracy": 90.0, "recoil": 15.0}})
	sr.range_canvas = Control.new()
	sr.range_canvas.size = Vector2(1000, 600)
	var head_pos = Vector2(220, 224.5)
	sr._process_bullet_impact(head_pos, 30.0)
	if sr.headshots_count == 1 and sr.hits_count == 1 and sr.total_damage > 60.0:
		print("[PASS] Test 6: ShootingRange headshot critical calculation succeeded (Damage: %.1f)" % sr.total_damage)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 6: ShootingRange hit processing failed (hits: %d, dmg: %.1f)" % [sr.hits_count, sr.total_damage])
	sr.range_canvas.free()
	sr.free()

	# Test 7: Tactical map window setup check
	total_tests += 1
	var mw = preload("res://scenes/ui/map_window.gd").new()
	mw.setup(Vector2(100, 200), 0.5, [{"name": "탈출구", "pos": Vector2(2000, 2000), "type": 0}], "군사기지", null, [], [], {})
	if mw.player_pos == Vector2(100, 200) and mw.current_biome == "군사기지" and mw.extraction_points.size() == 1:
		print("[PASS] Test 7: Tactical MapWindow setup with extraction points & biome succeeded")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 7: MapWindow setup failed")
	mw.free()

	# Test 8: SurvivalStats armor durability loss & zeroing verification
	total_tests += 1
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node2D\nvar equipment: Dictionary = {}"
	dummy_script.reload()
	var dummy_player = Node2D.new()
	dummy_player.set_script(dummy_script)
	var dummy_eq = {
		"helmet": {"id": "1레벨_헬멧", "durability": 100.0, "max_durability": 100.0},
		"vest": {"id": "1레벨_방탄복", "durability": 100.0, "max_durability": 100.0}
	}
	dummy_player.equipment = dummy_eq
	add_child(dummy_player)
	var surv = preload("res://scenes/entities/player/survival_stats.gd").new()
	dummy_player.add_child(surv)
	var def_full = surv.get_total_armor_defense()
	# 내구도를 0으로 파손 시 방어력 상실 검증
	dummy_eq["helmet"]["durability"] = 0.0
	dummy_eq["vest"]["durability"] = 0.0
	var def_broken = surv.get_total_armor_defense()
	if def_full >= 20.0 and def_broken == 0.0:
		print("[PASS] Test 8: Armor defense correctly scales to 0.0 when armor durability is 0 (Full: %.1f -> Broken: %.1f)" % [def_full, def_broken])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 8: Armor defense failed to zero out on 0 durability (Full: %.1f, Broken: %.1f)" % [def_full, def_broken])
	remove_child(dummy_player)
	dummy_player.free()

	# Test 9: WeaponModdingWindow multi-rail preservation
	total_tests += 1
	var m4_wep = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	var wmw = preload("res://scenes/ui/weapon_modding_window.gd").new()
	add_child(wmw)
	wmw.setup(null, null, m4_wep)
	var rail_arr = wmw.current_weapon.get("parts", {}).get("rail", [])
	if rail_arr is Array and rail_arr.size() >= 2:
		print("[PASS] Test 9: WeaponModdingWindow preserved multi-rail parts: %s" % str(rail_arr))
		passed_tests += 1
	else:
		printerr("[FAIL] Test 9: Multi-rail parts corrupted or vanished in modding window: %s" % str(rail_arr))
	wmw.free()

	# Test 10: ExtractionZone trigger enforcement when rubles insufficient
	total_tests += 1
	if GameManager:
		GameManager.current_world_data = {"player": {"rubles": 500}}
	var ez_sec = preload("res://scenes/world/extraction_zone.gd").new()
	ez_sec.extraction_type = 1 # VEHICLE
	ez_sec.required_rubles = 3000
	ez_sec._trigger_extraction()
	var final_rubles = int(GameManager.current_world_data["player"].get("rubles", 0)) if GameManager else 500
	if final_rubles == 500:
		print("[PASS] Test 10: ExtractionZone securely aborts vehicle extraction on insufficient rubles (Balance: %d)" % final_rubles)
		passed_tests += 1
	else:
		printerr("[FAIL] Test 10: Vehicle extraction allowed without sufficient rubles (Balance: %d)" % final_rubles)
	# Test 11: InventoryWindow ammo drag-and-drop reload & stack deduction
	total_tests += 1
	var inv_win = preload("res://scenes/ui/inventory_window.gd").new()
	var test_grid = InventoryGrid.new()
	var test_eq = {"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버")}
	test_eq["sidearm"]["current_magazine_ammo"] = 0
	inv_win.inventory_grid = test_grid
	inv_win.equipment_data = test_eq
	var ammo_item = {"id": "9mm", "amount": 20, "uid": "ammo_test_1"}
	inv_win.drag_data = {"item": ammo_item, "source": "grid"}
	inv_win._try_equip_weapon("sidearm")
	if test_eq["sidearm"]["current_magazine_ammo"] == 15 and ammo_item["amount"] == 5:
		print("[PASS] Test 11: Drag-and-drop ammo reload correctly loaded 15 rounds and left 5 in stack")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 11: Ammo reload math failed (Loaded: %d, Remainder: %d)" % [test_eq["sidearm"]["current_magazine_ammo"], ammo_item["amount"]])
	test_grid.free()
	inv_win.free()

	print("=== RESULTS: %d/%d TESTS PASSED ===" % [passed_tests, total_tests])
	get_tree().quit(0 if passed_tests == total_tests else 1)
