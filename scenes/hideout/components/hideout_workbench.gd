# res://scenes/hideout/components/hideout_workbench.gd
class_name HideoutWorkbench
extends TabBar

## 은신처 총기 커스텀 작업대 컴포넌트 (Workbench & Smart Presets)
## 무기 목록 탐색, 부착물 탈부착, 프리셋 자동 구매/조립, 픽셀아트 프리뷰 드로잉을 전담합니다.

signal weapon_saved(weapon_dict: Dictionary, source_info: Dictionary)
signal money_spent(amount: int)

# 작업대 탭 (Workbench) UI 노드
@onready var wb_weapon_list_vbox: VBoxContainer = $VBox/MainHBox/WeaponListPanel/VBox/Scroll/WeaponListVBox
@onready var wb_preview: Control = $VBox/MainHBox/ModdingCenterPanel/VBox/PreviewPanel/WorkbenchPreview
@onready var wb_slots_grid: GridContainer = $VBox/MainHBox/ModdingCenterPanel/VBox/Scroll/SlotsGrid
@onready var wb_stats_vbox: VBoxContainer = $VBox/MainHBox/StatsAndPresetPanel/VBox/StatsScroll/StatsVBox
@onready var wb_preset_vbox: VBoxContainer = $VBox/MainHBox/StatsAndPresetPanel/VBox/PresetButtonsVBox
@onready var wb_preset_buy_btn: Button = $VBox/MainHBox/StatsAndPresetPanel/VBox/PresetBuyButton
@onready var wb_save_btn: Button = $VBox/MainHBox/StatsAndPresetPanel/VBox/SaveWeaponBtn
@onready var wb_compat_hbox: HBoxContainer = $VBox/CompatPartsPanel/VBox/Scroll/CompatPartsHBox
@onready var wb_compat_title: Label = $VBox/CompatPartsPanel/VBox/CompatTitle
const ShootingRangeScript = preload("res://scenes/ui/shooting_range_window.gd")
const WorkbenchPreviewHelper = preload("res://scenes/hideout/components/workbench_preview_helper.gd")

# 외부 주입 의존성
var player_grid_mgr: InventoryGrid = null
var stash_grid_mgr: InventoryGrid = null
var equipment_data: Dictionary = {}

# 총기 작업대(Workbench) 상태 변수
var wb_selected_weapon: Dictionary = {}
var wb_base_stats: Dictionary = {}
var wb_weapon_source: Dictionary = {}
var wb_active_slot: String = ""
var wb_committed_parts: Dictionary = {}
var wb_preset_pending_assembly: bool = false
var wb_current_preset_parts: Dictionary = {}
var wb_missing_preset_cost: int = 0
var wb_missing_preset_parts: Array = []
var active_confirm_dialog: Control = null

func _ready() -> void:
	if wb_preview:
		wb_preview.draw.connect(_on_workbench_preview_draw)
	if wb_preset_buy_btn:
		wb_preset_buy_btn.pressed.connect(_buy_and_assemble_preset)
		if UiIconManager:
			UiIconManager.apply_button_icon(wb_preset_buy_btn, "cart", "", 15)
	if wb_save_btn:
		wb_save_btn.pressed.connect(_save_workbench_weapon)
		if UiIconManager:
			UiIconManager.apply_button_icon(wb_save_btn, "save", "", 15)
	if UiIconManager:
		var wl_title := get_node_or_null("VBox/MainHBox/WeaponListPanel/VBox/Title") as Label
		if wl_title:
			UiIconManager.set_label_icon(wl_title, "clipboard", "", 16, 6)
		var mc_title := get_node_or_null("VBox/MainHBox/ModdingCenterPanel/VBox/Title") as Label
		if mc_title:
			UiIconManager.set_label_icon(mc_title, "gun_gold", "", 16, 6)
		var st_title := get_node_or_null("VBox/MainHBox/StatsAndPresetPanel/VBox/StatsTitle") as Label
		if st_title:
			UiIconManager.set_label_icon(st_title, "stats", "", 16, 6)
		var pr_title := get_node_or_null("VBox/MainHBox/StatsAndPresetPanel/VBox/PresetTitle") as Label
		if pr_title:
			UiIconManager.set_label_icon(pr_title, "preset", "", 15, 6)
		if wb_compat_title:
			UiIconManager.set_label_icon(wb_compat_title, "toolbox", "", 15, 6)

func setup(p_player_grid: InventoryGrid, p_stash_grid: InventoryGrid, p_equipment: Dictionary) -> void:
	player_grid_mgr = p_player_grid
	stash_grid_mgr = p_stash_grid
	equipment_data = p_equipment

func _exit_tree() -> void:
	_close_confirm_dialog()

func _input(event: InputEvent) -> void:
	if is_instance_valid(active_confirm_dialog) and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_close_confirm_dialog()
			if get_viewport():
				get_viewport().set_input_as_handled()

func _close_confirm_dialog() -> void:
	if is_instance_valid(active_confirm_dialog):
		active_confirm_dialog.queue_free()
	active_confirm_dialog = null

func _get_dialog_mount_parent() -> Node:
	var cur: Node = self
	var highest_ctrl: Control = self
	while cur.get_parent() != null:
		cur = cur.get_parent()
		if cur is Window:
			break
		if cur is Control:
			highest_ctrl = cur as Control
	return highest_ctrl

