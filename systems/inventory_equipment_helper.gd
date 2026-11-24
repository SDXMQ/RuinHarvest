# res://systems/inventory_equipment_helper.gd
extends RefCounted

## 인벤토리 창(inventory_window.gd)의 수리, 컨텍스트 메뉴, 장비/무기/부착물 슬롯 및 빠른 사용 액션 헬퍼

static func get_player_rubles() -> int:
	if GameManager and GameManager.current_world_data:
		var p_data: Variant = GameManager.current_world_data.get("player", {})
		if p_data is Dictionary and p_data.has("rubles"):
			return int(p_data["rubles"])
		if GameManager.current_world_data.has("rubles"):
			return int(GameManager.current_world_data["rubles"])
	return 0

static func deduct_player_rubles(cost: int) -> bool:
	if GameManager and GameManager.current_world_data:
		var p_data: Variant = GameManager.current_world_data.get("player", {})
		if p_data is Dictionary and p_data.has("rubles"):
			var cur: int = int(p_data["rubles"])
			if cur >= cost:
				p_data["rubles"] = cur - cost
				return true
		elif GameManager.current_world_data.has("rubles"):
			var cur: int = int(GameManager.current_world_data["rubles"])
			if cur >= cost:
				GameManager.current_world_data["rubles"] = cur - cost
				return true
	return false

static func perform_item_repair(win: Control, item: Dictionary, slot_ref: String = "") -> bool:
	if item.is_empty():
		return false
	var id: String = str(item.get("id", ""))
	var idata: Dictionary = ItemDatabase.get_item_data(id)
	var item_name: String = str(idata.get("name", id))
	var max_dur: float = float(item.get("max_durability", idata.get("max_durability", 0.0)))
	var cur_dur: float = float(item.get("durability", max_dur))
	var missing_dur: float = max_dur - cur_dur
	if max_dur <= 0.0 or missing_dur <= 0.5:
		return false

	var is_field_repair: bool = (GameManager != null and GameManager.current_state == GameManager.GameState.IN_GAME)
	var cost_mult: float = HideoutWorkbench.FIELD_REPAIR_RATE_RUBLES if is_field_repair else HideoutWorkbench.QUICK_REPAIR_RATE_RUBLES
	var repair_cost: int = int(ceil(missing_dur * cost_mult))
	if not deduct_player_rubles(repair_cost):
		return false

	if is_field_repair:
		var new_max_dur: float = max(10.0, round(max_dur * 0.9))
		item["max_durability"] = new_max_dur
		item["durability"] = new_max_dur
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:tools] [%s] 야전 응급 수리 완료! (-%d RUB, 최대 내구도 %.0f → %.0f)" % [item_name, repair_cost, max_dur, new_max_dur])
	else:
		item["max_durability"] = max_dur
		item["durability"] = max_dur
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:wrench_blue] [%s] 은신처 정밀 수리 완료! (-%d RUB, 내구도 %.0f/%.0f)" % [item_name, repair_cost, max_dur, max_dur])

	if win.inventory_grid:
		win.inventory_grid.grid_changed.emit()
	if slot_ref != "":
		sync_weapon_to_player(win, slot_ref)
	update_weapons_ui(win)
	update_equipment_ui(win)
	if SoundManager: SoundManager.play("craft_complete")
	return true

