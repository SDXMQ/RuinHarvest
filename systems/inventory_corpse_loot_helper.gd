# res://systems/inventory_corpse_loot_helper.gd
extends RefCounted

## 인벤토리 창(inventory_window.gd)의 시체 장비, 수색 컨테이너(Container), 주변(Vicinity) 및 월드 드롭/오버플로우 헬퍼

const SANITIZED_PROP_KEYS: Array[String] = [
	"parts", "attachments", "loaded_ammo", "current_magazine_ammo",
	"computed_stats", "durability", "max_durability", "receiver",
	"name", "type", "inner_items", "inner_grid_w", "inner_grid_h",
	"locked", "unsearched"
]

static func _build_item_dict_with_props(item_id: String, amount: int, raw_cd: Dictionary, include_grid_size: bool) -> Dictionary:
	var clean_cd: Dictionary = InventoryGrid.sanitize_custom_data(raw_cd)
	var item_dict: Dictionary = {
		"id": item_id,
		"amount": amount,
		"custom_data": clean_cd.duplicate(true)
	}
	if include_grid_size:
		var base_size: Vector2i = ItemDatabase.get_item_grid_size(item_id)
		item_dict["w"] = base_size.x
		item_dict["h"] = base_size.y
	for k in SANITIZED_PROP_KEYS:
		if clean_cd.has(k):
			item_dict[k] = clean_cd[k]
	return item_dict

static func get_corpse_equipment(win: Control) -> Dictionary:
	if win.target_inventory and bool(win.target_inventory.get_meta("is_corpse", false)):
		var ceq: Variant = win.target_inventory.get_meta("corpse_equipment", {})
		if ceq is Dictionary:
			return ceq
	return {}

static func is_corpse_equipment_popup(win: Control, popup: ContainerPopupWindow) -> bool:
	if not popup:
		return false
	var p_uid: String = str(popup.container_item.get("uid", ""))
	if p_uid == "":
		return false
	var corpse_eq: Dictionary = get_corpse_equipment(win)
	for slot_key in corpse_eq.keys():
		var slot_it: Variant = corpse_eq[slot_key]
		if slot_it is Dictionary and not slot_it.is_empty() and str(slot_it.get("uid", "")) == p_uid:
			return true
	return false

static func has_corpse_equipment_items(corpse_eq: Dictionary) -> bool:
	for k in corpse_eq.keys():
		var eq_it: Variant = corpse_eq[k]
		if eq_it is Dictionary and not eq_it.is_empty() and str(eq_it.get("id", "")) != "":
			return true
	return false

static func consume_corpse_equip_drag_source(win: Control) -> void:
	var slot_name: String = str(win.drag_data.get("slot_name", ""))
	var corpse_eq: Dictionary = get_corpse_equipment(win)
	if slot_name != "" and corpse_eq.has(slot_name):
		var prev_it: Variant = corpse_eq[slot_name]
		if prev_it is Dictionary:
			win._close_popup_by_uid(str(prev_it.get("uid", "")))
		corpse_eq[slot_name] = {}
		if win.target_inventory:
			win.target_inventory.inventory_changed.emit()
	update_container_list(win)