func _show_confirm_dialog(title_text: String, body_text: String, confirm_label: String, on_confirm: Callable) -> void:
	_close_confirm_dialog()
	var overlay := ColorRect.new()
	overlay.name = "WorkbenchConfirmDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 280
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_close_confirm_dialog()
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.15, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.72, 0.25, 0.90)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var parsed_title: Dictionary = UiIconManager.parse_tagged_message(title_text) if UiIconManager else {"icon_key": "", "clean_text": title_text}
	var title_lbl := Label.new()
	title_lbl.name = "ConfirmTitleLabel"
	title_lbl.text = String(parsed_title.get("clean_text", title_text))
	if PixelAssetManager:
		title_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(title_lbl)
	if UiIconManager and String(parsed_title.get("icon_key", "")) != "":
		UiIconManager.set_label_icon(title_lbl, String(parsed_title.get("icon_key", "")), "", 16, 6)

	var body_lbl := Label.new()
	body_lbl.name = "ConfirmBodyLabel"
	body_lbl.text = body_text
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 12)
	body_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
	vbox.add_child(body_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.theme_type_variation = &"SmallButton"
	cancel_btn.custom_minimum_size = Vector2(96, 32)
	cancel_btn.text = "취소"
	cancel_btn.pressed.connect(func():
		if SoundManager: SoundManager.play("menu_move")
		_close_confirm_dialog()
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmBtn"
	confirm_btn.theme_type_variation = &"PrimaryButton"
	confirm_btn.custom_minimum_size = Vector2(128, 32)
	confirm_btn.text = confirm_label
	confirm_btn.pressed.connect(func():
		_close_confirm_dialog()
		if on_confirm.is_valid():
			on_confirm.call()
	)
	btn_row.add_child(confirm_btn)

	active_confirm_dialog = overlay
	_get_dialog_mount_parent().add_child(overlay)
	if SoundManager:
		SoundManager.play("menu_select")

# ============================================================
const WEAPON_PRESETS: Dictionary = WorkbenchPreviewHelper.WEAPON_PRESETS

func refresh_workbench_ui() -> void:
	_refresh_workbench_ui()

func _refresh_workbench_ui() -> void:
	_populate_workbench_weapon_list()
	if wb_selected_weapon.is_empty():
		_auto_select_first_weapon()
	else:
		_build_workbench_slots()
		_refresh_workbench_stats_comparison()
		_populate_workbench_presets()
		_populate_workbench_compat_parts(wb_active_slot)
	if wb_preview:
		wb_preview.queue_redraw()

func _auto_select_first_weapon() -> void:
	# 1. 장비 슬롯 우선 탐색
	for s_key in ["primary1", "primary2", "sidearm"]:
		var eq = equipment_data.get(s_key, {})
		if WeaponPartsDatabase.is_modifiable_weapon(eq):
			_select_workbench_weapon(eq, {"type": "equipment", "slot": s_key})
			return
				
	# 2. 창고 그리드 탐색
	if stash_grid_mgr:
		for it in stash_grid_mgr.items:
			if WeaponPartsDatabase.is_modifiable_weapon(it):
				_select_workbench_weapon(it, {"type": "stash", "uid": it.get("uid", "")})
				return
				
	# 3. 배낭 그리드 탐색
	if player_grid_mgr:
		for it in player_grid_mgr.items:
			if WeaponPartsDatabase.is_modifiable_weapon(it):
				_select_workbench_weapon(it, {"type": "player", "uid": it.get("uid", "")})
				return

func _populate_workbench_weapon_list() -> void:
	if not wb_weapon_list_vbox: return
	for c in wb_weapon_list_vbox.get_children():
		c.queue_free()
		
	var weapons_found = []
	
	# 장비 슬롯 총기
	for s_key in ["primary1", "primary2", "sidearm"]:
		var eq = equipment_data.get(s_key, {})
		if WeaponPartsDatabase.is_modifiable_weapon(eq):
			var s_label = "주무기 1" if s_key == "primary1" else ("주무기 2" if s_key == "primary2" else "보조무기")
			weapons_found.append({"weapon": eq, "source": {"type": "equipment", "slot": s_key}, "label_prefix": "[장착:%s]" % s_label})
				
	# 창고 총기
	if stash_grid_mgr:
		for it in stash_grid_mgr.items:
			if WeaponPartsDatabase.is_modifiable_weapon(it):
				weapons_found.append({"weapon": it, "source": {"type": "stash", "uid": it.get("uid", "")}, "label_prefix": "[창고]"})
				
	# 배낭 총기
	if player_grid_mgr:
		for it in player_grid_mgr.items:
			if WeaponPartsDatabase.is_modifiable_weapon(it):
				weapons_found.append({"weapon": it, "source": {"type": "player", "uid": it.get("uid", "")}, "label_prefix": "[배낭]"})
				
	if weapons_found.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(보유 중인 총기 없음)"
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		wb_weapon_list_vbox.add_child(empty_lbl)
		return
		
	for entry in weapons_found:
		var w_dict = entry["weapon"]
		var src = entry["source"]
		var prefix = entry["label_prefix"]
		
		var raw_id = w_dict.get("receiver", w_dict.get("id", "M4_리시버"))
		var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
		var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
		var w_name = w_dict.get("name", r_data.get("name", raw_id))
		
		var btn = Button.new()
		btn.text = "%s %s" % [prefix, w_name]
		btn.tooltip_text = btn.text
		btn.clip_text = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(raw_id)
			btn.expand_icon = true
			
		var is_cur = (wb_selected_weapon.get("uid", "") == w_dict.get("uid", "") and not w_dict.get("uid", "").is_empty()) or (src == wb_weapon_source and not src.is_empty())
		if is_cur and PixelAssetManager:
			var cur_style: StyleBox = PixelAssetManager.get_pixel_stylebox("workbench_selected_btn", 8.0, 4.0, 8.0, 4.0, 4)
			if cur_style != null:
				btn.add_theme_stylebox_override("normal", cur_style)
			
		btn.pressed.connect(func():
			_select_workbench_weapon(w_dict, src)
			_populate_workbench_weapon_list()
		)
		wb_weapon_list_vbox.add_child(btn)

func _select_workbench_weapon(weapon_dict: Dictionary, source_info: Dictionary) -> void:
	wb_weapon_source = source_info
	wb_selected_weapon = weapon_dict.duplicate(true)
	wb_preset_pending_assembly = false
	wb_current_preset_parts.clear()
	wb_missing_preset_parts.clear()
	wb_missing_preset_cost = 0
	
	var raw_id = wb_selected_weapon.get("receiver", wb_selected_weapon.get("id", "M4_리시버"))
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	wb_selected_weapon["receiver"] = rec_id
	if not wb_selected_weapon.has("parts"):
		wb_selected_weapon["parts"] = wb_selected_weapon.get("attachments", {}).duplicate(true)
	wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
	wb_committed_parts = wb_selected_weapon["parts"].duplicate(true)
		
	# 모딩 전 기준 스탯 산출
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_base_stats = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_selected_weapon["parts"], wb_selected_weapon.get("loaded_ammo", def_ammo))
	wb_selected_weapon["computed_stats"] = wb_base_stats
	
	if wb_preset_buy_btn:
		if UiIconManager:
			UiIconManager.set_button(wb_preset_buy_btn, "cart", "프리셋을 선택해 주세요", 15)
		else:
			wb_preset_buy_btn.text = "프리셋을 선택해 주세요"
		wb_preset_buy_btn.remove_theme_color_override("font_color")
	
	wb_active_slot = ""
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_presets()
	_populate_workbench_compat_parts("")
	if wb_preview: wb_preview.queue_redraw()

func _build_workbench_slots() -> void:
	if not wb_slots_grid: return
	for c in wb_slots_grid.get_children():
		c.queue_free()
		
	if wb_selected_weapon.is_empty(): return
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	var slots_def = r_data.get("slots", {})
	var parts = wb_selected_weapon.get("parts", {})
	
	var slot_labels = {
		"barrel": "총열 (Barrel)",
		"muzzle": "총구 (Muzzle)",
		"optic": "조준경 (Optic)",
		"grip": "손잡이 (Grip)",
		"magazine": "탄창 (Magazine)",
		"stock": "개머리판 (Stock)",
		"rail": "레일 부착물 (Rail)"
	}
	
	for slot_name in slots_def.keys():
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var is_active = (wb_active_slot == slot_name)
		if PixelAssetManager:
			var style: StyleBox = PixelAssetManager.get_pixel_stylebox("workbench_slot_active" if is_active else "workbench_slot", 8.0, 4.0, 8.0, 4.0, 4)
			if style != null:
				card.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		
		var title_lbl = Label.new()
		title_lbl.text = slot_labels.get(slot_name, slot_name)
		title_lbl.custom_minimum_size = Vector2(100, 0)
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		hbox.add_child(title_lbl)
		
		var cur_part_id = parts.get(slot_name, "")
		if slot_name == "rail" and cur_part_id is Array:
			cur_part_id = cur_part_id[0] if cur_part_id.size() > 0 else ""
			
		var val_btn = Button.new()
		val_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if cur_part_id != "" and WeaponPartsDatabase.PARTS.has(cur_part_id):
			var p_info = WeaponPartsDatabase.PARTS[cur_part_id]
			val_btn.text = p_info.get("name", cur_part_id)
			if ItemIconManager:
				val_btn.icon = ItemIconManager.get_icon(cur_part_id)
				val_btn.expand_icon = true
			val_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		else:
			val_btn.text = "(미장착 - 부품 선택)"
			val_btn.icon = null
			val_btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
			
		var captured_slot = slot_name
		val_btn.pressed.connect(func():
			wb_active_slot = captured_slot
			_build_workbench_slots()
			_populate_workbench_compat_parts(captured_slot)
		)
		
		# 우클릭 시 즉시 탈착
		val_btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_detach_workbench_part(captured_slot)
		)
		
		hbox.add_child(val_btn)
		card.add_child(hbox)
		wb_slots_grid.add_child(card)