static func show_context_menu(win: Control, item: Dictionary, source_type: String = "grid", slot_ref: String = "", source_grid: InventoryGrid = null) -> void:
	win._close_context_menu()
	var id: String = str(item.get("id", ""))
	var idata: Dictionary = ItemDatabase.get_item_data(id)
	var item_name: String = str(idata.get("name", id))

	var shell: Dictionary = InventoryUIHelper.create_context_menu_shell(item_name, "ContextMenuPanel", Color(0.9, 0.85, 0.4))
	win.context_menu_panel = shell["panel"] as PanelContainer
	var vbox: VBoxContainer = shell["vbox"] as VBoxContainer

	if InventoryGrid.is_container_item(item) and (source_type == "grid" or (source_type == "equipment" and slot_ref == "vest")):
		var open_txt: String = "포켓 열기" if source_type == "equipment" else "컨테이너 열기"
		win._add_context_menu_btn(vbox, open_txt, func():
			win._close_context_menu()
			win.open_container_popup(item, source_grid if source_type == "grid" else null)
		, false, "folder")

	if source_type in ["grid", "popup_grid"]:
		var lock_grid: InventoryGrid = source_grid if source_grid else win.inventory_grid
		var is_locked: bool = bool(item.get("locked", false))
		win._add_context_menu_btn(vbox, "잠금 해제 (L)" if is_locked else "아이템 잠금 (L)", func():
			win._close_context_menu()
			if lock_grid:
				var now_locked: bool = lock_grid.toggle_item_lock(str(item.get("uid", "")))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit(("[icon:lock] [%s] 잠금됨" if now_locked else "[icon:unlock] [%s] 잠금 해제") % item_name)
				if SoundManager: SoundManager.play("menu_select")
		, false, "unlock" if is_locked else "lock")

	if source_type == "grid":
		win._add_context_menu_btn(vbox, "사용 / 장착", func():
			win._close_context_menu()
			handle_item_quick_action(win, item, true)
		, false, "power")

		var amt: int = int(item.get("amount", 1))
		if amt > 1:
			win._add_context_menu_btn(vbox, "수량 분할", func():
				win._close_context_menu()
				win._open_split_dialog(item, func(split_amt):
					var split_item: Dictionary = InventoryUIHelper.prepare_split_drag_item(item, int(split_amt), win.inventory_grid)
					win._start_drag("split", split_item, Vector2i(int(item.get("x", 0)), int(item.get("y", 0))), "", null, win.inventory_grid)
					win.drag_data["is_split"] = true
					win.drag_data["split_source_item"] = item
					win.drag_data["split_source_grid"] = win.inventory_grid
					win.drag_data["split_amount"] = split_amt
				)
			, false, "split")
	elif source_type == "popup_grid" and source_grid:
		win._add_context_menu_btn(vbox, "메인 가방으로 꺼내기", func():
			win._close_context_menu()
			var popup_ref: ContainerPopupWindow = win.open_container_popups.get(source_grid.owner_container_uid, null) as ContainerPopupWindow
			if popup_ref:
				win._handle_popup_quick_action(popup_ref, item, true)
		, false, "export_out")
	elif source_type in ["equipment", "weapon_slot"] and slot_ref != "":
		win._add_context_menu_btn(vbox, "가방으로 장착 해제", func():
			win._close_context_menu()
			var rem: int = win.inventory_grid.auto_add_item(id, int(item.get("amount", 1)), item) if win.inventory_grid else 1
			if rem <= 0:
				win.equipment_data[slot_ref] = {}
				if source_type == "equipment":
					apply_backpack_grid_size(win)
					update_equipment_ui(win)
				else:
					sync_weapon_to_player(win, slot_ref)
					update_weapons_ui(win)
				if SoundManager: SoundManager.play("menu_select")
		, false, "export_out")

	var has_parts: bool = false
	var parts_dict: Dictionary = item.get("parts", item.get("attachments", {}))
	for pk in parts_dict.keys():
		var pv: Variant = parts_dict[pk]
		if pv is Array and not pv.is_empty():
			has_parts = true
			break
		elif pv != null and String(pv) != "":
			has_parts = true
			break

	if has_parts:
		win._add_context_menu_btn(vbox, "부품 모두 분리", func():
			win._close_context_menu()
			detach_all_item_parts(win, item)
			if source_type == "weapon_slot" and slot_ref != "":
				sync_weapon_to_player(win, slot_ref)
				update_weapons_ui(win)
		, false, "bolt")

	var cur_mag_ammo: int = int(item.get("current_magazine_ammo", 0))
	var loaded_ammo_type: String = str(item.get("loaded_ammo", ""))
	if cur_mag_ammo > 0 and loaded_ammo_type != "":
		win._add_context_menu_btn(vbox, "탄약 비우기 (%d발)" % cur_mag_ammo, func():
			win._close_context_menu()
			var rem: int = win.inventory_grid.auto_add_item(loaded_ammo_type, cur_mag_ammo) if win.inventory_grid else cur_mag_ammo
			if rem > 0:
				win._handle_overflow_item({"id": loaded_ammo_type, "amount": rem})
			item["current_magazine_ammo"] = 0
			if win.inventory_grid:
				win.inventory_grid.grid_changed.emit()
			if source_type == "weapon_slot" and slot_ref != "":
				sync_weapon_to_player(win, slot_ref)
				update_weapons_ui(win)
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:refresh] [%s] 탄약 %d발을 회수했습니다." % [item_name, cur_mag_ammo - rem])
		, false, "refresh")

	var max_dur: float = float(item.get("max_durability", idata.get("max_durability", 0.0)))
	var cur_dur: float = float(item.get("durability", max_dur))
	var missing_dur: float = max_dur - cur_dur
	if max_dur > 0 and missing_dur > 0.5:
		var is_field_repair: bool = (GameManager != null and GameManager.current_state == GameManager.GameState.IN_GAME)
		var repair_cost: int = int(ceil(missing_dur * (15.0 if is_field_repair else 10.0)))
		var repair_txt: String = ("야전 응급 수리 (%d RUB | 최대 -10%%)" if is_field_repair else "수리하기 (%d RUB)") % repair_cost
		var user_funds: int = get_player_rubles()
		if user_funds < repair_cost:
			repair_txt += " (잔액 부족)"
		win._add_context_menu_btn(vbox, repair_txt, func():
			win._close_context_menu()
			perform_item_repair(win, item, slot_ref)
		, user_funds < repair_cost, "tools" if is_field_repair else "wrench_blue")

	var is_item_locked: bool = bool(item.get("locked", false))
	var drop_disabled: bool = is_item_locked or (win.player == null)
	var drop_lbl: String = "은신처 버리기 불가" if win.player == null else ("잠금됨 (버리기 불가)" if is_item_locked else "바닥에 버리기")
	var drop_icon: String = "lock" if (win.player == null or is_item_locked) else "trash"
	win._add_context_menu_btn(vbox, drop_lbl, func():
		win._close_context_menu()
		if win.player == null:
			return
		if bool(item.get("locked", false)):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:lock] 잠금된 아이템은 바닥에 버릴 수 없습니다.")
			return
		if source_type == "grid" and win.inventory_grid:
			win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
		elif source_type == "popup_grid" and source_grid:
			source_grid.remove_item_by_uid(str(item.get("uid", "")))
		elif source_type == "equipment" and slot_ref != "":
			win.equipment_data[slot_ref] = {}
			apply_backpack_grid_size(win)
			update_equipment_ui(win)
		elif source_type == "weapon_slot" and slot_ref != "":
			win.equipment_data[slot_ref] = {}
			sync_weapon_to_player(win, slot_ref)
			update_weapons_ui(win)
		win._drop_item_to_world(item)
	, drop_disabled, drop_icon)

	win.add_child(win.context_menu_panel)
	var mpos: Vector2 = win.get_global_mouse_position() - win.global_position
	win.context_menu_panel.position = InventoryUIHelper.clamp_popup_position(win.context_menu_panel, mpos, win.size, 8.0)

static func detach_all_item_parts(win: Control, item: Dictionary) -> void:
	var parts_dict: Dictionary = item.get("parts", item.get("attachments", {}))
	var detached_count: int = 0
	var dropped_count: int = 0
	for pk in parts_dict.keys():
		var pv: Variant = parts_dict[pk]
		if pv is Array:
			for sub_p in pv:
				var p_id: String = String(sub_p)
				if p_id != "":
					var rem: int = win.inventory_grid.auto_add_item(p_id, 1) if win.inventory_grid else 1
					if rem > 0:
						win._handle_overflow_item({"id": p_id, "amount": rem})
						dropped_count += rem
					else:
						detached_count += 1
		elif pv != null and String(pv) != "":
			var p_id: String = String(pv)
			var rem: int = win.inventory_grid.auto_add_item(p_id, 1) if win.inventory_grid else 1
			if rem > 0:
				win._handle_overflow_item({"id": p_id, "amount": rem})
				dropped_count += rem
			else:
				detached_count += 1
	item["parts"] = {}
	item["attachments"] = {}
	var computed: Dictionary = WeaponPartsDatabase.compute_weapon_from_dict(item)
	item.clear()
	for k in computed:
		item[k] = computed[k]
	clamp_weapon_excess_ammo(win, item)
	if win.inventory_grid:
		win.inventory_grid.grid_changed.emit()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		if dropped_count > 0:
			EventBus.event_logged.emit("[icon:bolt] 총기 부품 %d개를 가방에 넣고, 공간이 부족한 %d개는 바닥에 드랍했습니다." % [detached_count, dropped_count])
		else:
			EventBus.event_logged.emit("[icon:bolt] 총기 부품 %d개를 모두 분리했습니다." % detached_count)

static func clamp_weapon_excess_ammo(win: Control, w_dict: Dictionary) -> void:
	if w_dict.is_empty():
		return
	var max_mag: int = int(w_dict.get("computed_stats", {}).get("magazine_size", 10))
	var cur_mag: int = int(w_dict.get("current_magazine_ammo", 0))
	if cur_mag > max_mag:
		var excess: int = cur_mag - max_mag
		var l_ammo: String = str(w_dict.get("loaded_ammo", ""))
		if excess > 0 and l_ammo != "":
			var rem: int = win.inventory_grid.auto_add_item(l_ammo, excess) if win.inventory_grid else excess
			if rem > 0:
				win._handle_overflow_item({"id": l_ammo, "amount": rem})
		w_dict["current_magazine_ammo"] = max_mag