static func update_corpse_equipment_ui(win: Control) -> void:
	if not is_instance_valid(win.corpse_equip_section):
		return
	for c in win.corpse_equip_section.get_children():
		c.queue_free()
	var corpse_eq: Dictionary = get_corpse_equipment(win)
	if corpse_eq.is_empty():
		win.corpse_equip_section.visible = false
		return
	win.corpse_equip_section.visible = true

	var hdr := Label.new()
	hdr.text = "시체 착용 장비"
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.95, 0.78, 0.36, 0.95))
	win.corpse_equip_section.add_child(hdr)

	var slot_defs: Array = [["primary1", "주무기"], ["helmet", "헬멧"], ["vest", "방탄복"], ["backpack", "가방"]]
	for pair in slot_defs:
		var slot_key: String = str(pair[0])
		var slot_label: String = str(pair[1])
		var slot_item: Variant = corpse_eq.get(slot_key, {})

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		win.corpse_equip_section.add_child(row)

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(0, 34)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_text = true
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.add_theme_font_size_override("font_size", 11)
		row.add_child(slot_btn)

		if not (slot_item is Dictionary) or slot_item.is_empty() or str(slot_item.get("id", "")) == "":
			slot_btn.text = "[%s] (비어 있음)" % slot_label
			slot_btn.disabled = true
			slot_btn.modulate = Color(0.58, 0.60, 0.64, 0.68)
			continue

		if str(slot_item.get("uid", "")) == "":
			slot_item["uid"] = InventoryGrid.next_uid()
		var item_id: String = str(slot_item.get("id", ""))
		var idata: Dictionary = ItemDatabase.get_item_data(item_id)
		var disp_name: String = str(slot_item.get("name", idata.get("name", item_id)))
		slot_btn.text = "[%s] %s" % [slot_label, disp_name]
		if ItemIconManager:
			slot_btn.icon = ItemIconManager.get_icon(item_id)
			slot_btn.expand_icon = true

		slot_btn.mouse_entered.connect(func():
			if not win.is_dragging and win.tooltip:
				win.tooltip.display_item(slot_item, idata)
				win.tooltip.update_position(win.get_global_mouse_position())
		)
		slot_btn.mouse_exited.connect(func():
			if win.tooltip: win.tooltip.hide()
		)
		slot_btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL)):
					if not win.inventory_grid:
						return
					var amt: int = maxi(1, int(slot_item.get("amount", 1)))
					var rem: int = win.inventory_grid.auto_add_item(item_id, amt, slot_item)
					if rem <= 0:
						win._close_popup_by_uid(str(slot_item.get("uid", "")))
						corpse_eq[slot_key] = {}
						if win.target_inventory:
							win.target_inventory.inventory_changed.emit()
						if SoundManager: SoundManager.play("menu_select")
						update_container_list(win)
					elif EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("[icon:warn] 가방 공간이 부족합니다.")
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if event.double_click and InventoryGrid.is_container_item(slot_item):
						win.open_container_popup(slot_item, null)
						return
					var drag_it: Dictionary = (slot_item as Dictionary).duplicate(true)
					var bsize: Vector2i = ItemDatabase.get_item_grid_size(item_id)
					if not drag_it.has("w"): drag_it["w"] = bsize.x
					if not drag_it.has("h"): drag_it["h"] = bsize.y
					win._start_drag("corpse_equip", drag_it, Vector2i.ZERO, slot_key)
		)

		if slot_key == "backpack" or (slot_key == "vest" and InventoryGrid.is_container_item(slot_item)):
			var inner_raw: Variant = slot_item.get("inner_items", [])
			var inner_arr: Array = inner_raw if inner_raw is Array else []
			var unsearched_cnt: int = 0
			for in_it in inner_arr:
				if in_it is Dictionary and ContainerPopupWindow.is_item_unsearched(in_it):
					unsearched_cnt += 1
			var open_btn := Button.new()
			open_btn.focus_mode = Control.FOCUS_NONE
			open_btn.custom_minimum_size = Vector2(78, 34)
			open_btn.add_theme_font_size_override("font_size", 11)
			if unsearched_cnt > 0:
				open_btn.text = "탐색 (%d)" % unsearched_cnt
				open_btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
			else:
				open_btn.text = "열기 (%d)" % inner_arr.size()
			open_btn.pressed.connect(func():
				win.open_container_popup(slot_item, null)
			)
			row.add_child(open_btn)

	var sep := HSeparator.new()
	win.corpse_equip_section.add_child(sep)

static func update_container_list(win: Control) -> void:
	if not is_instance_valid(win.container_section):
		return

	if not win.target_inventory:
		win.container_section.visible = false
		update_corpse_equipment_ui(win)
		if not win.open_container_popups.is_empty():
			win._prune_and_rebind_popups()
		return

	win.container_section.visible = true
	win.container_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win.container_title_label.clip_text = true
	if UiIconManager:
		var parsed: Dictionary = UiIconManager.parse_tagged_message(win.target_title)
		var clean_t: String = String(parsed.get("clean_text", ""))
		var title_txt: String = "CONTAINER // " + (clean_t if clean_t != "" else "수색 대상")
		var icon_k: String = String(parsed.get("icon_key", ""))
		UiIconManager.set_label_icon(win.container_title_label, icon_k if icon_k != "" else "box", title_txt, 14, 5, true)
	else:
		win.container_title_label.text = "CONTAINER // " + (win.target_title if win.target_title != "" else "수색 대상")

	update_corpse_equipment_ui(win)

	if win.tooltip and win.tooltip.visible and not win.is_dragging and win.container_list.get_global_rect().has_point(win.get_global_mouse_position()):
		win.tooltip.hide()

	for c in win.container_list.get_children():
		if c != win.container_empty_label:
			c.queue_free()

	var has_items: bool = false
	for i in range(win.target_inventory.items.size()):
		var slot_item: Variant = win.target_inventory.items[i]
		if slot_item != null and not slot_item.is_empty() and str(slot_item.get("id", "")) != "":
			has_items = true
			create_container_entry(win, slot_item, i)

	var corpse_has_gear: bool = has_corpse_equipment_items(get_corpse_equipment(win))
	win.container_empty_label.visible = (not has_items) and (not corpse_has_gear)