func _populate_workbench_compat_parts(slot_name: String) -> void:
	if not wb_compat_hbox: return
	for c in wb_compat_hbox.get_children():
		c.queue_free()
		
	if wb_selected_weapon.is_empty():
		wb_compat_title.text = "호환 부품: 총기를 먼저 선택해주세요."
		return
		
	if slot_name == "":
		wb_compat_title.text = "위 슬롯 카드(총열, 총구, 스코프 등)를 클릭하면 내 창고/배낭의 호환 부품이 표시됩니다."
		return
		
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	var cat = r_data.get("category", "rifle")
	wb_compat_title.text = "[%s] 슬롯 호환 부품 목록 (내 창고/배낭 소지품):" % slot_name
	
	# 내 인벤토리에서 해당 슬롯에 맞는 부품 검색
	var owned_compat_parts = []
	
	# 1. 창고 탐색 (부품 상자 포함)
	if stash_grid_mgr:
		for it in stash_grid_mgr.get_all_items_flat(true):
			var it_id = it.get("id", "")
			if WeaponPartsDatabase.PARTS.has(it_id):
				var p_info = WeaponPartsDatabase.PARTS[it_id]
				if p_info.get("slot") == slot_name:
					var comps = p_info.get("compatible_categories", ["all"])
					if "all" in comps or cat in comps:
						owned_compat_parts.append({"id": it_id, "source": "stash", "item": it})
						
	# 2. 배낭 탐색 (부품 상자 포함)
	if player_grid_mgr:
		for it in player_grid_mgr.get_all_items_flat(true):
			var it_id = it.get("id", "")
			if WeaponPartsDatabase.PARTS.has(it_id):
				var p_info = WeaponPartsDatabase.PARTS[it_id]
				if p_info.get("slot") == slot_name:
					var comps = p_info.get("compatible_categories", ["all"])
					if "all" in comps or cat in comps:
						owned_compat_parts.append({"id": it_id, "source": "player", "item": it})
						
	# 탈착 버튼 (현재 부품이 있을 때)
	var cur_p = wb_selected_weapon.get("parts", {}).get(slot_name, "")
	var cur_p_str = ""
	if cur_p is Array:
		cur_p_str = cur_p[0] if cur_p.size() > 0 else ""
	elif cur_p is String:
		cur_p_str = cur_p
		
	if cur_p_str != "":
		var detach_btn = Button.new()
		if UiIconManager:
			UiIconManager.set_button(detach_btn, "error", "부품 분리(탈착)", 14)
		else:
			detach_btn.text = "부품 분리(탈착)"
		detach_btn.custom_minimum_size = Vector2(130, 40)
		detach_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		detach_btn.pressed.connect(func(): _detach_workbench_part(slot_name))
		wb_compat_hbox.add_child(detach_btn)
		
	if owned_compat_parts.is_empty():
		var none_lbl = Label.new()
		none_lbl.text = "(보유 중인 호환 부품이 없습니다. 상인이나 플리마켓에서 획득 가능)"
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		wb_compat_hbox.add_child(none_lbl)
		return
		
	for p_entry in owned_compat_parts:
		var p_id = p_entry["id"]
		var p_info = WeaponPartsDatabase.PARTS[p_id]
		var btn = Button.new()
		btn.text = "%s\n[%s]" % [p_info.get("name", p_id), "창고" if p_entry["source"] == "stash" else "배낭"]
		btn.custom_minimum_size = Vector2(150, 48)
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(p_id)
			btn.expand_icon = true
			
		var is_equipped = (cur_p_str == p_id)
		if is_equipped:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			
		btn.pressed.connect(func():
			_attach_workbench_part(slot_name, p_id)
		)
		wb_compat_hbox.add_child(btn)