static func connect_equipment_slot(win: Control, btn: Button, slot_name: String) -> void:
	btn.mouse_entered.connect(func():
		if not win.is_dragging and win.tooltip:
			var equipped: Dictionary = win.equipment_data.get(slot_name, {})
			if not equipped.is_empty():
				var idata: Dictionary = ItemDatabase.get_item_data(str(equipped.get("id", "")))
				win.tooltip.display_item(equipped, idata)
				win.tooltip.update_position(win.get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if win.tooltip: win.tooltip.hide()
	)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if win.is_dragging:
					win._try_equip_dragged_item(slot_name)
				else:
					var equipped: Dictionary = win.equipment_data.get(slot_name, {})
					if event.double_click and slot_name == "vest" and not equipped.is_empty():
						if win.tooltip: win.tooltip.hide()
						win.open_container_popup(equipped, null)
					elif not equipped.is_empty():
						win._start_drag("equipment", equipped, Vector2i.ZERO, slot_name)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var equipped: Dictionary = win.equipment_data.get(slot_name, {})
				if not equipped.is_empty():
					if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
						if win.tooltip: win.tooltip.hide()
						win._show_context_menu(equipped, "equipment", slot_name)
					else:
						var rem: int = win.inventory_grid.auto_add_item(str(equipped.get("id", "")), int(equipped.get("amount", 1)), equipped)
						if rem <= 0:
							win.equipment_data[slot_name] = {}
							apply_backpack_grid_size(win)
							update_equipment_ui(win)
							if SoundManager: SoundManager.play("menu_select")
	)

static func try_equip_dragged_item(win: Control, slot_name: String) -> void:
	var item: Dictionary = win.drag_data.get("item", {})
	var item_id: String = str(item.get("id", ""))

	if not InventoryUIHelper.is_slot_compatible(item_id, slot_name):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] [%s] 슬롯에 장착할 수 없는 아이템입니다." % slot_name)
		win._end_drag()
		return

	if slot_name == "backpack":
		var inner_arr: Variant = item.get("inner_items", [])
		if inner_arr is Array and not inner_arr.is_empty():
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
			if SoundManager: SoundManager.play("hit_melee")
			win._end_drag()
			return

	var src: String = str(win.drag_data.get("source", ""))
	var orig_slot: String = str(win.drag_data.get("slot_name", ""))

	if src == "equipment" and orig_slot == slot_name:
		win._end_drag()
		return

	if src == "grid":
		win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "split":
		win.drag_data["is_split"] = false
	elif src == "popup_grid":
		var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
		if p_grid: p_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "vicinity":
		var ground_node: Variant = win.drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx: int = int(win.drag_data.get("origin_index", -1))
		if orig_idx != -1 and win.target_inventory:
			win.target_inventory.remove_item_at(orig_idx, int(item.get("amount", 1)))
			win._update_container_list()
	elif src == "equipment":
		win.equipment_data[orig_slot] = {}
	elif src == "corpse_equip":
		win._consume_corpse_equip_drag_source()

	var prev_equipped: Dictionary = win.equipment_data.get(slot_name, {})
	win.equipment_data[slot_name] = item

	apply_backpack_grid_size(win)
	if not prev_equipped.is_empty():
		var rem: int = win.inventory_grid.auto_add_item(str(prev_equipped.get("id", "")), int(prev_equipped.get("amount", 1)), prev_equipped)
		if rem > 0:
			var overflow_eq: Dictionary = prev_equipped.duplicate(true)
			overflow_eq["amount"] = rem
			win._handle_overflow_item(overflow_eq)

	update_equipment_ui(win)
	if SoundManager: SoundManager.play("menu_select")
	win._end_drag()

static func apply_backpack_grid_size(win: Control) -> void:
	var bp: Dictionary = win.equipment_data.get("backpack", {})
	var new_w: int = 6
	var new_h: int = 3

	if not bp.is_empty():
		var id: String = str(bp.get("id", ""))
		var d: Dictionary = ItemDatabase.get_item_data(id)
		var b_grid: Vector2i = d.get("backpack_grid", Vector2i(6, 5))
		new_w = b_grid.x
		new_h = b_grid.y

	if win.inventory_grid:
		var dropped: Array = win.inventory_grid.resize_grid(new_w, new_h)
		for it in dropped:
			win._handle_overflow_item(it)
	win._update_grid_ui_size()

static func update_equipment_ui(win: Control) -> void:
	InventoryUIHelper.render_equip_slot_button(win.helmet_slot, "helmet", "HEAD\n헬멧", win.equipment_data)
	InventoryUIHelper.render_equip_slot_button(win.vest_slot, "vest", "RIG\n방탄복", win.equipment_data)
	InventoryUIHelper.render_equip_slot_button(win.backpack_slot, "backpack", "PACK\n배낭", win.equipment_data)
	InventoryUIHelper.render_equip_slot_button(win.bottom_slot, "bottom", "BOOTS\n전술화", win.equipment_data)

	rebuild_drop_targets(win, true)

	if win.player:
		win.player.set("equipment", win.equipment_data)
		if win.player.has_signal("stats_changed"):
			win.player.stats_changed.emit()

static func rebuild_drop_targets(win: Control, preserve_non_equip: bool = false) -> void:
	win._clear_slot_highlights()
	var preserved: Array[Dictionary] = []
	if preserve_non_equip:
		for t in win.drop_targets:
			if str(t.get("type", "")) != "equipment" and is_instance_valid(t.get("control")):
				preserved.append(t)
	win.drop_targets.clear()
	win.drop_targets.append({"control": win.helmet_slot, "type": "equipment", "slot_name": "helmet"})
	win.drop_targets.append({"control": win.vest_slot, "type": "equipment", "slot_name": "vest"})
	win.drop_targets.append({"control": win.backpack_slot, "type": "equipment", "slot_name": "backpack"})
	win.drop_targets.append({"control": win.bottom_slot, "type": "equipment", "slot_name": "bottom"})
	for p_t in preserved:
		win.drop_targets.append(p_t)

static func sync_weapon_to_player(win: Control, slot_key: String = "") -> void:
	if win.player:
		win.player.set("equipment", win.equipment_data)
		if "weapon_handler" in win.player and win.player.weapon_handler:
			win.player.weapon_handler.equipment = win.equipment_data
			if slot_key == "" or win.player.weapon_handler.active_weapon_slot == slot_key:
				win.player.weapon_handler.switch_weapon_slot(win.player.weapon_handler.active_weapon_slot)
		if "player_visuals" in win.player and win.player.player_visuals:
			win.player.player_visuals.queue_redraw()

static func update_weapons_ui(win: Control) -> void:
	if not win.weapons_vbox:
		return
	if win.tooltip and win.tooltip.visible and not win.is_dragging and win.weapons_vbox.get_global_rect().has_point(win.get_global_mouse_position()):
		win.tooltip.hide()
	for c in win.weapons_vbox.get_children():
		c.queue_free()

	rebuild_drop_targets(win, false)
	create_weapon_card(win, "주무기 1", "primary1", win.equipment_data.get("primary1", {}))
	create_weapon_card(win, "주무기 2", "primary2", win.equipment_data.get("primary2", {}))
	create_weapon_card(win, "보조 무기", "sidearm", win.equipment_data.get("sidearm", {}))
	create_weapon_card(win, "투척 무기", "throwable", win.equipment_data.get("throwable", {}))

