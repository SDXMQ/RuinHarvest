# res://tests/economy_and_containers_suite.gd
extends Node

var _passed: int = 0
var _failed: int = 0

func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)

func run_all() -> void:
	await get_tree().process_frame

	_test_flea_market_and_elasticity()
	_test_trader_specialty_and_loyalty()
	_test_nested_containers_depth_filter_weight()
	_test_bulk_sell_protection_and_wishlist()
	await _test_scene_instantiation()
	_test_serialization_and_raid_pouch()
	await _test_centered_drag_drop_and_click_guard()
	await _test_hideout_to_raid_pouch_and_inventory_window_guards()
	await _test_popup_rebind_and_sort_survival()
	await _test_recursive_container_gameplay_integrations()
	await _test_261118_play_feedback_regressions()

	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _make_test_world_data() -> Dictionary:
	return {
		"current_day": 1,
		"difficulty": "normal",
		"player": {
			"rubles": 200000,
			"inventory": [],
			"equipment": {
				"helmet": {},
				"vest": {"id": "1레벨_방탄복", "name": "1레벨 경찰 조끼", "durability": 40.0, "max_durability": 40.0},
				"backpack": {"id": "2레벨_가방", "name": "2레벨 대형 백팩"},
				"bottom": {},
				"primary1": WeaponPartsDatabase.create_default_weapon("M4_리시버"),
				"primary2": {},
				"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버"),
				"throwable": {}
			},
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

func _test_flea_market_and_elasticity() -> void:
	print("-- [Test 1] Flea Market Dualization & Dynamic Price Elasticity --")
	FleaMarket.supply_pressure.clear()
	FleaMarket.player_listings.clear()
	FleaMarket.current_day = 3
	FleaMarket.update_market_prices(3)
	FleaMarket.refresh_listings(3)

	var npc_listings: Array = []
	var has_basic_consumable := false
	var all_stock_valid := true
	for l in FleaMarket.listings:
		if not bool(l.get("is_player", false)):
			npc_listings.append(l)
			var nm := str(l.get("item_name", ""))
			if nm in ["붕대", "생수", "통조림", "9mm"]:
				has_basic_consumable = true
			var s_rem := int(l.get("stock_remaining", 0))
			if s_rem < 1 or s_rem > 3:
				all_stock_valid = false

	_assert(npc_listings.size() >= 6 and npc_listings.size() <= 8, "Flea market NPC pool size is 6..8 (%d)" % npc_listings.size())
	_assert(not has_basic_consumable, "Flea market NPC pool excludes basic consumables")
	_assert(all_stock_valid, "Each NPC listing has stock_remaining in 1..3")

	if not npc_listings.is_empty():
		var first_l: Dictionary = npc_listings[0]
		var init_stock := int(first_l["stock_remaining"])
		var buy_res := FleaMarket.purchase_listing(first_l, init_stock)
		_assert(bool(buy_res.get("success", false)) and bool(buy_res.get("sold_out", false)), "Purchasing remaining stock marks listing sold_out")
		var retry_res := FleaMarket.purchase_listing(first_l, 1)
		_assert(not bool(retry_res.get("success", true)) and str(retry_res.get("reason", "")) == "sold_out", "Sold-out listing rejects subsequent purchase")

	FleaMarket.supply_pressure.clear()
	var gpu_ref := FleaMarket.get_current_price("그래픽카드")
	var fee_rate_1x := FleaMarket.calculate_listing_fee_rate("그래픽카드", gpu_ref)
	var fee_rate_high := FleaMarket.calculate_listing_fee_rate("그래픽카드", int(gpu_ref * 3.0))
	_assert(absf(fee_rate_1x - 0.05) < 0.001, "Listing fee rate at 1.0x reference is 5%% (got %.3f)" % fee_rate_1x)
	_assert(fee_rate_high > 0.25 and fee_rate_high <= 0.35 + 0.001, "Listing fee rate scales progressively up to 35%% (got %.3f)" % fee_rate_high)

	_assert(FleaMarket.register_item("고철", 1, 400, true), "Player listing slot 1 succeeds")
	_assert(FleaMarket.register_item("폐전선", 1, 600, true), "Player listing slot 2 succeeds")
	_assert(FleaMarket.register_item("못", 1, 300, true), "Player listing slot 3 succeeds")
	_assert(not FleaMarket.can_register_more_listings() and not FleaMarket.register_item("나무", 1, 300, true), "Player listing 4th slot is blocked (max 3)")
	FleaMarket.player_listings.clear()

	FleaMarket.supply_pressure.clear()
	var w_data := _make_test_world_data()
	var p_before := FleaMarket.get_current_price("그래픽카드")
	var sell_before := HideoutProgression.get_item_sell_unit_price("fence", {"id": "그래픽카드"}, w_data)
	FleaMarket.record_player_sale("그래픽카드", 3)
	var pressure_after_sale := float(FleaMarket.supply_pressure.get("그래픽카드", 0.0))
	var p_after_sale := FleaMarket.get_current_price("그래픽카드")
	var sell_after_sale := HideoutProgression.get_item_sell_unit_price("fence", {"id": "그래픽카드"}, w_data)
	_assert(pressure_after_sale > 0.0, "Selling increases supply_pressure (%.3f)" % pressure_after_sale)
	_assert(p_after_sale < p_before and sell_after_sale < sell_before, "Bulk selling lowers both Flea Market & Trader prices (%d->%d, %d->%d)" % [p_before, p_after_sale, sell_before, sell_after_sale])

	var med_before := FleaMarket.get_current_price("고급_치료킷")
	FleaMarket.record_player_purchase("고급_치료킷", 4)
	var med_after := FleaMarket.get_current_price("고급_치료킷")
	_assert(med_after > med_before, "Purchasing increases demand pressure and raises price (%d->%d)" % [med_before, med_after])

	FleaMarket.advance_day()
	var pressure_decayed := float(FleaMarket.supply_pressure.get("그래픽카드", 0.0))
	_assert(pressure_decayed > 0.0 and pressure_decayed < pressure_after_sale, "advance_day() decays supply_pressure toward 0 (%.3f -> %.3f)" % [pressure_after_sale, pressure_decayed])

func _test_trader_specialty_and_loyalty() -> void:
	print("-- [Test 2] Trader Specialty Multipliers & Loyalty Levels --")
	FleaMarket.supply_pressure.clear()
	var w_data := _make_test_world_data()

	var med_therapist := HideoutProgression.get_trader_base_sell_ratio("therapist", "구급상자")
	var med_prapor := HideoutProgression.get_trader_base_sell_ratio("prapor", "구급상자")
	var med_fence := HideoutProgression.get_trader_base_sell_ratio("fence", "구급상자")
	_assert(absf(med_therapist - 0.75) < 0.001 and absf(med_prapor - 0.48) < 0.001 and absf(med_fence - 0.55) < 0.001, "Medical buy ratios match Therapist 75%% / Prapor 48%% / Fence 55%%")

	var ammo_prapor := HideoutProgression.get_trader_base_sell_ratio("prapor", "7.62mm")
	var wep_prapor := HideoutProgression.get_trader_base_sell_ratio("prapor", "AK_리시버")
	var med_sell_t := HideoutProgression.get_item_sell_unit_price("therapist", {"id": "구급상자"}, w_data)
	var med_sell_f := HideoutProgression.get_item_sell_unit_price("fence", {"id": "구급상자"}, w_data)
	_assert(absf(ammo_prapor - 0.70) < 0.001 and absf(wep_prapor - 0.70) < 0.001, "Prapor weapon/ammo buy ratio is 70%%")
	_assert(med_sell_t > med_sell_f, "Therapist pays more for medical items (%d) than Fence (%d)" % [med_sell_t, med_sell_f])

	_assert(HideoutProgression.get_trader_loyalty_level(w_data, "prapor") == 1, "Initial Prapor loyalty is Lv.1")
	var lv4_entry: Dictionary = {}
	for st in ItemDatabase.traders["prapor"]["stock"]:
		if int(st.get("min_level", 1)) >= 4:
			lv4_entry = st
			break
	_assert(not lv4_entry.is_empty(), "Prapor stock contains Lv.4 unlock item (%s)" % str(lv4_entry.get("id", "")))
	_assert(not HideoutProgression.is_trader_item_unlocked(w_data, "prapor", lv4_entry), "Lv.4 Prapor item is locked at Lv.1")

	w_data["hideout"]["completed_quests"].append("q_prapor_1")
	HideoutProgression.record_trader_transaction(w_data, "prapor", 16000)
	_assert(HideoutProgression.get_trader_loyalty_level(w_data, "prapor") == 2, "1 quest + 16k RUB unlocks Prapor Lv.2")

	w_data["hideout"]["completed_quests"].append("q_prapor_2")
	HideoutProgression.record_trader_transaction(w_data, "prapor", 30000)
	_assert(HideoutProgression.get_trader_loyalty_level(w_data, "prapor") == 3, "2 quests + 46k RUB unlocks Prapor Lv.3")

	HideoutProgression.record_trader_transaction(w_data, "prapor", 50000)
	_assert(HideoutProgression.get_trader_loyalty_level(w_data, "prapor") == 4, "2 quests + 96k RUB unlocks Prapor Lv.4")
	_assert(HideoutProgression.is_trader_item_unlocked(w_data, "prapor", lv4_entry), "Lv.4 Prapor item unlocks at Loyalty Lv.4")

func _test_nested_containers_depth_filter_weight() -> void:
	print("-- [Test 3] Nested Containers, Depth Guard, Case Filters & Recursive Weight --")
	var root := get_tree().get_root()
	var main_grid := InventoryGrid.new()
	main_grid.grid_width = 8
	main_grid.grid_height = 8
	main_grid.has_secure_container = true
	main_grid.container_depth = 0
	root.add_child(main_grid)

	_assert(main_grid.auto_add_item("탄약 케이스", 1) == 0, "Ammo case (2x2) fits into main grid")
	_assert(main_grid.auto_add_item("2레벨_가방", 1) == 0, "Backpack fits into main grid")
	var ammo_case_item: Dictionary = {}
	var bag_item: Dictionary = {}
	for it in main_grid.items:
		if str(it.get("id", "")) == "탄약 케이스":
			ammo_case_item = it
		elif str(it.get("id", "")) == "2레벨_가방":
			bag_item = it
	_assert(InventoryGrid.is_container_item(ammo_case_item) and InventoryGrid.is_container_item(bag_item), "Both storage case and backpack are detected as containers")

	var sub_grid := InventoryGrid.new()
	sub_grid.grid_width = 6
	sub_grid.grid_height = 6
	sub_grid.container_depth = 1
	sub_grid.owner_container_uid = str(bag_item["uid"])
	root.add_child(sub_grid)

	var self_res := sub_grid.can_accept_item(bag_item, "2레벨_가방")
	_assert(not bool(self_res["ok"]) and str(self_res["reason"]) == "self_drop", "Self-drop into own popup is blocked (self_drop)")
	_assert(not sub_grid.can_place_item(3, 3, 0, 0, "", "2레벨_가방", bag_item), "can_place_item blocks self-drop")

	var inner_case := {"uid": InventoryGrid.next_uid(), "id": "의약품 케이스", "amount": 1, "w": 2, "h": 2, "inner_items": []}
	var depth_res := sub_grid.can_accept_item(inner_case, "의약품 케이스")
	_assert(not bool(depth_res["ok"]) and str(depth_res["reason"]) == "max_depth_exceeded", "Depth >= 2 container nesting is blocked (max_depth_exceeded)")

	var bag_with_nested_bag := {
		"uid": InventoryGrid.next_uid(),
		"id": "1레벨_가방",
		"amount": 1,
		"w": 3,
		"h": 3,
		"inner_items": [{"uid": InventoryGrid.next_uid(), "id": "탄약 케이스", "amount": 1, "w": 2, "h": 2, "x": 0, "y": 0}]
	}
	var depth0_res := main_grid.can_accept_item(bag_with_nested_bag, "1레벨_가방")
	_assert(not bool(depth0_res["ok"]) and str(depth0_res["reason"]) == "max_depth_exceeded", "Depth 0 grid blocks importing a container with nested containers inside")

	_assert(InventoryGrid.is_item_allowed_by_filter("5.56mm", "ammo") and not InventoryGrid.is_item_allowed_by_filter("붕대", "ammo"), "Ammo case filter allows ammo only")
	_assert(InventoryGrid.is_item_allowed_by_filter("구급상자", "medical") and not InventoryGrid.is_item_allowed_by_filter("9mm", "medical"), "Medical case filter allows medical only")
	_assert(InventoryGrid.is_item_allowed_by_filter("수직_포어그립", "weapon_part") and not InventoryGrid.is_item_allowed_by_filter("생수", "weapon_part"), "Weapon part case filter allows parts only")
	_assert(InventoryGrid.is_item_allowed_by_filter("Scav 인식표", "dogtag_key") and InventoryGrid.is_item_allowed_by_filter("보안 키카드", "dogtag_key") and not InventoryGrid.is_item_allowed_by_filter("고철", "dogtag_key"), "Dogtag/Key wallet filter allows dogtags/keys/keycards only")

	var popup := ContainerPopupWindow.new()
	root.add_child(popup)
	popup.setup(ammo_case_item, main_grid, null)
	var base_total_w := main_grid.get_total_weight()
	var added_ammo_rem: int = popup.inner_grid.auto_add_item("5.56mm", 30)
	_assert(added_ammo_rem == 0, "ContainerPopupWindow inner_grid accepts 30x 5.56mm ammo")
	var after_total_w := main_grid.get_total_weight()
	var expected_ammo_w := float(ItemDatabase.get_item_data("5.56mm").get("weight", 0.01)) * 30.0
	_assert(absf((after_total_w - base_total_w) - expected_ammo_w) < 0.01, "Main grid recursive get_total_weight() adds popup inner_items weight (+%.2fkg)" % expected_ammo_w)
	_assert(ammo_case_item.get("inner_items", []).size() == 1, "Popup inner_items synced back to container_item")

	popup.queue_free()
	sub_grid.queue_free()
	main_grid.queue_free()

func _test_bulk_sell_protection_and_wishlist() -> void:
	print("-- [Test 4] Bulk Sell Protections & Auto Wishlist Markers --")
	FleaMarket.supply_pressure.clear()
	var w_data := _make_test_world_data()
	var root := get_tree().get_root()
	var p_grid := InventoryGrid.new()
	p_grid.grid_width = 6
	p_grid.grid_height = 5
	p_grid.has_secure_container = true
	root.add_child(p_grid)

	var s_grid := InventoryGrid.new()
	s_grid.grid_width = 10
	s_grid.grid_height = 12
	s_grid.has_secure_container = false
	root.add_child(s_grid)

	var sec_item := {"uid": InventoryGrid.next_uid(), "id": "금시계", "amount": 1, "w": 1, "h": 1}
	p_grid.place_item(sec_item, 0, 0, false)
	var locked_item := {"uid": InventoryGrid.next_uid(), "id": "CPU", "amount": 1, "w": 1, "h": 1, "locked": true}
	p_grid.place_item(locked_item, 2, 0, false)
	var free_scrap := {"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 2, "w": 1, "h": 1}
	p_grid.place_item(free_scrap, 3, 0, false)
	var gear_item := {"uid": InventoryGrid.next_uid(), "id": "M9_리시버", "amount": 1, "w": 2, "h": 1}
	s_grid.place_item(gear_item, 0, 0, false)
	var med_item := {"uid": InventoryGrid.next_uid(), "id": "구급상자", "amount": 1, "w": 1, "h": 1}
	s_grid.place_item(med_item, 3, 0, false)

	var val_cands := HideoutProgression.collect_bulk_sell_candidates("valuables", p_grid, s_grid)
	var non_gear_cands := HideoutProgression.collect_bulk_sell_candidates("non_gear", p_grid, s_grid)
	_assert(val_cands.size() == 1 and str(val_cands[0]["uid"]) == str(free_scrap["uid"]), "valuables auto-collect picks only unlocked non-SECURE misc/material")
	_assert(non_gear_cands.size() == 2, "non_gear auto-collect picks unlocked scrap + medkit while excluding gear/locked/SECURE")

	var forced_entries := [
		{"uid": sec_item["uid"], "is_stash": false, "source_grid": p_grid},
		{"uid": locked_item["uid"], "is_stash": false, "source_grid": p_grid},
		{"uid": free_scrap["uid"], "is_stash": false, "source_grid": p_grid},
		{"uid": med_item["uid"], "is_stash": true, "source_grid": s_grid}
	]
	var preview := HideoutProgression.preview_bulk_sell_receipt("therapist", forced_entries, w_data, p_grid, s_grid)
	_assert(int(preview["valid_count"]) == 2 and int(preview["total_units"]) == 3, "preview_bulk_sell_receipt ignores locked & SECURE items")
	var init_rubles := int(w_data["player"]["rubles"])
	var exec_res := HideoutProgression.execute_bulk_sell("therapist", forced_entries, w_data, p_grid, s_grid)
	_assert(bool(exec_res["success"]) and int(exec_res["sold_count"]) == 2 and int(exec_res["skipped_protected"]) == 2, "execute_bulk_sell skips 2 protected items and sells 2 valid entries")
	_assert(int(w_data["player"]["rubles"]) == init_rubles + int(preview["total_final_rubles"]), "Bulk sell payout matches receipt preview (%d RUB)" % int(preview["total_final_rubles"]))
	_assert(not p_grid.get_item_by_uid(str(sec_item["uid"])).is_empty(), "SECURE item remains in backpack after bulk sell")
	_assert(not p_grid.get_item_by_uid(str(locked_item["uid"])).is_empty(), "Locked item remains in backpack after bulk sell")

	_assert(HideoutProgression.is_wishlist_item("나무", w_data), "Lv.1 stash_expansion required material ('나무') marked as wishlist")
	_assert(HideoutProgression.is_wishlist_item("붕대", w_data), "Lv.1 med_station / therapist quest material ('붕대') marked as wishlist")
	_assert(not HideoutProgression.is_wishlist_item("9mm", w_data), "Non-required item ('9mm') is not marked as wishlist")

	p_grid.queue_free()
	s_grid.queue_free()

func _test_scene_instantiation() -> void:
	print("-- [Test 5] UI & Scene Instantiation Verification --")
	_assert(absf(InventoryUIHelper.CELL_SIZE - 36.0) < 0.01, "Main InventoryUIHelper.CELL_SIZE is 36.0")
	_assert(absf(InventoryUIHelper.POPUP_CELL_SIZE - 32.0) < 0.01, "Popup InventoryUIHelper.POPUP_CELL_SIZE is 32.0")
	var bullet_scr: Script = load("res://scenes/entities/projectiles/bullet.gd")
	var ground_scr: Script = load("res://scenes/entities/items/ground_item.gd")
	var player_scr: Script = load("res://scenes/entities/player/player.gd")
	_assert(bullet_scr != null and ground_scr != null and player_scr != null, "Core gameplay scripts (bullet, ground_item, player) reload cleanly")

	GameManager.current_world_data = _make_test_world_data()
	var inv_scene: PackedScene = load("res://scenes/ui/inventory_window.tscn")
	var inv_win := inv_scene.instantiate()
	_assert(inv_win != null, "inventory_window.tscn instantiates cleanly")
	get_tree().get_root().add_child(inv_win)
	await get_tree().process_frame
	if inv_win:
		var tmp_grid := InventoryGrid.new()
		get_tree().get_root().add_child(tmp_grid)
		inv_win.setup(null, tmp_grid, GameManager.current_world_data["player"]["equipment"])
		_assert(is_instance_valid(inv_win.grid_control), "InventoryWindow setup binds valid grid_control")
		inv_win.queue_free()
		tmp_grid.queue_free()

	GameManager.current_save_slot = ""
	var hideout_scene: PackedScene = load("res://scenes/hideout/hideout.tscn")
	var hideout_node := hideout_scene.instantiate()
	_assert(hideout_node != null, "hideout.tscn instantiates cleanly")
	get_tree().get_root().add_child(hideout_node)
	await get_tree().process_frame
	if hideout_node:
		_assert(is_instance_valid(hideout_node.get("sell_player_grid_ctrl")), "Hideout 3-col TradersTab created SellPlayerGridControl")
		_assert(is_instance_valid(hideout_node.get("sell_stash_grid_ctrl")), "Hideout 3-col TradersTab created SellStashGridControl")
		_assert(is_instance_valid(hideout_node.get("sell_bulk_btn")), "Hideout 3-col TradersTab created BulkSell settle button")
		_assert(is_instance_valid(hideout_node.get("market_player_grid_ctrl")), "Hideout MarketTab created MarketPlayerGridControl")
		_assert(is_instance_valid(hideout_node.get("market_stash_grid_ctrl")), "Hideout MarketTab created MarketStashGridControl")
		_assert(is_instance_valid(hideout_node.get("market_search_input")), "Hideout MarketTab created search input")
		_assert(is_instance_valid(hideout_node.get("market_confirm_btn")), "Hideout MarketTab created register confirm button")

		FleaMarket.player_listings.clear()
		var hp_grid: InventoryGrid = hideout_node.get("player_grid_mgr")
		var m_p_ctrl: Control = hideout_node.get("market_player_grid_ctrl")
		hp_grid.auto_add_item("그래픽카드", 1)
		hp_grid.auto_add_item("구급상자", 1)
		hp_grid.auto_add_item("CPU", 1, {"locked": true})
		var gpu_uid := ""
		var med_uid := ""
		var cpu_uid := ""
		for it in hp_grid.items:
			if str(it.get("id", "")) == "그래픽카드": gpu_uid = str(it.get("uid", ""))
			elif str(it.get("id", "")) == "구급상자": med_uid = str(it.get("uid", ""))
			elif str(it.get("id", "")) == "CPU": cpu_uid = str(it.get("uid", ""))

		hideout_node.set("market_search_text", "그래픽")
		hideout_node.set("market_filter_category", "all")
		hideout_node.call("_refresh_market_register_ui")
		var m_matched: Dictionary = m_p_ctrl.get_meta("matched_uids", {})
		var m_unavail: Dictionary = m_p_ctrl.get_meta("unavailable_uids", {})
		_assert(bool(m_p_ctrl.get_meta("filter_active", false)) and m_matched.has(gpu_uid) and not m_matched.has(med_uid), "Market search highlights only matching items (GPU)")
		_assert(m_unavail.has(cpu_uid), "Market register grid marks locked item as unavailable")

		hideout_node.set("market_search_text", "")
		hideout_node.set("market_filter_category", "medical_supply")
		hideout_node.call("_refresh_market_register_ui")
		var cat_matched: Dictionary = m_p_ctrl.get_meta("matched_uids", {})
		_assert(cat_matched.has(med_uid) and not cat_matched.has(gpu_uid), "Market category filter 'medical_supply' filters to medical items")

		hideout_node.set("market_filter_category", "all")
		hideout_node.set("market_selected_uid", gpu_uid)
		hideout_node.set("market_selected_is_stash", false)
		hideout_node.call("_refresh_market_register_ui")
		var confirm_btn: Button = hideout_node.get("market_confirm_btn")
		_assert(not confirm_btn.disabled, "Selecting valid item enables Market confirm register button")
		hideout_node.call("_try_register_selected_market_item")
		_assert(FleaMarket.player_listings.size() == 1 and hp_grid.get_item_by_uid(gpu_uid).is_empty(), "Confirming Market register moves selected item to player_listings")
		FleaMarket.player_listings.clear()

		hideout_node.queue_free()
	await get_tree().process_frame

func _test_serialization_and_raid_pouch() -> void:
	print("-- [Test 6] SaveManager Serialization & End Raid Pouch Preservation --")
	var w_data := _make_test_world_data()
	var root := get_tree().get_root()
	var p_grid := InventoryGrid.new()
	p_grid.grid_width = 6
	p_grid.grid_height = 5
	p_grid.has_secure_container = true
	root.add_child(p_grid)

	var pouch_case := {
		"uid": InventoryGrid.next_uid(),
		"id": "인식표 지갑",
		"amount": 1,
		"w": 2,
		"h": 2,
		"locked": true,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "보안 키카드", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0, "rotated": false, "locked": true}
		]
	}
	var ammo_case := {
		"uid": InventoryGrid.next_uid(),
		"id": "탄약 케이스",
		"amount": 1,
		"w": 2,
		"h": 2,
		"locked": false,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "7.62mm", "amount": 30, "w": 1, "h": 1, "x": 0, "y": 0, "rotated": false, "locked": true}
		]
	}
	_assert(p_grid.place_item(pouch_case, 0, 0, false), "2x2 인식표 지갑 fits inside 2x2 SECURE zone")
	_assert(not p_grid.can_place_item(2, 2, 0, 0, "", "무기 부품 상자", ammo_case), "Non-pouch stash case is still blocked from 2x2 SECURE zone")
	_assert(p_grid.place_item(ammo_case, 2, 0, false), "2x2 탄약 케이스 fits outside 2x2 SECURE zone")

	w_data["player"]["inventory"] = p_grid.items.duplicate(true)
	FleaMarket.supply_pressure.clear()
	FleaMarket.record_player_sale("CPU", 2)
	w_data["flea_market"] = FleaMarket.to_save_dict()

	var slot_name := "__test_ruinharvest_eco__"
	_assert(SaveManager.save_game(w_data, slot_name), "SaveManager.save_game succeeds")
	var loaded := SaveManager.load_game(slot_name)
	_assert(not loaded.is_empty(), "SaveManager.load_game succeeds")

	var verify_grid := InventoryGrid.new()
	verify_grid.grid_width = 6
	verify_grid.grid_height = 5
	verify_grid.has_secure_container = true
	root.add_child(verify_grid)
	verify_grid.load_items(loaded.get("player", {}).get("inventory", []))
	var restored_pouch := verify_grid.get_item_at(0, 0)
	var restored_ammo_case := verify_grid.get_item_at(2, 0)
	_assert(bool(restored_pouch.get("locked", false)), "Loaded SECURE wallet preserves locked=true")
	_assert(restored_pouch.get("inner_items", []).size() == 1 and str(restored_pouch["inner_items"][0].get("id", "")) == "보안 키카드", "Loaded wallet preserves inner_items")
	_assert(bool(restored_pouch["inner_items"][0].get("locked", false)), "Loaded inner keycard preserves locked=true")
	_assert(restored_ammo_case.get("inner_items", []).size() == 1 and str(restored_ammo_case["inner_items"][0].get("id", "")) == "7.62mm", "Loaded ammo case preserves inner_items")

	GameManager.current_world_data = loaded.duplicate(true)
	GameManager.current_save_slot = slot_name
	GameManager.end_raid("survived", p_grid.items.duplicate(true))
	var extracted_inv: Array = GameManager.current_world_data.get("player", {}).get("inventory", [])
	_assert(extracted_inv.size() == 2, "Survived end_raid preserves both wallet & ammo case (%d)" % extracted_inv.size())

	GameManager.current_world_data = loaded.duplicate(true)
	GameManager.end_raid("kia", p_grid.items.duplicate(true))
	var pouch_saved: Array = GameManager.current_world_data.get("player", {}).get("inventory", [])
	_assert(pouch_saved.size() == 1 and str(pouch_saved[0].get("id", "")) == "인식표 지갑", "KIA end_raid keeps only SECURE 2x2 item (인식표 지갑)")
	_assert(pouch_saved[0].get("inner_items", []).size() == 1, "KIA end_raid preserves nested inner_items inside SECURE wallet")
	_assert(int(GameManager.last_raid_result.get("pouch_saved_count", 0)) == 1, "end_raid records pouch_saved_count == 1")

	SaveManager.delete_save(slot_name)
	p_grid.queue_free()
	verify_grid.queue_free()