func _flatten_parts_dict(parts_dict: Dictionary) -> Array[String]:
	return WorkbenchPreviewHelper.flatten_parts_dict(parts_dict)

func _return_parts_to_storage(part_ids: Array) -> bool:
	var placed: Array[Dictionary] = []
	for raw_pid in part_ids:
		var p_id := String(raw_pid)
		if p_id == "":
			continue
		var stored := false
		if stash_grid_mgr and stash_grid_mgr.auto_add_item(p_id, 1) == 0:
			placed.append({"grid": stash_grid_mgr, "uid": String(stash_grid_mgr.items[-1].get("uid", ""))})
			stored = true
		elif player_grid_mgr and player_grid_mgr.auto_add_item(p_id, 1) == 0:
			placed.append({"grid": player_grid_mgr, "uid": String(player_grid_mgr.items[-1].get("uid", ""))})
			stored = true
		if not stored:
			for rec in placed:
				if rec["uid"] != "":
					rec["grid"].remove_item_by_uid(rec["uid"], true)
			return false
	return true

func _commit_selected_weapon_to_source() -> void:
	if wb_selected_weapon.is_empty():
		return
	var src_type := str(wb_weapon_source.get("type", ""))
	if src_type == "equipment":
		var s_key := str(wb_weapon_source.get("slot", ""))
		if s_key != "":
			equipment_data[s_key] = wb_selected_weapon.duplicate(true)
	elif src_type == "stash" and stash_grid_mgr:
		var uid := str(wb_weapon_source.get("uid", ""))
		for i in range(stash_grid_mgr.items.size()):
			if stash_grid_mgr.items[i].get("uid", "") == uid:
				stash_grid_mgr.items[i] = wb_selected_weapon.duplicate(true)
				stash_grid_mgr.grid_changed.emit()
				break
	elif src_type == "player" and player_grid_mgr:
		var uid := str(wb_weapon_source.get("uid", ""))
		for i in range(player_grid_mgr.items.size()):
			if player_grid_mgr.items[i].get("uid", "") == uid:
				player_grid_mgr.items[i] = wb_selected_weapon.duplicate(true)
				player_grid_mgr.grid_changed.emit()
				break