static func create_container_entry(win: Control, slot_item: Dictionary, index: int) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(32, 32)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c_item_id: String = str(slot_item.get("id", ""))
	if ItemIconManager:
		icon.texture = ItemIconManager.get_icon(c_item_id)
	icon_wrap.add_child(icon)

	var is_wish: bool = HideoutProgression.is_wishlist_item(c_item_id)
	if is_wish and UiIconManager:
		var w_badge: TextureRect = UiIconManager.create_icon_rect("star", 12)
		w_badge.position = Vector2(20.0, 0.0)
		icon_wrap.add_child(w_badge)

	var lbl := Label.new()
	var d: Dictionary = ItemDatabase.get_item_data(c_item_id)
	var amt: int = int(slot_item.get("amount", 1))
	lbl.text = "%s %s" % [d.get("name", c_item_id), ("(x%d)" % amt if amt > 1 else "")]
	if is_wish:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	btn.mouse_entered.connect(func():
		if not win.is_dragging and win.tooltip:
			win.tooltip.display_item(slot_item, d)
			win.tooltip.update_position(win.get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if win.tooltip: win.tooltip.hide()
	)

	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL)):
				var rem: int = win.inventory_grid.auto_add_item(c_item_id, amt, slot_item)
				var added: int = amt - rem
				if added > 0:
					win.target_inventory.remove_item_at(index, added)
					if SoundManager: SoundManager.play("menu_select")
					update_container_list(win)
				if rem > 0 and EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("[icon:warn] 가방 공간이 부족합니다.")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.double_click and InventoryGrid.is_container_item(slot_item):
					win.open_container_popup(slot_item, null)
					return
				var item_dict: Dictionary = _build_item_dict_with_props(c_item_id, amt, slot_item, true)
				win._start_drag("container", item_dict, Vector2i(index, 0))
				win.drag_data["origin_index"] = index
	)

	win.container_list.add_child(btn)