func _test_centered_drag_drop_and_click_guard() -> void:
	print("-- [Test 7] Centered Drag Drop, Click Guard & Hideout Equip Overflow --")
	FleaMarket.supply_pressure.clear()
	FleaMarket.player_listings.clear()
	var root := get_tree().get_root()

	# 1) Direct calc_drag_drop_cell test for 2x2 item dropped near its visual center
	var dummy_ctrl := Control.new()
	dummy_ctrl.position = Vector2(100.0, 100.0)
	dummy_ctrl.size = Vector2(6.0 * InventoryUIHelper.CELL_SIZE, 5.0 * InventoryUIHelper.CELL_SIZE)
	root.add_child(dummy_ctrl)
	var c_grid := InventoryGrid.new()
	c_grid.grid_width = 6
	c_grid.grid_height = 5
	c_grid.has_secure_container = true
	root.add_child(c_grid)
	await get_tree().process_frame

	var wallet_dummy := {"uid": InventoryGrid.next_uid(), "id": "인식표 지갑", "amount": 1, "w": 2, "h": 2, "rotated": false}
	var drag_dummy := {"item": wallet_dummy, "rotated": false}
	var center_hover_pos := dummy_ctrl.global_position + Vector2(1.15 * InventoryUIHelper.CELL_SIZE, 1.15 * InventoryUIHelper.CELL_SIZE)
	var calc_cell := InventoryUIHelper.calc_drag_drop_cell(dummy_ctrl, center_hover_pos, c_grid, drag_dummy, InventoryUIHelper.CELL_SIZE)
	_assert(calc_cell == Vector2i(0, 0), "calc_drag_drop_cell maps 2x2 centered cursor near (1.15,1.15) to (0,0) SECURE cell (got %s)" % [calc_cell])
	dummy_ctrl.queue_free()
	c_grid.queue_free()

	# 2) Hideout centered drop of 2x2 인식표 지갑 onto SECURE (0,0) + click-without-drag guard
	var w_data := _make_test_world_data()
	var keycard_uid := InventoryGrid.next_uid()
	var wallet_uid := InventoryGrid.next_uid()
	var stash_wallet := {
		"uid": wallet_uid,
		"id": "인식표 지갑",
		"amount": 1,
		"w": 2,
		"h": 2,
		"x": 0,
		"y": 0,
		"rotated": false,
		"locked": true,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": keycard_uid, "id": "보안 키카드", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0, "rotated": false, "locked": true}
		]
	}
	w_data["hideout"]["stash"] = [stash_wallet]
	GameManager.current_world_data = w_data.duplicate(true)

	var hideout_scene := load("res://scenes/hideout/hideout.tscn")
	var hideout: Control = hideout_scene.instantiate()
	root.add_child(hideout)
	await get_tree().process_frame
	await get_tree().process_frame

	var loaded_wallet: Dictionary = hideout.stash_grid_mgr.get_item_by_uid(wallet_uid)
	_assert(not loaded_wallet.is_empty(), "Hideout loaded 인식표 지갑 into stash")

	var drop_center_pos: Vector2 = hideout.player_grid_control.global_position + Vector2(1.15 * hideout.CELL_SIZE, 1.15 * hideout.CELL_SIZE)
	hideout.is_dragging = true
	hideout.drag_data = {
		"source": "stash_grid",
		"item": loaded_wallet,
		"rotated": false,
		"orig_rotated": false,
		"start_mouse_pos": Vector2(-500.0, -500.0),
		"source_grid": hideout.stash_grid_mgr
	}
	hideout._handle_hideout_global_drop(drop_center_pos)

	var placed_in_secure: Dictionary = hideout.player_grid_mgr.get_item_at(0, 0)
	_assert(String(placed_in_secure.get("id", "")) == "인식표 지갑", "Hideout centered drop places 2x2 인식표 지갑 onto SECURE (0,0)")
	_assert(hideout.stash_grid_mgr.get_item_by_uid(wallet_uid).is_empty(), "Moved 인식표 지갑 removed from stash")
	_assert(placed_in_secure.get("inner_items", []).size() == 1 and bool(placed_in_secure.get("locked", false)), "Moved 인식표 지갑 keeps inner_items and locked state")

	# Click-without-drag (< 5px movement) must leave wallet at (0,0) instead of offsetting to (1,1)
	hideout.is_dragging = true
	hideout.drag_data = {
		"source": "player_grid",
		"item": placed_in_secure,
		"rotated": false,
		"orig_rotated": false,
		"start_mouse_pos": drop_center_pos,
		"source_grid": hideout.player_grid_mgr
	}
	hideout._handle_hideout_global_drop(drop_center_pos + Vector2(2.0, 2.0))
	var after_click: Dictionary = hideout.player_grid_mgr.get_item_at(0, 0)
	_assert(String(after_click.get("uid", "")) == wallet_uid and not hideout.is_dragging, "Click-without-drag (<5px) keeps 인식표 지갑 at (0,0) without ejecting")

	# 3) Hideout equipment swap overflow fallback when stash is full
	hideout.stash_grid_mgr.resize_grid(2, 2)
	hideout.stash_grid_mgr.auto_add_item("탄약 케이스", 1)
	var extra_vest := {"uid": InventoryGrid.next_uid(), "id": "1레벨_방탄복", "name": "1레벨 예비 조끼", "amount": 1, "w": 2, "h": 2, "durability": 40.0, "max_durability": 40.0}
	_assert(hideout.player_grid_mgr.auto_add_item("1레벨_방탄복", 1, extra_vest) == 0, "Spare vest placed in player grid for swap overflow check")
	var placed_spare: Dictionary = {}
	for it in hideout.player_grid_mgr.items:
		if String(it.get("id", "")) == "1레벨_방탄복":
			placed_spare = it
			break
	hideout.is_dragging = true
	hideout.drag_data = {
		"source": "player_grid",
		"item": placed_spare,
		"rotated": false,
		"orig_rotated": false,
		"start_mouse_pos": Vector2(-100.0, -100.0),
		"source_grid": hideout.player_grid_mgr
	}
	hideout._try_equip_hideout_item("vest")
	var remaining_vests_in_player := 0
	for it in hideout.player_grid_mgr.items:
		if String(it.get("id", "")) == "1레벨_방탄복":
			remaining_vests_in_player += 1
	_assert(String(hideout.equipment_data.get("vest", {}).get("id", "")) == "1레벨_방탄복" and remaining_vests_in_player == 1, "Hideout equip swap preserves prev_equipped via player_grid fallback when stash is full")

	hideout.queue_free()
	await get_tree().process_frame