static func remove_attachment_from_weapon_slot(win: Control, w_slot: String, a_slot: String, r_idx: int, part_id: String = "") -> void:
	if not win.equipment_data.has(w_slot):
		return
	var w_dict: Dictionary = win.equipment_data[w_slot]
	if w_dict.is_empty():
		return
	var w_parts: Dictionary = w_dict.get("parts", w_dict.get("attachments", {}))
	if w_parts.has(a_slot):
		var p_val: Variant = w_parts[a_slot]
		if p_val is Array:
			if r_idx >= 0 and r_idx < p_val.size():
				p_val.remove_at(r_idx)
			elif part_id != "":
				p_val.erase(part_id)
			if p_val.is_empty():
				w_parts.erase(a_slot)
		else:
			w_parts.erase(a_slot)
	w_dict["parts"] = w_parts
	w_dict["attachments"] = w_parts
	win.equipment_data[w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
	clamp_weapon_excess_ammo(win, win.equipment_data[w_slot])
	sync_weapon_to_player(win, w_slot)

static func create_weapon_card(win: Control, title: String, slot_key: String, weapon_dict: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_active_hand: bool = (win.player != null and "active_weapon_slot" in win.player and String(win.player.active_weapon_slot) == slot_key)
	var w_world_data: Dictionary = GameManager.current_world_data if (GameManager and GameManager.current_world_data is Dictionary) else {}
	var is_gold_master: bool = false
	if not weapon_dict.is_empty():
		var m_bonus: Dictionary = HideoutProgression.get_weapon_mastery_bonus(w_world_data, str(weapon_dict.get("id", "")))
		is_gold_master = bool(m_bonus.get("gold_border", false))

	if PixelAssetManager:
		var card_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("weapon_card_gold" if is_gold_master else "weapon_card", 8.0, 6.0, 8.0, 6.0, 4)
		if card_sb != null:
			panel.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "[%s · 장착중]" % title if is_active_hand else "[%s]" % title
	if PixelAssetManager:
		title_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55) if is_active_hand else Color(1, 0.8, 0.3))
	top_hbox.add_child(title_lbl)
	if is_active_hand and UiIconManager:
		UiIconManager.set_label_icon(title_lbl, "star", "", 13, 4)

	if not weapon_dict.is_empty() and ItemIconManager:
		var icon_frame := PanelContainer.new()
		if PixelAssetManager:
			var ic_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("icon_frame_gold" if is_gold_master else "icon_frame", 2.0, 2.0, 2.0, 2.0, 3)
			if ic_sb != null:
				icon_frame.add_theme_stylebox_override("panel", ic_sb)
		var wep_icon := TextureRect.new()
		wep_icon.name = "EquippedWeaponIcon"
		wep_icon.custom_minimum_size = Vector2(30, 30)
		wep_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wep_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wep_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wep_icon.texture = ItemIconManager.get_icon(str(weapon_dict.get("id", "")))
		icon_frame.add_child(wep_icon)
		top_hbox.add_child(icon_frame)

	var wep_btn := Button.new()
	wep_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wep_btn.custom_minimum_size = Vector2(0, 34)
	wep_btn.focus_mode = Control.FOCUS_NONE
	wep_btn.clip_text = true

	var is_throwable: bool = false
	if weapon_dict.is_empty():
		wep_btn.text = "장착된 무기 없음 (드래그하여 장착)"
	else:
		var w_id: String = str(weapon_dict.get("id", ""))
		var d: Dictionary = ItemDatabase.get_item_data(w_id)
		var w_name: String = str(weapon_dict.get("name", ""))
		if w_name == "" or w_name == w_id:
			var d_name: String = str(d.get("name", w_id))
			if d_name == w_id and WeaponPartsDatabase.RECEIVERS.has(w_id):
				d_name = str(WeaponPartsDatabase.RECEIVERS[w_id].get("name", w_id))
			w_name = d_name
		is_throwable = slot_key == "throwable" or str(weapon_dict.get("type", "")) == "throwable" or str(d.get("type", "")) == "throwable"
		var is_melee: bool = str(d.get("type", "")) == "melee" or w_id in ["나이프", "파이프", "도끼", "야구방망이"]
		if is_throwable:
			wep_btn.text = "%s (x%d개)" % [w_name, int(weapon_dict.get("amount", 1))]
		elif is_melee:
			wep_btn.text = "%s [근접]" % w_name
		else:
			var stats: Dictionary = weapon_dict.get("computed_stats", {})
			var max_mag: int = int(stats.get("magazine_size", weapon_dict.get("magazine_size", 10)))
			var cur_mag: int = int(weapon_dict.get("current_magazine_ammo", 0))
			var l_ammo: String = str(weapon_dict.get("loaded_ammo", ""))
			var ammo_name: String = "9mm 탄약" if l_ammo in ["9mm", "탄약"] else (l_ammo.replace("_", " ") if l_ammo != "" else "없음")
			var info_str: String = ""
			if max_mag > 0 or l_ammo != "":
				info_str = " [%s | %d/%d발]" % [ammo_name, cur_mag, max_mag]
			wep_btn.text = "%s%s" % [w_name, info_str]
	top_hbox.add_child(wep_btn)

	if not weapon_dict.is_empty() and not is_throwable:
		var d: Dictionary = ItemDatabase.get_item_data(str(weapon_dict.get("id", "")))
		var max_dur: float = float(weapon_dict.get("max_durability", d.get("max_durability", 100.0)))
		var cur_dur: float = float(weapon_dict.get("durability", max_dur))
		if max_dur > 0:
			var dur_bar := ProgressBar.new()
			dur_bar.custom_minimum_size = Vector2(0, 4)
			dur_bar.show_percentage = false
			dur_bar.max_value = max_dur
			dur_bar.value = cur_dur
			var ratio: float = cur_dur / max_dur
			var dur_col := Color(0.2, 0.85, 0.3) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
			InventoryUIHelper.apply_dynamic_tint(dur_bar, "fill", dur_col)
			vbox.add_child(dur_bar)

	wep_btn.mouse_entered.connect(func():
		if not win.is_dragging and win.tooltip and not weapon_dict.is_empty():
			var d: Dictionary = ItemDatabase.get_item_data(str(weapon_dict.get("id", "")))
			win.tooltip.display_item(weapon_dict, d)
			win.tooltip.update_position(win.get_global_mouse_position())
	)
	wep_btn.mouse_exited.connect(func():
		if win.tooltip: win.tooltip.hide()
	)

	win.drop_targets.append({"control": wep_btn, "type": "weapon", "slot_key": slot_key})

	wep_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if win.is_dragging:
					win._try_equip_weapon(slot_key)
				elif not weapon_dict.is_empty():
					if win.tooltip: win.tooltip.hide()
					win._start_drag("weapon_slot", weapon_dict, Vector2i.ZERO, slot_key)
			elif event.button_index == MOUSE_BUTTON_RIGHT and not weapon_dict.is_empty():
				if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
					if win.tooltip: win.tooltip.hide()
					win._show_context_menu(weapon_dict, "weapon_slot", slot_key)
				else:
					var rem: int = win.inventory_grid.auto_add_item(str(weapon_dict.get("id", "")), int(weapon_dict.get("amount", 1)), weapon_dict)
					if rem <= 0:
						win.equipment_data[slot_key] = {}
						sync_weapon_to_player(win, slot_key)
						update_weapons_ui(win)
						if win.tooltip: win.tooltip.hide()
						if SoundManager: SoundManager.play("menu_select")
	)

	if not weapon_dict.is_empty() and (slot_key.begins_with("primary") or slot_key == "sidearm"):
		var raw_id: String = str(weapon_dict.get("receiver", weapon_dict.get("id", "")))
		var rec_id: String = WeaponPartsDatabase.resolve_receiver_id(raw_id)
		var receiver_data: Dictionary = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
		var allowed_slots: Dictionary = receiver_data.get("slots", {})

		var attach_flow := HFlowContainer.new()
		attach_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attach_flow.add_theme_constant_override("h_separation", 4)
		attach_flow.add_theme_constant_override("v_separation", 4)
		vbox.add_child(attach_flow)

		var attach_dict: Dictionary = weapon_dict.get("parts", weapon_dict.get("attachments", {}))
		for a_type in ["barrel", "optic", "muzzle", "grip", "magazine", "stock", "rail"]:
			if not allowed_slots.is_empty() and not allowed_slots.has(a_type):
				continue
			var cur_p: Variant = attach_dict.get(a_type, "")
			if a_type == "rail":
				var rail_slots_count: int = int(allowed_slots.get("rail", 1))
				var cur_rail_arr: Array = cur_p if (cur_p is Array) else ([String(cur_p)] if String(cur_p) != "" else [])
				for r_i in range(rail_slots_count):
					var r_part_id: String = str(cur_rail_arr[r_i]) if r_i < cur_rail_arr.size() else ""
					create_attachment_sub_slot(win, attach_flow, slot_key, "rail", r_part_id, r_i)
			else:
				var cur_p_str: String = String(cur_p[0]) if (cur_p is Array and not cur_p.is_empty()) else String(cur_p)
				create_attachment_sub_slot(win, attach_flow, slot_key, a_type, cur_p_str, -1)

	win.weapons_vbox.add_child(panel)