static func loot_all_from_container(win: Control) -> void:
	if not win.target_inventory or not win.inventory_grid:
		return
	var moved_any: bool = false
	var full_warn: bool = false
	var unsearched_blocked: bool = false
	for i in range(win.target_inventory.items.size() - 1, -1, -1):
		var slot_item: Variant = win.target_inventory.items[i]
		if slot_item != null and not slot_item.is_empty() and str(slot_item.get("id", "")) != "":
			var amt: int = int(slot_item.get("amount", 1))
			var rem: int = win.inventory_grid.auto_add_item(str(slot_item.get("id", "")), amt, slot_item)
			var added: int = amt - rem
			if added > 0:
				win.target_inventory.remove_item_at(i, added)
				moved_any = true
			if rem > 0:
				full_warn = true

	var corpse_eq: Dictionary = get_corpse_equipment(win)
	if not corpse_eq.is_empty():
		var corpse_changed: bool = false
		for slot_key in ["primary1", "helmet", "vest"]:
			var eq_it: Variant = corpse_eq.get(slot_key, {})
			if eq_it is Dictionary and not eq_it.is_empty() and str(eq_it.get("id", "")) != "":
				var amt: int = maxi(1, int(eq_it.get("amount", 1)))
				var rem: int = win.inventory_grid.auto_add_item(str(eq_it.get("id", "")), amt, eq_it)
				if rem <= 0:
					win._close_popup_by_uid(str(eq_it.get("uid", "")))
					corpse_eq[slot_key] = {}
					moved_any = true
					corpse_changed = true
				else:
					full_warn = true
		var bp_slot: Variant = corpse_eq.get("backpack", {})
		if bp_slot is Dictionary and not bp_slot.is_empty() and str(bp_slot.get("id", "")) != "":
			var bp_uid: String = str(bp_slot.get("uid", ""))
			var open_pop: ContainerPopupWindow = win.open_container_popups.get(bp_uid, null) as ContainerPopupWindow
			if open_pop and is_instance_valid(open_pop) and open_pop.inner_grid:
				for bi in range(open_pop.inner_grid.items.size() - 1, -1, -1):
					var in_it: Variant = open_pop.inner_grid.items[bi]
					if not (in_it is Dictionary) or in_it.is_empty():
						continue
					if ContainerPopupWindow.is_item_unsearched(in_it):
						unsearched_blocked = true
						continue
					var in_amt: int = maxi(1, int(in_it.get("amount", 1)))
					var rem: int = win.inventory_grid.auto_add_item(str(in_it.get("id", "")), in_amt, in_it)
					var added: int = in_amt - rem
					if added > 0:
						moved_any = true
						corpse_changed = true
						if rem <= 0:
							open_pop.inner_grid.remove_item_by_uid(str(in_it.get("uid", "")))
						else:
							in_it["amount"] = rem
							open_pop.inner_grid.grid_changed.emit()
					if rem > 0:
						full_warn = true
			else:
				var inner_raw: Variant = bp_slot.get("inner_items", [])
				if inner_raw is Array:
					for bi in range(inner_raw.size() - 1, -1, -1):
						var in_it: Variant = inner_raw[bi]
						if not (in_it is Dictionary) or in_it.is_empty():
							continue
						if ContainerPopupWindow.is_item_unsearched(in_it):
							unsearched_blocked = true
							continue
						var in_amt: int = maxi(1, int(in_it.get("amount", 1)))
						var rem: int = win.inventory_grid.auto_add_item(str(in_it.get("id", "")), in_amt, in_it)
						var added: int = in_amt - rem
						if added > 0:
							moved_any = true
							corpse_changed = true
							if rem <= 0:
								inner_raw.remove_at(bi)
							else:
								in_it["amount"] = rem
						if rem > 0:
							full_warn = true
			var bp_inner_left: Variant = bp_slot.get("inner_items", [])
			if bp_inner_left is Array and bp_inner_left.is_empty():
				var rem_bp: int = win.inventory_grid.auto_add_item(str(bp_slot.get("id", "")), 1, bp_slot)
				if rem_bp <= 0:
					win._close_popup_by_uid(bp_uid)
					corpse_eq["backpack"] = {}
					moved_any = true
					corpse_changed = true
				else:
					full_warn = true
		if corpse_changed and win.target_inventory:
			win.target_inventory.inventory_changed.emit()

	if moved_any:
		if win.inventory_grid.has_method("consolidate_stacks"):
			win.inventory_grid.consolidate_stacks()
		if SoundManager: SoundManager.play("item_pickup")
		update_container_list(win)
	if full_warn and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:warn] 가방 공간이 부족하여 일부 아이템만 획득했습니다.")
	elif unsearched_blocked and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:backpack] 시체 가방 안의 미탐색 물품은 [탐색] 버튼을 눌러 확인한 뒤 회수할 수 있습니다.")

static func quick_transfer_grid_to_container(win: Control, item: Dictionary) -> void:
	if not win.target_inventory or not win.inventory_grid:
		return
	var item_id: String = str(item.get("id", ""))
	var amt: int = int(item.get("amount", 1))
	var rem: int = win.target_inventory.add_item(item_id, amt, item)
	var added: int = amt - rem
	if added > 0:
		if rem <= 0:
			win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
		else:
			item["amount"] = rem
			win.inventory_grid.grid_changed.emit()
		if SoundManager: SoundManager.play("menu_select")
		update_container_list(win)
	else:
		if SoundManager: SoundManager.play("hit_melee")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 보관함 공간이 부족합니다.")