func _cancel_pending_preset_preview() -> void:
	if not wb_preset_pending_assembly:
		return
	wb_preset_pending_assembly = false
	wb_current_preset_parts.clear()
	wb_missing_preset_parts.clear()
	wb_missing_preset_cost = 0
	if not wb_selected_weapon.is_empty():
		wb_selected_weapon["parts"] = wb_committed_parts.duplicate(true)
		wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
		var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
		var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
		wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_selected_weapon["parts"], wb_selected_weapon.get("loaded_ammo", def_ammo))
	if wb_preset_buy_btn:
		if UiIconManager:
			UiIconManager.set_button(wb_preset_buy_btn, "cart", "프리셋을 선택해 주세요", 15)
		else:
			wb_preset_buy_btn.text = "프리셋을 선택해 주세요"
		wb_preset_buy_btn.remove_theme_color_override("font_color")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	if wb_preview: wb_preview.queue_redraw()

func _attach_workbench_part(slot_name: String, part_id: String) -> void:
	if wb_selected_weapon.is_empty(): return
	if wb_preset_pending_assembly:
		_cancel_pending_preset_preview()
	var owned_pool := _get_owned_parts_list()
	if int(owned_pool.get(part_id, 0)) <= 0:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 보유 중인 [%s] 부품이 없습니다." % part_id)
		if SoundManager: SoundManager.play("hit_melee")
		return

	var parts: Dictionary = wb_selected_weapon.get("parts", {})
	var prev_part = parts.get(slot_name, "")
	var to_return: Array[String] = []
	if prev_part is Array:
		for p in prev_part:
			if String(p) != "":
				to_return.append(String(p))
	elif prev_part is String and prev_part != "":
		to_return.append(prev_part)

	# 동일 부품 재클릭 시 중복 소비/반환 방지
	if prev_part is String and prev_part == part_id:
		return
	if prev_part is Array and prev_part.size() == 1 and String(prev_part[0]) == part_id:
		return

	if not _remove_owned_part_from_inv(part_id):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 부품 차감에 실패했습니다.")
		return

	if not to_return.is_empty() and not _return_parts_to_storage(to_return):
		# 공간 부족 시 새 부품 복구 후 중단
		_return_parts_to_storage([part_id])
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 부족하여 기존 부품을 교체할 수 없습니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	
	if slot_name == "rail":
		parts["rail"] = [part_id]
	else:
		parts[slot_name] = part_id
		
	wb_selected_weapon["parts"] = parts
	wb_selected_weapon["attachments"] = parts
	wb_committed_parts = parts.duplicate(true)
	
	# 스탯 재계산
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	_commit_selected_weapon_to_source()
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
	
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(slot_name)
	if wb_preview: wb_preview.queue_redraw()

func _detach_workbench_part(slot_name: String) -> void:
	if wb_selected_weapon.is_empty(): return
	if wb_preset_pending_assembly:
		_cancel_pending_preset_preview()
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:info] 프리셋 미리보기가 취소되어 실제 장착 상태로 복원되었습니다.")
		return
	var parts: Dictionary = wb_selected_weapon.get("parts", {})
	if not parts.has(slot_name): return
	var prev_part = parts.get(slot_name)
	var to_return: Array[String] = []
	if prev_part is Array:
		for p in prev_part:
			if String(p) != "":
				to_return.append(String(p))
	elif prev_part is String and prev_part != "":
		to_return.append(prev_part)

	if not to_return.is_empty() and not _return_parts_to_storage(to_return):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 부족하여 부품을 분리할 수 없습니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	parts.erase(slot_name)
		
	wb_selected_weapon["parts"] = parts
	wb_selected_weapon["attachments"] = parts
	wb_committed_parts = parts.duplicate(true)
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	_commit_selected_weapon_to_source()
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
	
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(slot_name)
	if wb_preview: wb_preview.queue_redraw()

func _remove_owned_part_from_inv(part_id: String) -> bool:
	if stash_grid_mgr:
		var rem_s := stash_grid_mgr.remove_item(part_id, 1)
		if rem_s == 0:
			return true
	if player_grid_mgr:
		var rem_p := player_grid_mgr.remove_item(part_id, 1)
		if rem_p == 0:
			return true
	return false

func _refresh_workbench_stats_comparison() -> void:
	if not wb_stats_vbox: return
	for c in wb_stats_vbox.get_children():
		c.queue_free()
		
	if wb_selected_weapon.is_empty(): return
	
	var cur_stats = wb_selected_weapon.get("computed_stats", {})
	var base = wb_base_stats if not wb_base_stats.is_empty() else cur_stats
	
	_add_stat_compare_row("explosion", "데미지", base.get("damage", 20.0), cur_stats.get("damage", 20.0), "%.1f", true)
	_add_stat_compare_row("target", "정확도", base.get("accuracy", 70.0), cur_stats.get("accuracy", 70.0), "%d%%", true)
	_add_stat_compare_row("power", "연사력 (RPM)", base.get("rpm", 150), cur_stats.get("rpm", 150), "%d", true)
	_add_stat_compare_row("refresh", "반동 제어", base.get("recoil", 30.0), cur_stats.get("recoil", 30.0), "%.1f", false) # 반동 감소가 좋음
	_add_stat_compare_row("scope", "유효 사거리", base.get("range", 10.0), cur_stats.get("range", 10.0), "%.1fm", true)
	_add_stat_compare_row("zoom", "조준경 줌", base.get("zoom", 1.0), cur_stats.get("zoom", 1.0), "%.1fx", true)
	_add_stat_compare_row("box", "탄창 용량", base.get("magazine_size", 15), cur_stats.get("magazine_size", 15), "%d발", true)
	_add_stat_compare_row("sound", "사격 소음", base.get("noise_radius", 600.0), cur_stats.get("noise_radius", 600.0), "%dpx", false) # 소음 감소가 좋음
	_add_stat_compare_row("weight", "총기 무게", base.get("weight", 2.0), cur_stats.get("weight", 2.0), "%.2fkg", false) # 무게 감소가 좋음
	_build_repair_controls()
	
	if not wb_selected_weapon.is_empty():
		var sep2 = HSeparator.new()
		wb_stats_vbox.add_child(sep2)
		var test_btn = Button.new()
		if UiIconManager:
			UiIconManager.set_button(test_btn, "target", "사격 시험 (Test Fire)", 15)
		else:
			test_btn.text = "사격 시험 (Test Fire)"
		test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		test_btn.pressed.connect(_open_shooting_range_test)
		wb_stats_vbox.add_child(test_btn)

