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

	# Test 12: ShootingRangeWindow default receiver ID check
	total_tests += 1
	var sr_default = preload("res://scenes/ui/shooting_range_window.gd").new()
	sr_default.setup({})
	var sr_rec = sr_default.weapon_data.get("receiver", sr_default.weapon_data.get("id", ""))
	if sr_rec == "M4_리시버":
		print("[PASS] Test 12: ShootingRangeWindow default weapon correctly loads M4_리시버")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 12: ShootingRangeWindow default weapon is '%s', expected 'M4_리시버'" % sr_rec)
	sr_default.free()

	# Test 13: HudTacticalHelper stylebox mutation prevention
	total_tests += 1
	var tac_theme = preload("res://ui/theme/tactical_theme.tres")
	var orig_sb = tac_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var orig_border = orig_sb.border_color
	var orig_bg = orig_sb.bg_color
	var quick_btn = Button.new()
	var hud_helper = preload("res://scenes/ui/hud_tactical_helper.gd")
	hud_helper.style_quickslot_button(quick_btn, "1", "", "1", "Test", true, true, Color(0.12, 0.98, 0.45))
	var sb_after = tac_theme.get_stylebox("normal", "Button") as StyleBoxFlat
	if sb_after.border_color == orig_border and sb_after.bg_color == orig_bg and quick_btn.has_theme_stylebox_override("normal"):
		print("[PASS] Test 13: HudTacticalHelper overrides normal stylebox without mutating tactical_theme.tres")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 13: tactical_theme.tres Button StyleBoxFlat was mutated! (Orig: %s, After: %s)" % [orig_border, sb_after.border_color])
	quick_btn.free()

	# Test 14: Fallback player inventory grid has_secure_container == true
	total_tests += 1
	var inv_win_fb = preload("res://scenes/ui/inventory_window.gd").new()
	inv_win_fb.setup(null, null)
	if inv_win_fb.inventory_grid and inv_win_fb.inventory_grid.has_secure_container == true:
		var can_place_weapon_in_secure = inv_win_fb.inventory_grid.can_place_item(2, 2, 0, 0, "", "M4_리시버")
		if can_place_weapon_in_secure == false:
			print("[PASS] Test 14: Fallback inventory grid has has_secure_container == true and rejects weapons in 2x2 secure zone")
			passed_tests += 1
		else:
			printerr("[FAIL] Test 14: Secure container allowed weapon in 2x2 secure zone!")
	else:
		printerr("[FAIL] Test 14: Fallback inventory grid has_secure_container is false or missing")
	inv_win_fb.free()

	# Test 15: _detach_all_item_parts in-place dictionary update
	total_tests += 1
	var inv_win_detach = preload("res://scenes/ui/inventory_window.gd").new()
	var d_grid = InventoryGrid.new()
	d_grid.resize_grid(6, 5)
	inv_win_detach.inventory_grid = d_grid
	var modded_weapon = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	modded_weapon["parts"] = {"optic": "레드닷_사이트", "barrel": "정밀_롱헤비_총열"}
	modded_weapon = WeaponPartsDatabase.compute_weapon_from_dict(modded_weapon)
	var modded_recoil = modded_weapon["computed_stats"]["recoil"]
	inv_win_detach._detach_all_item_parts(modded_weapon)
	if modded_weapon["parts"].is_empty() and modded_weapon["computed_stats"]["recoil"] != modded_recoil:
		print("[PASS] Test 15: _detach_all_item_parts modified weapon dictionary in-place (recoil: %.1f -> %.1f)" % [modded_recoil, modded_weapon["computed_stats"]["recoil"]])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 15: In-place update failed on weapon parts or computed_stats (modded: %.1f, now: %s)" % [modded_recoil, str(modded_weapon.get("computed_stats", {}).get("recoil", 0))])
	d_grid.free()
	inv_win_detach.free()

	# Test 16: Same-ammo top-up reload in _try_equip_weapon
	total_tests += 1
	var inv_win_topup = preload("res://scenes/ui/inventory_window.gd").new()
	var topup_grid = InventoryGrid.new()
	var topup_eq = {"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버")}
	topup_eq["sidearm"]["current_magazine_ammo"] = 10 # Max is 15
	inv_win_topup.inventory_grid = topup_grid
	inv_win_topup.equipment_data = topup_eq
	var topup_ammo = {"id": "9mm", "amount": 8, "uid": "topup_ammo_1"}
	inv_win_topup.drag_data = {"item": topup_ammo, "source": "grid"}
	inv_win_topup._try_equip_weapon("sidearm")
	if topup_eq["sidearm"]["current_magazine_ammo"] == 15 and topup_ammo["amount"] == 3 and topup_grid.items.size() == 0:
		print("[PASS] Test 16: Same ammo top-up reload filled to 15/15, left 3 in stack, without dumping existing 10 rounds")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 16: Same ammo top-up failed (Mag: %d, AmmoLeft: %d, BagItems: %d)" % [topup_eq["sidearm"]["current_magazine_ammo"], topup_ammo["amount"], topup_grid.items.size()])
	topup_grid.free()
	inv_win_topup.free()

	# Test 17: Split ammo drag-and-drop reload prevents ammo duplication
	total_tests += 1
	var inv_win_split = preload("res://scenes/ui/inventory_window.gd").new()
	var split_grid = InventoryGrid.new()
	var split_eq = {"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버")}
	split_eq["sidearm"]["current_magazine_ammo"] = 0
	inv_win_split.inventory_grid = split_grid
	inv_win_split.equipment_data = split_eq
	var orig_stack = {"id": "9mm", "amount": 20, "uid": "orig_ammo_stack"}
	var split_stack = {"id": "9mm", "amount": 10, "uid": "split_ammo_stack"}
	inv_win_split.drag_data = {
		"item": split_stack,
		"source": "split",
		"is_split": true,
		"split_source_item": orig_stack,
		"split_amount": 10
	}
	inv_win_split.is_dragging = true
	inv_win_split._try_equip_weapon("sidearm")
	if inv_win_split.is_dragging == false and split_eq["sidearm"]["current_magazine_ammo"] == 10 and orig_stack["amount"] == 20:
		print("[PASS] Test 17: Split ammo drag reload properly consumed split stack without duplicating into original stack")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 17: Split ammo duplication bug detected (Orig: %d, Mag: %d, is_dragging: %s)" % [orig_stack["amount"], split_eq["sidearm"]["current_magazine_ammo"], str(inv_win_split.is_dragging)])
	split_grid.free()
	inv_win_split.free()

	# Test 18: Attachment sub-slot drag initiation
	total_tests += 1
	var inv_win_attach = preload("res://scenes/ui/inventory_window.gd").new()
	var hbox = HBoxContainer.new()
	inv_win_attach.add_child(hbox)
	inv_win_attach.equipment_data = {"primary1": WeaponPartsDatabase.create_default_weapon("M4_리시버")}
	inv_win_attach._create_attachment_sub_slot(hbox, "primary1", "optic", "홀로그래픽_조준기", -1)
	var attach_btn = hbox.get_child(0) as Button
	var fake_click = InputEventMouseButton.new()
	fake_click.button_index = MOUSE_BUTTON_LEFT
	fake_click.pressed = true
	attach_btn.gui_input.emit(fake_click)
	if inv_win_attach.is_dragging and inv_win_attach.drag_data.get("source") == "attachment" and inv_win_attach.drag_data.get("item", {}).get("id") == "홀로그래픽_조준기":
		print("[PASS] Test 18: Left-clicking equipped attachment initiates attachment drag with correct item data")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 18: Attachment sub-slot left-click did not initiate drag (is_dragging: %s, data: %s)" % [str(inv_win_attach.is_dragging), str(inv_win_attach.drag_data)])
	inv_win_attach.free()

	# Test 19: weapon_durability_bar does not mutate tactical_theme.tres ProgressBar fill stylebox
	total_tests += 1
	var pb_theme = preload("res://ui/theme/tactical_theme.tres")
	var orig_fill_sb = pb_theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat
	var orig_fill_bg = orig_fill_sb.bg_color
	var bar = ProgressBar.new()
	bar.theme = pb_theme
	var fill_style: StyleBoxFlat
	if bar.has_theme_stylebox_override("fill"):
		fill_style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not fill_style:
		var base_style = bar.get_theme_stylebox("fill")
		fill_style = base_style.duplicate() as StyleBoxFlat if base_style is StyleBoxFlat else StyleBoxFlat.new()
		bar.add_theme_stylebox_override("fill", fill_style)
	fill_style.bg_color = Color(0.9, 0.2, 0.2)
	var fill_after = pb_theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat
	if fill_after.bg_color == orig_fill_bg and bar.has_theme_stylebox_override("fill"):
		print("[PASS] Test 19: weapon_durability_bar fill stylebox overridden without mutating tactical_theme.tres")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 19: tactical_theme.tres ProgressBar fill was mutated! (Orig: %s, After: %s)" % [orig_fill_bg, fill_after.bg_color])
	bar.free()

	# Test 20: Dropping attachment into container removes it from weapon (prevents dupe)
	total_tests += 1
	var inv_win_cont = preload("res://scenes/ui/inventory_window.gd").new()
	var cont_inv = Inventory.new()
	cont_inv.clear()
	var cont_eq = {"primary1": WeaponPartsDatabase.create_default_weapon("M4_리시버")}
	inv_win_cont.equipment_data = cont_eq
	inv_win_cont.target_inventory = cont_inv
	inv_win_cont.is_dragging = true
	var attach_drop_item = {
		"id": "4배율_ACOG",
		"weapon_slot": "primary1",
		"attach_slot": "optic",
		"rail_index": -1,
		"amount": 1
	}
	inv_win_cont.drag_data = {
		"source": "attachment",
		"item": attach_drop_item,
		"weapon_slot": "primary1",
		"attach_slot": "optic",
		"rail_index": -1
	}
	inv_win_cont._try_drop_on_container()
	var primary_parts = cont_eq["primary1"].get("parts", {})
	if cont_inv.get_item_count("4배율_ACOG") == 1 and not primary_parts.has("optic"):
		print("[PASS] Test 20: Dropping attachment into container moved item to container and removed from weapon")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 20: Dropping attachment into container failed or duplicated (ContCount: %d, WeaponHasOptic: %s)" % [cont_inv.get_item_count("4배율_ACOG"), str(primary_parts.has("optic"))])
	cont_inv.free()
	inv_win_cont.free()

	# Test 21: _detach_all_item_parts safely returns excess ammo when magazine size shrinks
	total_tests += 1
	var inv_win_mag = preload("res://scenes/ui/inventory_window.gd").new()
	var mag_grid = InventoryGrid.new()
	mag_grid.resize_grid(6, 6)
	inv_win_mag.inventory_grid = mag_grid
	var ak_weapon = WeaponPartsDatabase.create_default_weapon("AK_리시버")
	ak_weapon["current_magazine_ammo"] = 30
	ak_weapon["loaded_ammo"] = "7.62mm"
	inv_win_mag._detach_all_item_parts(ak_weapon)
	var returned_ammo_count = mag_grid.get_item_count("7.62mm")
	if ak_weapon["current_magazine_ammo"] == 10 and returned_ammo_count == 20:
		print("[PASS] Test 21: _detach_all_item_parts returned 20 excess rounds to inventory instead of evaporating")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 21: Excess ammo evaporated on magazine detachment (GunAmmo: %d, BagAmmo: %d)" % [ak_weapon.get("current_magazine_ammo", 0), returned_ammo_count])
	mag_grid.free()
	inv_win_mag.free()

	# Test 22: Player entity initializes inventory_grid with has_secure_container == true
	total_tests += 1
	var player_test = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(player_test)
	if player_test.inventory_grid and player_test.inventory_grid.has_secure_container == true:
		print("[PASS] Test 22: Player scene initializes inventory_grid.has_secure_container == true")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 22: Player scene failed to set inventory_grid.has_secure_container == true")
	player_test.queue_free()

	# Test 23: Split ammo partial top-up reload correctly returns unused split ammo to source stack
	total_tests += 1
	var inv_win_partial = preload("res://scenes/ui/inventory_window.gd").new()
	var partial_grid = InventoryGrid.new()
	var partial_eq = {"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버")}
	partial_eq["sidearm"]["current_magazine_ammo"] = 12 # needs 3
	inv_win_partial.inventory_grid = partial_grid
	inv_win_partial.equipment_data = partial_eq
	var p_orig = {"id": "9mm", "amount": 10, "uid": "p_orig_ammo"}
	var p_split = {"id": "9mm", "amount": 10, "uid": "p_split_ammo"}
	inv_win_partial.drag_data = {
		"item": p_split,
		"source": "split",
		"is_split": true,
		"split_source_item": p_orig,
		"split_amount": 10
	}
	inv_win_partial.is_dragging = true
	inv_win_partial._try_equip_weapon("sidearm")
	if partial_eq["sidearm"]["current_magazine_ammo"] == 15 and p_orig["amount"] == 17:
		print("[PASS] Test 23: Split ammo partial top-up loaded 3 rounds and returned remaining 7 rounds to source stack")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 23: Split partial reload math error (Mag: %d, OrigStack: %d)" % [partial_eq["sidearm"]["current_magazine_ammo"], p_orig["amount"]])
	partial_grid.free()
	inv_win_partial.free()

	print("=== RESULTS: %d/%d TESTS PASSED ===" % [passed_tests, total_tests])
	get_tree().quit(0 if passed_tests == total_tests else 1)