static func try_drop_on_container(win: Control) -> void:
	if not win.target_inventory:
		win._end_drag()
		return

	var src: String = str(win.drag_data.get("source", ""))
	if src == "container" or (src == "corpse_equip" and not get_corpse_equipment(win).is_empty()):
		win._end_drag()
		return
	var item: Dictionary = win.drag_data.get("item", {})
	var item_id: String = str(item.get("id", ""))
	var amt: int = int(item.get("amount", 1))

	var rem: int = win.target_inventory.add_item(item_id, amt, item)
	var added: int = amt - rem

	if added > 0:
		if src == "grid":
			if rem <= 0:
				win.inventory_grid.remove_item_by_uid(str(item.get("uid", "")))
			else:
				item["amount"] = rem
				win.inventory_grid.grid_changed.emit()
		elif src == "popup_grid":
			var p_grid: InventoryGrid = win.drag_data.get("source_grid") as InventoryGrid
			if p_grid:
				if rem <= 0:
					p_grid.remove_item_by_uid(str(item.get("uid", "")))
				else:
					var p_it: Dictionary = p_grid.get_item_by_uid(str(item.get("uid", "")))
					if not p_it.is_empty(): p_it["amount"] = rem
					p_grid.grid_changed.emit()
		elif src == "split":
			if rem > 0:
				var orig_item: Variant = win.drag_data.get("split_source_item", {})
				if orig_item is Dictionary and not orig_item.is_empty():
					orig_item["amount"] = int(orig_item.get("amount", 0)) + rem
					var sp_grid: InventoryGrid = win.drag_data.get("split_source_grid", win.inventory_grid) as InventoryGrid
					if sp_grid: sp_grid.grid_changed.emit()
			win.drag_data["is_split"] = false
		elif src == "equipment":
			if rem <= 0:
				win.equipment_data[win.drag_data.get("slot_name", "")] = {}
				win._apply_backpack_grid_size()
				win._update_equipment_ui()
			else:
				item["amount"] = rem
		elif src == "weapon_slot":
			if rem <= 0:
				var s_name: String = str(win.drag_data.get("slot_name", ""))
				win.equipment_data[s_name] = {}
				win._sync_weapon_to_player(s_name)
				win._update_weapons_ui()
			else:
				item["amount"] = rem
		elif src == "attachment":
			if rem <= 0:
				var w_slot: String = str(win.drag_data.get("weapon_slot", item.get("weapon_slot", "primary1")))
				var a_slot: String = str(win.drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", ""))))
				var r_idx: int = int(win.drag_data.get("rail_index", item.get("rail_index", -1)))
				win._remove_attachment_from_weapon_slot(w_slot, a_slot, r_idx, str(item.get("id", "")))
				win._update_weapons_ui()
		elif src == "vicinity":
			var ground_node: Variant = win.drag_data.get("ground_ref")
			if is_instance_valid(ground_node):
				if rem <= 0:
					ground_node.queue_free()
				else:
					ground_node.amount = rem
					ground_node.update_visuals()

		if SoundManager: SoundManager.play("menu_select")
		update_container_list(win)
	else:
		if SoundManager: SoundManager.play("hit_melee")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 보관함 공간이 부족합니다.")

	win._end_drag()

static func update_vicinity_list(win: Control, force_rebuild: bool = false) -> void:
	if not win.is_inside_tree() or not win.get_tree():
		return
	var p_pos: Vector2 = win.player.global_position if win.player else Vector2.ZERO
	var ground_items: Array = win.get_tree().get_nodes_in_group("ground_items")
	var nearby_items: Array = []
	var sig_parts: PackedStringArray = PackedStringArray()

	for g_item in ground_items:
		if is_instance_valid(g_item) and g_item is GroundItem:
			var dist: float = p_pos.distance_to(g_item.global_position)
			if dist <= 140.0:
				nearby_items.append(g_item)
				sig_parts.append("%d:%s:%d" % [g_item.get_instance_id(), g_item.item_id, g_item.amount])

	var new_sig: String = "|".join(sig_parts)
	if not force_rebuild and new_sig == win._last_vicinity_signature:
		return
	win._last_vicinity_signature = new_sig
	if win.tooltip and win.tooltip.visible and not win.is_dragging and win.vicinity_list.get_global_rect().has_point(win.get_global_mouse_position()):
		win.tooltip.hide()

	for c in win.vicinity_list.get_children():
		if c != win.vicinity_empty_label:
			c.queue_free()

	if nearby_items.is_empty():
		win.vicinity_empty_label.visible = true
	else:
		win.vicinity_empty_label.visible = false
		for g_item in nearby_items:
			create_vicinity_entry(win, g_item)

static func create_vicinity_entry(win: Control, g_item: GroundItem) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(32, 32)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ItemIconManager:
		icon.texture = ItemIconManager.get_icon(g_item.item_id)
	icon_wrap.add_child(icon)

	var is_wish: bool = HideoutProgression.is_wishlist_item(g_item.item_id)
	if is_wish and UiIconManager:
		var w_badge: TextureRect = UiIconManager.create_icon_rect("star", 12)
		w_badge.position = Vector2(20.0, 0.0)
		icon_wrap.add_child(w_badge)

	var lbl := Label.new()
	var d: Dictionary = ItemDatabase.get_item_data(g_item.item_id)
	lbl.text = "%s %s" % [d.get("name", g_item.item_id), ("(x%d)" % g_item.amount if g_item.amount > 1 else "")]
	if is_wish:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	btn.mouse_entered.connect(func():
		if not win.is_dragging and win.tooltip:
			var raw_cd: Dictionary = g_item.custom_data if g_item.custom_data is Dictionary else {}
			var item_dict: Dictionary = _build_item_dict_with_props(g_item.item_id, g_item.amount, raw_cd, false)
			win.tooltip.display_item(item_dict, d)
			win.tooltip.update_position(win.get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if win.tooltip: win.tooltip.hide()
	)

	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL)):
				var rem: int = win.inventory_grid.auto_add_item(g_item.item_id, g_item.amount, g_item.custom_data)
				if rem <= 0:
					g_item.queue_free()
					if SoundManager: SoundManager.play("menu_select")
					update_vicinity_list(win, true)
				else:
					g_item.amount = rem
					g_item.update_visuals()
					update_vicinity_list(win, true)
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("[icon:warn] 가방 공간이 부족합니다.")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var raw_cd: Dictionary = g_item.custom_data if g_item.custom_data is Dictionary else {}
				var item_dict: Dictionary = _build_item_dict_with_props(g_item.item_id, g_item.amount, raw_cd, true)
				win._start_drag("vicinity", item_dict, Vector2i.ZERO, "", g_item)
	)

	win.vicinity_list.add_child(btn)