func _test_hideout_to_raid_pouch_and_inventory_window_guards() -> void:
	print("-- [Test 8] Hideout->Raid Pouch Persistence & InventoryWindow Hideout Guards --")
	var root := get_tree().get_root()
	var slot_name := "__test_hideout_to_raid_pouch__"
	var w_data := _make_test_world_data()
	var wallet_uid := InventoryGrid.next_uid()
	var keycard_uid := InventoryGrid.next_uid()
	w_data["player"]["inventory"] = [
		{
			"uid": wallet_uid,
			"id": "인식표 지갑",
			"amount": 1,
			"w": 2,
			"h": 2,
			"x": 0,
			"y": 0,
			"rotated": false,
			"locked": true,
			"inner_grid_w": 6,
			"inner_grid_h": 6,
			"inner_items": [
				{"uid": keycard_uid, "id": "보안 키카드", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0, "rotated": false, "locked": true}
			]
		}
	]
	GameManager.current_world_data = w_data.duplicate(true)

	# 1) Hideout _sync_save_data -> SaveManager -> Player _ready() (raid load path)
	var hideout: Control = load("res://scenes/hideout/hideout.tscn").instantiate()
	root.add_child(hideout)
	await get_tree().process_frame
	hideout._sync_save_data()
	_assert(SaveManager.save_game(GameManager.current_world_data, slot_name), "Save after Hideout sync succeeds")
	hideout.queue_free()
	await get_tree().process_frame

	GameManager.current_world_data = SaveManager.load_game(slot_name)
	var mw_scene: PackedScene = load("res://scenes/world/main_world.tscn")
	var mw_e2e: Node = mw_scene.instantiate()
	root.add_child(mw_e2e)
	await get_tree().process_frame

	var mw_player: Node = mw_e2e.get("player")
	var raid_wallet: Dictionary = mw_player.inventory_grid.get_item_at(0, 0) if mw_player and mw_player.inventory_grid else {}
	_assert(String(raid_wallet.get("id", "")) == "인식표 지갑" and bool(raid_wallet.get("locked", false)), "MainWorld._ready loads 인식표 지갑 into SECURE (0,0) on raid start")
	_assert(raid_wallet.get("inner_items", []).size() == 1 and String(raid_wallet["inner_items"][0].get("id", "")) == "보안 키카드", "MainWorld._ready preserves nested inner_items inside 인식표 지갑")
	mw_e2e.queue_free()
	SaveManager.delete_save(slot_name)
	await get_tree().process_frame

	# 2) InventoryWindow opened in Hideout mode (player == null, hideout_stash_grid bound)
	var p_grid := InventoryGrid.new()
	p_grid.grid_width = 6
	p_grid.grid_height = 5
	p_grid.has_secure_container = true
	root.add_child(p_grid)

	var s_grid := InventoryGrid.new()
	s_grid.grid_width = 8
	s_grid.grid_height = 8
	s_grid.has_secure_container = false
	root.add_child(s_grid)

	var inv_wallet := {
		"uid": InventoryGrid.next_uid(),
		"id": "인식표 지갑",
		"amount": 1,
		"w": 2,
		"h": 2,
		"x": 0,
		"y": 0,
		"rotated": false,
		"locked": true,
		"inner_items": []
	}
	_assert(p_grid.place_item(inv_wallet, 0, 0, false), "Placed wallet at SECURE (0,0) for InventoryWindow test")
	# Fill all remaining cells in the upper 6x3 area so shrinking 6x5 -> 6x3 must overflow row 4 item
	for fy in range(3):
		for fx in range(6):
			if fx < 2 and fy < 2:
				continue
			p_grid.place_item({"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 1, "w": 1, "h": 1}, fx, fy, false)
	var row4_item := {"uid": InventoryGrid.next_uid(), "id": "생수", "amount": 1, "w": 1, "h": 1}
	_assert(p_grid.place_item(row4_item, 0, 4, false), "Placed 생수 at (0,4) before backpack shrink test")

	var inv_win: Control = load("res://scenes/ui/inventory_window.tscn").instantiate()
	root.add_child(inv_win)
	inv_win.hideout_stash_grid = s_grid
	inv_win.setup(null, p_grid, {"backpack": {"id": "2레벨_가방"}})
	await get_tree().process_frame

	# Click-without-drag (<5px) guard in InventoryWindow (headless mouse pos is Vector2.ZERO)
	inv_win.is_dragging = true
	inv_win.drag_data = {
		"source": "grid",
		"item": inv_wallet,
		"rotated": false,
		"orig_rotated": false,
		"start_mouse_pos": Vector2(2.0, 2.0),
		"source_grid": p_grid
	}
	inv_win._handle_global_drop()
	_assert(String(p_grid.get_item_at(0, 0).get("id", "")) == "인식표 지갑", "InventoryWindow click-without-drag (<5px) keeps wallet at (0,0)")

	# Dropping onto VicinityCol while in Hideout (player == null) must NOT delete item
	inv_win.vicinity_section.global_position = Vector2(-50.0, -50.0)
	inv_win.vicinity_section.size = Vector2(300.0, 300.0)
	inv_win.is_dragging = true
	inv_win.drag_data = {
		"source": "grid",
		"item": inv_wallet,
		"rotated": false,
		"orig_rotated": false,
		"start_mouse_pos": Vector2(200.0, 200.0),
		"source_grid": p_grid
	}
	inv_win._handle_global_drop()
	_assert(String(p_grid.get_item_at(0, 0).get("id", "")) == "인식표 지갑", "InventoryWindow in Hideout blocks dropping items into Vicinity (prevents silent deletion)")

	# Overflow routing via _handle_overflow_item + shrinking backpack moves overflow to hideout_stash_grid
	inv_win._handle_overflow_item({"uid": InventoryGrid.next_uid(), "id": "붕대", "amount": 2, "w": 1, "h": 1})
	_assert(s_grid.has_item("붕대", 2), "InventoryWindow._handle_overflow_item routes overflow to hideout_stash_grid")
	inv_win.equipment_data["backpack"] = {}
	inv_win._apply_backpack_grid_size()
	_assert(s_grid.has_item("생수", 1), "Shrinking backpack in Hideout InventoryWindow sends overflow items to hideout_stash_grid instead of losing them")

	inv_win.queue_free()
	p_grid.queue_free()
	s_grid.queue_free()
	await get_tree().process_frame

func _test_popup_rebind_and_sort_survival() -> void:
	print("-- [Test 9] Popup Rebind & Sort Survival (Hideout & InventoryWindow) --")
	var root := get_tree().get_root()
	var w_data := _make_test_world_data()
	var vest_uid := InventoryGrid.next_uid()
	w_data["player"]["equipment"]["vest"]["uid"] = vest_uid
	var ammo_case_uid := InventoryGrid.next_uid()
	w_data["player"]["inventory"] = [
		{"uid": ammo_case_uid, "id": "탄약 케이스", "amount": 1, "w": 2, "h": 2, "x": 2, "y": 0, "rotated": false, "inner_grid_w": 6, "inner_grid_h": 6, "inner_items": []}
	]
	var med_case_uid := InventoryGrid.next_uid()
	w_data["hideout"]["stash"] = [
		{"uid": med_case_uid, "id": "의약품 케이스", "amount": 1, "w": 2, "h": 2, "x": 0, "y": 0, "rotated": false, "inner_grid_w": 7, "inner_grid_h": 7, "inner_items": []}
	]
	GameManager.current_world_data = w_data.duplicate(true)

	# 1) Hideout popup rebinding after sort_items() & vest ownership preservation
	var hideout: Control = load("res://scenes/hideout/hideout.tscn").instantiate()
	root.add_child(hideout)
	await get_tree().process_frame

	var p_case: Dictionary = hideout.player_grid_mgr.get_item_by_uid(ammo_case_uid)
	var s_case: Dictionary = hideout.stash_grid_mgr.get_item_by_uid(med_case_uid)
	hideout.open_container_popup(hideout.equipment_data["vest"], null)
	hideout.open_container_popup(p_case, hideout.player_grid_mgr)
	hideout.open_container_popup(s_case, hideout.stash_grid_mgr)
	_assert(hideout.open_container_popups.size() == 3, "Hideout opens 3 container popups (equipped vest + player case + stash case)")

	hideout.player_grid_mgr.sort_items()
	hideout.stash_grid_mgr.sort_items()
	hideout._prune_stale_popups()
	_assert(hideout.open_container_popups.size() == 3 and hideout.open_container_popups.has(vest_uid), "Hideout._prune_stale_popups keeps all 3 popups open after sort_items() including equipped vest")

	var p_popup: ContainerPopupWindow = hideout.open_container_popups[ammo_case_uid] as ContainerPopupWindow
	_assert(p_popup != null and p_popup.inner_grid.auto_add_item("5.56mm", 30) == 0, "Added 30x 5.56mm into post-sort rebound popup")
	var sorted_p_case: Dictionary = hideout.player_grid_mgr.get_item_by_uid(ammo_case_uid)
	_assert(sorted_p_case.get("inner_items", []).size() == 1 and int(sorted_p_case["inner_items"][0].get("amount", 0)) == 30, "Hideout popup rebound container_item to live dictionary after sort_items()")

	hideout.queue_free()
	await get_tree().process_frame

	# 2) InventoryWindow _prune_and_rebind_popups after sort_items()
	var p_grid := InventoryGrid.new()
	p_grid.grid_width = 6
	p_grid.grid_height = 5
	p_grid.has_secure_container = true
	root.add_child(p_grid)
	var iw_case_uid := InventoryGrid.next_uid()
	var iw_case := {"uid": iw_case_uid, "id": "탄약 케이스", "amount": 1, "w": 2, "h": 2, "inner_grid_w": 6, "inner_grid_h": 6, "inner_items": []}
	p_grid.place_item(iw_case, 2, 0, false)
	var eq_vest := {"uid": vest_uid, "id": "1레벨_방탄복", "name": "1레벨 경찰 조끼", "durability": 40.0, "max_durability": 40.0}

	var inv_win: Control = load("res://scenes/ui/inventory_window.tscn").instantiate()
	root.add_child(inv_win)
	inv_win.setup(null, p_grid, {"vest": eq_vest, "backpack": {"id": "2레벨_가방"}})
	await get_tree().process_frame

	inv_win.open_container_popup(iw_case, p_grid)
	inv_win.open_container_popup(eq_vest, null)
	_assert(inv_win.open_container_popups.size() == 2, "InventoryWindow opens 2 popups (grid case + equipped vest)")
	p_grid.sort_items()
	inv_win._prune_and_rebind_popups()
	_assert(inv_win.open_container_popups.size() == 2, "InventoryWindow._prune_and_rebind_popups preserves both popups after sort_items()")
	var iw_popup: ContainerPopupWindow = inv_win.open_container_popups[iw_case_uid] as ContainerPopupWindow
	iw_popup.inner_grid.auto_add_item("9mm", 20)
	_assert(p_grid.get_item_by_uid(iw_case_uid).get("inner_items", []).size() == 1, "InventoryWindow popup stays synced to rebound grid item after sort_items()")

	inv_win.queue_free()
	p_grid.queue_free()
	await get_tree().process_frame

func _test_recursive_container_gameplay_integrations() -> void:
	print("-- [Test 10] Recursive Container Support (Grid, 1D Inv, Reload, Quickslot, Door/Radio, Crafting/WB, Flea Return) --")
	var root := get_tree().get_root()

	# 1) InventoryGrid recursive helpers + 1D Inventory metadata preservation
	var r_grid := InventoryGrid.new()
	r_grid.grid_width = 6
	r_grid.grid_height = 5
	r_grid.has_secure_container = true
	root.add_child(r_grid)

	var kc_uid := InventoryGrid.next_uid()
	var tag_uid := InventoryGrid.next_uid()
	var key1_uid := InventoryGrid.next_uid()
	var keycard_uid := InventoryGrid.next_uid()
	var wallet := {
		"uid": InventoryGrid.next_uid(),
		"id": "인식표 지갑",
		"amount": 1,
		"w": 2,
		"h": 2,
		"locked": true,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": kc_uid, "id": "무기고 열쇠", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0, "durability": 1.0, "max_durability": 5.0},
			{"uid": tag_uid, "id": "Scav 인식표", "amount": 1, "w": 1, "h": 1, "x": 1, "y": 0},
			{"uid": keycard_uid, "id": "보안 키카드", "amount": 1, "w": 1, "h": 1, "x": 2, "y": 0, "durability": 3.0, "max_durability": 3.0}
		]
	}
	r_grid.place_item(wallet, 0, 0, false)
	var ammo_case := {
		"uid": InventoryGrid.next_uid(),
		"id": "탄약 케이스",
		"amount": 1,
		"w": 2,
		"h": 2,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": key1_uid, "id": "5.56mm", "amount": 30, "w": 1, "h": 1, "x": 0, "y": 0}
		]
	}
	r_grid.place_item(ammo_case, 2, 0, false)
	var med_case := {
		"uid": InventoryGrid.next_uid(),
		"id": "의약품 케이스",
		"amount": 1,
		"w": 2,
		"h": 2,
		"inner_grid_w": 7,
		"inner_grid_h": 7,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "붕대", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0}
		]
	}
	r_grid.place_item(med_case, 4, 0, false)

	_assert(r_grid.get_all_items_flat(true).size() == 8, "get_all_items_flat(true) returns top-level + nested items (%d)" % r_grid.get_all_items_flat(true).size())
	var f_res := r_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool: return String(it.get("id", "")) == "Scav 인식표")
	_assert(bool(f_res.get("found", false)) and bool(f_res.get("is_nested", false)), "find_item_recursive_by_predicate locates nested dogtag")
	var removed_tag := r_grid.remove_item_by_uid_recursive(tag_uid)
	_assert(String(removed_tag.get("id", "")) == "Scav 인식표" and wallet["inner_items"].size() == 2, "remove_item_by_uid_recursive removes nested item cleanly")

	# 1D Inventory preservation (loot crates / corpses)
	var inv1 := Inventory.new()
	var inv2 := Inventory.new()
	if inv1 is Node: root.add_child(inv1)
	if inv2 is Node: root.add_child(inv2)
	inv1.add_item("인식표 지갑", 1, wallet)
	var slot0_1 = inv1.items[0] if not inv1.items.is_empty() else null
	_assert(slot0_1 is Dictionary and slot0_1.get("inner_items", []).size() == 2 and bool(slot0_1.get("locked", false)), "1D Inventory.add_item preserves inner_items and locked")
	var moved_ok := inv1.move_item(0, 0, inv2)
	var slot0_2 = inv2.items[0] if not inv2.items.is_empty() else null
	_assert(moved_ok and inv1.items[0] == null and slot0_2 is Dictionary and slot0_2.get("inner_items", []).size() == 2, "1D Inventory.move_item deep-copies inner_items across containers")

	# 2) Player + WeaponHandler reload from 탄약 케이스 & quickslot heal from 의약품 케이스 & MainWorld door/radio
	var w_data := _make_test_world_data()
	w_data["player"]["inventory"] = r_grid.items.duplicate(true)
	w_data["player"]["equipment"]["primary1"]["current_magazine_ammo"] = 0
	GameManager.current_world_data = w_data.duplicate(true)

	var player: CharacterBody2D = load("res://scenes/entities/player/player.tscn").instantiate()
	root.add_child(player)
	await get_tree().process_frame
	player.equipment = w_data["player"]["equipment"].duplicate(true)
	player.inventory_grid.load_items(w_data["player"]["inventory"])
	if player.weapon_handler:
		player.weapon_handler.equipment = player.equipment

	player.weapon_handler.switch_weapon_slot("primary1")
	_assert(player.weapon_handler.get_available_ammo_count() == 30, "WeaponHandler counts 30x 5.56mm inside nested 탄약 케이스")
	player.weapon_handler._finish_reload()
	_assert(int(player.weapon_handler.equipped_weapon_data.get("current_magazine_ammo", 0)) == 30 and player.weapon_handler.get_available_ammo_count() == 0, "WeaponHandler._finish_reload loads magazine from 탄약 케이스 and consumes it")

	player.is_bleeding = true
	player._use_quickslot_item("bleed")
	_assert(player.is_channeling, "Player quickslot 'bleed' starts channeling using 붕대 inside 의약품 케이스")
	player._handle_channeling(player.channel_duration + 0.1)
	var bandage_after: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool: return String(it.get("id", "")) == "붕대")
	_assert(not player.is_bleeding and not bool(bandage_after.get("found", false)), "Completing quickslot channel cures bleeding and consumes nested 붕대")

	# MainWorld radio + locked door recursion
	var bag_with_radio := {
		"uid": InventoryGrid.next_uid(),
		"id": "1레벨_가방",
		"amount": 1,
		"w": 3,
		"h": 3,
		"inner_grid_w": 5,
		"inner_grid_h": 4,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "무전기", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0}
		]
	}
	player.inventory_grid.auto_add_item("1레벨_가방", 1, bag_with_radio)

	var mw: Node = load("res://scenes/world/main_world.gd").new()
	mw.player = player
	_assert(mw.player_has_radio(), "MainWorld.player_has_radio finds radio inside nested sub-bag")

	var toggle_state := {"count": 0}
	var toggle_cb := func(_tpos: Vector2i, is_open: bool) -> void:
		if is_open: toggle_state["count"] += 1
	EventBus.door_toggled.connect(toggle_cb)
	mw._on_object_interacted(Vector2.ZERO, Vector2i(10, 10), TileManager.OBJ_DOOR_LOCKED)
	mw._on_object_interacted(Vector2.ZERO, Vector2i(12, 12), TileManager.OBJ_DOOR_LOCKED)
	EventBus.door_toggled.disconnect(toggle_cb)
	_assert(int(toggle_state["count"]) == 2, "MainWorld unlocks OBJ_DOOR_LOCKED twice using keys/keycard inside SECURE 인식표 지갑")
	var armory_after: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool: return String(it.get("id", "")) == "무기고 열쇠")
	var keycard_after: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool: return String(it.get("id", "")) == "보안 키카드")
	_assert(not bool(armory_after.get("found", false)), "1-use 무기고 열쇠 inside wallet is destroyed when uses reach 0")
	_assert(bool(keycard_after.get("found", false)) and int(round(float(keycard_after.get("item", {}).get("durability", 0.0)))) == 2, "보안 키카드 inside wallet decrements durability (3->2)")

	mw.free()
	player.queue_free()

	# 3) CraftingWindow._count_material & HideoutWorkbench nested part discovery/consume
	var bag_mat_grid := InventoryGrid.new()
	bag_mat_grid.grid_width = 6
	bag_mat_grid.grid_height = 5
	root.add_child(bag_mat_grid)
	bag_mat_grid.auto_add_item("1레벨_가방", 1, {
		"uid": InventoryGrid.next_uid(),
		"id": "1레벨_가방",
		"amount": 1,
		"w": 3,
		"h": 3,
		"inner_grid_w": 5,
		"inner_grid_h": 4,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 5, "w": 1, "h": 1, "x": 0, "y": 0}
		]
	})
	var cw: Control = load("res://scenes/ui/crafting_window.gd").new()
	cw.player_inv = bag_mat_grid
	_assert(cw._count_material("고철") == 5, "CraftingWindow._count_material counts materials stored in nested container")
	cw.free()

	var part_case_grid := InventoryGrid.new()
	part_case_grid.grid_width = 6
	part_case_grid.grid_height = 5
	root.add_child(part_case_grid)
	part_case_grid.auto_add_item("무기 부품 상자", 1, {
		"uid": InventoryGrid.next_uid(),
		"id": "무기 부품 상자",
		"amount": 1,
		"w": 2,
		"h": 2,
		"inner_grid_w": 6,
		"inner_grid_h": 6,
		"inner_items": [
			{"uid": InventoryGrid.next_uid(), "id": "수직_포어그립", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0}
		]
	})
	var wb: Control = load("res://scenes/hideout/components/hideout_workbench.gd").new()
	wb.player_grid_mgr = bag_mat_grid
	wb.stash_grid_mgr = part_case_grid
	_assert(int(wb._get_owned_parts_list().get("수직_포어그립", 0)) == 1, "HideoutWorkbench finds parts stored inside 무기 부품 상자")
	_assert(wb._remove_owned_part_from_inv("수직_포어그립") and int(wb._get_owned_parts_list().get("수직_포어그립", 0)) == 0, "HideoutWorkbench removes used part from inside 무기 부품 상자")
	wb.free()

	# 4) GameManager.end_raid returns expired Flea Market listings to hideout stash
	FleaMarket.player_listings.clear()
	_assert(FleaMarket.register_item("그래픽카드", 1, 9999999, true), "Overpriced player listing registers for expiry test")
	FleaMarket.player_listings[-1]["timer"] = 1.0
	GameManager.current_world_data = _make_test_world_data()
	GameManager.current_save_slot = ""
	GameManager.end_raid("survived", [])
	var stash_after_expiry: Array = GameManager.current_world_data.get("hideout", {}).get("stash", [])
	var returned_list: Array = GameManager.last_raid_result.get("sales_report", {}).get("returned_items", [])
	var found_gpu_in_stash := false
	for s_it in stash_after_expiry:
		if String(s_it.get("id", "")) == "그래픽카드":
			found_gpu_in_stash = true
			break
	_assert(found_gpu_in_stash and returned_list.size() == 1, "GameManager.end_raid returns expired Flea Market listings into hideout stash")

	if inv1 is Node: inv1.queue_free()
	if inv2 is Node: inv2.queue_free()
	r_grid.queue_free()
	bag_mat_grid.queue_free()
	part_case_grid.queue_free()
	await get_tree().process_frame