static func create_attachment_sub_slot(win: Control, parent: Container, weapon_slot_key: String, attach_type: String, current_part_id: String, rail_index: int = -1) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"SmallButton"
	btn.custom_minimum_size = Vector2(78, 28)
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE

	var slot_labels: Dictionary = {
		"barrel": "총열", "optic": "조준경", "muzzle": "총구", "grip": "손잡이", "magazine": "탄창", "stock": "개머리판", "rail": "레일"
	}

	if current_part_id == "":
		if attach_type == "rail" and rail_index >= 0:
			btn.text = "레일%d" % (rail_index + 1)
		else:
			btn.text = str(slot_labels.get(attach_type, attach_type))
		btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		if PixelAssetManager:
			btn.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
		btn.add_theme_font_size_override("font_size", 10)
	else:
		var p_data: Dictionary = WeaponPartsDatabase.PARTS.get(current_part_id, {})
		btn.text = str(p_data.get("name", current_part_id))
		btn.tooltip_text = btn.text
		btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		if PixelAssetManager:
			btn.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
		btn.add_theme_font_size_override("font_size", 10)

	win.drop_targets.append({"control": btn, "type": "attachment", "weapon_slot_key": weapon_slot_key, "attach_type": attach_type, "rail_index": rail_index})

	btn.mouse_entered.connect(func():
		if not win.is_dragging and win.tooltip and current_part_id != "":
			var p_data: Dictionary = WeaponPartsDatabase.PARTS.get(current_part_id, {})
			var fake_item: Dictionary = {"id": current_part_id, "name": p_data.get("name", current_part_id)}
			win.tooltip.display_item(fake_item, p_data)
			win.tooltip.update_position(win.get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if win.tooltip: win.tooltip.hide()
	)

	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if win.is_dragging:
					try_equip_attachment(win, weapon_slot_key, attach_type, rail_index)
				elif current_part_id != "":
					if win.tooltip: win.tooltip.hide()
					var part_dict: Dictionary = {
						"id": current_part_id,
						"part_slot": attach_type,
						"attach_slot": attach_type,
						"rail_index": rail_index,
						"weapon_slot": weapon_slot_key,
						"amount": 1
					}
					win._start_drag("attachment", part_dict)
					win.drag_data["weapon_slot"] = weapon_slot_key
					win.drag_data["attach_slot"] = attach_type
					win.drag_data["part_slot"] = attach_type
					win.drag_data["rail_index"] = rail_index
			elif event.button_index == MOUSE_BUTTON_RIGHT and current_part_id != "":
				var rem: int = win.inventory_grid.auto_add_item(current_part_id, 1)
				if rem <= 0:
					remove_attachment_from_weapon_slot(win, weapon_slot_key, attach_type, rail_index, current_part_id)
					update_weapons_ui(win)
					if SoundManager: SoundManager.play("menu_select")
	)

	parent.add_child(btn)