static func handle_overflow_item(win: Control, item: Dictionary) -> void:
	if item.is_empty():
		return
	if win.player != null:
		drop_item_to_world(win, item)
		return
	var item_id: String = str(item.get("id", ""))
	var amt: int = maxi(1, int(item.get("amount", 1)))
	if win.hideout_stash_grid != null:
		var rem: int = win.hideout_stash_grid.auto_add_item(item_id, amt, item)
		if rem <= 0:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:box] 공간 부족으로 [%s]을(를) 은신처 창고로 이동했습니다." % ItemDatabase.get_item_data(item_id).get("name", item_id))
			return
	if win.inventory_grid != null:
		var rem2: int = win.inventory_grid.auto_add_item(item_id, amt, item)
		if rem2 <= 0:
			return
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 모두 부족합니다.")

static func drop_item_to_world(win: Control, item: Dictionary) -> void:
	if not win.player:
		return

	var g_item: Node = win.GroundItemScene.instantiate()
	g_item.global_position = win.player.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))

	var world_node: Node = win.get_tree().current_scene if (win.is_inside_tree() and win.get_tree()) else null
	if world_node and world_node.has_node("Entities"):
		world_node.get_node("Entities").add_child(g_item)
	elif world_node:
		world_node.add_child(g_item)
	elif win.is_inside_tree() and win.get_tree() and win.get_tree().root:
		win.get_tree().root.add_child(g_item)
	elif win.player.get_parent():
		win.player.get_parent().add_child(g_item)
	else:
		g_item.free()
		return

	var drop_data: Dictionary = InventoryGrid.sanitize_custom_data(item)
	g_item.setup(str(item.get("id", "")), int(item.get("amount", 1)), drop_data)

	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:box] %s을(를) 바닥에 버렸습니다." % ItemDatabase.get_item_data(str(item.get("id", ""))).get("name", str(item.get("id", ""))))
	if win.is_inside_tree():
		update_vicinity_list(win, true)
