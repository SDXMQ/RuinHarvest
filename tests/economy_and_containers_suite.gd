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