func _open_shooting_range_test() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var win = ShootingRangeScript.new()
	var root = get_tree().current_scene
	if root:
		root.add_child(win)
	else:
		add_child(win)
	win.setup(wb_selected_weapon)

const WORKBENCH_REPAIR_RATE_RUBLES: float = 35.0
const FIELD_REPAIR_RATE_RUBLES: float = 15.0
const QUICK_REPAIR_RATE_RUBLES: float = 10.0

static func calculate_repair_cost_rubles(cur_dur: float, max_dur: float = 100.0, rate_per_point: float = WORKBENCH_REPAIR_RATE_RUBLES) -> int:
	var missing = max(0.0, max_dur - cur_dur)
	return int(round(missing * rate_per_point))

static func calculate_repair_cost_scrap(cur_dur: float, max_dur: float = 100.0) -> int:
	var missing = max(0.0, max_dur - cur_dur)
	if missing <= 0.001:
		return 0
	return int(ceil(missing / 20.0))

func _try_pay_repair_cost(cur_dur: float, max_dur: float, use_scrap: bool) -> bool:
	if use_scrap:
		var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
		if _get_total_scrap_count() < scrap_cost:
			return false
		_consume_scrap(scrap_cost)
		return true
	var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
	var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	if cur_rubles < rub_cost:
		return false
	if GameManager and GameManager.current_world_data.has("player"):
		GameManager.current_world_data["player"]["rubles"] = cur_rubles - rub_cost
	money_spent.emit(rub_cost)
	return true

func _get_total_scrap_count() -> int:
	var count = 0
	if stash_grid_mgr:
		count += stash_grid_mgr.get_item_count("고철")
	if player_grid_mgr:
		count += player_grid_mgr.get_item_count("고철")
	return count

func _consume_scrap(amount: int) -> void:
	var rem = amount
	if stash_grid_mgr and rem > 0:
		rem = stash_grid_mgr.remove_item("고철", rem)
	if player_grid_mgr and rem > 0:
		player_grid_mgr.remove_item("고철", rem)

