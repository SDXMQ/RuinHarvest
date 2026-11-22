# res://tests/p0_regression_suite.gd
extends Node

var _passed: int = 0
var _failed: int = 0
var _temp_saves: Array[String] = []

func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)

func _make_test_world_data(mode_str: String = "normal") -> Dictionary:
	var m4: Dictionary = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	var m9: Dictionary = WeaponPartsDatabase.create_default_weapon("M9_리시버")
	return {
		"world_name": "P0_Test_World",
		"current_day": 1,
		"difficulty": "normal",
		"world_settings": {
			"mode": mode_str,
			"sandbox_mode": (mode_str == "sandbox"),
			"raid_duration_minutes": 30.0
		},
		"player": {
			"rubles": 250000,
			"inventory": [],
			"equipment": {
				"helmet": {},
				"vest": {"id": "1레벨_방탄복", "name": "1레벨 경찰 조끼", "durability": 40.0, "max_durability": 40.0},
				"backpack": {"id": "2레벨_가방", "name": "2레벨 대형 백팩"},
				"bottom": {},
				"primary1": m4,
				"primary2": {},
				"sidearm": m9,
				"throwable": {}
			},
			"equipment_initialized": true,
			"insured": false
		},
		"hideout": {
			"stash": [],
			"upgrades": {
				"stash_expansion": 0,
				"med_station": 0,
				"bitcoin_farm": 0,
				"intel_center": 0
			},
			"completed_quests": [],
			"trader_stats": {}
		}
	}

func _cleanup_temp_saves() -> void:
	for s in _temp_saves:
		if s != "" and SaveManager:
			SaveManager.delete_save(s)
	_temp_saves.clear()

func _find_button_by_text(node: Node, target_text: String) -> Button:
	if node is Button and String((node as Button).text).contains(target_text):
		return node as Button
	for ch in node.get_children():
		var found: Button = _find_button_by_text(ch, target_text)
		if found != null:
			return found
	return null

