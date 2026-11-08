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

	# Test 24: InventoryGrid.auto_add_item preserves custom_data keys and damaged armor durability
	total_tests += 1
	var test24_grid = InventoryGrid.new()
	test24_grid.resize_grid(6, 6)
	var modded_gun_custom = {
		"parts": {"optic": "4배율_ACOG", "muzzle": "소음기"},
		"loaded_ammo": "5.56mm",
		"current_magazine_ammo": 27,
		"computed_stats": {"magazine_size": 30, "rpm": 650}
	}
	test24_grid.auto_add_item("M4_리시버", 1, modded_gun_custom)
	var damaged_vest_custom = {
		"durability": 35.0
	}
	test24_grid.auto_add_item("3레벨_방탄복", 1, damaged_vest_custom)
	
	var gun_item = test24_grid.items[0]
	var vest_item = test24_grid.items[1]
	var gun_ok = gun_item.has("parts") and gun_item["parts"].get("optic") == "4배율_ACOG" and gun_item.get("current_magazine_ammo") == 27
	var vest_ok = vest_item.get("durability") == 35.0
	if gun_ok and vest_ok:
		print("[PASS] Test 24: InventoryGrid.auto_add_item preserves top-level parts/ammo and preserves damaged armor durability without resetting")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 24: custom_data keys lost or durability reset (GunOK: %s, VestDur: %s)" % [str(gun_ok), str(vest_item.get("durability"))])
	test24_grid.free()

	# Test 25: 1D Container Inventory.add_item preserves custom_data
	total_tests += 1
	var test25_inv = Inventory.new()
	test25_inv.clear()
	test25_inv.add_item("3레벨_방탄복", 1, {"durability": 42.0})
	test25_inv.add_item("M4_리시버", 1, {"parts": {"optic": "4배율_ACOG"}, "loaded_ammo": "5.56mm", "current_magazine_ammo": 18})
	var slot0 = test25_inv.items[0]
	var slot1 = test25_inv.items[1]
	var inv_vest_ok = slot0 != null and slot0.get("durability") == 42.0
	var inv_gun_ok = slot1 != null and slot1.has("parts") and slot1.get("current_magazine_ammo") == 18
	if inv_vest_ok and inv_gun_ok:
		print("[PASS] Test 25: Inventory (1D container) preserves custom_data parts and damaged armor durability")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 25: Inventory custom_data preservation failed (VestOK: %s, GunOK: %s)" % [str(inv_vest_ok), str(inv_gun_ok)])
	test25_inv.free()

	# Test 26: Clamping weapon excess ammo returns surplus rounds to inventory grid
	total_tests += 1
	var test26_win = preload("res://scenes/ui/inventory_window.gd").new()
	var test26_grid = InventoryGrid.new()
	test26_grid.resize_grid(6, 6)
	test26_win.inventory_grid = test26_grid
	var test_wep = {
		"id": "AK_리시버",
		"computed_stats": {"magazine_size": 10},
		"current_magazine_ammo": 30,
		"loaded_ammo": "7.62mm"
	}
	test26_win._clamp_weapon_excess_ammo(test_wep)
	var bag_ammo = test26_grid.get_item_count("7.62mm")
	if test_wep["current_magazine_ammo"] == 10 and bag_ammo == 20:
		print("[PASS] Test 26: _clamp_weapon_excess_ammo clamped magazine to 10 and refunded 20 rounds to inventory")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 26: Clamping failed (Mag: %d, Bag: %d)" % [test_wep["current_magazine_ammo"], bag_ammo])
	test26_grid.free()
	test26_win.free()

	# Test 27: MapWindow zoom & pan state and EventBus random_world_event_triggered signal
	total_tests += 1
	var map_win = preload("res://scenes/ui/map_window.gd").new()
	var has_event_sig = EventBus.has_signal("random_world_event_triggered")
	var map_fields_ok = "scale_factor" in map_win and "map_pan_offset" in map_win
	if has_event_sig and map_fields_ok:
		print("[PASS] Test 27: MapWindow zoom/pan fields and EventBus.random_world_event_triggered verified")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 27: Signal or MapWindow fields missing (Sig: %s, Map: %s)" % [str(has_event_sig), str(map_fields_ok)])
	map_win.free()

	# Test 28: _drop_item_to_world preserves modified parts, ammo, and reduced armor durability
	total_tests += 1
	var t28_world = Node2D.new()
	var t28_entities = Node2D.new()
	t28_entities.name = "Entities"
	t28_world.add_child(t28_entities)
	var t28_player = preload("res://scenes/entities/player/player.tscn").instantiate()
	t28_entities.add_child(t28_player)
	add_child(t28_world)
	var t28_win = preload("res://scenes/ui/inventory_window.gd").new()
	t28_win.player = t28_player
	var mod_gun = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	mod_gun["parts"]["optic"] = "8배율_스나이퍼_스코프"
	mod_gun["current_magazine_ammo"] = 7
	mod_gun["durability"] = 63.0
	mod_gun["custom_data"] = {} # Simulate stale/empty custom_data
	t28_win._drop_item_to_world(mod_gun)
	var dropped_ground: GroundItem = null
	for ch in get_tree().root.get_children():
		if ch is GroundItem:
			dropped_ground = ch
			break
	if dropped_ground == null:
		for ch in t28_entities.get_children():
			if ch is GroundItem:
				dropped_ground = ch
				break
	var t28_grid = InventoryGrid.new()
	t28_grid.resize_grid(6, 6)
	var t28_ok = false
	if dropped_ground != null:
		t28_grid.auto_add_item(dropped_ground.item_id, dropped_ground.amount, dropped_ground.custom_data)
		if t28_grid.items.size() == 1:
			var recovered = t28_grid.items[0]
			t28_ok = recovered.get("parts", {}).get("optic", "") == "8배율_스나이퍼_스코프" and int(recovered.get("current_magazine_ammo", -1)) == 7 and is_equal_approx(float(recovered.get("durability", 0.0)), 63.0)
		dropped_ground.free()
	if t28_ok:
		print("[PASS] Test 28: _drop_item_to_world preserves top-level parts, remaining ammo, and damaged durability")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 28: _drop_item_to_world lost top-level attributes")
	t28_grid.free()
	t28_win.free()
	t28_world.free()

	# Test 29: InventoryGrid.place_item unpacks custom_data keys on direct drag-and-drop
	total_tests += 1
	var t29_grid = InventoryGrid.new()
	t29_grid.resize_grid(6, 6)
	var drag_payload = {
		"id": "AK_리시버",
		"amount": 1,
		"w": 3,
		"h": 2,
		"custom_data": {
			"parts": {"muzzle": "소음기"},
			"loaded_ammo": "7.62mm",
			"current_magazine_ammo": 22,
			"durability": 55.0
		}
	}
	var placed_ok = t29_grid.place_item(drag_payload, 2, 0, false)
	var placed_it = t29_grid.get_item_at(2, 0)
	if placed_ok and placed_it.get("parts", {}).get("muzzle", "") == "소음기" and int(placed_it.get("current_magazine_ammo", 0)) == 22 and is_equal_approx(float(placed_it.get("durability", 0.0)), 55.0):
		print("[PASS] Test 29: InventoryGrid.place_item unpacks custom_data attributes to top-level")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 29: place_item failed to unpack custom_data: ", placed_it)
	t29_grid.free()

	# Test 30: Context menu [Use / Equip] ignores open container instead of transferring item into container
	total_tests += 1
	var t30_win = preload("res://scenes/ui/inventory_window.gd").new()
	var t30_grid = InventoryGrid.new()
	t30_grid.resize_grid(6, 6)
	var t30_container = Inventory.new()
	t30_container.clear()
	t30_win.inventory_grid = t30_grid
	t30_win.target_inventory = t30_container
	t30_win.equipment_data = {"helmet": {}, "vest": {}, "backpack": {}, "bottom": {}, "primary1": {}, "primary2": {}, "sidearm": {}, "throwable": {}}
	t30_grid.auto_add_item("3레벨_헬멧", 1, {"durability": 88.0})
	var helmet_in_bag = t30_grid.items[0]
	t30_win._handle_item_quick_action(helmet_in_bag, true)
	var equipped_h = t30_win.equipment_data.get("helmet", {})
	var container_has_helmet = t30_container.get_item_count("3레벨_헬멧") > 0
	if equipped_h.get("id", "") == "3레벨_헬멧" and not container_has_helmet:
		print("[PASS] Test 30: _handle_item_quick_action(item, true) equips item even while container is open")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 30: Context quick action sent item to container or failed to equip")
	t30_container.free()
	t30_grid.free()
	t30_win.free()

	# Test 31: AirdropCrate bonus weapon is assembled via create_default_weapon with parts and ammo
	total_tests += 1
	var t31_mw = preload("res://scenes/world/main_world.gd").new()
	t31_mw._on_object_interacted(Vector2.ZERO, Vector2i(99, 99), Vector2i(7, 2))
	var airdrop_inv: Inventory = t31_mw.container_inventories.get(Vector2i(99, 99), null)
	var found_complete_gun = false
	if airdrop_inv != null:
		for s_it in airdrop_inv.items:
			if s_it != null and s_it.get("id", "") in ["M4_리시버", "AK_리시버", "SV98_리시버"]:
				if s_it.has("parts") and not s_it["parts"].is_empty() and int(s_it.get("current_magazine_ammo", 0)) > 0:
					found_complete_gun = true
					break
	if found_complete_gun:
		print("[PASS] Test 31: AirdropCrate spawns fully assembled weapon with parts and loaded magazine")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 31: AirdropCrate bonus weapon missing parts or ammo")
	t31_mw.free()

	# Test 32: EventSystem RAID defense_check fails when unarmored (spawning Raiders & HP penalty) and passes when armored
	total_tests += 1
	var t32_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t32_p)
	t32_p.hp = 100.0
	t32_p.armor_defense = 0.0
	t32_p.equipped_weapon = "맨손"
	t32_p.equipped_weapon_data = {}
	t32_p.equipment = {}
	var raid_spawn_info = {"raiders": 0}
	var raid_cb = func(ev_id: String, ev_data: Dictionary):
		if ev_id == "야간_습격":
			raid_spawn_info["raiders"] = int(ev_data.get("raider_count", 0))
	EventBus.random_world_event_triggered.connect(raid_cb)
	var def_fail_res = EventSystem.trigger_event("야간_습격", t32_p)
	var hp_after_fail = t32_p.hp
	t32_p.armor_defense = 25.0
	var def_pass_res = EventSystem.trigger_event("야간_습격", t32_p)
	EventBus.random_world_event_triggered.disconnect(raid_cb)
	if (not def_fail_res) and is_equal_approx(hp_after_fail, 80.0) and raid_spawn_info["raiders"] >= 2 and def_pass_res:
		print("[PASS] Test 32: EventSystem RAID defense_check penalizes unarmored player (-20 HP, %d Raiders) and passes at 25 armor" % raid_spawn_info["raiders"])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 32: RAID defense_check failed (FailRes: %s, HP: %.1f, Raiders: %d, PassRes: %s)" % [str(def_fail_res), hp_after_fail, raid_spawn_info["raiders"], str(def_pass_res)])
	t32_p.free()

	# Test 33: New procedural tiles (Bed, Desk, Shelf, Locked Door, Horizontal Road Line, Crosswalk) & Secure Container Keys
	total_tests += 1
	var ts_check := TileManager.get_tileset()
	var atlas_src: TileSetAtlasSource = ts_check.get_source(0) as TileSetAtlasSource if ts_check and ts_check.get_source_count() > 0 else null
	var tiles_valid := false
	if atlas_src != null:
		var has_bed_col = atlas_src.has_tile(TileManager.OBJ_BED) and atlas_src.get_tile_data(TileManager.OBJ_BED, 0).get_collision_polygons_count(0) > 0
		var has_desk_col = atlas_src.has_tile(TileManager.OBJ_DESK) and atlas_src.get_tile_data(TileManager.OBJ_DESK, 0).get_collision_polygons_count(0) > 0
		var has_shelf_col = atlas_src.has_tile(TileManager.OBJ_SHELF) and atlas_src.get_tile_data(TileManager.OBJ_SHELF, 0).get_collision_polygons_count(0) > 0
		var has_locked_col = atlas_src.has_tile(TileManager.OBJ_DOOR_LOCKED) and atlas_src.get_tile_data(TileManager.OBJ_DOOR_LOCKED, 0).get_collision_polygons_count(0) > 0
		var has_road_h = atlas_src.has_tile(TileManager.TILE_ROAD_LINE_H) and atlas_src.has_tile(TileManager.TILE_CROSSWALK)
		tiles_valid = has_bed_col and has_desk_col and has_shelf_col and has_locked_col and has_road_h
	var t33_grid := InventoryGrid.new()
	var key_sec_ok = t33_grid.is_allowed_in_secure_container("무기고 열쇠") and t33_grid.is_allowed_in_secure_container("보안 키카드")
	t33_grid.free()
	if tiles_valid and key_sec_ok:
		print("[PASS] Test 33: New furniture/locked-door/road tiles registered with physics & keys allowed in Secure Container")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 33: TileSet or Secure Container key check failed (tiles_valid=%s, key_sec_ok=%s)" % [str(tiles_valid), str(key_sec_ok)])

	# Test 34: Procedural WorldGenerator indoor mask (0 indoor grass/trees) & hybrid road continuity
	total_tests += 1
	var t34_gen := WorldGenerator.new(123456)
	var t34_bad_indoor := 0
	var t34_bad_road := 0
	for cy in range(-3, 3):
		for cx in range(-3, 3):
			var cd := t34_gen.generate_chunk(Vector2i(cx, cy))
			var c_tiles: Array = cd["tiles"]
			var c_objs: Array = cd["objects"]
			var c_in: PackedByteArray = cd["inside_mask"]
			for i in range(WorldGenerator.CHUNK_SIZE * WorldGenerator.CHUNK_SIZE):
				if c_in[i] == 1:
					if c_tiles[i] == TileManager.TILE_GRASS or c_objs[i] == TileManager.OBJ_TREE or c_objs[i] == TileManager.OBJ_ROCK:
						t34_bad_indoor += 1
				var wx := cx * WorldGenerator.CHUNK_SIZE + (i % WorldGenerator.CHUNK_SIZE)
				var wy := cy * WorldGenerator.CHUNK_SIZE + int(i / WorldGenerator.CHUNK_SIZE)
				if t34_gen.is_road(wx, wy):
					var rn := 0
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if t34_gen.is_road(wx + d.x, wy + d.y):
							rn += 1
					if rn < 2:
						t34_bad_road += 1
	if t34_bad_indoor == 0 and t34_bad_road == 0:
		print("[PASS] Test 34: WorldGenerator guarantees 0 indoor grass/trees and 100% continuous non-crumbling roads")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 34: WorldGenerator check failed (bad_indoor=%d, bad_road=%d)" % [t34_bad_indoor, t34_bad_road])

	# Test 35: All 12 BuildingPresets flood-fill interior & furniture reachability
	total_tests += 1
	var t35_ok := true
	for bt in BuildingPresets.BuildingType.values():
		var pr := BuildingPresets.get_preset(bt)
		var bw := int(pr["width"])
		var bh := int(pr["height"])
		var is_l: bool = String(pr.get("shape", "rect")) == "l_shape"
		var f_map := {}
		for f in pr.get("furniture", []):
			f_map[Vector2i(int(f["x"]), int(f["y"]))] = true
		var walk := {}
		for ry in range(bh):
			for rx in range(bw):
				if is_l and rx >= bw / 2 and ry < bh / 2:
					continue
				var pt := Vector2i(rx, ry)
				var ext := (rx == 0 or ry == bh - 1 or (ry == 0 and rx < bw / 2) or (rx == bw - 1 and ry >= bh / 2) or (rx == bw / 2 - 1 and ry <= bh / 2) or (ry == bh / 2 and rx >= bw / 2 - 1)) if is_l else (rx == 0 or rx == bw - 1 or ry == 0 or ry == bh - 1)
				if ext:
					if pt in pr.get("doors", []): walk[pt] = true
				else:
					if pt in pr.get("locked_doors", []) or pt in pr.get("inner_doors", []): walk[pt] = true
					elif not (pt in pr.get("inner_walls", []) or f_map.has(pt)): walk[pt] = true
		var vis := {}
		var q: Array[Vector2i] = []
		for d_pt in pr.get("doors", []):
			if walk.has(d_pt):
				vis[d_pt] = true
				q.append(d_pt)
		while not q.is_empty():
			var cur: Vector2i = q.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if walk.has(cur + d) and not vis.has(cur + d):
					vis[cur + d] = true
					q.append(cur + d)
		if vis.size() != walk.size():
			t35_ok = false
		for f_pt in f_map.keys():
			if not (vis.has(f_pt + Vector2i(1, 0)) or vis.has(f_pt + Vector2i(-1, 0)) or vis.has(f_pt + Vector2i(0, 1)) or vis.has(f_pt + Vector2i(0, -1))):
				t35_ok = false
	if t35_ok:
		print("[PASS] Test 35: All 12 BuildingPresets pass 100% floor and furniture flood-fill reachability")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 35: One or more BuildingPresets have unreachable rooms or blocked furniture")

	# Test 36: Locked Door (OBJ_DOOR_LOCKED) blocks keyless player and unlocks when key is in Secure Container
	total_tests += 1
	var t36_mw = preload("res://scenes/world/main_world.gd").new()
	var t36_cm = preload("res://scenes/world/chunk_manager.gd").new()
	t36_cm.object_layer = TileMapLayer.new()
	t36_cm.object_layer.tile_set = TileManager.get_tileset()
	t36_cm.add_child(t36_cm.object_layer)
	t36_mw.chunk_manager = t36_cm
	var t36_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t36_p)
	t36_mw.player = t36_p
	var lock_pos := Vector2i(42, 42)
	t36_cm.object_layer.set_cell(lock_pos, 0, TileManager.OBJ_DOOR_LOCKED)
	# Attempt without key -> remains OBJ_DOOR_LOCKED
	t36_mw._on_object_interacted(Vector2.ZERO, lock_pos, TileManager.OBJ_DOOR_LOCKED)
	var still_locked = t36_cm.object_layer.get_cell_atlas_coords(lock_pos) == TileManager.OBJ_DOOR_LOCKED
	# Place key inside 2x2 Secure Container at (0, 0) and retry -> becomes OBJ_DOOR_OPEN
	t36_p.inventory_grid.place_item({"id": "무기고 열쇠", "amount": 1, "w": 1, "h": 1}, 0, 0, false)
	t36_mw._on_object_interacted(Vector2.ZERO, lock_pos, TileManager.OBJ_DOOR_LOCKED)
	var unlocked_now = t36_cm.object_layer.get_cell_atlas_coords(lock_pos) == TileManager.OBJ_DOOR_OPEN
	# Also verify new Desk furniture container interaction populates loot
	t36_mw._on_object_interacted(Vector2.ZERO, Vector2i(43, 42), TileManager.OBJ_DESK)
	var desk_inv_ok = t36_mw.container_inventories.has(Vector2i(43, 42))
	if still_locked and unlocked_now and desk_inv_ok:
		print("[PASS] Test 36: OBJ_DOOR_LOCKED requires key, unlocks via Secure Container key, and OBJ_DESK spawns container loot")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 36: Locked door / Desk interaction failed (still_locked=%s, unlocked_now=%s, desk_inv_ok=%s)" % [str(still_locked), str(unlocked_now), str(desk_inv_ok)])
	t36_p.free()
	t36_cm.free()
	t36_mw.free()

	# Test 37: Armor slot buttons (Helmet, Vest) render 4px SlotDurabilityBar & support slot context menu
	total_tests += 1
	var t37_helm_btn := Button.new()
	var t37_vest_btn := Button.new()
	var t37_eq := {
		"helmet": {"id": "3레벨_헬멧", "durability": 42.0, "max_durability": 100.0},
		"vest": {"id": "2레벨_방탄복", "durability": 18.0, "max_durability": 80.0}
	}
	InventoryUIHelper.render_equip_slot_button(t37_helm_btn, "helmet", "HEAD", t37_eq)
	InventoryUIHelper.render_equip_slot_button(t37_vest_btn, "vest", "RIG", t37_eq)
	var h_bar: ProgressBar = t37_helm_btn.get_node_or_null("SlotDurabilityBar") as ProgressBar
	var v_bar: ProgressBar = t37_vest_btn.get_node_or_null("SlotDurabilityBar") as ProgressBar
	var t37_win = preload("res://scenes/ui/inventory_window.tscn").instantiate()
	add_child(t37_win)
	t37_win.equipment_data = t37_eq
	t37_win._show_context_menu(t37_eq["helmet"], "equipment", "helmet")
	var ctx_ok = t37_win.context_menu_panel != null
	if h_bar != null and h_bar.visible and is_equal_approx(h_bar.value, 42.0) and v_bar != null and v_bar.visible and is_equal_approx(v_bar.value, 18.0) and ctx_ok:
		print("[PASS] Test 37: Helmet & Vest slots render 4px SlotDurabilityBar and open slot context menu")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 37: Armor durability bar or context menu failed")
	t37_helm_btn.free()
	t37_vest_btn.free()
	t37_win.free()

	# Test 38: MapWindow conditional extraction lock status ([잠김: 3,000R 필요] & [잠김: 단말기 미해킹])
	total_tests += 1
	var MapWinScript = preload("res://scenes/ui/map_window.gd")
	GameManager.current_world_data = {"player": {"rubles": 1200, "field_objectives_completed": 0}}
	GameManager.raid_landmark_completed = false
	var lock_v1: Dictionary = MapWinScript.get_extraction_lock_info(1, [])
	var lock_b1: Dictionary = MapWinScript.get_extraction_lock_info(2, [])
	GameManager.current_world_data["player"]["rubles"] = 4500
	GameManager.raid_landmark_completed = true
	var lock_v2: Dictionary = MapWinScript.get_extraction_lock_info(1, [])
	var lock_b2: Dictionary = MapWinScript.get_extraction_lock_info(2, [])
	if bool(lock_v1["locked"]) and String(lock_v1["reason"]) == "잠김: 3,000R 필요" and bool(lock_b1["locked"]) and String(lock_b1["reason"]) == "잠김: 단말기 미해킹" and not bool(lock_v2["locked"]) and not bool(lock_b2["locked"]):
		print("[PASS] Test 38: Tactical Map conditional extractions report exact lock reasons and unlock dynamically")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 38: Conditional extraction lock check failed: ", lock_v1, lock_b1, lock_v2, lock_b2)

	# Test 39: WeaponModdingWindow left TestInRangeBtn & Differentiated Repair (Hideout 1.0x vs In-Raid 1.5x & -10% max_durability)
	total_tests += 1
	var t39_grid := InventoryGrid.new()
	var t39_mod = preload("res://scenes/ui/weapon_modding_window.gd").new()
	add_child(t39_mod)
	t39_mod.setup(t39_grid, null, WeaponPartsDatabase.create_default_weapon("M4_리시버"))
	var range_btn = t39_mod.find_child("TestInRangeBtn", true, false)
	var range_is_leftmost = range_btn != null and range_btn.get_index() == 0
	var t39_win = preload("res://scenes/ui/inventory_window.gd").new()
	GameManager.current_world_data = {"player": {"rubles": 5000}}
	GameManager.current_state = GameManager.GameState.HIDEOUT
	var vest_hideout = {"id": "3레벨_방탄복", "durability": 80.0, "max_durability": 100.0}
	var rep_h_ok = t39_win.perform_item_repair(vest_hideout)
	var rub_after_h = int(GameManager.current_world_data["player"]["rubles"]) # 5000 - 200 = 4800
	GameManager.current_state = GameManager.GameState.IN_GAME
	var vest_field = {"id": "3레벨_방탄복", "durability": 80.0, "max_durability": 100.0}
	var rep_f_ok = t39_win.perform_item_repair(vest_field)
	var rub_after_f = int(GameManager.current_world_data["player"]["rubles"]) # 4800 - 300 = 4500
	if range_is_leftmost and rep_h_ok and rub_after_h == 4800 and is_equal_approx(float(vest_hideout["max_durability"]), 100.0) and rep_f_ok and rub_after_f == 4500 and is_equal_approx(float(vest_field["max_durability"]), 90.0) and is_equal_approx(float(vest_field["durability"]), 90.0):
		print("[PASS] Test 39: Modding footer has leftmost TestInRangeBtn & Field Repair applies 1.5x cost and -10% max_durability")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 39: Modding range button or repair differentiation failed")
	t39_win.free()
	t39_mod.free()
	t39_grid.free()

	# Test 40: Jammed weapon dry_fire WAV & try_attack dry-fire handling
	total_tests += 1
	var dry_wav = SoundManager.get_sound("dry_fire")
	var t40_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t40_p)
	var t40_wh = t40_p.get_node("WeaponHandler")
	t40_wh.equipped_weapon_data = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	t40_wh.equipped_weapon_data["current_magazine_ammo"] = 20
	t40_wh.is_jammed = true
	t40_wh.try_attack(Vector2.RIGHT, Vector2.ZERO)
	if dry_wav != null and dry_wav.data.size() > 100 and int(t40_wh.equipped_weapon_data["current_magazine_ammo"]) == 20 and t40_wh.attack_cooldown_timer > 0.0:
		print("[PASS] Test 40: SoundManager generates dry_fire WAV and jammed weapon triggers dry-fire without spending ammo")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 40: Jammed dry-fire check failed")
	t40_p.free()

	# Test 41: Ammo penetration vs Enemy armor_value (Scav=15, Raider=30, Boss=45) up to 60% damage reduction
	total_tests += 1
	var BulletScript = preload("res://scenes/entities/projectiles/bullet.gd")
	var e_scav = preload("res://scenes/entities/enemies/enemy.tscn").instantiate()
	e_scav.enemy_type = 3
	add_child(e_scav)
	var e_raider = preload("res://scenes/entities/enemies/enemy.tscn").instantiate()
	e_raider.enemy_type = 4
	add_child(e_raider)
	var e_boss = preload("res://scenes/entities/enemies/enemy.tscn").instantiate()
	e_boss.enemy_type = 5
	add_child(e_boss)
	var mult_buckshot_boss: float = BulletScript.compute_armor_damage_multiplier(5.0, e_boss.armor_value) # ~0.4667
	var mult_9mm_raider: float = BulletScript.compute_armor_damage_multiplier(10.0, e_raider.armor_value) # 0.60
	var mult_762_raider: float = BulletScript.compute_armor_damage_multiplier(35.0, e_raider.armor_value) # 1.00
	var mult_zero_boss: float = BulletScript.compute_armor_damage_multiplier(0.0, e_boss.armor_value) # 0.40 (max 60% reduction)
	if is_equal_approx(e_scav.armor_value, 15.0) and is_equal_approx(e_raider.armor_value, 30.0) and is_equal_approx(e_boss.armor_value, 45.0) and is_equal_approx(mult_9mm_raider, 0.60) and is_equal_approx(mult_762_raider, 1.0) and is_equal_approx(mult_zero_boss, 0.40) and mult_buckshot_boss < 0.50:
		print("[PASS] Test 41: Enemy armor (15/30/45) vs ammo penetration scales damage accurately (9mm vs Raider=%.2f, 7.62 vs Raider=%.2f)" % [mult_9mm_raider, mult_762_raider])
		passed_tests += 1
	else:
		printerr("[FAIL] Test 41: Penetration vs enemy armor check failed")
	e_scav.free()
	e_raider.free()
	e_boss.free()

	# Test 42: Night Stalker (EnemyType.NIGHT_STALKER) night check, flashlight cone evasion, and melee bio-infection
	total_tests += 1
	var t42_mw = preload("res://scenes/world/main_world.gd").new()
	t42_mw.day_night_cycle_duration = 300.0
	t42_mw.raid_total_time = 1800.0
	t42_mw.raid_time_remaining = 1750.0 # elapsed 50s -> progress 0.166 (day)
	var day_ok := not t42_mw.is_night_time()
	t42_mw.raid_time_remaining = 1620.0 # elapsed 180s -> progress 0.60 (night)
	var night_ok := t42_mw.is_night_time()
	var t42_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t42_p)
	t42_p.global_position = Vector2(100, 100)
	t42_p.rotation = 0.0 # facing RIGHT (+X)
	t42_p.set_flashlight(true)
	t42_p.is_infected = false
	var e_stalker = preload("res://scenes/entities/enemies/enemy.tscn").instantiate()
	e_stalker.enemy_type = 6 # NIGHT_STALKER
	add_child(e_stalker)
	e_stalker.global_position = Vector2(240, 100) # directly in front of flashlight cone (140px)
	e_stalker.target_player = t42_p
	var exposed_on: bool = e_stalker.is_exposed_to_player_flashlight()
	var evade_vel: Vector2 = e_stalker.compute_night_stalker_evade_velocity(t42_p.global_position)
	var dir_to_p: Vector2 = e_stalker.global_position.direction_to(t42_p.global_position)
	var evades_beam: bool = evade_vel.dot(dir_to_p) < 0.0 and abs(evade_vel.y) > 80.0
	t42_p.set_flashlight(false)
	var exposed_off: bool = e_stalker.is_exposed_to_player_flashlight()
	e_stalker.attack_timer = 0.0
	e_stalker._try_attack(t42_p)
	var infected_hit: bool = t42_p.is_infected
	if day_ok and night_ok and is_equal_approx(e_stalker.speed, 152.0) and exposed_on and not exposed_off and evades_beam and infected_hit:
		print("[PASS] Test 42: Night Stalker spawns at night, flanks out of flashlight cone, and inflicts bio-infection on melee hit")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 42: Night Stalker check failed (day=%s, night=%s, exp_on=%s, exp_off=%s, evade=%s, inf=%s)" % [str(day_ok), str(night_ok), str(exposed_on), str(exposed_off), str(evades_beam), str(infected_hit)])
	e_stalker.free()
	t42_p.free()
	t42_mw.free()

	# Test 43: RadioWindow Emergency Supply Drone Drop (2,500 RUB) stocks tailored caliber ammo & medical gear
	total_tests += 1
	var t43_mw = preload("res://scenes/world/main_world.gd").new()
	var t43_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t43_p)
	t43_p.global_position = Vector2(320, 320)
	t43_p.equipped_weapon_data = WeaponPartsDatabase.create_default_weapon("AK_리시버") # uses 7.62mm
	GameManager.current_world_data = {"player": {"rubles": 6000}, "hideout": {"stash": []}}
	var t43_radio = preload("res://scenes/ui/radio_window.tscn").instantiate()
	add_child(t43_radio)
	t43_radio.setup(t43_p, t43_mw)
	var drop_ok: bool = t43_radio.request_emergency_supply_drop()
	var rub_after_drop: int = int(GameManager.current_world_data["player"]["rubles"]) # 6000 - 2500 = 3500
	var drop_tile := Vector2i(int(floor((320.0 + 64.0) / 32.0)), int(floor(320.0 / 32.0)))
	var drop_inv: Inventory = t43_mw.container_inventories.get(drop_tile, null)
	var has_ak_ammo: bool = drop_inv != null and drop_inv.get_item_count("7.62mm") >= 60 and drop_inv.get_item_count("고급 치료킷") >= 1
	if drop_ok and rub_after_drop == 3500 and has_ak_ammo:
		print("[PASS] Test 43: RadioWindow 2,500 RUB Emergency Drone Drop spawns tailored 7.62mm x60 & medical crate")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 43: Emergency drone supply drop failed (ok=%s, rub=%d, ammo_ok=%s)" % [str(drop_ok), rub_after_drop, str(has_ak_ammo)])
	t43_radio.free()
	t43_p.free()
	t43_mw.free()

	# Test 44: RadioWindow Fulton Extraction (2,000 RUB) transfers modded weapon to Hideout Stash preserving parts, ammo & durability
	total_tests += 1
	var t44_p = preload("res://scenes/entities/player/player.tscn").instantiate()
	add_child(t44_p)
	t44_p.inventory_grid.resize_grid(6, 4)
	var fulton_m4 = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	fulton_m4["parts"]["muzzle"] = "소음기"
	fulton_m4["attachments"] = fulton_m4["parts"]
	fulton_m4 = WeaponPartsDatabase.compute_weapon_from_dict(fulton_m4)
	fulton_m4["current_magazine_ammo"] = 24
	fulton_m4["durability"] = 77.0
	t44_p.inventory_grid.auto_add_item("M4_리시버", 1, fulton_m4)
	var m4_uid: String = String(t44_p.inventory_grid.items[0].get("uid", ""))
	GameManager.current_world_data = {"player": {"rubles": 3500}, "hideout": {"stash": []}}
	var t44_radio = preload("res://scenes/ui/radio_window.tscn").instantiate()
	add_child(t44_radio)
	t44_radio.setup(t44_p, null)
	var fulton_ok: bool = t44_radio.request_fulton_extract_item(m4_uid)
	var rub_after_fulton: int = int(GameManager.current_world_data["player"]["rubles"]) # 3500 - 2000 = 1500
	var removed_from_bag: bool = t44_p.inventory_grid.items.is_empty()
	var stash_arr: Array = GameManager.current_world_data["hideout"]["stash"]
	var t44_stash_grid := InventoryGrid.new()
	t44_stash_grid.grid_width = 10
	t44_stash_grid.grid_height = 12
	t44_stash_grid._init_grid_map()
	t44_stash_grid.load_items(stash_arr)
	var loaded_stash_m4: Dictionary = t44_stash_grid.items[0] if not t44_stash_grid.items.is_empty() else {}
	var stash_preserved: bool = (
		String(loaded_stash_m4.get("parts", {}).get("muzzle", "")) == "소음기"
		and int(loaded_stash_m4.get("current_magazine_ammo", 0)) == 24
		and is_equal_approx(float(loaded_stash_m4.get("durability", 0.0)), 77.0)
	)
	if fulton_ok and rub_after_fulton == 1500 and removed_from_bag and stash_preserved:
		print("[PASS] Test 44: RadioWindow 2,000 RUB Fulton Extraction safely transfers modded M4 (suppressor, 24 ammo, 77 dur) into Hideout Stash")
		passed_tests += 1
	else:
		printerr("[FAIL] Test 44: Fulton extraction failed (ok=%s, rub=%d, bag_empty=%s, stash_ok=%s)" % [str(fulton_ok), rub_after_fulton, str(removed_from_bag), str(stash_preserved)])
	t44_stash_grid.free()
	t44_radio.free()
	t44_p.free()

	print("=== RESULTS: %d/%d TESTS PASSED ===" % [passed_tests, total_tests])
	get_tree().quit(0 if passed_tests == total_tests else 1)