func _build_repair_controls() -> void:
	if not wb_stats_vbox or wb_selected_weapon.is_empty():
		return
	var sep = HSeparator.new()
	wb_stats_vbox.add_child(sep)
	
	var w_id = wb_selected_weapon.get("id", wb_selected_weapon.get("receiver", "M4_리시버"))
	var w_meta = ItemDatabase.get_item_data(w_id)
	var max_dur = float(wb_selected_weapon.get("max_durability", w_meta.get("max_durability", 100.0)))
	var cur_dur = float(wb_selected_weapon.get("durability", max_dur))
	var missing = max(0.0, max_dur - cur_dur)
	var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
	var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
	var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	var cur_scrap = _get_total_scrap_count()
	
	var dur_lbl = Label.new()
	dur_lbl.text = "총기 내구도: %.1f / %.0f" % [cur_dur, max_dur]
	dur_lbl.add_theme_font_size_override("font_size", 11)
	dur_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if missing <= 0.1 else Color(1.0, 0.78, 0.3))
	wb_stats_vbox.add_child(dur_lbl)
	if UiIconManager:
		UiIconManager.set_label_icon(dur_lbl, "tools", "", 13, 5)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	
	var rub_btn = Button.new()
	rub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rub_btn.add_theme_font_size_override("font_size", 10)
	if UiIconManager:
		UiIconManager.set_button(
			rub_btn,
			"wrench_blue" if missing > 0.1 else "ok",
			"루블 수리 (%d RUB)" % rub_cost if missing > 0.1 else "내구도 100%",
			13
		)
	else:
		rub_btn.text = "루블 수리 (%d RUB)" % rub_cost if missing > 0.1 else "내구도 100%"
	rub_btn.disabled = (missing <= 0.1 or cur_rubles < rub_cost)
	rub_btn.pressed.connect(func(): _repair_selected_weapon(false))
	btn_hbox.add_child(rub_btn)
	
	var scrap_btn = Button.new()
	scrap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrap_btn.add_theme_font_size_override("font_size", 10)
	if UiIconManager:
		UiIconManager.set_button(
			scrap_btn,
			"bolt",
			"고철 수리 (%d/%d)" % [cur_scrap, scrap_cost] if missing > 0.1 else "수리 불필요",
			13
		)
	else:
		scrap_btn.text = "고철 수리 (%d/%d)" % [cur_scrap, scrap_cost] if missing > 0.1 else "수리 불필요"
	scrap_btn.disabled = (missing <= 0.1 or cur_scrap < scrap_cost)
	scrap_btn.pressed.connect(func(): _repair_selected_weapon(true))
	btn_hbox.add_child(scrap_btn)
	wb_stats_vbox.add_child(btn_hbox)
	
	for a_slot in ["helmet", "vest"]:
		var armor_dict = equipment_data.get(a_slot, {})
		if armor_dict.is_empty():
			continue
		var a_id = armor_dict.get("id", "")
		var a_meta = ItemDatabase.get_item_data(a_id)
		var a_max = float(armor_dict.get("max_durability", a_meta.get("max_durability", 100.0)))
		var a_cur = float(armor_dict.get("durability", a_max))
		var a_miss = max(0.0, a_max - a_cur)
		var a_rub = calculate_repair_cost_rubles(a_cur, a_max)
		var a_scr = calculate_repair_cost_scrap(a_cur, a_max)
		var slot_title = "헬멧" if a_slot == "helmet" else "방탄복"
		var slot_icon = "helmet" if a_slot == "helmet" else "vest"
		
		var a_row = HBoxContainer.new()
		a_row.add_theme_constant_override("separation", 4)
		if UiIconManager:
			a_row.add_child(UiIconManager.create_icon_rect(slot_icon, 13))
		var a_lbl = Label.new()
		a_lbl.text = "%s (%.0f/%.0f)" % [slot_title, a_cur, a_max]
		a_lbl.custom_minimum_size = Vector2(76, 0)
		a_lbl.add_theme_font_size_override("font_size", 10)
		a_row.add_child(a_lbl)
		
		var ar_btn = Button.new()
		ar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ar_btn.add_theme_font_size_override("font_size", 10)
		ar_btn.text = "%d RUB" % a_rub if a_miss > 0.1 else "완료"
		ar_btn.disabled = (a_miss <= 0.1 or cur_rubles < a_rub)
		var cap_slot = a_slot
		ar_btn.pressed.connect(func(): _repair_equipped_armor(cap_slot, false))
		a_row.add_child(ar_btn)
		
		var as_btn = Button.new()
		as_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		as_btn.add_theme_font_size_override("font_size", 10)
		as_btn.text = "고철 %d" % a_scr if a_miss > 0.1 else "-"
		as_btn.disabled = (a_miss <= 0.1 or cur_scrap < a_scr)
		as_btn.pressed.connect(func(): _repair_equipped_armor(cap_slot, true))
		a_row.add_child(as_btn)
		wb_stats_vbox.add_child(a_row)

func _repair_selected_weapon(use_scrap: bool) -> void:
	if wb_selected_weapon.is_empty():
		return
	var w_id = wb_selected_weapon.get("id", wb_selected_weapon.get("receiver", "M4_리시버"))
	var w_meta = ItemDatabase.get_item_data(w_id)
	var max_dur = float(wb_selected_weapon.get("max_durability", w_meta.get("max_durability", 100.0)))
	var cur_dur = float(wb_selected_weapon.get("durability", max_dur))
	if max_dur - cur_dur <= 0.1:
		return

	var w_name := str(wb_selected_weapon.get("name", w_meta.get("name", w_id)))
	if use_scrap:
		var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
		if _get_total_scrap_count() < scrap_cost:
			return
		_show_confirm_dialog(
			"[icon:wrench_blue] 무기 수리 확인",
			"%s 내구도(%.0f → %.0f)를 복구하시겠습니까?\n소모 비용: 고철 %d개" % [w_name, cur_dur, max_dur, scrap_cost],
			"고철 %d개 소모 수리" % scrap_cost,
			func(): _execute_repair_selected_weapon(true)
		)
	else:
		var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
		var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
		if cur_rubles < rub_cost:
			return
		_show_confirm_dialog(
			"[icon:wrench_blue] 무기 수리 확인",
			"%s 내구도(%.0f → %.0f)를 수리하시겠습니까?\n소모 비용: %d RUB (보유: %d RUB)" % [w_name, cur_dur, max_dur, rub_cost, cur_rubles],
			"%d RUB 결제 수리" % rub_cost,
			func(): _execute_repair_selected_weapon(false)
		)

func _execute_repair_selected_weapon(use_scrap: bool) -> void:
	if wb_selected_weapon.is_empty():
		return
	var w_id = wb_selected_weapon.get("id", wb_selected_weapon.get("receiver", "M4_리시버"))
	var w_meta = ItemDatabase.get_item_data(w_id)
	var max_dur = float(wb_selected_weapon.get("max_durability", w_meta.get("max_durability", 100.0)))
	var cur_dur = float(wb_selected_weapon.get("durability", max_dur))
	if max_dur - cur_dur <= 0.1:
		return
	if not _try_pay_repair_cost(cur_dur, max_dur, use_scrap):
		return

	wb_selected_weapon["durability"] = max_dur
	_save_workbench_weapon()
	_refresh_workbench_stats_comparison()