static func try_equip_weapon(win: Control, slot_key: String) -> void:
	var item: Dictionary = win.drag_data.get("item", {})
	var it_id: String = String(item.get("id", ""))
	var it_data: Dictionary = ItemDatabase.get_item_data(it_id)
	var it_type: String = String(it_data.get("type", ""))

	if it_type == "ammo" or ItemDatabase.is_ammo_item(it_id) or WeaponPartsDatabase.AMMO_TYPES.has(it_id):
		var target_w: Dictionary = win.equipment_data.get(slot_key, {})
		if target_w.is_empty():
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 탄약을 장전할 무기가 슬롯에 없습니다.")
			win._end_drag()
			return
		if slot_key == "throwable" or not WeaponHandler.is_firearm_dict(target_w):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 총기가 아닌 장비(근접무기/도구)에는 탄약을 장전할 수 없습니다.")
			win._end_drag()
			return

		var raw_rec: String = str(target_w.get("receiver", target_w.get("id", "")))
		var rec_id: String = WeaponPartsDatabase.resolve_receiver_id(raw_rec)
		var rec_data: Dictionary = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
		var allowed_ammos: Array = rec_data.get("ammo_types", target_w.get("computed_stats", {}).get("ammo_types", []))
		if allowed_ammos.is_empty() and rec_data.has("default_ammo"):
			allowed_ammos = [rec_data["default_ammo"]]

		if not (it_id in allowed_ammos or (it_id == "9mm" and "탄약" in allowed_ammos) or (it_id == "탄약" and "9mm" in allowed_ammos)):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] [%s] 탄약은 [%s]에 호환되지 않습니다." % [it_data.get("name", it_id), target_w.get("name", rec_id)])
			win._end_drag()
			return

		var stats: Dictionary = target_w.get("computed_stats", {})
		var max_mag: int = int(stats.get("magazine_size", 15))
		var old_ammo: String = str(target_w.get("loaded_ammo", ""))
		if old_ammo == "":
			old_ammo = str(rec_data.get("default_ammo", it_id))
		var old_count: int = int(target_w.get("current_magazine_ammo", 0))
		var drag_amt: int = maxi(1, int(item.get("amount", 1)))

		var load_amt: int = 0
		var final_mag_ammo: int = 0
		var is_same_ammo: bool = (old_count > 0 and old_ammo == it_id)

		if is_same_ammo:
			var needed: int = maxi(0, max_mag - old_count)
			if needed <= 0:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("[icon:warn] 이미 탄창이 가득 차 있습니다. (%d/%d발)" % [old_count, max_mag])
				win._end_drag()
				return
			load_amt = mini(drag_amt, needed)
			final_mag_ammo = old_count + load_amt
		else:
			if old_count > 0 and old_ammo != "":
				var rem: int = win.inventory_grid.auto_add_item(old_ammo, old_count) if win.inventory_grid else old_count
				if rem > 0:
					win._handle_overflow_item({"id": old_ammo, "amount": rem})
			load_amt = mini(drag_amt, max_mag)
			final_mag_ammo = load_amt

		var ammo_src: String = str(win.drag_data.get("source", ""))
		if drag_amt <= load_amt:
			if ammo_src == "grid" and win.inventory_grid:
				win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
			elif ammo_src == "popup_grid":
				var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
				if p_grid:
					p_grid.remove_item_by_uid(str(item.get("uid", "")))
			elif ammo_src == "split":
				win.drag_data["is_split"] = false
			elif ammo_src == "vicinity":
				var ground_node: Variant = win.drag_data.get("ground_ref")
				if is_instance_valid(ground_node): ground_node.queue_free()
				win._update_vicinity_list(true)
			elif ammo_src == "container":
				var orig_idx: int = int(win.drag_data.get("origin_index", -1))
				if orig_idx != -1 and win.target_inventory:
					win.target_inventory.remove_item_at(orig_idx, drag_amt)
					win._update_container_list()
		else:
			item["amount"] = drag_amt - load_amt
			if ammo_src == "grid" and win.inventory_grid:
				var orig_it: Dictionary = win.inventory_grid.get_item_by_uid(str(item.get("uid", "")))
				if not orig_it.is_empty(): orig_it["amount"] = item["amount"]
				win.inventory_grid.grid_changed.emit()
			elif ammo_src == "popup_grid":
				var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
				if p_grid:
					var orig_pit: Dictionary = p_grid.get_item_by_uid(str(item.get("uid", "")))
					if not orig_pit.is_empty(): orig_pit["amount"] = item["amount"]
					p_grid.grid_changed.emit()
			elif ammo_src == "split":
				var orig_sp: Variant = win.drag_data.get("split_source_item", {})
				if orig_sp is Dictionary and not orig_sp.is_empty():
					orig_sp["amount"] = int(orig_sp.get("amount", 0)) + int(item["amount"])
				win.drag_data["is_split"] = false
				var sp_grid: InventoryGrid = win.drag_data.get("split_source_grid", win.inventory_grid) as InventoryGrid
				if sp_grid:
					sp_grid.grid_changed.emit()
			elif ammo_src == "vicinity":
				var ground_node: Variant = win.drag_data.get("ground_ref")
				if is_instance_valid(ground_node):
					ground_node.amount = item["amount"]
					ground_node.update_visuals()
				win._update_vicinity_list(true)
			elif ammo_src == "container":
				var orig_idx: int = int(win.drag_data.get("origin_index", -1))
				if orig_idx != -1 and win.target_inventory:
					win.target_inventory.remove_item_at(orig_idx, load_amt)
					win._update_container_list()

		target_w["loaded_ammo"] = it_id
		target_w["current_magazine_ammo"] = final_mag_ammo
		target_w = WeaponPartsDatabase.compute_weapon_from_dict(target_w)
		win.equipment_data[slot_key] = target_w
		sync_weapon_to_player(win, slot_key)
		update_weapons_ui(win)
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			if is_same_ammo:
				EventBus.event_logged.emit("[icon:refresh] [%s] 탄약 추가 장전 완료! (%d/%d발)" % [it_data.get("name", it_id), final_mag_ammo, max_mag])
			else:
				EventBus.event_logged.emit("[icon:refresh] [%s] 탄약으로 교체 장전 완료! (%d/%d발)" % [it_data.get("name", it_id), final_mag_ammo, max_mag])
		win._end_drag()
		return

	var eq_slot: String = ItemDatabase.get_item_equip_slot(str(item.get("id", "")))
	var valid: bool = false
	if it_type == "ammo" or ItemDatabase.is_ammo_item(it_id):
		valid = false
	elif slot_key.begins_with("primary") and (eq_slot == "primary" or it_type == "receiver"): valid = true
	elif slot_key == "sidearm" and (eq_slot == "sidearm" or eq_slot == "melee"): valid = true
	elif slot_key == "throwable" and eq_slot == "throwable": valid = true

	if not valid:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 해당 무기 슬롯에 호환되지 않는 아이템입니다.")
		win._end_drag()
		return

	var src: String = str(win.drag_data.get("source", ""))
	var orig_slot: String = str(win.drag_data.get("slot_name", ""))

	if (src == "weapon_slot" or src == "equipment") and orig_slot == slot_key:
		win._end_drag()
		return

	if src == "grid": win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "split": win.drag_data["is_split"] = false
	elif src == "popup_grid":
		var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
		if p_grid: p_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "vicinity":
		var ground_node: Variant = win.drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx: int = int(win.drag_data.get("origin_index", -1))
		if orig_idx != -1 and win.target_inventory:
			win.target_inventory.remove_item_at(orig_idx, int(item.get("amount", 1)))
			win._update_container_list()
	elif src == "weapon_slot" or src == "equipment":
		win.equipment_data[orig_slot] = {}
	elif src == "corpse_equip":
		win._consume_corpse_equip_drag_source()

	var prev: Dictionary = win.equipment_data.get(slot_key, {})
	if not item.has("parts"):
		item["parts"] = item.get("attachments", {}).duplicate(true)
	item["attachments"] = item["parts"]
	item = WeaponPartsDatabase.compute_weapon_from_dict(item)
	win.equipment_data[slot_key] = item

	if not prev.is_empty():
		var rem: int = win.inventory_grid.auto_add_item(str(prev.get("id", "")), int(prev.get("amount", 1)), prev) if win.inventory_grid else int(prev.get("amount", 1))
		if rem > 0:
			var overflow_w: Dictionary = prev.duplicate(true)
			overflow_w["amount"] = rem
			win._handle_overflow_item(overflow_w)

	sync_weapon_to_player(win, slot_key)
	update_weapons_ui(win)
	if SoundManager: SoundManager.play("menu_select")
	win._end_drag()