func run_all() -> void:
	await get_tree().process_frame

	_test_uid_collision_and_non_mutating_fit()
	await _test_workbench_and_modding_exploits()
	await _test_split_channel_flea_overflow_exploits()
	await _test_combat_and_reload_fixes()
	_test_weighted_loot_tables()
	await _test_insurance_and_no_free_starter_refill()
	await _test_raid_timer_unification_and_unlimited()
	await _test_sandbox_f1_guard_and_font_fallbacks()
	await _test_issue4_play_feedback_regressions()
	await _test_permadeath_returns_to_main_menu()

	_cleanup_temp_saves()
	print("=== P0 Regression Summary: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

# ------------------------------------------------------------
# 1. UID Collision After Restart & Non-Mutating Fit Check
# ------------------------------------------------------------
func _test_uid_collision_and_non_mutating_fit() -> void:
	print("-- [P0 Test 1] UID Collision & Non-Mutating can_fit_item() --")
	var root: Window = get_tree().get_root()
	var g := InventoryGrid.new()
	g.grid_width = 6
	g.grid_height = 5
	root.add_child(g)

	# Simulate fresh restart resetting counter while loading saved nested UID=item_105
	InventoryGrid._uid_counter = 0
	var saved_items: Array = [
		{
			"uid": "item_42",
			"id": "탄약 케이스",
			"amount": 1,
			"w": 2,
			"h": 2,
			"x": 0,
			"y": 0,
			"inner_grid_w": 6,
			"inner_grid_h": 6,
			"inner_items": [
				{"uid": "item_105", "id": "9mm", "amount": 20, "w": 1, "h": 1, "x": 0, "y": 0}
			]
		}
	]
	g.load_items(saved_items)
	var fresh_uid: String = InventoryGrid.next_uid()
	_assert(InventoryGrid._uid_counter >= 106 and fresh_uid == "item_106" and fresh_uid != "item_42" and fresh_uid != "item_105", "load_items() syncs _uid_counter past nested max UID (next=%s)" % fresh_uid)

	var before_count: int = g.items.size()
	var can_med: bool = g.can_fit_item("구급상자", 1)
	_assert(can_med and g.items.size() == before_count, "can_fit_item() returns true for free 2x2 slot without mutating items")

	# Explicitly occupy remaining cells without auto-stacking so no 2x2 slot exists anywhere
	for cy in range(g.grid_height):
		for cx in range(g.grid_width):
			if cx < 2 and cy < 2:
				continue
			g.place_item({"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 1, "w": 1, "h": 1}, cx, cy, false)
	var items_before_fail: int = g.items.size()
	var can_fit_full: bool = g.can_fit_item("구급상자", 1)
	_assert(not can_fit_full and g.items.size() == items_before_fail, "can_fit_item() returns false cleanly without side-effects when full")

	g.queue_free()

# ------------------------------------------------------------
# 2. Workbench Preset Preview Exploit & Modding Single-Slot Sync
# ------------------------------------------------------------
func _test_workbench_and_modding_exploits() -> void:
	print("-- [P0 Test 2] Workbench Preset Preview & Modding Window Single-Slot Sync --")
	var root: Window = get_tree().get_root()
	GameManager.last_raid_result.clear()
	GameManager.current_world_data = _make_test_world_data()

	var hideout: Control = (load("res://scenes/hideout/hideout.tscn") as PackedScene).instantiate()
	root.add_child(hideout)
	await get_tree().process_frame

	var wb: Control = hideout.workbench
	var p1: Dictionary = hideout.equipment_data.get("primary1", {})
	var orig_parts: Dictionary = p1.get("parts", {}).duplicate(true)
	wb._select_workbench_weapon(p1, {"type": "equipment", "slot": "primary1"})

	# Choose preset requiring parts player does not own (expensive sniper build on M4)
	var sniper_preset: Dictionary = wb.WEAPON_PRESETS["M4_리시버"][2]
	wb._apply_workbench_preset(sniper_preset)
	_assert(wb.wb_preset_pending_assembly, "Applying workbench preset sets wb_preset_pending_assembly=true")

	wb._save_workbench_weapon()
	var eq_parts_after_save: Dictionary = hideout.equipment_data["primary1"].get("parts", {})
	_assert(eq_parts_after_save == orig_parts, "_save_workbench_weapon() blocks committing unpurchased preset preview parts")

	var stash_before_detach: int = hideout.stash_grid_mgr.items.size()
	wb._detach_workbench_part("optic")
	_assert(not wb.wb_preset_pending_assembly and wb.wb_selected_weapon.get("parts", {}) == orig_parts, "_detach_workbench_part() cancels pending preset preview cleanly")
	_assert(hideout.stash_grid_mgr.items.size() == stash_before_detach, "Detaching during preset preview does not dupe unowned parts into stash")

	hideout.queue_free()
	await get_tree().process_frame

	# WeaponModdingWindow with duplicate M4 receivers in primary1 & primary2
	var player: CharacterBody2D = (load("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await get_tree().process_frame

	var m4_a: Dictionary = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	var m4_b: Dictionary = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	player.equipment["primary1"] = m4_a
	player.equipment["primary2"] = m4_b
	player.active_weapon_slot = "primary1"

	var wmod_script: GDScript = load("res://scenes/ui/weapon_modding_window.gd")
	var wmod: Control = wmod_script.new()
	root.add_child(wmod)
	wmod.setup(player.inventory_grid, null, m4_a, "primary1")
	await get_tree().process_frame

	wmod.current_weapon["parts"]["muzzle"] = ""
	wmod._recompute_and_update_ui()
	wmod._sync_to_equipped_player_weapon()
	_assert(String(player.equipment["primary1"].get("parts", {}).get("muzzle", "")) == "", "WeaponModdingWindow updates targeted primary1 weapon slot")
	_assert(String(player.equipment["primary2"].get("parts", {}).get("muzzle", "")) == "소음기", "WeaponModdingWindow leaves duplicate M4 in primary2 untouched")

	wmod.queue_free()
	player.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------
# 3. Split-Drag, Channeling Pre-Consume, FleaMarket & Overflow Guards
# ------------------------------------------------------------
func _test_split_channel_flea_overflow_exploits() -> void:
	print("-- [P0 Test 3] Split-Drag, Channeling, FleaMarket & Overflow/Capacity Guards --")
	var root: Window = get_tree().get_root()

	# A) Split-drag equip clears is_split (no phantom refund on _end_drag)
	var s_grid := InventoryGrid.new()
	s_grid.grid_width = 6
	s_grid.grid_height = 5
	root.add_child(s_grid)
	s_grid.auto_add_item("수류탄", 3)
	var orig_g: Dictionary = s_grid.items[0]
	orig_g["amount"] = 2 # Simulates split dialog taking 1 grenade out of 3

	var inv_win: Control = (load("res://scenes/ui/inventory_window.tscn") as PackedScene).instantiate()
	root.add_child(inv_win)
	inv_win.setup(null, s_grid, GameManager.create_empty_equipment())
	await get_tree().process_frame

	inv_win.is_dragging = true
	inv_win.drag_data = {
		"source": "split",
		"is_split": true,
		"split_source_item": orig_g,
		"split_amount": 1,
		"split_source_grid": s_grid,
		"item": {"id": "수류탄", "amount": 1, "uid": InventoryGrid.next_uid()}
	}
	inv_win._try_equip_weapon("throwable")
	_assert(String(inv_win.equipment_data.get("throwable", {}).get("id", "")) == "수류탄" and int(orig_g.get("amount", 0)) == 2, "Equipping split-dragged throwable keeps source stack at 2 without duplicating")

	inv_win.queue_free()
	s_grid.queue_free()
	await get_tree().process_frame

	# B) Channeling consumable aborts cleanly if item disappears mid-channel
	GameManager.current_world_data = _make_test_world_data()
	var player: CharacterBody2D = (load("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await get_tree().process_frame

	player.hp = 50.0
	player.inventory_grid.clear()
	player.inventory_grid.auto_add_item("구급상자", 1)
	var medkit: Dictionary = player.inventory_grid.items[0]
	var started_ch: bool = player.use_consumable_item(medkit)
	_assert(started_ch and player.is_channeling, "use_consumable_item() starts channeling without pre-consuming")
	player.inventory_grid.remove_item_by_uid(String(medkit.get("uid", "")))
	player.complete_channeling()
	_assert(absf(player.hp - 50.0) < 0.01 and not player.is_channeling, "Channeling completion aborts healing when item was removed mid-channel")

	# C) FleaMarket bounty exclusion, custom_data preservation on expiry, & trends save
	_assert(not ("고철" in FleaMarket.BOUNTY_CANDIDATE_POOL) and not ("폐전선" in FleaMarket.BOUNTY_CANDIDATE_POOL), "BOUNTY_CANDIDATE_POOL excludes 고철 & 폐전선 arbitrage items")
	FleaMarket.refresh_daily_bounties(7)
	var bad_bounty_found: bool = false
	for b in FleaMarket.daily_bounties:
		if String(b.get("item_id", "")) in ["고철", "폐전선"]:
			bad_bounty_found = true
	_assert(not bad_bounty_found, "Daily bounties do not generate 고철 or 폐전선")

	FleaMarket.supply_pressure.clear()
	FleaMarket.player_listings.clear()
	GameManager.current_world_data = _make_test_world_data()
	GameManager.current_world_data["current_day"] = 1
	GameManager.current_world_data["player"]["rubles"] = 500000
	var custom_m4_meta: Dictionary = {
		"type": "assembled_weapon",
		"receiver": "M4_리시버",
		"parts": {"muzzle": "소음기", "optic": "4배율_ACOG"},
		"loaded_ammo": "5.56mm",
		"durability": 88.0,
		"max_durability": 100.0
	}
	FleaMarket.register_item("M4_리시버", 1, 9999999, false, custom_m4_meta)
	FleaMarket.player_listings[-1]["timer"] = 1.0
	seed(12345)
	GameManager.end_raid("survived", [])
	await get_tree().process_frame

	var stash_ret: Array = GameManager.current_world_data.get("hideout", {}).get("stash", [])
	var ret_found: bool = false
	for it in stash_ret:
		if String(it.get("id", "")) == "M4_리시버":
			var ret_parts: Dictionary = it.get("parts", {})
			var ret_dur: float = float(it.get("durability", 0.0))
			if String(ret_parts.get("muzzle", "")) == "소음기" and absf(ret_dur - 88.0) < 0.01:
				ret_found = true
	_assert(ret_found, "Expired FleaMarket listing restores modded weapon parts & durability on return")

	FleaMarket.trends["나무"] = 0.25
	var fm_save: Dictionary = FleaMarket.to_save_dict()
	FleaMarket.trends.clear()
	FleaMarket.load_from_save_dict(fm_save)
	_assert(absf(float(FleaMarket.trends.get("나무", 0.0)) - 0.25) < 0.001, "FleaMarket to_save_dict()/load_from_save_dict() preserves price trends")

	# D) Shop, Market, Quest, and Fulton capacity rejections
	GameManager.last_raid_result.clear()
	var w_full: Dictionary = _make_test_world_data()
	var full_stash: Array = []
	for sy in range(12):
		for sx in range(10):
			full_stash.append({"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 1, "w": 1, "h": 1, "x": sx, "y": sy})
	w_full["hideout"]["stash"] = full_stash
	# Row 0..6 filled in 6x7 (2레벨_가방) bag except (0,0)=붕대 x2 and (1,0)=생수 x1 so consuming req leaves only 2x1 (no 2x2 room for 구급상자)
	var full_bag: Array = [
		{"uid": InventoryGrid.next_uid(), "id": "붕대", "amount": 2, "w": 1, "h": 1, "x": 0, "y": 0},
		{"uid": InventoryGrid.next_uid(), "id": "생수", "amount": 1, "w": 1, "h": 1, "x": 1, "y": 0}
	]
	for by in range(7):
		for bx in range(6):
			if by == 0 and (bx == 0 or bx == 1):
				continue
			full_bag.append({"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 1, "w": 1, "h": 1, "x": bx, "y": by})
	w_full["player"]["inventory"] = full_bag
	w_full["player"]["rubles"] = 50000
	GameManager.current_world_data = w_full.duplicate(true)

	var h_full: Control = (load("res://scenes/hideout/hideout.tscn") as PackedScene).instantiate()
	root.add_child(h_full)
	await get_tree().process_frame

	h_full._buy_item("1레벨_방탄복", 1, 5000)
	_assert(int(GameManager.current_world_data["player"]["rubles"]) == 50000, "_buy_item() rejects purchase without charging RUB when bag+stash are full")

	var fake_listing: Dictionary = {"id": 9999, "item_name": "1레벨_방탄복", "count": 1, "stock_remaining": 1, "sold_out": false, "price": 5000, "is_player": false}
	h_full._buy_market_item(fake_listing, 5000)
	_assert(int(GameManager.current_world_data["player"]["rubles"]) == 50000 and int(fake_listing["stock_remaining"]) == 1, "_buy_market_item() rejects purchase without charging RUB or draining stock when full")

	HideoutProgression.refresh_progression_tab(h_full, h_full.progression_tab)
	var quest_btn: Button = _find_button_by_text(h_full.progression_tab, "의뢰 완수 및 보상 수령")
	_assert(quest_btn != null and not quest_btn.disabled, "Quest button for q_therapist_1 is enabled with req items")
	if quest_btn != null:
		quest_btn.pressed.emit()
	_assert(int(GameManager.current_world_data["player"]["rubles"]) == 50000 and h_full.player_grid_mgr.has_item("붕대", 2) and not ("q_therapist_1" in GameManager.current_world_data["hideout"]["completed_quests"]), "Quest completion rolls back consumed items and reward when no 2x2 room exists")

	h_full.queue_free()
	await get_tree().process_frame

	# Fulton capacity rejection
	GameManager.current_world_data = w_full.duplicate(true)
	player.inventory_grid.clear()
	player.inventory_grid.auto_add_item("금시계", 1)
	var watch_uid: String = String(player.inventory_grid.items[0].get("uid", ""))
	var rw_scene: PackedScene = load("res://scenes/ui/radio_window.tscn") as PackedScene
	var rw: Control = rw_scene.instantiate()
	root.add_child(rw)
	rw.setup(player, null)
	await get_tree().process_frame
	var fulton_ok: bool = rw.request_fulton_extract_item(watch_uid)
	_assert(not fulton_ok and int(GameManager.current_world_data["player"]["rubles"]) == 50000 and player.inventory_grid.has_item("금시계", 1), "Fulton extract rejects without charging 2,000 RUB or deleting item when Hideout stash is full")

	rw.queue_free()
	player.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------
# 4. Combat Formulas, Ammo-Type Switching Reload & Jam Fixes
# ------------------------------------------------------------
func _test_combat_and_reload_fixes() -> void:
	print("-- [P0 Test 4] Combat Formulas, Ammo-Type Reload & Jam Persistence --")
	var m9_s: Dictionary = WeaponPartsDatabase.compute_weapon_stats("M9_리시버")
	var mp5_s: Dictionary = WeaponPartsDatabase.compute_weapon_stats("MP5_리시버")
	var ak_s: Dictionary = WeaponPartsDatabase.compute_weapon_stats("AK_리시버")
	var m4_s: Dictionary = WeaponPartsDatabase.compute_weapon_stats("M4_리시버")
	var sv98_s: Dictionary = WeaponPartsDatabase.compute_weapon_stats("SV98_리시버")
	_assert(not WeaponPartsDatabase.is_automatic_weapon(m9_s) and int(m9_s["rpm"]) == 240, "M9 is semi-auto (rpm=240)")
	_assert(WeaponPartsDatabase.is_automatic_weapon(mp5_s) and int(mp5_s["rpm"]) == 450, "MP5 is full-auto (rpm=450)")
	_assert(WeaponPartsDatabase.is_automatic_weapon(ak_s) and int(ak_s["rpm"]) == 300, "AK is full-auto (rpm=300)")
	_assert(WeaponPartsDatabase.is_automatic_weapon(m4_s) and int(m4_s["rpm"]) == 360, "M4 is full-auto (rpm=360)")
	_assert(not WeaponPartsDatabase.is_automatic_weapon(sv98_s) and int(sv98_s["rpm"]) == 40, "SV98 is bolt-action (rpm=40)")

	var mp5_def: Dictionary = WeaponPartsDatabase.create_default_weapon("MP5_리시버")
	_assert(not mp5_def.get("parts", {}).is_empty() and String(mp5_def.get("id", "")) == "MP5_리시버", "create_default_weapon('MP5_리시버') builds full default parts")

	var m4_short: Dictionary = WeaponPartsDatabase.compute_weapon_stats("M4_리시버", {"barrel": "짧은_총열"})
	_assert(absf(float(m4_short.get("weight", 0.0)) - 1.3) < 0.01, "_apply_part_modifier avoids double-adding weight (1.6 - 0.3 == 1.3)")

	var m9_px: float = maxf(160.0, float(m9_s["range"]) * 32.0)
	var m4_px: float = maxf(160.0, float(m4_s["range"]) * 32.0)
	var sv_px: float = maxf(160.0, float(sv98_s["range"]) * 32.0)
	_assert(sv_px > m4_px and m4_px > m9_px, "32x range scaling cleanly separates M9(%.0f) < M4(%.0f) < SV98(%.0f)" % [m9_px, m4_px, sv_px])

	var root: Window = get_tree().get_root()
	GameManager.current_world_data = _make_test_world_data()
	var player: CharacterBody2D = (load("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await get_tree().process_frame

	var m9_eq: Dictionary = WeaponPartsDatabase.create_default_weapon("M9_리시버")
	m9_eq["loaded_ammo"] = "9mm"
	m9_eq["current_magazine_ammo"] = 10
	player.equipment["sidearm"] = m9_eq
	player.equipment["primary1"] = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	player.weapon_handler.equipment = player.equipment

	player.inventory_grid.clear()
	player.inventory_grid.auto_add_item(".45ACP", 15)
	player.weapon_handler.switch_weapon_slot("sidearm")
	player.weapon_handler.cycle_ammo_type()
	_assert(player.inventory_grid.has_item("9mm", 10), "cycle_ammo_type() returns existing 10x 9mm to bag before switching")
	_assert(player.weapon_handler.is_reloading, "cycle_ammo_type() begins reloading selected ammo")

	player.weapon_handler.reload_timer = 0.01
	player.weapon_handler._process(0.05)
	_assert(String(player.weapon_handler.equipped_weapon_data.get("loaded_ammo", "")) == ".45ACP", "_finish_reload() updates loaded_ammo to .45ACP")
	_assert(String(player.weapon_handler.equipped_weapon_data.get("computed_stats", {}).get("ammo_type", "")) == ".45ACP", "_finish_reload() recomputes weapon stats for newly loaded .45ACP")
	_assert(int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", 0)) == 15 and not player.inventory_grid.has_item(".45ACP", 1), "_finish_reload() loads 15x .45ACP without mixing 9mm")

	# Partial mag preserves current caliber (.45ACP) and refuses 9mm
	player.weapon_handler.equipped_weapon_data["current_magazine_ammo"] = 5
	player.equipment["sidearm"]["current_magazine_ammo"] = 5
	player.weapon_handler.preferred_ammo_type = "9mm"
	player.weapon_handler._finish_reload()
	_assert(int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", 0)) == 5 and player.inventory_grid.has_item("9mm", 10), "Partial mag reload refuses mixing 9mm into .45ACP mag")

	# Jam persists on weapon swap and clearing jam grants 0 free rounds
	player.weapon_handler.is_jammed = true
	player.weapon_handler.equipped_weapon_data["is_jammed"] = true
	player.weapon_handler.equipped_weapon_data["current_magazine_ammo"] = 0
	player.equipment["sidearm"]["is_jammed"] = true
	player.equipment["sidearm"]["current_magazine_ammo"] = 0
	player.weapon_handler.switch_weapon_slot("primary1")
	_assert(not player.weapon_handler.is_jammed, "Swapping to clean primary1 does not inherit sidearm jam")
	player.weapon_handler.switch_weapon_slot("sidearm")
	_assert(player.weapon_handler.is_jammed, "Swapping back to jammed sidearm preserves is_jammed=true")

	player.weapon_handler.start_reload()
	player.weapon_handler.reload_timer = 0.01
	player.weapon_handler._process(0.05)
	_assert(not player.weapon_handler.is_jammed and not player.weapon_handler.is_reloading, "Clearing jam completes unjamming timer")
	_assert(int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", -1)) == 0, "Clearing jam does NOT grant a free reload on empty mag")

	player.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------
# 5. Weighted Loot Tables, Stack Splitting & Alias Grid Size
# ------------------------------------------------------------
func _test_weighted_loot_tables() -> void:
	print("-- [P0 Test 5] Weighted Loot Tables, Stack Split & Alias Grid Size --")
	var unique_ids: Dictionary = {}
	for _i in range(600):
		var drop: Array[Dictionary] = ItemDatabase.generate_loot("locked_armory", 1)
		for d in drop:
			unique_ids[String(d.get("id", ""))] = true
	_assert(unique_ids.size() >= 6, "Weighted generate_loot('locked_armory') distributes across tail items (distinct=%d)" % unique_ids.size())

	var bag_res: Array = []
	var ammo_cap: int = int(ItemDatabase.get_item_data("9mm").get("max_stack", 60))
	ItemDatabase._add_to_loot(bag_res, "9mm", ammo_cap * 2 + 15)
	var total_added: int = 0
	var all_within_cap: bool = true
	for entry in bag_res:
		var amt: int = int(entry.get("amount", 0))
		total_added += amt
		if amt > ammo_cap:
			all_within_cap = false
	_assert(total_added == ammo_cap * 2 + 15 and all_within_cap and bag_res.size() == 3, "_add_to_loot() splits 135x 9mm cleanly across max_stack=%d stacks" % ammo_cap)

	_assert(ItemDatabase.get_item_grid_size("짧은 총열") == Vector2i(1, 2), "get_item_grid_size('짧은 총열') resolves alias to Vector2i(1, 2)")

# ------------------------------------------------------------
# 6. Uninsured Death Gear Loss & Starter Refill Prevention
# ------------------------------------------------------------
func _test_insurance_and_no_free_starter_refill() -> void:
	print("-- [P0 Test 6] Uninsured Gear Loss, Insured Recovery & No Starter Refill --")
	var root: Window = get_tree().get_root()
	GameManager.start_new_game({"world_name": "InsTest", "difficulty": "normal"})
	_temp_saves.append(GameManager.current_save_slot)

	GameManager.current_world_data["player"]["insured"] = false
	GameManager.end_raid("kia", [])
	var uninsured_kia_res: Dictionary = GameManager.last_raid_result.duplicate(true)
	await get_tree().process_frame

	var eq_after_kia: Dictionary = GameManager.current_world_data.get("player", {}).get("equipment", {})
	_assert(eq_after_kia.get("primary1", {}).is_empty() and eq_after_kia.get("vest", {}).is_empty(), "Uninsured KIA clears equipped weapon and armor")
	_assert(bool(GameManager.current_world_data["player"].get("equipment_initialized", false)), "Uninsured KIA marks equipment_initialized=true")
	_assert(not bool(uninsured_kia_res.get("insurance_claimed", true)), "Uninsured KIA sets insurance_claimed=false")

	var hideout_post_kia: Control = (load("res://scenes/hideout/hideout.tscn") as PackedScene).instantiate()
	root.add_child(hideout_post_kia)
	await get_tree().process_frame
	_assert(hideout_post_kia.equipment_data.get("primary1", {}).is_empty() and hideout_post_kia.equipment_data.get("sidearm", {}).is_empty(), "Hideout does NOT refill free starter M4/M9 after uninsured death")
	hideout_post_kia.queue_free()
	await get_tree().process_frame

	var blank_player := Node.new()
	blank_player.set_script(null)
	var empty_inv_win: Control = (load("res://scenes/ui/inventory_window.tscn") as PackedScene).instantiate()
	root.add_child(empty_inv_win)
	var p_grid := InventoryGrid.new()
	p_grid.grid_width = 6
	p_grid.grid_height = 5
	root.add_child(p_grid)
	empty_inv_win.setup(null, p_grid, {})
	await get_tree().process_frame
	_assert(empty_inv_win.equipment_data.get("primary1", {}).is_empty() and empty_inv_win.equipment_data.get("backpack", {}).is_empty(), "InventoryWindow.setup() with empty equipment does NOT spawn free starter gear")
	empty_inv_win.queue_free()
	p_grid.queue_free()
	blank_player.free()
	await get_tree().process_frame

	# Insured KIA retains equipped weapon & resets insured flag
	GameManager.current_world_data["player"]["equipment"] = GameManager.create_starter_equipment()
	GameManager.current_world_data["player"]["insured"] = true
	GameManager.end_raid("kia", [])
	var insured_kia_res: Dictionary = GameManager.last_raid_result.duplicate(true)
	await get_tree().process_frame
	var eq_insured: Dictionary = GameManager.current_world_data.get("player", {}).get("equipment", {})
	_assert(not eq_insured.get("primary1", {}).is_empty() and not bool(GameManager.current_world_data["player"].get("insured", true)) and bool(insured_kia_res.get("insurance_claimed", false)), "Insured KIA preserves equipment and consumes insured flag")

# ------------------------------------------------------------
# 7. Raid Timer Unification, Reload Persistence & Unlimited Mode
# ------------------------------------------------------------
func _test_raid_timer_unification_and_unlimited() -> void:
	print("-- [P0 Test 7] Raid Timer Unification, Load Restore & Unlimited Mode --")
	GameManager.start_new_game({"world_name": "TimerTest", "mode": "sandbox", "raid_duration_minutes": 99999.0})
	var timer_slot: String = GameManager.current_save_slot
	_temp_saves.append(timer_slot)

	GameManager.raid_duration_minutes = 12.0
	GameManager.load_game(timer_slot)
	_assert(absf(GameManager.raid_duration_minutes - 99999.0) < 0.01, "load_game() restores raid_duration_minutes from world_settings")

	# Paused tree must not advance timer or trigger MIA
	GameManager.current_state = GameManager.GameState.IN_GAME
	GameManager.is_paused = false
	GameManager.time_elapsed_in_raid = 0.0
	GameManager.raid_duration_minutes = 0.01
	get_tree().paused = true
	GameManager._process(5.0)
	_assert(GameManager.current_state == GameManager.GameState.IN_GAME, "GameManager._process() pauses raid timer when get_tree().paused is true")
	get_tree().paused = false

	# Unlimited timer threshold skips GameManager backup MIA
	GameManager.raid_duration_minutes = 99999.0
	GameManager.time_elapsed_in_raid = 1000000.0
	GameManager._process(1.0)
	_assert(GameManager.current_state == GameManager.GameState.IN_GAME, "GameManager._process() never triggers MIA when raid_duration_minutes >= 90000.0")

	# MainWorld renders unlimited label cleanly
	var root: Window = get_tree().get_root()
	GameManager.current_world_data = _make_test_world_data("sandbox")
	GameManager.current_world_data["world_settings"]["raid_duration_minutes"] = 99999.0
	var world: Node2D = (load("res://scenes/world/main_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await get_tree().process_frame
	world._process(0.1)
	_assert(world.raid_timer_label != null and world.raid_timer_label.text == "탈출 시간: 무제한", "MainWorld renders '탈출 시간: 무제한' without countdown for 99999m sandbox")
	world.queue_free()
	await get_tree().process_frame

# ------------------------------------------------------------
# 8. Sandbox-Only F1 Tool & Korean/Emoji Font Fixes
# ------------------------------------------------------------
func _test_sandbox_f1_guard_and_font_fallbacks() -> void:
	print("-- [P0 Test 8] Sandbox-Only F1 Cheat Guard & Font System Fallbacks --")
	var root: Window = get_tree().get_root()
	GameManager.last_raid_result.clear()
	GameManager.current_world_data = _make_test_world_data("normal")
	_assert(not GameManager.is_sandbox_mode(), "is_sandbox_mode() is false in normal mode")

	var hideout_norm: Control = (load("res://scenes/hideout/hideout.tscn") as PackedScene).instantiate()
	root.add_child(hideout_norm)
	await get_tree().process_frame
	var sb_btn_hideout: Node = hideout_norm.find_child("SandboxToolBtn", true, false)
	hideout_norm._open_item_spawner()
	var spawner_in_hideout: Node = hideout_norm.find_child("ItemSpawnerWindow", true, false)
	_assert(sb_btn_hideout == null and spawner_in_hideout == null, "Normal Hideout hides SandboxToolBtn and blocks _open_item_spawner()")
	hideout_norm.queue_free()
	await get_tree().process_frame

	var world_norm: Node2D = (load("res://scenes/world/main_world.tscn") as PackedScene).instantiate()
	root.add_child(world_norm)
	await get_tree().process_frame
	world_norm._open_item_spawner()
	var sb_btn_norm: Node = world_norm.find_child("SandboxToolBtn", true, false)
	_assert(sb_btn_norm == null and world_norm.current_spawner_window == null, "Normal MainWorld hides SandboxToolBtn and blocks F1 spawner")
	world_norm.queue_free()
	await get_tree().process_frame

	GameManager.current_world_data = _make_test_world_data("sandbox")
	_assert(GameManager.is_sandbox_mode(), "is_sandbox_mode() is true in sandbox mode")
	var world_sb: Node2D = (load("res://scenes/world/main_world.tscn") as PackedScene).instantiate()
	root.add_child(world_sb)
	await get_tree().process_frame
	var sb_btn_sb: Node = world_sb.find_child("SandboxToolBtn", true, false)
	_assert(sb_btn_sb != null, "Sandbox MainWorld displays UI/SandboxToolBtn")
	world_sb.queue_free()
	await get_tree().process_frame

	# Font system fallback & draw_string fallback_font regression guard
	var reg_font: Font = PixelAssetManager.get_pixel_font_regular()
	_assert(reg_font is FontFile and (reg_font as FontFile).allow_system_fallback, "PixelAssetManager regular font has allow_system_fallback=true")

	var checked_paths: Array[String] = [
		"res://scenes/ui/map_window.gd",
		"res://scenes/world/main_world.gd",
		"res://scenes/entities/player/player_visuals.gd",
		"res://scenes/hideout/components/hideout_workbench.gd",
		"res://scenes/ui/shooting_range_window.gd",
		"res://scenes/ui/hud_tactical_helper.gd"
	]
	for p in checked_paths:
		var f := FileAccess.open(p, FileAccess.READ)
		var src: String = f.get_as_text() if f else ""
		if f:
			f.close()
		var has_bare_draw: bool = src.contains("draw_string(ThemeDB.fallback_font") or src.contains("ThemeDB.fallback_font.get_string_size") or src.contains("var font := ThemeDB.fallback_font") or src.contains("var font = ThemeDB.fallback_font")
		_assert(src != "" and not has_bare_draw, "Patched render script avoids bare ThemeDB.fallback_font (%s)" % p.get_file())

# ------------------------------------------------------------
# 9. Issue #4 Play Feedback Regressions (Ghosting, Quickslots, Auto-Fire, Audio)
# ------------------------------------------------------------
func _test_issue4_play_feedback_regressions() -> void:
	print("-- [P0 Test 9] Issue #4 Play Feedback Regressions --")
	var root: Window = get_tree().get_root()

	# 1. Bug #1: InventoryWindow & Hideout drag preview, hover cell, tooltip, marquee, popup dedupe
	var inv_grid := InventoryGrid.new()
	inv_grid.grid_width = 6
	inv_grid.grid_height = 5
	root.add_child(inv_grid)
	inv_grid.auto_add_item("붕대", 4)

	var inv_win: Control = (load("res://scenes/ui/inventory_window.tscn") as PackedScene).instantiate()
	root.add_child(inv_win)
	inv_win.setup(null, inv_grid, {})
	await get_tree().process_frame

	inv_win._start_drag("grid", inv_grid.items[0], Vector2i(0, 0), "", null, inv_grid)
	inv_win.hovered_grid_cell = Vector2i(1, 1)
	_assert(inv_win.is_dragging and inv_win.drag_preview != null, "InventoryWindow._start_drag creates drag_preview")
	inv_win._end_drag()
	_assert(not inv_win.is_dragging and inv_win.drag_preview == null and inv_win.hovered_grid_cell == Vector2i(-1, -1), "InventoryWindow._end_drag clears drag_preview and resets hovered_grid_cell")

	var orig_bandages: Dictionary = inv_grid.items[0]
	var split_copy: Dictionary = orig_bandages.duplicate(true)
	split_copy["amount"] = 2
	orig_bandages["amount"] = int(orig_bandages.get("amount", 4)) - 2
	inv_win._start_drag("split", split_copy, Vector2i(0, 0), "", null, inv_grid)
	inv_win.drag_data["is_split"] = true
	inv_win.drag_data["split_source_item"] = orig_bandages
	inv_win.drag_data["split_source_grid"] = inv_grid
	inv_win.drag_data["split_amount"] = 2
	if inv_win.tooltip:
		inv_win.tooltip.visible = true
	inv_win._on_close_pressed()
	await get_tree().process_frame
	_assert(inv_grid.get_item_count("붕대") == 4, "InventoryWindow._on_close_pressed restores active split-drag amount without item loss")
	if is_instance_valid(inv_win):
		inv_win.queue_free()
	inv_grid.queue_free()
	await get_tree().process_frame

	GameManager.last_raid_result.clear()
	GameManager.current_world_data = _make_test_world_data()
	var hideout_i4: Control = (load("res://scenes/hideout/hideout.tscn") as PackedScene).instantiate()
	root.add_child(hideout_i4)
	await get_tree().process_frame

	hideout_i4.hovered_player_cell = Vector2i(0, 0)
	if hideout_i4.tooltip:
		hideout_i4.tooltip.visible = true
	hideout_i4.player_grid_control.mouse_exited.emit()
	_assert(hideout_i4.hovered_player_cell == Vector2i(-1, -1) and (hideout_i4.tooltip == null or not hideout_i4.tooltip.visible), "Hideout player_grid_control mouse_exited clears hovered cell and hides tooltip")

	hideout_i4.hovered_stash_cell = Vector2i(1, 1)
	if hideout_i4.tooltip:
		hideout_i4.tooltip.visible = true
	hideout_i4.stash_grid_control.mouse_exited.emit()
	_assert(hideout_i4.hovered_stash_cell == Vector2i(-1, -1) and (hideout_i4.tooltip == null or not hideout_i4.tooltip.visible), "Hideout stash_grid_control mouse_exited clears hovered cell and hides tooltip")

	hideout_i4._is_marquee_selecting = true
	hideout_i4._on_tab_changed(1)
	_assert(not hideout_i4.is_dragging and not hideout_i4._is_marquee_selecting, "Hideout._on_tab_changed clears drag and marquee selection")

	hideout_i4._open_inventory_window()
	hideout_i4._open_inventory_window()
	var inv_script := load("res://scenes/ui/inventory_window.gd")
	var inv_win_count: int = 0
	for ch in hideout_i4.get_children():
		if ch.get_script() == inv_script:
			inv_win_count += 1
	_assert(is_instance_valid(hideout_i4._current_inventory_window) and inv_win_count == 1, "Hideout._open_inventory_window prevents stacking duplicate InventoryWindow instances")
	if is_instance_valid(hideout_i4._current_inventory_window):
		hideout_i4._current_inventory_window.queue_free()
	hideout_i4.queue_free()
	await get_tree().process_frame

	# 2. Bug #2: Food [7] vs Water [8] quickslot separation & HUD 1:1 sync
	GameManager.current_world_data = _make_test_world_data()
	var player: CharacterBody2D = (load("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await get_tree().process_frame

	player.inventory_grid.clear()
	player.inventory_grid.auto_add_item("생수", 1)
	player.inventory_grid.auto_add_item("식량통조림", 1)

	var found_food: Dictionary = Player.find_quickslot_item(player.inventory_grid, "food").get("item", {})
	var found_water: Dictionary = Player.find_quickslot_item(player.inventory_grid, "water").get("item", {})
	_assert(String(found_food.get("id", "")) == "식량통조림", "find_quickslot_item('food') selects 식량통조림 even when 생수 comes first")
	_assert(String(found_water.get("id", "")) == "생수", "find_quickslot_item('water') selects 생수 separately")

	var world_qs: Node2D = (load("res://scenes/world/main_world.tscn") as PackedScene).instantiate()
	root.add_child(world_qs)
	await get_tree().process_frame
	HudTacticalHelper.update_quickslot_bar(world_qs.quickslot_hbox, player)
	var slot7_btn: Button = world_qs.quickslot_hbox.get_node_or_null("Slot7")
	var slot8_btn: Button = world_qs.quickslot_hbox.get_node_or_null("Slot8")
	var food_disp_name: String = String(ItemDatabase.get_item_data("식량통조림").get("name", "식량통조림"))
	var water_disp_name: String = String(ItemDatabase.get_item_data("생수").get("name", "생수"))
	_assert(slot7_btn != null and slot7_btn.tooltip_text.contains(food_disp_name) and not slot7_btn.tooltip_text.contains(water_disp_name), "Quickslot Slot7 displays food tooltip without mixing water")
	_assert(slot8_btn != null and slot8_btn.tooltip_text.contains(water_disp_name), "Quickslot Slot8 displays water tooltip")
	world_qs.queue_free()
	await get_tree().process_frame

	player.hunger = 50.0
	player.thirst = 50.0
	player._use_quickslot_item("food")
	_assert(player.is_channeling and player.channel_item_name.contains(food_disp_name), "Quickslot [7] starts channeling 식량통조림")
	player.complete_channeling()
	_assert(player.hunger > 50.0 and not player.inventory_grid.has_item("식량통조림", 1) and player.inventory_grid.has_item("생수", 1), "Quickslot [7] restores hunger and leaves 생수 untouched")

	player._use_quickslot_item("water")
	_assert(player.is_channeling and player.channel_item_name.contains(water_disp_name), "Quickslot [8] starts channeling 생수")
	player.complete_channeling()
	_assert(player.thirst > 50.0 and not player.inventory_grid.has_item("생수", 1), "Quickslot [8] restores thirst and consumes 생수")

	# 3. Bug #3: Reliable automatic fire across WeaponPartsDatabase, ShootingRangeWindow, WeaponHandler
	var empty_rec := WeaponPartsDatabase.compute_weapon_from_dict({"id": "M4_리시버", "receiver": ""})
	_assert(String(empty_rec.get("computed_stats", {}).get("fire_mode", "")) == "auto" and int(empty_rec.get("computed_stats", {}).get("rpm", 0)) == 360, "compute_weapon_from_dict resolves empty receiver string to id (M4_리시버)")

	var legacy_m4 := {"id": "M4_리시버", "parts": {}, "computed_stats": {"rpm": 135}}
	var legacy_ak := {"id": "AK_리시버", "parts": {}, "computed_stats": {"rpm": 110}}
	var legacy_mp5 := {"id": "MP5_리시버", "parts": {}, "computed_stats": {}}
	_assert(WeaponPartsDatabase.is_automatic_weapon_dict(legacy_m4) and WeaponPartsDatabase.is_automatic_weapon_dict(legacy_ak) and WeaponPartsDatabase.is_automatic_weapon_dict(legacy_mp5), "is_automatic_weapon_dict detects auto receivers despite stale legacy computed_stats")

	var srw_script := load("res://scenes/ui/shooting_range_window.gd") as GDScript
	var srw: Control = srw_script.new()
	root.add_child(srw)
	await get_tree().process_frame
	srw.setup(legacy_m4)
	_assert(String(srw.computed_stats.get("fire_mode", "")) == "auto" and int(srw.computed_stats.get("rpm", 0)) == 360, "ShootingRangeWindow.setup recomputes stale M4 stats to fire_mode=auto and rpm=360")
	srw.queue_free()
	await get_tree().process_frame

	var prev_scene: Node = get_tree().current_scene
	var fire_host := Node2D.new()
	root.add_child(fire_host)
	get_tree().current_scene = fire_host
	get_tree().paused = false
	player.hp = 100.0
	player.ui_input_blocked = false
	var auto_m4: Dictionary = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	auto_m4["current_magazine_ammo"] = 30
	auto_m4["durability"] = 100.0
	auto_m4["max_durability"] = 100.0
	player.equipment["primary1"] = auto_m4
	player.weapon_handler.equipment = player.equipment
	player.weapon_handler.switch_weapon_slot("primary1")
	player.weapon_handler.attack_cooldown_timer = 0.0
	player.weapon_handler.is_reloading = false
	player.weapon_handler.is_jammed = false

	Input.action_press("attack")
	player.weapon_handler._process(0.01)
	player.weapon_handler._process(0.20)
	player.weapon_handler._process(0.20)
	Input.action_release("attack")

	var ammo_after_burst: int = int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", 30))
	_assert(ammo_after_burst <= 27, "WeaponHandler auto-fire fires consecutive shots while trigger is held (ammo=%d)" % ammo_after_burst)
	player.weapon_handler._process(0.25)
	var ammo_after_release: int = int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", 30))
	_assert(ammo_after_release == ammo_after_burst and not player.weapon_handler._trigger_held, "WeaponHandler stops firing cleanly after trigger release")

	get_tree().current_scene = prev_scene if is_instance_valid(prev_scene) else null
	fire_host.queue_free()
	player.queue_free()
	await get_tree().process_frame

	# 4. Bug #4: Audio buses, softened SFX headroom/waveform peak, SettingsWindow sync
	var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")
	var bgm_bus_idx: int = AudioServer.get_bus_index("BGM")
	_assert(sfx_bus_idx != -1 and bgm_bus_idx != -1, "AudioServer registers both SFX and BGM buses")
	_assert(SoundManager._players.size() > 0 and SoundManager._players[0].bus == &"SFX" and SoundManager.SFX_BASE_GAIN_DB <= -6.0, "SoundManager routes players to SFX bus with attenuated base gain")

	var max_peaks_ok: bool = true
	for sname in ["hit_ranged", "hit_melee", "explosion", "dry_fire"]:
		var wav: AudioStreamWAV = SoundManager.get_sound(sname)
		var peak: float = 0.0
		if wav and wav.data.size() >= 2:
			for byte_i in range(0, wav.data.size() - 1, 2):
				var amp: float = absf(float(wav.data.decode_s16(byte_i))) / 32767.0
				if amp > peak:
					peak = amp
		if peak <= 0.001 or peak > 0.25:
			max_peaks_ok = false
	_assert(max_peaks_ok, "Procedural SFX PCM peaks stay within soft headroom (0.001 < peak <= 0.25)")

	var prev_master: float = GameSettings.master_volume
	var prev_bgm: float = GameSettings.bgm_volume
	var prev_sfx: float = GameSettings.sfx_volume
	var settings_existed: bool = FileAccess.file_exists(GameSettings.SETTINGS_FILE_PATH)
	var prev_settings_raw: String = ""
	if settings_existed:
		var rf := FileAccess.open(GameSettings.SETTINGS_FILE_PATH, FileAccess.READ)
		if rf:
			prev_settings_raw = rf.get_as_text()
			rf.close()

	GameSettings.sfx_volume = 0.35
	GameSettings.apply_audio_settings()
	var sw: Control = (load("res://scenes/ui/settings_window.tscn") as PackedScene).instantiate()
	root.add_child(sw)
	await get_tree().process_frame
	_assert(absf(sw.sfx_vol.value - 0.35) < 0.01, "SettingsWindow initializes SFXVol slider from GameSettings")
	sw.sfx_vol.value = 0.25
	var sfx_db_after: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	_assert(absf(GameSettings.sfx_volume - 0.25) < 0.01 and absf(sfx_db_after - linear_to_db(0.25)) < 0.2, "SettingsWindow volume change updates GameSettings and SFX bus dB")
	sw.queue_free()
	await get_tree().process_frame

	GameSettings.master_volume = prev_master
	GameSettings.bgm_volume = prev_bgm
	GameSettings.sfx_volume = prev_sfx
	GameSettings.apply_audio_settings()
	if settings_existed:
		var wf := FileAccess.open(GameSettings.SETTINGS_FILE_PATH, FileAccess.WRITE)
		if wf:
			wf.store_string(prev_settings_raw)
			wf.close()
	elif FileAccess.file_exists(GameSettings.SETTINGS_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.SETTINGS_FILE_PATH))

# ------------------------------------------------------------
# 10. Permadeath Returns to MAIN_MENU (Run Last)
# ------------------------------------------------------------
func _test_permadeath_returns_to_main_menu() -> void:
	print("-- [P0 Test 10] Permadeath Deletes Save & Transitions to MAIN_MENU --")
	GameManager.start_new_game({"world_name": "HardcorePermadeath", "difficulty": "hardcore"})
	var hc_slot: String = GameManager.current_save_slot
	_temp_saves.append(hc_slot)

	GameManager.end_raid("kia", [])
	var permadeath_res: Dictionary = GameManager.last_raid_result.duplicate(true)
	await get_tree().process_frame

	_assert(bool(permadeath_res.get("permadeath", false)), "Permadeath KIA sets last_raid_result.permadeath=true")
	_assert(GameManager.current_world_data.is_empty() and GameManager.current_save_slot == "", "Permadeath KIA clears world data & save slot")
	_assert(SaveManager.load_game(hc_slot).is_empty(), "Permadeath KIA deletes save file from disk")
	_assert(GameManager.current_state == GameManager.GameState.MAIN_MENU, "Permadeath KIA transitions to GameState.MAIN_MENU (not HIDEOUT)")