func _repair_equipped_armor(slot_key: String, use_scrap: bool) -> void:
	var armor_dict = equipment_data.get(slot_key, {})
	if armor_dict.is_empty():
		return
	var a_id = armor_dict.get("id", "")
	var a_meta = ItemDatabase.get_item_data(a_id)
	var max_dur = float(armor_dict.get("max_durability", a_meta.get("max_durability", 100.0)))
	var cur_dur = float(armor_dict.get("durability", max_dur))
	if max_dur - cur_dur <= 0.1:
		return

	var a_name := str(armor_dict.get("name", a_meta.get("name", a_id)))
	if use_scrap:
		var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
		if _get_total_scrap_count() < scrap_cost:
			return
		_show_confirm_dialog(
			"[icon:shield] 방어구 수리 확인",
			"%s 내구도(%.0f → %.0f)를 복구하시겠습니까?\n소모 비용: 고철 %d개" % [a_name, cur_dur, max_dur, scrap_cost],
			"고철 %d개 소모 수리" % scrap_cost,
			func(): _execute_repair_equipped_armor(slot_key, true)
		)
	else:
		var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
		var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
		if cur_rubles < rub_cost:
			return
		_show_confirm_dialog(
			"[icon:shield] 방어구 수리 확인",
			"%s 내구도(%.0f → %.0f)를 수리하시겠습니까?\n소모 비용: %d RUB (보유: %d RUB)" % [a_name, cur_dur, max_dur, rub_cost, cur_rubles],
			"%d RUB 결제 수리" % rub_cost,
			func(): _execute_repair_equipped_armor(slot_key, false)
		)

func _execute_repair_equipped_armor(slot_key: String, use_scrap: bool) -> void:
	var armor_dict = equipment_data.get(slot_key, {})
	if armor_dict.is_empty():
		return
	var a_id = armor_dict.get("id", "")
	var a_meta = ItemDatabase.get_item_data(a_id)
	var max_dur = float(armor_dict.get("max_durability", a_meta.get("max_durability", 100.0)))
	var cur_dur = float(armor_dict.get("durability", max_dur))
	if max_dur - cur_dur <= 0.1:
		return
	if not _try_pay_repair_cost(cur_dur, max_dur, use_scrap):
		return

	armor_dict["durability"] = max_dur
	equipment_data[slot_key] = armor_dict
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
	_refresh_workbench_stats_comparison()

func _add_stat_compare_row(icon_key: String, title: String, base_val: float, cur_val: float, fmt: String, higher_is_better: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	
	if UiIconManager and icon_key != "":
		row.add_child(UiIconManager.create_icon_rect(icon_key, 13))
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.custom_minimum_size = Vector2(84, 0)
	t_lbl.add_theme_font_size_override("font_size", 11)
	t_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	row.add_child(t_lbl)
	
	var diff = cur_val - base_val
	var v_lbl = Label.new()
	v_lbl.text = fmt % cur_val
	v_lbl.add_theme_font_size_override("font_size", 11)
	v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v_lbl)
	
	var delta_lbl = Label.new()
	delta_lbl.custom_minimum_size = Vector2(65, 0)
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_lbl.add_theme_font_size_override("font_size", 11)
	
	if abs(diff) < 0.05:
		delta_lbl.text = " - "
		delta_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		var is_good = (diff > 0) if higher_is_better else (diff < 0)
		var sign_str = "+" if diff > 0 else ""
		var arrow = "▲" if diff > 0 else "▼"
		delta_lbl.text = "%s%s %s" % [sign_str, fmt % diff, arrow]
		delta_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if is_good else Color(1.0, 0.35, 0.35))
		
	row.add_child(delta_lbl)
	wb_stats_vbox.add_child(row)

func _populate_workbench_presets() -> void:
	WorkbenchPreviewHelper.populate_workbench_presets(self)

func _apply_workbench_preset(preset_dict: Dictionary) -> void:
	WorkbenchPreviewHelper.apply_workbench_preset(self, preset_dict)

func _buy_and_assemble_preset() -> void:
	WorkbenchPreviewHelper.buy_and_assemble_preset(self)

func _execute_buy_and_assemble_preset() -> void:
	WorkbenchPreviewHelper.execute_buy_and_assemble_preset(self)

func _get_owned_parts_list() -> Dictionary:
	var pool = {}
	if stash_grid_mgr:
		for it in stash_grid_mgr.get_all_items_flat(true):
			var id = it.get("id", "")
			pool[id] = pool.get(id, 0) + int(it.get("amount", 1))
	if player_grid_mgr:
		for it in player_grid_mgr.get_all_items_flat(true):
			var id = it.get("id", "")
			pool[id] = pool.get(id, 0) + int(it.get("amount", 1))
	return pool

func _save_workbench_weapon() -> void:
	if wb_selected_weapon.is_empty(): return
	if wb_preset_pending_assembly or not wb_missing_preset_parts.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 프리셋 미리보기 상태입니다. 먼저 [구매 후 조립] 버튼으로 조립을 완료하세요.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	wb_selected_weapon["name"] = r_data.get("name", rec_id) + " (모딩)"
	wb_selected_weapon["attachments"] = wb_selected_weapon.get("parts", {}).duplicate(true)
	wb_committed_parts = wb_selected_weapon.get("parts", {}).duplicate(true)
	_commit_selected_weapon_to_source()
					
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:save] [%s] 총기 모딩이 성공적으로 저장/장착되었습니다!" % wb_selected_weapon["name"])
	if SoundManager: SoundManager.play("menu_select")
	_populate_workbench_weapon_list()

# ============================================================
# 픽셀아트 실루엣 + 부착물 오버레이 총기 프리뷰 드로잉
# ============================================================
func _on_workbench_preview_draw() -> void:
	WorkbenchPreviewHelper.draw_workbench_preview(self, wb_preview)