func _test_261118_play_feedback_regressions() -> void:
	print("-- [Test 11] 261118 Play Feedback Regressions (Fonts, Hideout UI, WB Confirm, Map/Inv Live, Painkiller, Silent Switch) --")
	var root := get_tree().get_root()

	# 1. Display / Fonts & Settings UI
	var font_imp := FileAccess.get_file_as_string("res://assets/fonts/Galmuri11.ttf.import")
	_assert(font_imp.contains("oversampling=0.0") and font_imp.contains("antialiasing=1"), "Galmuri11.ttf.import uses dynamic oversampling=0.0 & antialiasing=1")

	var settings_win: Control = load("res://scenes/ui/settings_window.tscn").instantiate()
	_assert(settings_win.process_mode == Node.PROCESS_MODE_ALWAYS, "SettingsWindow has PROCESS_MODE_ALWAYS")
	settings_win.free()

	var main_menu: Control = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	_assert(main_menu.has_node("VBoxContainer/SettingsButton"), "MainMenu exposes SettingsButton")
	main_menu.free()

	# 2. Hideout: SettingsBtn, Paperdoll, Dynamic Grids, Traders Buy/Sell Split & Toggle, Market Guide & Fit Grids
	var hw_data := _make_test_world_data()
	hw_data["player"]["rubles"] = 80000
	hw_data["hideout"]["stash"] = [
		{"uid": InventoryGrid.next_uid(), "id": "금시계", "amount": 1, "w": 1, "h": 1, "x": 0, "y": 0},
		{"uid": InventoryGrid.next_uid(), "id": "고철", "amount": 5, "w": 1, "h": 1, "x": 1, "y": 0},
		{"uid": InventoryGrid.next_uid(), "id": "붕대", "amount": 2, "w": 1, "h": 1, "x": 2, "y": 0}
	]
	GameManager.current_world_data = hw_data.duplicate(true)
	var hideout: Control = load("res://scenes/hideout/hideout.tscn").instantiate()
	root.add_child(hideout)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(hideout.has_node("TopBar/TopToolBar/SettingsBtn"), "Hideout TopToolBar exposes SettingsBtn")
	_assert(is_instance_valid(hideout.character_paperdoll_preview), "Hideout StashTab created Minecraft-style character paperdoll preview")
	hideout.equipment_data["vest"] = {"id": "2레벨_방탄복", "name": "2레벨 방탄복"}
	hideout._update_equipment_ui()
	_assert(String(hideout.character_paperdoll_preview.equipment_data.get("vest", {}).get("id", "")) == "2레벨_방탄복", "Paperdoll preview syncs equipped vest dynamically")

	var wide_probe := Control.new()
	wide_probe.size = Vector2(460.0, 320.0)
	var fitted_cell: float = hideout._compute_fit_cell_size(wide_probe, 6, InventoryUIHelper.CELL_SIZE, 56.0)
	wide_probe.free()
	_assert(fitted_cell > InventoryUIHelper.CELL_SIZE, "Hideout _compute_fit_cell_size scales grid cells larger on wide panels (got %.1f)" % fitted_cell)

	var p_scroll := hideout.player_grid_control.get_parent() as ScrollContainer
	var s_scroll := hideout.stash_grid_control.get_parent() as ScrollContainer
	_assert(p_scroll != null and p_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "StashTab PlayerPanel Scroll disables horizontal scrollbar")
	_assert(s_scroll != null and s_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "StashTab StashPanel Scroll disables horizontal scrollbar")

	_assert(hideout.trader_mode_tabs != null and hideout.trader_mode_tabs.get_tab_count() == 2, "TradersTab splits Buy and Sell into 2 sub-tabs")
	var shop_scroll := hideout.trader_items_vbox.get_parent() as ScrollContainer
	_assert(shop_scroll != null and shop_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "TradersTab Shop scroll disables horizontal scrollbar")

	hideout._auto_select_bulk_sell("valuables")
	var selected_val_cnt: int = hideout.selected_sell_uids.size()
	hideout._auto_select_bulk_sell("valuables")
	_assert(selected_val_cnt > 0 and hideout.selected_sell_uids.is_empty(), "TradersTab '환금템 모두 담기' toggles select and deselect cleanly")

	hideout._auto_select_bulk_sell("non_gear")
	var selected_ng_cnt: int = hideout.selected_sell_uids.size()
	hideout._auto_select_bulk_sell("non_gear")
	_assert(selected_ng_cnt > selected_val_cnt and hideout.selected_sell_uids.is_empty(), "TradersTab '장비/무기 제외 모두 담기' toggles select and deselect cleanly")

	var m_guide: Node = hideout.find_child("MarketGuidePanel", true, false)
	var m_shop_scroll := hideout.market_items_vbox.get_parent() as ScrollContainer
	_assert(m_guide != null, "MarketTab displays MarketGuidePanel consignment instructions")
	_assert(m_shop_scroll != null and m_shop_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "MarketTab listings scroll disables horizontal scrollbar")
	_assert(hideout.market_grids_scroll != null and hideout.market_grids_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "MarketTab register grids scroll disables horizontal scrollbar")

	# 3. Workbench Confirmation Dialogs (Preset Purchase & Weapon/Armor Repairs)
	var wb: Control = hideout.workbench
	GameManager.current_world_data["player"]["rubles"] = 500000
	wb.equipment_data["vest"] = {"id": "1레벨_방탄복", "name": "1레벨 방탄복", "durability": 20.0, "max_durability": 40.0}
	wb.wb_selected_weapon = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	wb.wb_selected_weapon["durability"] = 40.0
	wb.wb_selected_weapon["max_durability"] = 100.0
	wb._apply_workbench_preset(wb.WEAPON_PRESETS["M4_리시버"][0])
	var rubles_before_preset: int = int(GameManager.current_world_data["player"]["rubles"])
	wb._buy_and_assemble_preset()
	_assert(is_instance_valid(wb.active_confirm_dialog) and int(GameManager.current_world_data["player"]["rubles"]) == rubles_before_preset, "Workbench preset buy waits for confirmation dialog before charging RUB")
	var preset_cbtn := wb.active_confirm_dialog.find_child("ConfirmBtn", true, false) as Button
	preset_cbtn.pressed.emit()
	_assert(not is_instance_valid(wb.active_confirm_dialog) and int(GameManager.current_world_data["player"]["rubles"]) < rubles_before_preset, "Confirming preset dialog deducts missing parts RUB")

	var rubles_before_w_rep: int = int(GameManager.current_world_data["player"]["rubles"])
	wb._repair_selected_weapon(false)
	_assert(is_instance_valid(wb.active_confirm_dialog) and int(GameManager.current_world_data["player"]["rubles"]) == rubles_before_w_rep, "Workbench weapon repair waits for confirmation dialog")
	var w_cbtn := wb.active_confirm_dialog.find_child("ConfirmBtn", true, false) as Button
	w_cbtn.pressed.emit()
	_assert(int(GameManager.current_world_data["player"]["rubles"]) < rubles_before_w_rep and absf(float(wb.wb_selected_weapon.get("durability", 0.0)) - 100.0) < 0.01, "Confirming weapon repair deducts RUB and restores durability")

	var rubles_before_a_rep: int = int(GameManager.current_world_data["player"]["rubles"])
	wb._repair_equipped_armor("vest", false)
	_assert(is_instance_valid(wb.active_confirm_dialog) and int(GameManager.current_world_data["player"]["rubles"]) == rubles_before_a_rep, "Workbench armor repair waits for confirmation dialog")
	var a_cbtn := wb.active_confirm_dialog.find_child("ConfirmBtn", true, false) as Button
	a_cbtn.pressed.emit()
	_assert(int(GameManager.current_world_data["player"]["rubles"]) < rubles_before_a_rep and absf(float(wb.equipment_data["vest"].get("durability", 0.0)) - 40.0) < 0.01, "Confirming armor repair deducts RUB and restores armor durability")

	hideout.queue_free()
	await get_tree().process_frame

	# 4. MapWindow Pin Panning, Recenter & MainWorld Live Time + Player Painkiller & Silent Switch
	var mw_ui: Control = load("res://scenes/ui/map_window.tscn").instantiate()
	root.add_child(mw_ui)
	await get_tree().process_frame
	_assert(mw_ui.process_mode == Node.PROCESS_MODE_ALWAYS, "MapWindow uses PROCESS_MODE_ALWAYS")
	mw_ui.setup(Vector2(1000.0, 500.0), 0.0, [], "주거지")
	var base_pin: Vector2 = mw_ui.get_player_screen_pos()
	mw_ui.map_pan_offset = Vector2(90.0, -35.0)
	var panned_pin: Vector2 = mw_ui.get_player_screen_pos()
	_assert(panned_pin.distance_to(base_pin + Vector2(90.0, -35.0)) < 0.01, "MapWindow player pin follows map_pan_offset")
	mw_ui.recenter_on_player()
	_assert(mw_ui.get_player_screen_pos().distance_to(base_pin) < 0.01, "MapWindow recenter_on_player snaps pin back to center")
	mw_ui.queue_free()
	await get_tree().process_frame

	GameManager.current_world_data = _make_test_world_data()
	get_tree().paused = false
	var world: Node2D = load("res://scenes/world/main_world.tscn").instantiate()
	root.add_child(world)
	await get_tree().process_frame

	world._open_map_window()
	await get_tree().process_frame
	_assert(not get_tree().paused and world.player.ui_input_blocked, "MainWorld keeps game unpaused and blocks player input while MapWindow is open")
	world.current_map_window._on_close_pressed()
	await get_tree().process_frame
	_assert(not world.player.ui_input_blocked, "Closing MapWindow re-enables player input")

	world._open_inventory_window()
	await get_tree().process_frame
	_assert(not get_tree().paused and world.player.ui_input_blocked, "MainWorld keeps game unpaused and blocks player input while InventoryWindow is open")
	world.current_inventory_window._on_close_pressed()
	await get_tree().process_frame
	_assert(not world.player.ui_input_blocked, "Closing InventoryWindow re-enables player input")

	# 5. Painkiller 60s Damage Reduction Buff
	var p_node: CharacterBody2D = world.player
	p_node.equipment["helmet"] = {}
	p_node.equipment["vest"] = {}
	p_node.survival_stats.base_armor_defense = 0.0
	var pk_item: Dictionary = {"uid": InventoryGrid.next_uid(), "id": "진통제", "amount": 1, "w": 1, "h": 1}
	p_node.inventory_grid.auto_add_item("진통제", 1, pk_item)
	p_node.use_consumable_item(pk_item)
	p_node.complete_channeling()
	_assert(p_node.painkiller_timer >= 59.0 and absf(p_node.painkiller_damage_reduction - 0.25) < 0.001, "Using 진통제 applies 60s 25%% damage reduction buff")
	p_node.hp = 100.0
	p_node.survival_stats.take_damage(40.0, "test")
	_assert(absf(p_node.hp - 70.0) < 0.05, "Painkiller buff reduces 40.0 incoming damage to 30.0 (hp=70.0)")
	p_node.painkiller_timer = 0.05
	p_node.survival_stats._process(0.1)
	_assert(p_node.painkiller_timer == 0.0 and p_node.painkiller_damage_reduction == 0.0, "Painkiller buff expires when timer reaches 0")
	p_node.hp = 100.0
	p_node.survival_stats.take_damage(40.0, "test")
	_assert(absf(p_node.hp - 60.0) < 0.05, "Without Painkiller buff 40.0 damage deals full 40.0 (hp=60.0)")

	# 6. Weapon Switch Does Not Emit Event Log
	var switch_logs: Array[String] = []
	var switch_cb := func(msg: String): switch_logs.append(msg)
	EventBus.event_logged.connect(switch_cb)
	p_node.weapon_handler.switch_weapon_slot("primary1")
	p_node.weapon_handler.switch_weapon_slot("primary2")
	p_node.weapon_handler.switch_weapon_slot("sidearm")
	p_node.weapon_handler.switch_weapon_slot("throwable")
	if EventBus.event_logged.is_connected(switch_cb):
		EventBus.event_logged.disconnect(switch_cb)
	_assert(switch_logs.is_empty(), "Switching weapon slots emits 0 EventBus.event_logged notifications")

	world.queue_free()
	await get_tree().process_frame