static func try_equip_attachment(win: Control, weapon_slot_key: String, attach_type: String, rail_index: int = -1) -> void:
	var item: Dictionary = win.drag_data.get("item", {})
	var part_id: String = str(item.get("id", ""))

	if not WeaponPartsDatabase.PARTS.has(part_id):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 부착물 부품이 아닙니다.")
		win._end_drag()
		return

	var part_data: Dictionary = WeaponPartsDatabase.PARTS[part_id]
	if str(part_data.get("slot", "")) != attach_type:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 부착 슬롯이 일치하지 않습니다 (%s != %s)" % [part_data.get("slot", ""), attach_type])
		win._end_drag()
		return

	var w: Dictionary = win.equipment_data.get(weapon_slot_key, {})
	if w.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 무기가 장착되어 있지 않습니다.")
		win._end_drag()
		return

	var raw_id: String = str(w.get("receiver", w.get("id", "")))
	var rec_id: String = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	var receiver_data: Dictionary = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	if not receiver_data.is_empty():
		var allowed_slots: Dictionary = receiver_data.get("slots", {})
		if not allowed_slots.has(attach_type):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 해당 무기에는 이 부품을 장착할 슬롯이 없습니다.")
			win._end_drag()
			return
		var comp_cats: Array = part_data.get("compatible_categories", ["all"])
		var rec_cat: String = str(receiver_data.get("category", ""))
		if not ("all" in comp_cats or rec_cat in comp_cats):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 해당 무기 카테고리와 호환되지 않는 부품입니다.")
			win._end_drag()
			return

	var src: String = str(win.drag_data.get("source", ""))
	if src == "grid":
		win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "split":
		win.drag_data["is_split"] = false
	elif src == "popup_grid":
		var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
		if p_grid: p_grid.remove_item_by_uid(str(item.get("uid", "")))
	elif src == "vicinity":
		var ground_node: Variant = win.drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx: int = int(win.drag_data.get("origin_index", -1))
		if orig_idx != -1 and win.target_inventory:
			win.target_inventory.remove_item_at(orig_idx, 1)
			win._update_container_list()
	elif src == "corpse_equip":
		win._consume_corpse_equip_drag_source()
	elif src == "attachment":
		var old_w_slot: String = str(win.drag_data.get("weapon_slot", item.get("weapon_slot", "")))
		var old_a_slot: String = str(win.drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", ""))))
		var old_rail_idx: int = int(win.drag_data.get("rail_index", item.get("rail_index", -1)))
		if win.equipment_data.has(old_w_slot):
			var old_parts: Dictionary = win.equipment_data[old_w_slot].get("parts", {})
			if old_a_slot == "rail" and old_parts.get("rail") is Array:
				if old_rail_idx >= 0 and old_rail_idx < old_parts["rail"].size():
					old_parts["rail"].remove_at(old_rail_idx)
				else:
					old_parts["rail"].erase(part_id)
				if old_parts["rail"].is_empty():
					old_parts.erase("rail")
			else:
				old_parts.erase(old_a_slot)
			win.equipment_data[old_w_slot]["parts"] = old_parts
			win.equipment_data[old_w_slot]["attachments"] = old_parts
			win.equipment_data[old_w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(win.equipment_data[old_w_slot])
			clamp_weapon_excess_ammo(win, win.equipment_data[old_w_slot])
			sync_weapon_to_player(win, old_w_slot)

	if not win.equipment_data[weapon_slot_key].has("parts"):
		win.equipment_data[weapon_slot_key]["parts"] = win.equipment_data[weapon_slot_key].get("attachments", {}).duplicate(true)

	var prev_part: String = ""
	if attach_type == "rail":
		var raw_rails: Variant = win.equipment_data[weapon_slot_key]["parts"].get("rail", [])
		var cur_rails: Array = raw_rails if (raw_rails is Array) else ([str(raw_rails)] if str(raw_rails) != "" else [])
		if rail_index >= 0 and rail_index < cur_rails.size():
			prev_part = str(cur_rails[rail_index])
			cur_rails[rail_index] = part_id
		elif rail_index >= 0:
			cur_rails.append(part_id)
		else:
			var max_r: int = int(receiver_data.get("slots", {}).get("rail", 1))
			if cur_rails.size() < max_r:
				cur_rails.append(part_id)
			else:
				prev_part = str(cur_rails[0])
				cur_rails[0] = part_id
		win.equipment_data[weapon_slot_key]["parts"]["rail"] = cur_rails
	else:
		prev_part = str(win.equipment_data[weapon_slot_key]["parts"].get(attach_type, ""))
		win.equipment_data[weapon_slot_key]["parts"][attach_type] = part_id

	win.equipment_data[weapon_slot_key]["attachments"] = win.equipment_data[weapon_slot_key]["parts"]
	win.equipment_data[weapon_slot_key] = WeaponPartsDatabase.compute_weapon_from_dict(win.equipment_data[weapon_slot_key])
	clamp_weapon_excess_ammo(win, win.equipment_data[weapon_slot_key])
	sync_weapon_to_player(win, weapon_slot_key)

	if prev_part != "":
		var rem: int = win.inventory_grid.auto_add_item(prev_part, 1) if win.inventory_grid else 1
		if rem > 0:
			win._handle_overflow_item({"id": prev_part, "amount": rem})

	update_weapons_ui(win)
	if SoundManager: SoundManager.play("menu_select")
	win._end_drag()

static func _can_weapon_accept_part(w: Dictionary, part_data: Dictionary, attach_type: String) -> bool:
	if w.is_empty():
		return false
	var raw_id: String = str(w.get("receiver", w.get("id", "")))
	var rec_id: String = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	var receiver_data: Dictionary = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	if receiver_data.is_empty():
		return false
	var allowed_slots: Dictionary = receiver_data.get("slots", {})
	if not allowed_slots.has(attach_type):
		return false
	var comp_cats: Array = part_data.get("compatible_categories", ["all"])
	var rec_cat: String = str(receiver_data.get("category", ""))
	return "all" in comp_cats or rec_cat in comp_cats

static func handle_item_quick_action(win: Control, item: Dictionary, ignore_container: bool = false, allow_popup_transfer: bool = false) -> void:
	if win.target_inventory != null and not ignore_container:
		win._quick_transfer_grid_to_container(item)
		return

	if allow_popup_transfer and not ignore_container and InventoryUIHelper.try_quick_transfer_to_open_popup(win, win.open_container_popups, item, win.inventory_grid):
		return

	var id: String = str(item.get("id", ""))
	var idata: Dictionary = ItemDatabase.get_item_data(id)
	var cat: int = int(idata.get("category", -1))
	var equip_slot: String = ItemDatabase.get_item_equip_slot(id)

	if id in ["장거리 무전기", "군용 무전기", "무전기"] or id.contains("무전기") or String(idata.get("name", "")).contains("무전기"):
		var mw: Node = win._find_main_world_node()
		win._on_close_pressed()
		if mw and mw.has_method("open_radio_window"):
			mw.open_radio_window()
		return

	if cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or cat == ItemDatabase.ItemCategory.MEDICAL:
		use_consumable_item(win, item, idata)
		return

	if cat == ItemDatabase.ItemCategory.EQUIPMENT or (equip_slot in ["helmet", "vest", "backpack", "bottom"]):
		var slot: String = equip_slot
		if slot != "":
			if slot == "backpack":
				var inner_arr: Variant = item.get("inner_items", [])
				if inner_arr is Array and not inner_arr.is_empty():
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("[icon:warn] 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
					if SoundManager: SoundManager.play("hit_melee")
					return
			var prev_equipped: Dictionary = win.equipment_data.get(slot, {})
			win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
			win.equipment_data[slot] = item
			apply_backpack_grid_size(win)
			if not prev_equipped.is_empty():
				var rem: int = win.inventory_grid.auto_add_item(str(prev_equipped.get("id", "")), int(prev_equipped.get("amount", 1)), prev_equipped) if win.inventory_grid else int(prev_equipped.get("amount", 1))
				if rem > 0:
					var overflow_eq: Dictionary = prev_equipped.duplicate(true)
					overflow_eq["amount"] = rem
					win._handle_overflow_item(overflow_eq)
			update_equipment_ui(win)
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				if not prev_equipped.is_empty():
					EventBus.event_logged.emit("[icon:refresh] [%s] 장비 교체 완료!" % idata.get("name", id))
				else:
					EventBus.event_logged.emit("[icon:helmet] [%s] 장착 완료!" % idata.get("name", id))
			return

	var is_ammo_item: bool = (str(idata.get("type", "")) == "ammo" or ItemDatabase.is_ammo_item(id))
	if not is_ammo_item and (str(idata.get("type", "")) == "receiver" or equip_slot in ["primary", "sidearm", "throwable", "melee"]):
		var target_slot: String = "primary1"
		if equip_slot == "throwable":
			target_slot = "throwable"
		elif equip_slot == "sidearm" or equip_slot == "melee":
			target_slot = "sidearm"
		else:
			if win.equipment_data.get("primary1", {}).is_empty():
				target_slot = "primary1"
			elif win.equipment_data.get("primary2", {}).is_empty():
				target_slot = "primary2"
			else:
				var active_slot: String = "primary1"
				if win.player and "weapon_handler" in win.player and win.player.weapon_handler:
					active_slot = str(win.player.weapon_handler.active_weapon_slot)
				target_slot = active_slot if active_slot in ["primary1", "primary2"] else "primary1"

		var prev_weapon: Dictionary = win.equipment_data.get(target_slot, {})
		win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
		if not item.has("parts"):
			item["parts"] = item.get("attachments", {}).duplicate(true)
		item["attachments"] = item["parts"]
		item = WeaponPartsDatabase.compute_weapon_from_dict(item)
		win.equipment_data[target_slot] = item
		if not prev_weapon.is_empty():
			var rem: int = win.inventory_grid.auto_add_item(str(prev_weapon.get("id", "")), int(prev_weapon.get("amount", 1)), prev_weapon) if win.inventory_grid else int(prev_weapon.get("amount", 1))
			if rem > 0:
				var overflow_w: Dictionary = prev_weapon.duplicate(true)
				overflow_w["amount"] = rem
				win._handle_overflow_item(overflow_w)
		sync_weapon_to_player(win, target_slot)
		update_weapons_ui(win)
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			if not prev_weapon.is_empty():
				EventBus.event_logged.emit("[icon:refresh] [%s] 무기 교체 완료!" % idata.get("name", id))
			else:
				EventBus.event_logged.emit("[icon:gun] [%s] 무기 장착 완료!" % idata.get("name", id))
		return

	if WeaponPartsDatabase.PARTS.has(id):
		var part_data: Dictionary = WeaponPartsDatabase.PARTS[id]
		var attach_type: String = str(part_data.get("slot", ""))
		var candidate_slots: Array[String] = ["primary1", "primary2", "sidearm"]
		var best_slot: String = ""

		for s in candidate_slots:
			var w: Dictionary = win.equipment_data.get(s, {})
			if _can_weapon_accept_part(w, part_data, attach_type):
				var w_parts_chk: Dictionary = w.get("parts", w.get("attachments", {}))
				var cur_val: Variant = w_parts_chk.get(attach_type, null)
				var is_empty_slot: bool = (cur_val == null or (cur_val is String and cur_val == "") or (cur_val is Array and cur_val.is_empty()))
				if is_empty_slot:
					best_slot = s
					break

		if best_slot == "":
			for s in candidate_slots:
				var w: Dictionary = win.equipment_data.get(s, {})
				if _can_weapon_accept_part(w, part_data, attach_type):
					best_slot = s
					break

		if best_slot != "":
			if not win.equipment_data[best_slot].has("parts"):
				win.equipment_data[best_slot]["parts"] = win.equipment_data[best_slot].get("attachments", {}).duplicate(true)
			var w_parts: Dictionary = win.equipment_data[best_slot]["parts"]
			var prev_part: String = ""
			win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
			if attach_type == "rail":
				var raw_rails: Variant = w_parts.get("rail", [])
				var cur_rails: Array = raw_rails if (raw_rails is Array) else ([str(raw_rails)] if str(raw_rails) != "" else [])
				var raw_id: String = str(win.equipment_data[best_slot].get("receiver", win.equipment_data[best_slot].get("id", "")))
				var rec_id: String = WeaponPartsDatabase.resolve_receiver_id(raw_id)
				var receiver_data: Dictionary = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
				var max_rails: int = int(receiver_data.get("slots", {}).get("rail", 1))
				if cur_rails.size() < max_rails:
					cur_rails.append(id)
				else:
					prev_part = str(cur_rails[0])
					cur_rails[0] = id
				w_parts["rail"] = cur_rails
			else:
				prev_part = str(w_parts.get(attach_type, ""))
				w_parts[attach_type] = id

			win.equipment_data[best_slot]["parts"] = w_parts
			win.equipment_data[best_slot]["attachments"] = w_parts
			win.equipment_data[best_slot] = WeaponPartsDatabase.compute_weapon_from_dict(win.equipment_data[best_slot])
			clamp_weapon_excess_ammo(win, win.equipment_data[best_slot])
			sync_weapon_to_player(win, best_slot)

			if prev_part != "":
				var rem: int = win.inventory_grid.auto_add_item(prev_part, 1) if win.inventory_grid else 1
				if rem > 0:
					win._handle_overflow_item({"id": prev_part, "amount": rem})
			update_weapons_ui(win)
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:wrench_blue] [%s] 부착 완료!" % idata.get("name", id))
			return
		else:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 장착 가능한 무기가 없습니다.")
			return

static func use_consumable_item(win: Control, item: Dictionary, idata: Dictionary) -> void:
	if not win.player:
		return

	if win.player.has_method("use_consumable_item"):
		win.player.use_consumable_item(item, idata)
		win._on_close_pressed()
		return

	var item_name: String = str(idata.get("name", item.get("id", "")))
	var effects: Dictionary = idata.get("effects", {})
	if effects.has("hp"): win.player.hp = min(win.player.max_hp, win.player.hp + float(effects["hp"]))
	if effects.has("hunger"): win.player.hunger = min(win.player.max_hunger, win.player.hunger + float(effects["hunger"]))
	if effects.has("thirst"): win.player.thirst = min(win.player.max_thirst, win.player.thirst + float(effects["thirst"]))
	if effects.has("stamina"): win.player.stamina = min(win.player.max_stamina, win.player.stamina + float(effects["stamina"]))
	if effects.get("cures_bleeding", false): win.player.is_bleeding = false
	if effects.get("cures_fracture", false): win.player.is_fractured = false
	if effects.get("cures_infection", false) or int(effects.get("infection", 0)) < 0: win.player.is_infected = false
	if effects.has("damage_reduction_duration") or str(item.get("id", "")) == "진통제":
		if win.player.has_method("apply_painkiller_buff"):
			win.player.apply_painkiller_buff(float(effects.get("damage_reduction_duration", 60.0)), float(effects.get("damage_reduction", 0.25)))

	win.player.stats_changed.emit()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:stars] %s을(를) 사용했습니다." % item_name)

	var amt: int = int(item.get("amount", 1))
	if amt > 1:
		item["amount"] = amt - 1
		win.inventory_grid.grid_changed.emit()
	else:
		win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
