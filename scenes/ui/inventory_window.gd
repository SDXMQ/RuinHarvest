# res://scenes/ui/inventory_window.gd
extends Control

## 4단 레이아웃 + WxH 2D 그리드 결합 전술 인벤토리 시스템

signal window_closed

const CELL_SIZE: float = 44.0
const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
const SplitDialogScene = preload("res://scenes/ui/split_dialog.tscn")
const GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")

@onready var main_layout: HBoxContainer = $MainLayout
@onready var vicinity_col: VBoxContainer = $MainLayout/VicinityCol
@onready var inventory_col: VBoxContainer = $MainLayout/InventoryCol
@onready var character_col: VBoxContainer = $MainLayout/CharacterCol
@onready var weapons_col: VBoxContainer = $MainLayout/WeaponsCol

@onready var compact_tab_bar: HBoxContainer = get_node_or_null("CompactTabBar")
@onready var tab_vicinity_btn: Button = get_node_or_null("CompactTabBar/TabVicinityBtn")
@onready var tab_inventory_btn: Button = get_node_or_null("CompactTabBar/TabInventoryBtn")
@onready var tab_character_btn: Button = get_node_or_null("CompactTabBar/TabCharacterBtn")
@onready var tab_weapons_btn: Button = get_node_or_null("CompactTabBar/TabWeaponsBtn")

@onready var container_section: VBoxContainer = $MainLayout/VicinityCol/ContainerSection
@onready var container_title_label: Label = $MainLayout/VicinityCol/ContainerSection/Header/TitleLabel
@onready var container_list: VBoxContainer = $MainLayout/VicinityCol/ContainerSection/Scroll/ContainerList
@onready var container_empty_label: Label = $MainLayout/VicinityCol/ContainerSection/Scroll/ContainerList/EmptyLabel

@onready var vicinity_section: VBoxContainer = $MainLayout/VicinityCol/VicinitySection
@onready var vicinity_list: VBoxContainer = $MainLayout/VicinityCol/VicinitySection/Scroll/VicinityList
@onready var vicinity_empty_label: Label = $MainLayout/VicinityCol/VicinitySection/Scroll/VicinityList/EmptyLabel

@onready var grid_title_label: Label = $MainLayout/InventoryCol/Header/HBox/TitleLabel
@onready var weight_label: Label = $MainLayout/InventoryCol/Header/HBox/WeightLabel
@onready var grid_control: Control = $MainLayout/InventoryCol/GridScroll/GridContainerPanel/GridControl

@onready var helmet_slot: Button = $MainLayout/CharacterCol/SilhouetteArea/SlotsContainer/TopRow/HelmetSlot
@onready var vest_slot: Button = $MainLayout/CharacterCol/SilhouetteArea/SlotsContainer/MidRow/VestSlot
@onready var backpack_slot: Button = $MainLayout/CharacterCol/SilhouetteArea/SlotsContainer/MidRow/BackpackSlot
@onready var bottom_slot: Button = $MainLayout/CharacterCol/SilhouetteArea/SlotsContainer/BotRow/BottomSlot

@onready var weapons_vbox: VBoxContainer = $MainLayout/WeaponsCol/Scroll/WeaponsVBox
@onready var close_btn: Button = $BottomBar/CloseBtn

var active_compact_tab: int = 1 # 0: Vicinity, 1: Inventory, 2: Character, 3: Weapons

var player: CharacterBody2D = null
var inventory_grid: InventoryGrid = null
var target_inventory: Inventory = null
var target_title: String = ""
var tooltip: PanelContainer = null
var context_menu_panel: PanelContainer = null

# 플레이어 장비 데이터 딕셔너리
# schema: { "helmet": {}, "vest": {}, "backpack": {}, "bottom": {}, "primary1": {}, "primary2": {}, "sidearm": {}, "throwable": {} }
var equipment_data: Dictionary = {}

# 드래그 앤 드롭 상태 추적
var is_dragging: bool = false
var drag_data: Dictionary = {} # { "source": "grid"|"vicinity"|"container"|"equipment"|"attachment", "item": {}, "rotated": bool, "origin_pos": Vector2i, "slot_name": "", "ground_ref": Node, "origin_index": int }
var drag_preview: Control = null

# 마우스 위치 및 2D 그리드 셀 좌표
var hovered_grid_cell: Vector2i = Vector2i(-1, -1)
var vicinity_update_timer: float = 0.0
var _last_vicinity_signature: String = ""

func _ready() -> void:
	InventoryUIHelper.init_cached_styleboxes()
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)
	tooltip.hide()
	
	# 캐릭터 장비 슬롯 버튼 시그널
	_connect_equipment_slot(helmet_slot, "helmet")
	_connect_equipment_slot(vest_slot, "vest")
	_connect_equipment_slot(backpack_slot, "backpack")
	_connect_equipment_slot(bottom_slot, "bottom")
	
	# 그리드 커스텀 드로잉 및 마우스 이벤트
	grid_control.draw.connect(_on_grid_draw)
	grid_control.gui_input.connect(_on_grid_gui_input)
	grid_control.mouse_exited.connect(func():
		hovered_grid_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		grid_control.queue_redraw()
	)
	
	# 탭 버튼 연결 (반응형 콤팩트 모드)
	if tab_vicinity_btn: tab_vicinity_btn.pressed.connect(func(): _set_compact_tab(0))
	if tab_inventory_btn: tab_inventory_btn.pressed.connect(func(): _set_compact_tab(1))
	if tab_character_btn: tab_character_btn.pressed.connect(func(): _set_compact_tab(2))
	if tab_weapons_btn: tab_weapons_btn.pressed.connect(func(): _set_compact_tab(3))
	
	if ResponsiveManager:
		ResponsiveManager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		ResponsiveManager.window_resized.connect(_on_responsive_window_resized)
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, ResponsiveManager.current_viewport_size)
	
	# 가방 자동 정렬 버튼 동적 추가
	var inv_header_hbox = get_node_or_null("MainLayout/InventoryCol/Header/HBox")
	if inv_header_hbox:
		var sort_btn = Button.new()
		sort_btn.name = "AutoSortBtn"
		sort_btn.text = "정렬"
		sort_btn.tooltip_text = "동일 아이템 병합 및 빈 공간 자동 정렬"
		sort_btn.custom_minimum_size = Vector2(56, 22)
		sort_btn.add_theme_font_size_override("font_size", 11)
		sort_btn.pressed.connect(func():
			if inventory_grid and inventory_grid.has_method("sort_items"):
				inventory_grid.sort_items()
				if SoundManager: SoundManager.play("menu_select")
		)
		inv_header_hbox.add_child(sort_btn)

	# 수색 대상 모두 획득 버튼 동적 추가
	if container_section:
		var loot_all_btn = Button.new()
		loot_all_btn.name = "LootAllBtn"
		loot_all_btn.theme_type_variation = &"PrimaryButton"
		loot_all_btn.text = "모두 획득 [F]   (Ctrl+클릭: 빠른 이동)"
		loot_all_btn.custom_minimum_size = Vector2(0, 30)
		loot_all_btn.add_theme_font_size_override("font_size", 11)
		loot_all_btn.pressed.connect(_loot_all_from_container)
		container_section.add_child(loot_all_btn)
		container_section.move_child(loot_all_btn, 1)
	
	_disable_focus_recursively(self)

func _on_responsive_breakpoint_changed(new_bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	_apply_responsive_layout(new_bp, vp_size)

func _on_responsive_window_resized(vp_size: Vector2) -> void:
	if ResponsiveManager:
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, vp_size)

func _set_compact_tab(tab_idx: int) -> void:
	active_compact_tab = tab_idx
	_update_compact_tab_display()

func _update_compact_tab_display() -> void:
	if not ResponsiveManager or not ResponsiveManager.is_compact():
		return
		
	# 탭 버튼 활성화 색상 피드백
	var tabs = [tab_vicinity_btn, tab_inventory_btn, tab_character_btn, tab_weapons_btn]
	for i in range(tabs.size()):
		if tabs[i]:
			if i == active_compact_tab:
				tabs[i].modulate = Color(1.2, 1.2, 1.2)
			else:
				tabs[i].modulate = Color(0.7, 0.7, 0.7)
				
	# 해당 컬럼만 표시
	if vicinity_col: vicinity_col.visible = (active_compact_tab == 0)
	if inventory_col: inventory_col.visible = (active_compact_tab == 1)
	if character_col: character_col.visible = (active_compact_tab == 2)
	if weapons_col: weapons_col.visible = (active_compact_tab == 3)

func _apply_responsive_layout(bp: ResponsiveManager.Breakpoint, _vp_size: Vector2) -> void:
	if bp == ResponsiveManager.Breakpoint.COMPACT:
		if compact_tab_bar: compact_tab_bar.show()
		if main_layout:
			main_layout.offset_top = 54.0
			main_layout.add_theme_constant_override("separation", 8)
		_update_compact_tab_display()
	else:
		if compact_tab_bar: compact_tab_bar.hide()
		if main_layout:
			main_layout.offset_top = 16.0
			main_layout.add_theme_constant_override("separation", 16)
		# 모든 컬럼 표시
		if vicinity_col: vicinity_col.show()
		if inventory_col: inventory_col.show()
		if character_col: character_col.show()
		if weapons_col: weapons_col.show()

func _disable_focus_recursively(node: Node) -> void:
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus_recursively(child)

func setup(p_player: CharacterBody2D, p_grid: InventoryGrid = null, p_equip: Dictionary = {}, p_target_inv: Inventory = null, p_target_title: String = "") -> void:
	player = p_player
	target_inventory = p_target_inv
	target_title = p_target_title
	
	if p_grid:
		inventory_grid = p_grid
	elif player and "inventory_grid" in player and player.inventory_grid:
		inventory_grid = player.inventory_grid
	else:
		inventory_grid = InventoryGrid.new()
		inventory_grid.grid_width = 6
		inventory_grid.grid_height = 4
		add_child(inventory_grid)
	if inventory_grid:
		inventory_grid.has_secure_container = true
		
	if not inventory_grid.grid_changed.is_connected(_on_grid_changed):
		inventory_grid.grid_changed.connect(_on_grid_changed)
		
	if target_inventory and not target_inventory.inventory_changed.is_connected(_update_container_list):
		target_inventory.inventory_changed.connect(_update_container_list)
		
	if player and "equipment" in player and not player.equipment.is_empty():
		equipment_data = player.equipment
	elif not p_equip.is_empty():
		equipment_data = p_equip
	else:
		equipment_data = {
			"helmet": {},
			"vest": {},
			"backpack": {"id": "1레벨_가방", "name": "1레벨 소형 배낭"},
			"bottom": {},
			"primary1": WeaponPartsDatabase.create_default_weapon("M4_리시버"),
			"primary2": {},
			"sidearm": WeaponPartsDatabase.create_default_weapon("M9_리시버"),
			"throwable": {"id": "수류탄", "amount": 2}
		}
		if player: player.set("equipment", equipment_data)
		
	# 무기 부품 키 "parts" 단일화 및 computed_stats 동기화
	for slot_k in ["primary1", "primary2", "sidearm"]:
		var w = equipment_data.get(slot_k, {})
		if not w.is_empty() and w is Dictionary:
			if not w.has("parts"):
				w["parts"] = w.get("attachments", {}).duplicate(true)
			w["attachments"] = w["parts"]
			equipment_data[slot_k] = WeaponPartsDatabase.compute_weapon_from_dict(w)
	_sync_weapon_to_player()
		
	_apply_backpack_grid_size()
	_refresh_all()

func _process(delta: float) -> void:
	vicinity_update_timer -= delta
	if vicinity_update_timer <= 0.0:
		vicinity_update_timer = 0.25 # 0.25초마다 주변 탐색 갱신
		_update_vicinity_list()
		
	if is_dragging and drag_preview:
		_update_drag_preview_pos()
		grid_control.queue_redraw()
	elif tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())

func _refresh_all() -> void:
	_update_grid_ui_size()
	_update_container_list()
	if is_inside_tree():
		_update_vicinity_list()
	_update_equipment_ui()
	_update_weapons_ui()
	_update_weight_ui()
	if grid_control:
		grid_control.queue_redraw()

func _on_grid_changed() -> void:
	_update_weight_ui()
	if grid_control:
		grid_control.queue_redraw()

# ============================================================
# 1. 타르코프식 2D 그리드 (WxH) 렌더링 및 인터랙션
# ============================================================
func _update_grid_ui_size() -> void:
	if not inventory_grid or not grid_control: return
	var total_w = inventory_grid.grid_width * CELL_SIZE
	var total_h = inventory_grid.grid_height * CELL_SIZE
	grid_control.custom_minimum_size = Vector2(total_w, total_h)
	if grid_title_label:
		grid_title_label.text = "BACKPACK // 가방 (%d×%d, %d칸)" % [inventory_grid.grid_width, inventory_grid.grid_height, inventory_grid.grid_width * inventory_grid.grid_height]

func _on_grid_draw() -> void:
	InventoryUIHelper.draw_2d_grid(grid_control, inventory_grid, hovered_grid_cell, true, is_dragging, drag_data, CELL_SIZE)

func _calc_grid_hover_cell(m_global_pos: Vector2) -> Vector2i:
	if not is_dragging or not inventory_grid:
		return Vector2i(-1, -1)
		
	var item = drag_data.get("item", {})
	var is_rot = drag_data.get("rotated", false)
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	var cur_w = item.get("h", base_size.y) if is_rot else item.get("w", base_size.x)
	var cur_h = item.get("w", base_size.x) if is_rot else item.get("h", base_size.y)
	
	var grid_rect = grid_control.get_global_rect()
	if grid_rect.has_point(m_global_pos):
		var local_pos = grid_control.get_local_mouse_position()
		var center_cell_x = int(local_pos.x / CELL_SIZE)
		var center_cell_y = int(local_pos.y / CELL_SIZE)
		
		# 1x1 이상의 아이템을 획득/드래그할 때 포커스를 좌상단이 아니라 중앙에 두기
		var offset_x = int(cur_w / 2)
		var offset_y = int(cur_h / 2)
		return Vector2i(center_cell_x - offset_x, center_cell_y - offset_y)
	return Vector2i(-1, -1)

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if is_instance_valid(context_menu_panel) and context_menu_panel.is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed:
			var m_pos = get_global_mouse_position()
			if not context_menu_panel.get_global_rect().has_point(m_pos):
				_close_context_menu()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_close_context_menu()
				get_viewport().set_input_as_handled()
				return

	# Tab, ESC, 인벤토리 단축키 입력 시 인벤토리 창 닫기 (포커스 상태와 무관하게 즉시 닫힘 보장)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB or event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE or event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
			if is_dragging:
				_end_drag()
			_close_context_menu()
			_on_close_pressed()
			get_viewport().set_input_as_handled()
			return
		elif not is_dragging and (event.keycode == KEY_F or event.physical_keycode == KEY_F) and target_inventory != null:
			_loot_all_from_container()
			get_viewport().set_input_as_handled()
			return
	
	# 드래그 중 R 키 누르면 W <-> H 회전
	if is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			drag_data["rotated"] = not drag_data.get("rotated", false)
			_rebuild_drag_preview()
			hovered_grid_cell = _calc_grid_hover_cell(get_global_mouse_position())
			if SoundManager: SoundManager.play("menu_move")
			grid_control.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	# 드래그 중 마우스 이동 시 실시간 그리드 좌표 갱신, 드래그 프리뷰 위치 및 슬롯 하이라이트 갱신
	if is_dragging and event is InputEventMouseMotion:
		var m_pos = get_global_mouse_position()
		_update_drag_preview_pos()
		hovered_grid_cell = _calc_grid_hover_cell(m_pos)
		grid_control.queue_redraw()
		
		# 마우스 아래의 장비/무기 슬롯 감지 및 하이라이트
		var hovered_target_ctrl: Control = null
		for target in drop_targets:
			var ctrl: Control = target.get("control")
			if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
				hovered_target_ctrl = ctrl
				break
		_highlight_compatible_slots(drag_data.get("item", {}), hovered_target_ctrl)
		
	# 드래그 중 마우스 버튼을 어디서든 뗐을 때 완벽한 드롭 처리
	if is_dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_global_drop()
		get_viewport().set_input_as_handled()

var drop_targets: Array[Dictionary] = []

func _handle_global_drop() -> void:
	if not is_dragging: return
	
	var m_pos = get_global_mouse_position()
	
	# 1. 2D 그리드 영역 위인지 검사 (중앙 포커스 좌표 반영)
	var grid_global_rect = grid_control.get_global_rect()
	if grid_global_rect.has_point(m_pos):
		var target_cell = _calc_grid_hover_cell(m_pos)
		if target_cell.x != -1 and target_cell.y != -1:
			_try_drop_on_grid(target_cell.x, target_cell.y)
		else:
			var local_pos = grid_control.get_local_mouse_position()
			var cell_x = int(local_pos.x / CELL_SIZE)
			var cell_y = int(local_pos.y / CELL_SIZE)
			_try_drop_on_grid(cell_x, cell_y)
		return
		
	# 2. 등록된 모든 장비/무기/부착물 슬롯 위인지 검사
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
			var t_type = target.get("type", "")
			if t_type == "equipment":
				_try_equip_dragged_item(target.get("slot_name", ""))
				return
			elif t_type == "weapon":
				_try_equip_weapon(target.get("slot_key", ""))
				return
			elif t_type == "attachment":
				_try_equip_attachment(target.get("weapon_slot_key", ""), target.get("attach_type", ""), target.get("rail_index", -1))
				return
				
	# 3. 수색 대상(ContainerSection) 위로 드롭했는지 검사
	if target_inventory and container_section.is_visible_in_tree() and container_section.get_global_rect().has_point(m_pos):
		_try_drop_on_container()
		return
			
	# 4. 주변(Vicinity) 컬럼으로 드롭했는지 검사 (오직 VICINITY 영역에 드롭했을 때만 월드에 버리기 허용)
	var vicinity_rect = vicinity_section.get_global_rect() if is_instance_valid(vicinity_section) else $MainLayout/VicinityCol.get_global_rect()
	if vicinity_rect.has_point(m_pos):
		var src = drag_data.get("source", "")
		var item = drag_data.get("item", {})
		if src == "grid":
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			_drop_item_to_world(item)
		elif src == "split":
			drag_data["is_split"] = false
			_drop_item_to_world(item)
		elif src == "equipment":
			equipment_data[drag_data.get("slot_name", "")] = {}
			_apply_backpack_grid_size()
			_update_equipment_ui()
			_drop_item_to_world(item)
		elif src == "weapon_slot":
			var w_slot_name = drag_data.get("slot_name", "")
			equipment_data[w_slot_name] = {}
			_sync_weapon_to_player(w_slot_name)
			_update_weapons_ui()
			_drop_item_to_world(item)
		elif src == "attachment":
			var w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", "primary1"))
			var a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
			var r_idx = drag_data.get("rail_index", item.get("rail_index", -1))
			if equipment_data.has(w_slot):
				var w_dict = equipment_data[w_slot]
				var w_parts = w_dict.get("parts", w_dict.get("attachments", {}))
				if w_parts.has(a_slot):
					var p_val = w_parts[a_slot]
					if p_val is Array:
						if r_idx >= 0 and r_idx < p_val.size():
							p_val.remove_at(r_idx)
						else:
							p_val.erase(item.get("id", ""))
						if p_val.is_empty(): w_parts.erase(a_slot)
					else:
						w_parts.erase(a_slot)
				w_dict["parts"] = w_parts
				w_dict["attachments"] = w_parts
				equipment_data[w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
				_clamp_weapon_excess_ammo(equipment_data[w_slot])
				_sync_weapon_to_player(w_slot)
			_update_weapons_ui()
			_drop_item_to_world(item)
		_end_drag()
		return
		
	# 5. 그 외 영역에 놓쳤을 경우 원래대로 복귀
	_end_drag()

func _on_grid_gui_input(event: InputEvent) -> void:
	var local_pos = grid_control.get_local_mouse_position()
	var cell_x = int(local_pos.x / CELL_SIZE)
	var cell_y = int(local_pos.y / CELL_SIZE)
	
	if event is InputEventMouseMotion:
		if is_dragging:
			hovered_grid_cell = _calc_grid_hover_cell(get_global_mouse_position())
		else:
			if cell_x >= 0 and cell_x < inventory_grid.grid_width and cell_y >= 0 and cell_y < inventory_grid.grid_height:
				hovered_grid_cell = Vector2i(cell_x, cell_y)
				var hovered_item = inventory_grid.get_item_at(cell_x, cell_y)
				if not hovered_item.is_empty():
					var idata = ItemDatabase.get_item_data(hovered_item.get("id", ""))
					tooltip.display_item(hovered_item, idata)
					tooltip.update_position(get_global_mouse_position())
				else:
					tooltip.hide()
			else:
				hovered_grid_cell = Vector2i(-1, -1)
				tooltip.hide()
		grid_control.queue_redraw()
		
	elif event is InputEventMouseButton and event.pressed:
		_close_context_menu()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if Input.is_key_pressed(KEY_CTRL):
					if tooltip: tooltip.hide()
					if target_inventory != null:
						_quick_transfer_grid_to_container(item)
					else:
						_handle_item_quick_action(item)
				elif Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
					_open_split_dialog(item, func(split_amt):
						var split_item = item.duplicate()
						split_item["uid"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
						split_item["amount"] = split_amt
						item["amount"] -= split_amt
						inventory_grid.grid_changed.emit()
						_start_drag("split", split_item, Vector2i(cell_x, cell_y))
						drag_data["is_split"] = true
						drag_data["split_source_item"] = item
						drag_data["split_amount"] = split_amt
					)
				else:
					_start_drag("grid", item, Vector2i(cell_x, cell_y))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if Input.is_key_pressed(KEY_ALT):
					_show_context_menu(item)
				else:
					_handle_item_quick_action(item)

func perform_item_repair(item: Dictionary, slot_ref: String = "") -> bool:
	if item.is_empty():
		return false
	var id = item.get("id", "")
	var idata = ItemDatabase.get_item_data(id)
	var item_name = idata.get("name", id)
	var max_dur = float(item.get("max_durability", idata.get("max_durability", 0.0)))
	var cur_dur = float(item.get("durability", max_dur))
	var missing_dur = max_dur - cur_dur
	if max_dur <= 0.0 or missing_dur <= 0.5:
		return false

	var is_field_repair: bool = (GameManager != null and GameManager.current_state == GameManager.GameState.IN_GAME)
	var cost_mult: float = 15.0 if is_field_repair else 10.0
	var repair_cost: int = int(ceil(missing_dur * cost_mult))
	if not _deduct_player_rubles(repair_cost):
		return false

	if is_field_repair:
		var new_max_dur = max(10.0, round(max_dur * 0.9))
		item["max_durability"] = new_max_dur
		item["durability"] = new_max_dur
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🛠️ [%s] 야전 응급 수리 완료! (-%d RUB, 최대 내구도 %.0f ➔ %.0f)" % [item_name, repair_cost, max_dur, new_max_dur])
	else:
		item["max_durability"] = max_dur
		item["durability"] = max_dur
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🔧 [%s] 은신처 정밀 수리 완료! (-%d RUB, 내구도 %.0f/%.0f)" % [item_name, repair_cost, max_dur, max_dur])

	if inventory_grid:
		inventory_grid.grid_changed.emit()
	if slot_ref != "":
		_sync_weapon_to_player(slot_ref)
	_update_weapons_ui()
	_update_equipment_ui()
	if SoundManager: SoundManager.play("craft_complete")
	return true

func _show_context_menu(item: Dictionary, source_type: String = "grid", slot_ref: String = "") -> void:
	_close_context_menu()
	var id = item.get("id", "")
	var idata = ItemDatabase.get_item_data(id)
	var item_name = idata.get("name", id)

	context_menu_panel = PanelContainer.new()
	context_menu_panel.name = "ContextMenuPanel"
	context_menu_panel.z_index = 300

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	sb.border_color = Color(0.35, 0.45, 0.60, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	context_menu_panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	context_menu_panel.add_child(vbox)

	var header_lbl = Label.new()
	header_lbl.text = item_name
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header_lbl)
	vbox.add_child(HSeparator.new())

	if source_type == "grid":
		var btn_use = Button.new()
		btn_use.text = "⚡ 사용 / 장착"
		btn_use.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_use.custom_minimum_size = Vector2(130, 24)
		btn_use.pressed.connect(func():
			_close_context_menu()
			_handle_item_quick_action(item, true)
		)
		vbox.add_child(btn_use)

		var amt = int(item.get("amount", 1))
		if amt > 1:
			var btn_split = Button.new()
			btn_split.text = "✂️ 수량 분할"
			btn_split.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn_split.custom_minimum_size = Vector2(130, 24)
			btn_split.pressed.connect(func():
				_close_context_menu()
				_open_split_dialog(item, func(split_amt):
					var split_item = item.duplicate()
					split_item["uid"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
					split_item["amount"] = split_amt
					item["amount"] -= split_amt
					inventory_grid.grid_changed.emit()
					_start_drag("split", split_item, Vector2i(item.get("x", 0), item.get("y", 0)))
					drag_data["is_split"] = true
					drag_data["split_source_item"] = item
					drag_data["split_amount"] = split_amt
				)
			)
			vbox.add_child(btn_split)
	elif source_type in ["equipment", "weapon_slot"] and slot_ref != "":
		var btn_unequip = Button.new()
		btn_unequip.text = "📤 가방으로 장착 해제"
		btn_unequip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_unequip.custom_minimum_size = Vector2(130, 24)
		btn_unequip.pressed.connect(func():
			_close_context_menu()
			var rem = inventory_grid.auto_add_item(item.get("id", ""), item.get("amount", 1), item) if inventory_grid else 1
			if rem <= 0:
				equipment_data[slot_ref] = {}
				if source_type == "equipment":
					_apply_backpack_grid_size()
					_update_equipment_ui()
				else:
					_sync_weapon_to_player(slot_ref)
					_update_weapons_ui()
				if SoundManager: SoundManager.play("menu_select")
		)
		vbox.add_child(btn_unequip)

	var has_parts = false
	var parts_dict: Dictionary = item.get("parts", item.get("attachments", {}))
	for pk in parts_dict.keys():
		var pv = parts_dict[pk]
		if pv is Array and not pv.is_empty(): has_parts = true; break
		elif pv != null and String(pv) != "": has_parts = true; break

	if has_parts:
		var btn_detach = Button.new()
		btn_detach.text = "🔩 부품 모두 분리"
		btn_detach.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_detach.custom_minimum_size = Vector2(130, 24)
		btn_detach.pressed.connect(func():
			_close_context_menu()
			_detach_all_item_parts(item)
			if source_type == "weapon_slot" and slot_ref != "":
				_sync_weapon_to_player(slot_ref)
				_update_weapons_ui()
		)
		vbox.add_child(btn_detach)

	# 총기 탄약 비우기 (Unload)
	var cur_mag_ammo = int(item.get("current_magazine_ammo", 0))
	var loaded_ammo_type = item.get("loaded_ammo", "")
	if cur_mag_ammo > 0 and loaded_ammo_type != "":
		var btn_unload = Button.new()
		btn_unload.text = "🔄 탄약 비우기 (%d발)" % cur_mag_ammo
		btn_unload.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_unload.custom_minimum_size = Vector2(130, 24)
		btn_unload.pressed.connect(func():
			_close_context_menu()
			var rem = inventory_grid.auto_add_item(loaded_ammo_type, cur_mag_ammo) if inventory_grid else cur_mag_ammo
			if rem > 0:
				_spawn_ground_item(loaded_ammo_type, rem)
			item["current_magazine_ammo"] = 0
			if inventory_grid:
				inventory_grid.grid_changed.emit()
			if source_type == "weapon_slot" and slot_ref != "":
				_sync_weapon_to_player(slot_ref)
				_update_weapons_ui()
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🔄 [%s] 탄약 %d발을 회수했습니다." % [item_name, cur_mag_ammo - rem])
		)
		vbox.add_child(btn_unload)

	# 손상된 장비 수리 (은신처 정가 수리 vs 인레이드 야전 응급 수리 차등화)
	var max_dur = float(item.get("max_durability", idata.get("max_durability", 0.0)))
	var cur_dur = float(item.get("durability", max_dur))
	var missing_dur = max_dur - cur_dur
	if max_dur > 0 and missing_dur > 0.5:
		var is_field_repair: bool = (GameManager != null and GameManager.current_state == GameManager.GameState.IN_GAME)
		var repair_cost = int(ceil(missing_dur * (15.0 if is_field_repair else 10.0)))
		var btn_repair = Button.new()
		if is_field_repair:
			btn_repair.text = "🛠️ 야전 응급 수리 (%d RUB | 최대 -10%%)" % repair_cost
		else:
			btn_repair.text = "🔧 수리하기 (%d RUB)" % repair_cost
		btn_repair.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_repair.custom_minimum_size = Vector2(130, 24)
		var user_funds = _get_player_rubles()
		if user_funds < repair_cost:
			btn_repair.disabled = true
			btn_repair.text += " (잔액 부족)"
		btn_repair.pressed.connect(func():
			_close_context_menu()
			perform_item_repair(item, slot_ref)
		)
		vbox.add_child(btn_repair)

	var btn_drop = Button.new()
	btn_drop.text = "🗑️ 바닥에 버리기"
	btn_drop.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_drop.custom_minimum_size = Vector2(130, 24)
	btn_drop.pressed.connect(func():
		_close_context_menu()
		if source_type == "grid" and inventory_grid:
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
		elif source_type == "equipment" and slot_ref != "":
			equipment_data[slot_ref] = {}
			_apply_backpack_grid_size()
			_update_equipment_ui()
		elif source_type == "weapon_slot" and slot_ref != "":
			equipment_data[slot_ref] = {}
			_sync_weapon_to_player(slot_ref)
			_update_weapons_ui()
		_drop_item_to_world(item)
	)
	vbox.add_child(btn_drop)

	add_child(context_menu_panel)
	var mpos = get_global_mouse_position() - global_position
	mpos.x = min(mpos.x, size.x - 170)
	mpos.y = min(mpos.y, size.y - 150)
	context_menu_panel.position = mpos

func _close_context_menu() -> void:
	if context_menu_panel:
		context_menu_panel.queue_free()
		context_menu_panel = null

func _spawn_ground_item(p_id: String, amount: int = 1) -> void:
	_drop_item_to_world({"id": p_id, "amount": amount})

func _detach_all_item_parts(item: Dictionary) -> void:
	var parts_dict: Dictionary = item.get("parts", item.get("attachments", {}))
	var detached_count = 0
	var dropped_count = 0
	for pk in parts_dict.keys():
		var pv = parts_dict[pk]
		if pv is Array:
			for sub_p in pv:
				var p_id = String(sub_p)
				if p_id != "":
					var rem = inventory_grid.auto_add_item(p_id, 1) if inventory_grid else 1
					if rem > 0:
						_spawn_ground_item(p_id, rem)
						dropped_count += rem
					else:
						detached_count += 1
		elif pv != null and String(pv) != "":
			var p_id = String(pv)
			var rem = inventory_grid.auto_add_item(p_id, 1) if inventory_grid else 1
			if rem > 0:
				_spawn_ground_item(p_id, rem)
				dropped_count += rem
			else:
				detached_count += 1
	item["parts"] = {}
	item["attachments"] = {}
	var computed = WeaponPartsDatabase.compute_weapon_from_dict(item)
	item.clear()
	for k in computed:
		item[k] = computed[k]
	var max_mag = int(item.get("computed_stats", {}).get("magazine_size", 10))
	var cur_mag = int(item.get("current_magazine_ammo", 0))
	if cur_mag > max_mag:
		var excess = cur_mag - max_mag
		var l_ammo = item.get("loaded_ammo", "")
		if excess > 0 and l_ammo != "":
			var rem = inventory_grid.auto_add_item(l_ammo, excess) if inventory_grid else excess
			if rem > 0:
				_spawn_ground_item(l_ammo, rem)
		item["current_magazine_ammo"] = max_mag
	if inventory_grid:
		inventory_grid.grid_changed.emit()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		if dropped_count > 0:
			EventBus.event_logged.emit("🔩 총기 부품 %d개를 가방에 넣고, 공간이 부족한 %d개는 바닥에 드랍했습니다." % [detached_count, dropped_count])
		else:
			EventBus.event_logged.emit("🔩 총기 부품 %d개를 모두 분리했습니다." % detached_count)

func _clamp_weapon_excess_ammo(w_dict: Dictionary) -> void:
	if w_dict.is_empty(): return
	var max_mag = int(w_dict.get("computed_stats", {}).get("magazine_size", 10))
	var cur_mag = int(w_dict.get("current_magazine_ammo", 0))
	if cur_mag > max_mag:
		var excess = cur_mag - max_mag
		var l_ammo = w_dict.get("loaded_ammo", "")
		if excess > 0 and l_ammo != "":
			var rem = inventory_grid.auto_add_item(l_ammo, excess) if inventory_grid else excess
			if rem > 0:
				_spawn_ground_item(l_ammo, rem)
		w_dict["current_magazine_ammo"] = max_mag

func _get_player_rubles() -> int:
	if GameManager and GameManager.current_world_data:
		var p_data = GameManager.current_world_data.get("player", {})
		if p_data.has("rubles"):
			return int(p_data["rubles"])
		if GameManager.current_world_data.has("rubles"):
			return int(GameManager.current_world_data["rubles"])
	return 0

func _deduct_player_rubles(cost: int) -> bool:
	if GameManager and GameManager.current_world_data:
		var p_data = GameManager.current_world_data.get("player", {})
		if p_data.has("rubles"):
			var cur = int(p_data["rubles"])
			if cur >= cost:
				p_data["rubles"] = cur - cost
				return true
		elif GameManager.current_world_data.has("rubles"):
			var cur = int(GameManager.current_world_data["rubles"])
			if cur >= cost:
				GameManager.current_world_data["rubles"] = cur - cost
				return true
	return false

func _try_drop_on_grid(cell_x: int, cell_y: int) -> void:
	if not is_dragging: return
	
	var item = drag_data.get("item", {})
	var is_rot = drag_data.get("rotated", false)
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	var base_w = item.get("w", base_size.x)
	var base_h = item.get("h", base_size.y)
	var place_w = base_h if is_rot else base_w
	var place_h = base_w if is_rot else base_h
	
	var src = drag_data.get("source", "")
	var uid = item.get("uid", "")
	var ignore_uid = uid if src == "grid" else ""
	
	# 1. 같은 아이템 위로 드롭했을 때 중첩 (스택 병합) 처리
	var m_local = grid_control.get_local_mouse_position()
	var mouse_cx = int(m_local.x / CELL_SIZE)
	var mouse_cy = int(m_local.y / CELL_SIZE)
	var target_item = inventory_grid.get_item_at(mouse_cx, mouse_cy)
	if target_item.is_empty():
		target_item = inventory_grid.get_item_at(cell_x, cell_y)
		
	if not target_item.is_empty() and target_item.get("id", "") == item.get("id", "") and target_item.get("uid", "") != uid:
		var item_data = ItemDatabase.get_item_data(item.get("id", ""))
		var max_stack = int(item_data.get("max_stack", 1))
		if max_stack > 1:
			var cur_amt = int(target_item.get("amount", 1))
			var space = max_stack - cur_amt
			if space > 0:
				var drag_amt = int(item.get("amount", 1))
				var to_add = min(space, drag_amt)
				target_item["amount"] = cur_amt + to_add
				var rem_amt = drag_amt - to_add
				
				if rem_amt <= 0:
					if src == "grid":
						inventory_grid.remove_item_by_uid(uid)
					elif src == "split":
						drag_data["is_split"] = false
					elif src == "container":
						var orig_idx = drag_data.get("origin_index", -1)
						if orig_idx != -1 and target_inventory:
							target_inventory.remove_item_at(orig_idx, drag_amt)
							_update_container_list()
					elif src == "vicinity":
						var ground_node = drag_data.get("ground_ref")
						if is_instance_valid(ground_node): ground_node.queue_free()
						_update_vicinity_list(true)
					elif src == "equipment":
						var s_name = drag_data.get("slot_name", "")
						equipment_data[s_name] = {}
						_apply_backpack_grid_size()
						_update_equipment_ui()
					elif src == "weapon_slot":
						var s_name = drag_data.get("slot_name", "")
						equipment_data[s_name] = {}
						_update_weapons_ui()
					elif src == "attachment":
						var w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", "primary1"))
						var a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
						var r_idx = drag_data.get("rail_index", item.get("rail_index", -1))
						if equipment_data.has(w_slot):
							var w_dict = equipment_data[w_slot]
							var w_parts = w_dict.get("parts", w_dict.get("attachments", {}))
							if w_parts.has(a_slot):
								var p_val = w_parts[a_slot]
								if p_val is Array:
									if r_idx >= 0 and r_idx < p_val.size():
										p_val.remove_at(r_idx)
									else:
										p_val.erase(item.get("id", ""))
									if p_val.is_empty(): w_parts.erase(a_slot)
								else:
									w_parts.erase(a_slot)
							w_dict["parts"] = w_parts
							w_dict["attachments"] = w_parts
							equipment_data[w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
							_clamp_weapon_excess_ammo(equipment_data[w_slot])
							_sync_weapon_to_player(w_slot)
						_update_weapons_ui()
				else:
					item["amount"] = rem_amt
					if src == "grid":
						var orig_it = inventory_grid.get_item_by_uid(uid)
						if not orig_it.is_empty(): orig_it["amount"] = rem_amt
					elif src == "split":
						var orig_sp = drag_data.get("split_source_item", {})
						if not orig_sp.is_empty():
							orig_sp["amount"] = int(orig_sp.get("amount", 0)) + rem_amt
						drag_data["is_split"] = false
					elif src == "container":
						var orig_idx = drag_data.get("origin_index", -1)
						if orig_idx != -1 and target_inventory:
							target_inventory.remove_item_at(orig_idx, to_add)
							_update_container_list()
					elif src == "vicinity":
						var ground_node = drag_data.get("ground_ref")
						if is_instance_valid(ground_node):
							ground_node.amount = rem_amt
							ground_node.update_visuals()
						_update_vicinity_list(true)
						
				inventory_grid.consolidate_stacks()
				inventory_grid.grid_changed.emit()
				if SoundManager: SoundManager.play("menu_select")
				_end_drag()
				return
	
	# 2. 빈 공간 배치 시도
	if inventory_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item.get("id", "")):
		if src == "grid":
			inventory_grid.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
		elif src == "split":
			if inventory_grid.place_item(item, cell_x, cell_y, is_rot):
				drag_data["is_split"] = false
				if SoundManager: SoundManager.play("menu_select")
			else:
				if SoundManager: SoundManager.play("hit_melee")
		else:
			if inventory_grid.place_item(item, cell_x, cell_y, is_rot):
				if src == "vicinity":
					var ground_node = drag_data.get("ground_ref")
					if is_instance_valid(ground_node):
						ground_node.queue_free()
				elif src == "container":
					var orig_idx = drag_data.get("origin_index", -1)
					if orig_idx != -1 and target_inventory:
						target_inventory.remove_item_at(orig_idx, item.get("amount", 1))
						_update_container_list()
				elif src == "equipment":
					var s_name = drag_data.get("slot_name", "")
					equipment_data[s_name] = {}
					_apply_backpack_grid_size()
					_update_equipment_ui()
				elif src == "weapon_slot":
					var s_name = drag_data.get("slot_name", "")
					equipment_data[s_name] = {}
					_sync_weapon_to_player(s_name)
					_update_weapons_ui()
				elif src == "attachment":
					var w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", "primary1"))
					var a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
					var r_idx = drag_data.get("rail_index", item.get("rail_index", -1))
					if equipment_data.has(w_slot):
						var w_dict = equipment_data[w_slot]
						var w_parts = w_dict.get("parts", w_dict.get("attachments", {}))
						if w_parts.has(a_slot):
							var p_val = w_parts[a_slot]
							if p_val is Array:
								if r_idx >= 0 and r_idx < p_val.size():
									p_val.remove_at(r_idx)
								else:
									p_val.erase(item.get("id", ""))
								if p_val.is_empty(): w_parts.erase(a_slot)
							else:
								w_parts.erase(a_slot)
						w_dict["parts"] = w_parts
						w_dict["attachments"] = w_parts
						equipment_data[w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
						_clamp_weapon_excess_ammo(equipment_data[w_slot])
						_sync_weapon_to_player(w_slot)
					_update_weapons_ui()
					
				if SoundManager: SoundManager.play("menu_select")
			else:
				if SoundManager: SoundManager.play("hit_melee")
	else:
		# 배치 실패 -> 원위치
		if SoundManager: SoundManager.play("hit_melee")
		
	_end_drag()

# ============================================================
# 2. 수색 대상(Container) & 주변(Vicinity) 탐색 & 월드 드롭/픽업
# ============================================================
func _update_container_list() -> void:
	if not is_instance_valid(container_section): return
	
	if not target_inventory:
		container_section.visible = false
		return
		
	container_section.visible = true
	container_title_label.text = "CONTAINER // " + (target_title if target_title != "" else "수색 대상")
	
	for c in container_list.get_children():
		if c != container_empty_label:
			c.queue_free()
			
	var has_items = false
	for i in range(target_inventory.items.size()):
		var slot_item = target_inventory.items[i]
		if slot_item != null and not slot_item.is_empty() and slot_item.get("id", "") != "":
			has_items = true
			_create_container_entry(slot_item, i)
			
	container_empty_label.visible = not has_items

func _create_container_entry(slot_item: Dictionary, index: int) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ItemIconManager: icon.texture = ItemIconManager.get_icon(slot_item.get("id", ""))
	hbox.add_child(icon)
	
	var lbl = Label.new()
	var d = ItemDatabase.get_item_data(slot_item.get("id", ""))
	var amt = slot_item.get("amount", 1)
	lbl.text = "%s %s" % [d.get("name", slot_item.get("id", "")), ("(x%d)" % amt if amt > 1 else "")]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	
	# 툴팁 표시
	btn.mouse_entered.connect(func():
		if not is_dragging and tooltip:
			tooltip.display_item(slot_item, d)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	
	# 드래그 및 우클릭/Ctrl+좌클릭 픽업
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL)):
				var rem = inventory_grid.auto_add_item(slot_item.get("id", ""), amt, slot_item)
				var added = amt - rem
				if added > 0:
					target_inventory.remove_item_at(index, added)
					if SoundManager: SoundManager.play("menu_select")
					_update_container_list()
				if rem > 0 and EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var base_size = ItemDatabase.get_item_grid_size(slot_item.get("id", ""))
				var item_dict = {
					"id": slot_item.get("id", ""),
					"amount": amt,
					"w": base_size.x,
					"h": base_size.y,
					"custom_data": slot_item.duplicate(true)
				}
				var slot_cdata = slot_item.get("custom_data", {})
				for k in ["parts", "attachments", "loaded_ammo", "current_magazine_ammo", "computed_stats", "durability", "max_durability", "receiver", "name", "type"]:
					if slot_item.has(k):
						item_dict[k] = slot_item[k]
					elif slot_cdata is Dictionary and slot_cdata.has(k):
						item_dict[k] = slot_cdata[k]
				_start_drag("container", item_dict, Vector2i(index, 0))
				drag_data["origin_index"] = index
	)
	
	container_list.add_child(btn)

func _loot_all_from_container() -> void:
	if not target_inventory or not inventory_grid:
		return
	var moved_any = false
	var full_warn = false
	for i in range(target_inventory.items.size() - 1, -1, -1):
		var slot_item = target_inventory.items[i]
		if slot_item != null and not slot_item.is_empty() and slot_item.get("id", "") != "":
			var amt = int(slot_item.get("amount", 1))
			var rem = inventory_grid.auto_add_item(slot_item.get("id", ""), amt, slot_item)
			var added = amt - rem
			if added > 0:
				target_inventory.remove_item_at(i, added)
				moved_any = true
			if rem > 0:
				full_warn = true
	if moved_any:
		if inventory_grid.has_method("consolidate_stacks"):
			inventory_grid.consolidate_stacks()
		if SoundManager: SoundManager.play("item_pickup")
		_update_container_list()
	if full_warn and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("⚠️ 가방 공간이 부족하여 일부 아이템만 획득했습니다.")

func _quick_transfer_grid_to_container(item: Dictionary) -> void:
	if not target_inventory or not inventory_grid:
		return
	var item_id = item.get("id", "")
	var amt = int(item.get("amount", 1))
	var rem = target_inventory.add_item(item_id, amt, item)
	var added = amt - rem
	if added > 0:
		if rem <= 0:
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
		else:
			item["amount"] = rem
			inventory_grid.grid_changed.emit()
		if SoundManager: SoundManager.play("menu_select")
		_update_container_list()
	else:
		if SoundManager: SoundManager.play("hit_melee")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 보관함 공간이 부족합니다.")

func _try_drop_on_container() -> void:
	if not target_inventory:
		_end_drag()
		return
		
	var src = drag_data.get("source", "")
	var item = drag_data.get("item", {})
	var item_id = item.get("id", "")
	var amt = item.get("amount", 1)
	
	var rem = target_inventory.add_item(item_id, amt, item)
	var added = amt - rem
	
	if added > 0:
		if src == "grid":
			if rem <= 0:
				inventory_grid.remove_item_by_uid(item.get("uid", ""))
			else:
				item["amount"] = rem
				inventory_grid.grid_changed.emit()
		elif src == "split":
			if rem > 0:
				var orig_item = drag_data.get("split_source_item", {})
				if not orig_item.is_empty():
					orig_item["amount"] = int(orig_item.get("amount", 0)) + rem
					inventory_grid.grid_changed.emit()
			drag_data["is_split"] = false
		elif src == "equipment":
			if rem <= 0:
				equipment_data[drag_data.get("slot_name", "")] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
			else:
				item["amount"] = rem
		elif src == "weapon_slot":
			if rem <= 0:
				var s_name = drag_data.get("slot_name", "")
				equipment_data[s_name] = {}
				_sync_weapon_to_player(s_name)
				_update_weapons_ui()
			else:
				item["amount"] = rem
		elif src == "attachment":
			if rem <= 0:
				var w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", "primary1"))
				var a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
				var r_idx = drag_data.get("rail_index", item.get("rail_index", -1))
				if equipment_data.has(w_slot):
					var w_dict = equipment_data[w_slot]
					var w_parts = w_dict.get("parts", w_dict.get("attachments", {}))
					if w_parts.has(a_slot):
						var p_val = w_parts[a_slot]
						if p_val is Array:
							if r_idx >= 0 and r_idx < p_val.size():
								p_val.remove_at(r_idx)
							else:
								p_val.erase(item.get("id", ""))
							if p_val.is_empty(): w_parts.erase(a_slot)
						else:
							w_parts.erase(a_slot)
					w_dict["parts"] = w_parts
					w_dict["attachments"] = w_parts
					equipment_data[w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
					_clamp_weapon_excess_ammo(equipment_data[w_slot])
					_sync_weapon_to_player(w_slot)
				_update_weapons_ui()
		elif src == "vicinity":
			var ground_node = drag_data.get("ground_ref")
			if is_instance_valid(ground_node):
				if rem <= 0:
					ground_node.queue_free()
				else:
					ground_node.amount = rem
					ground_node.update_visuals()
					
		if SoundManager: SoundManager.play("menu_select")
		_update_container_list()
	else:
		if SoundManager: SoundManager.play("hit_melee")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 보관함 공간이 부족합니다.")
			
	_end_drag()

func _update_vicinity_list(force_rebuild: bool = false) -> void:
	if not is_inside_tree() or not get_tree(): return
	var p_pos = player.global_position if player else Vector2.ZERO
	var ground_items = get_tree().get_nodes_in_group("ground_items")
	var nearby_items: Array = []
	var sig_parts: PackedStringArray = PackedStringArray()
	
	for g_item in ground_items:
		if is_instance_valid(g_item) and g_item is GroundItem:
			var dist = p_pos.distance_to(g_item.global_position)
			if dist <= 140.0: # 반경 약 140px 내 아이템
				nearby_items.append(g_item)
				sig_parts.append("%d:%s:%d" % [g_item.get_instance_id(), g_item.item_id, g_item.amount])
				
	var new_sig = "|".join(sig_parts)
	if not force_rebuild and new_sig == _last_vicinity_signature:
		return
	_last_vicinity_signature = new_sig
	
	for c in vicinity_list.get_children():
		if c != vicinity_empty_label:
			c.queue_free()
				
	if nearby_items.is_empty():
		vicinity_empty_label.visible = true
	else:
		vicinity_empty_label.visible = false
		for g_item in nearby_items:
			_create_vicinity_entry(g_item)

func _create_vicinity_entry(g_item: GroundItem) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ItemIconManager: icon.texture = ItemIconManager.get_icon(g_item.item_id)
	hbox.add_child(icon)
	
	var lbl = Label.new()
	var d = ItemDatabase.get_item_data(g_item.item_id)
	lbl.text = "%s %s" % [d.get("name", g_item.item_id), ("(x%d)" % g_item.amount if g_item.amount > 1 else "")]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	
	# 툴팁 표시
	btn.mouse_entered.connect(func():
		if not is_dragging and tooltip:
			var item_dict = {
				"id": g_item.item_id,
				"amount": g_item.amount,
				"custom_data": g_item.custom_data
			}
			tooltip.display_item(item_dict, d)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	
	# 드래그 및 우클릭/Ctrl+좌클릭 픽업
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_CTRL)):
				var rem = inventory_grid.auto_add_item(g_item.item_id, g_item.amount, g_item.custom_data)
				if rem <= 0:
					g_item.queue_free()
					if SoundManager: SoundManager.play("menu_select")
					_update_vicinity_list(true)
				else:
					g_item.amount = rem
					g_item.update_visuals()
					_update_vicinity_list(true)
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var base_size = ItemDatabase.get_item_grid_size(g_item.item_id)
				var item_dict = {
					"id": g_item.item_id,
					"amount": g_item.amount,
					"w": base_size.x,
					"h": base_size.y,
					"custom_data": g_item.custom_data.duplicate(true) if g_item.custom_data is Dictionary else {}
				}
				if g_item.custom_data is Dictionary:
					for k in ["parts", "attachments", "loaded_ammo", "current_magazine_ammo", "computed_stats", "durability", "max_durability", "receiver", "name", "type"]:
						if g_item.custom_data.has(k):
							item_dict[k] = g_item.custom_data[k]
				_start_drag("vicinity", item_dict, Vector2i.ZERO, "", g_item)
	)
	
	vicinity_list.add_child(btn)

func _drop_item_to_world(item: Dictionary) -> void:
	if not player: return
	
	var g_item = GroundItemScene.instantiate()
	g_item.global_position = player.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	
	var world_node = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if world_node and world_node.has_node("Entities"):
		world_node.get_node("Entities").add_child(g_item)
	elif world_node:
		world_node.add_child(g_item)
	elif is_inside_tree() and get_tree() and get_tree().root:
		get_tree().root.add_child(g_item)
	elif player.get_parent():
		player.get_parent().add_child(g_item)
	else:
		g_item.free()
		return
	
	var drop_data: Dictionary = item.duplicate(true)
	for transient_k in ["uid", "x", "y", "rotated", "w", "h"]:
		drop_data.erase(transient_k)
	g_item.setup(item.get("id", ""), item.get("amount", 1), drop_data)
	
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📦 %s을(를) 바닥에 버렸습니다." % ItemDatabase.get_item_data(item.get("id", "")).get("name", item.get("id", "")))
	if is_inside_tree():
		_update_vicinity_list(true)

# ============================================================
# 3. 캐릭터 장비 슬롯 & 가방 용량 연동
# ============================================================
func _connect_equipment_slot(btn: Button, slot_name: String) -> void:
	btn.mouse_entered.connect(func():
		if not is_dragging and tooltip:
			var equipped = equipment_data.get(slot_name, {})
			if not equipped.is_empty():
				var idata = ItemDatabase.get_item_data(equipped.get("id", ""))
				tooltip.display_item(equipped, idata)
				tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_dragging:
					_try_equip_dragged_item(slot_name)
				else:
					var equipped = equipment_data.get(slot_name, {})
					if not equipped.is_empty():
						_start_drag("equipment", equipped, Vector2i.ZERO, slot_name)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var equipped = equipment_data.get(slot_name, {})
				if not equipped.is_empty():
					if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
						if tooltip: tooltip.hide()
						_show_context_menu(equipped, "equipment", slot_name)
					else:
						# 우클릭 시 가방으로 탈착
						var rem = inventory_grid.auto_add_item(equipped.get("id", ""), equipped.get("amount", 1), equipped)
						if rem <= 0:
							equipment_data[slot_name] = {}
							_apply_backpack_grid_size()
							_update_equipment_ui()
							if SoundManager: SoundManager.play("menu_select")
	)

func _try_equip_dragged_item(slot_name: String) -> void:
	var item = drag_data.get("item", {})
	var item_id = item.get("id", "")
	
	if not _is_slot_compatible(item_id, slot_name):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ [%s] 슬롯에 장착할 수 없는 아이템입니다." % slot_name)
		_end_drag()
		return
		
	var src = drag_data.get("source", "")
	var orig_slot = drag_data.get("slot_name", "")
	
	# 같은 장비 슬롯에 다시 드롭한 경우 -> 복제 방지 및 그대로 유지
	if src == "equipment" and orig_slot == slot_name:
		_end_drag()
		return
		
	if src == "grid":
		inventory_grid.remove_item_by_uid(item.get("uid", ""))
	elif src == "vicinity":
		var ground_node = drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx = drag_data.get("origin_index", -1)
		if orig_idx != -1 and target_inventory:
			target_inventory.remove_item_at(orig_idx, item.get("amount", 1))
			_update_container_list()
	elif src == "equipment":
		equipment_data[orig_slot] = {}
		
	var prev_equipped = equipment_data.get(slot_name, {})
	equipment_data[slot_name] = item
	
	if not prev_equipped.is_empty():
		inventory_grid.auto_add_item(prev_equipped.get("id", ""), prev_equipped.get("amount", 1), prev_equipped)
		
	_apply_backpack_grid_size()
	_update_equipment_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

func _is_slot_compatible(item_id: String, slot_name: String) -> bool:
	return InventoryUIHelper.is_slot_compatible(item_id, slot_name)

func _apply_backpack_grid_size() -> void:
	var bp = equipment_data.get("backpack", {})
	var new_w = 6
	var new_h = 3
	
	if not bp.is_empty():
		var id = bp.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var b_grid = d.get("backpack_grid", Vector2i(6, 5))
		new_w = b_grid.x
		new_h = b_grid.y
		
	if inventory_grid:
		var dropped = inventory_grid.resize_grid(new_w, new_h)
		for it in dropped:
			_drop_item_to_world(it)
	_update_grid_ui_size()

func _update_equipment_ui() -> void:
	_render_equip_slot_button(helmet_slot, "helmet", "HEAD\n헬멧")
	_render_equip_slot_button(vest_slot, "vest", "RIG\n방탄복")
	_render_equip_slot_button(backpack_slot, "backpack", "PACK\n배낭")
	_render_equip_slot_button(bottom_slot, "bottom", "BOOTS\n전술화")
	
	_rebuild_drop_targets()
	
	# 플레이어 장비 및 방어력 스탯 동기화
	if player:
		player.set("equipment", equipment_data)
		if player.has_signal("stats_changed"):
			player.stats_changed.emit()

func _rebuild_drop_targets() -> void:
	drop_targets.clear()
	drop_targets.append({"control": helmet_slot, "type": "equipment", "slot_name": "helmet"})
	drop_targets.append({"control": vest_slot, "type": "equipment", "slot_name": "vest"})
	drop_targets.append({"control": backpack_slot, "type": "equipment", "slot_name": "backpack"})
	drop_targets.append({"control": bottom_slot, "type": "equipment", "slot_name": "bottom"})

func _render_equip_slot_button(btn: Button, slot_name: String, default_text: String) -> void:
	InventoryUIHelper.render_equip_slot_button(btn, slot_name, default_text, equipment_data)

# ============================================================
# 4. 무기 슬롯 & 부착물 서브 슬롯 모딩
# ============================================================
func _sync_weapon_to_player(slot_key: String = "") -> void:
	if player:
		player.set("equipment", equipment_data)
		if "weapon_handler" in player and player.weapon_handler:
			player.weapon_handler.equipment = equipment_data
			if slot_key == "" or player.weapon_handler.active_weapon_slot == slot_key:
				player.weapon_handler.switch_weapon_slot(player.weapon_handler.active_weapon_slot)
		if "player_visuals" in player and player.player_visuals:
			player.player_visuals.queue_redraw()

func _update_weapons_ui() -> void:
	if not weapons_vbox:
		return
	for c in weapons_vbox.get_children():
		c.queue_free()
		
	_rebuild_drop_targets()
	_create_weapon_card("주무기 1", "primary1", equipment_data.get("primary1", {}))
	_create_weapon_card("주무기 2", "primary2", equipment_data.get("primary2", {}))
	_create_weapon_card("보조 무기", "sidearm", equipment_data.get("sidearm", {}))
	_create_weapon_card("투척 무기", "throwable", equipment_data.get("throwable", {}))

func _create_weapon_card(title: String, slot_key: String, weapon_dict: Dictionary) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	style.border_width_left = 3
	style.border_color = Color(0.9, 0.4, 0.4) if slot_key.begins_with("primary") else Color(0.4, 0.7, 1.0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# 상단 헤더 & 메인 무기 버튼
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "[%s]" % title
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	top_hbox.add_child(title_lbl)
	
	var wep_btn = Button.new()
	wep_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wep_btn.custom_minimum_size = Vector2(0, 32)
	wep_btn.focus_mode = Control.FOCUS_NONE
	
	if weapon_dict.is_empty():
		wep_btn.text = "장착된 무기 없음 (드래그하여 장착)"
	else:
		var d = ItemDatabase.get_item_data(weapon_dict.get("id", ""))
		var w_name = d.get("name", weapon_dict.get("id", ""))
		var stats = weapon_dict.get("computed_stats", {})
		var max_mag = int(stats.get("magazine_size", weapon_dict.get("magazine_size", 10)))
		var cur_mag = int(weapon_dict.get("current_magazine_ammo", 0))
		var l_ammo = weapon_dict.get("loaded_ammo", "")
		var ammo_name = l_ammo.replace("_탄약", "").replace("탄약", "") if l_ammo != "" else "없음"
		var info_str = ""
		if max_mag > 0 or l_ammo != "":
			info_str = " [%s | %d/%d발]" % [ammo_name, cur_mag, max_mag]
		wep_btn.text = "%s%s" % [w_name, info_str]
		if ItemIconManager: wep_btn.icon = ItemIconManager.get_icon(weapon_dict.get("id", ""))
	top_hbox.add_child(wep_btn)
	
	if not weapon_dict.is_empty():
		var d = ItemDatabase.get_item_data(weapon_dict.get("id", ""))
		var max_dur = float(weapon_dict.get("max_durability", d.get("max_durability", 100.0)))
		var cur_dur = float(weapon_dict.get("durability", max_dur))
		if max_dur > 0:
			var dur_bar = ProgressBar.new()
			dur_bar.custom_minimum_size = Vector2(0, 4)
			dur_bar.show_percentage = false
			dur_bar.max_value = max_dur
			dur_bar.value = cur_dur
			var dur_style = StyleBoxFlat.new()
			var ratio = cur_dur / max_dur
			dur_style.bg_color = Color(0.2, 0.85, 0.3) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
			dur_bar.add_theme_stylebox_override("fill", dur_style)
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
			dur_bar.add_theme_stylebox_override("background", bg_style)
			vbox.add_child(dur_bar)
	
	wep_btn.mouse_entered.connect(func():
		if not is_dragging and tooltip and not weapon_dict.is_empty():
			var d = ItemDatabase.get_item_data(weapon_dict.get("id", ""))
			tooltip.display_item(weapon_dict, d)
			tooltip.update_position(get_global_mouse_position())
	)
	wep_btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
	
	# 드롭 타겟 등록
	drop_targets.append({"control": wep_btn, "type": "weapon", "slot_key": slot_key})
	
	# 무기 슬롯 드래그/우클릭
	wep_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_dragging:
					_try_equip_weapon(slot_key)
				elif not weapon_dict.is_empty():
					if tooltip: tooltip.hide()
					_start_drag("weapon_slot", weapon_dict, Vector2i.ZERO, slot_key)
			elif event.button_index == MOUSE_BUTTON_RIGHT and not weapon_dict.is_empty():
				if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
					if tooltip: tooltip.hide()
					_show_context_menu(weapon_dict, "weapon_slot", slot_key)
				else:
					# 우클릭 시 가방으로 탈착
					var rem = inventory_grid.auto_add_item(weapon_dict.get("id", ""), weapon_dict.get("amount", 1), weapon_dict)
					if rem <= 0:
						equipment_data[slot_key] = {}
						_sync_weapon_to_player(slot_key)
						_update_weapons_ui()
						if tooltip: tooltip.hide()
						if SoundManager: SoundManager.play("menu_select")
	)
	
	# 총기일 경우 부착물 서브 슬롯 노출 (주무기 및 보조무기 sidearm 지원, barrel 및 rail 포함)
	if not weapon_dict.is_empty() and (slot_key.begins_with("primary") or slot_key == "sidearm"):
		var raw_id = weapon_dict.get("receiver", weapon_dict.get("id", ""))
		var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
		var receiver_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
		var allowed_slots = receiver_data.get("slots", {})
		
		var attach_hbox = HBoxContainer.new()
		attach_hbox.add_theme_constant_override("separation", 4)
		vbox.add_child(attach_hbox)
		
		var attach_dict = weapon_dict.get("parts", weapon_dict.get("attachments", {}))
		for a_type in ["barrel", "optic", "muzzle", "grip", "magazine", "stock", "rail"]:
			if not allowed_slots.is_empty() and not allowed_slots.has(a_type):
				continue
			var cur_p = attach_dict.get(a_type, "")
			if a_type == "rail":
				var rail_slots_count = int(allowed_slots.get("rail", 1))
				var cur_rail_arr: Array = cur_p if (cur_p is Array) else ([String(cur_p)] if String(cur_p) != "" else [])
				for r_i in range(rail_slots_count):
					var r_part_id = cur_rail_arr[r_i] if r_i < cur_rail_arr.size() else ""
					_create_attachment_sub_slot(attach_hbox, slot_key, "rail", r_part_id, r_i)
			else:
				var cur_p_str = String(cur_p[0]) if (cur_p is Array and not cur_p.is_empty()) else String(cur_p)
				_create_attachment_sub_slot(attach_hbox, slot_key, a_type, cur_p_str, -1)
			
	weapons_vbox.add_child(panel)

func _create_attachment_sub_slot(parent: HBoxContainer, weapon_slot_key: String, attach_type: String, current_part_id: String, rail_index: int = -1) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(58, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	
	var slot_labels = {
		"barrel": "총열", "optic": "조준경", "muzzle": "총구", "grip": "손잡이", "magazine": "탄창", "stock": "개머리판", "rail": "레일"
	}
	
	if current_part_id == "":
		if attach_type == "rail" and rail_index >= 0:
			btn.text = "레일%d" % (rail_index + 1)
		else:
			btn.text = slot_labels.get(attach_type, attach_type)
		btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		btn.add_theme_font_size_override("font_size", 10)
	else:
		var p_data = WeaponPartsDatabase.PARTS.get(current_part_id, {})
		btn.text = p_data.get("name", current_part_id)
		btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		btn.add_theme_font_size_override("font_size", 10)
		
	drop_targets.append({"control": btn, "type": "attachment", "weapon_slot_key": weapon_slot_key, "attach_type": attach_type, "rail_index": rail_index})
		
	btn.mouse_entered.connect(func():
		if not is_dragging and tooltip and current_part_id != "":
			var p_data = WeaponPartsDatabase.PARTS.get(current_part_id, {})
			var fake_item = {"id": current_part_id, "name": p_data.get("name", current_part_id)}
			tooltip.display_item(fake_item, p_data)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)
		
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_dragging:
					_try_equip_attachment(weapon_slot_key, attach_type, rail_index)
				elif current_part_id != "":
					if tooltip: tooltip.hide()
					var part_dict = {
						"id": current_part_id,
						"part_slot": attach_type,
						"attach_slot": attach_type,
						"rail_index": rail_index,
						"weapon_slot": weapon_slot_key,
						"amount": 1
					}
					_start_drag("attachment", part_dict)
					drag_data["weapon_slot"] = weapon_slot_key
					drag_data["attach_slot"] = attach_type
					drag_data["part_slot"] = attach_type
					drag_data["rail_index"] = rail_index
			elif event.button_index == MOUSE_BUTTON_RIGHT and current_part_id != "":
				# 부착물 가방으로 탈착
				var rem = inventory_grid.auto_add_item(current_part_id, 1)
				if rem <= 0:
					var w_dict = equipment_data.get(weapon_slot_key, {})
					var w_parts = w_dict.get("parts", w_dict.get("attachments", {}))
					if w_parts.has(attach_type):
						var p_val = w_parts[attach_type]
						if p_val is Array:
							if rail_index >= 0 and rail_index < p_val.size():
								p_val.remove_at(rail_index)
							else:
								p_val.erase(current_part_id)
							if p_val.is_empty(): w_parts.erase(attach_type)
						else:
							w_parts.erase(attach_type)
					w_dict["parts"] = w_parts
					w_dict["attachments"] = w_parts
					equipment_data[weapon_slot_key] = WeaponPartsDatabase.compute_weapon_from_dict(w_dict)
					_clamp_weapon_excess_ammo(equipment_data[weapon_slot_key])
					_sync_weapon_to_player(weapon_slot_key)
					_update_weapons_ui()
					if SoundManager: SoundManager.play("menu_select")
	)
	
	parent.add_child(btn)

func _try_equip_weapon(slot_key: String) -> void:
	var item = drag_data.get("item", {})
	var it_id = String(item.get("id", ""))
	var it_data = ItemDatabase.get_item_data(it_id)
	var it_cat = int(it_data.get("category", -1))
	var it_type = String(it_data.get("type", ""))

	# 탄약 드래그 앤 드롭 시 탄종 선택 재장전 및 잔탄 확인/교체 처리
	if it_type == "ammo" or WeaponPartsDatabase.AMMO_TYPES.has(it_id) or it_id.contains("탄약") or it_id.contains("mm") or it_id.contains("게이지") or it_id.contains("ACP"):
		var target_w = equipment_data.get(slot_key, {})
		if target_w.is_empty():
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 탄약을 장전할 무기가 슬롯에 없습니다.")
			_end_drag()
			return

		var raw_rec = target_w.get("receiver", target_w.get("id", ""))
		var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_rec)
		var rec_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
		var allowed_ammos: Array = rec_data.get("ammo_types", target_w.get("computed_stats", {}).get("ammo_types", []))
		if allowed_ammos.is_empty() and rec_data.has("default_ammo"):
			allowed_ammos = [rec_data["default_ammo"]]

		if not (it_id in allowed_ammos or "탄약" in allowed_ammos):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ [%s] 탄약은 [%s]에 호환되지 않습니다." % [it_data.get("name", it_id), target_w.get("name", rec_id)])
			_end_drag()
			return

		var stats = target_w.get("computed_stats", {})
		var max_mag = int(stats.get("magazine_size", 15))
		var old_ammo = str(target_w.get("loaded_ammo", ""))
		if old_ammo == "":
			old_ammo = str(rec_data.get("default_ammo", it_id))
		var old_count = int(target_w.get("current_magazine_ammo", 0))
		var drag_amt = max(1, int(item.get("amount", 1)))

		var load_amt = 0
		var final_mag_ammo = 0
		var is_same_ammo = (old_count > 0 and old_ammo == it_id)

		if is_same_ammo:
			var needed = max(0, max_mag - old_count)
			if needed <= 0:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 이미 탄창이 가득 차 있습니다. (%d/%d발)" % [old_count, max_mag])
				_end_drag()
				return
			load_amt = min(drag_amt, needed)
			final_mag_ammo = old_count + load_amt
		else:
			# 이전 잔탄 가방으로 회수
			if old_count > 0 and old_ammo != "":
				var rem = inventory_grid.auto_add_item(old_ammo, old_count) if inventory_grid else old_count
				if rem > 0:
					_spawn_ground_item(old_ammo, rem)
			load_amt = min(drag_amt, max_mag)
			final_mag_ammo = load_amt

		var src = drag_data.get("source", "")
		if drag_amt <= load_amt:
			if src == "grid":
				if inventory_grid:
					inventory_grid.remove_item_by_uid(item.get("uid", ""))
			elif src == "split":
				drag_data["is_split"] = false
			elif src == "vicinity":
				var ground_node = drag_data.get("ground_ref")
				if is_instance_valid(ground_node): ground_node.queue_free()
				_update_vicinity_list(true)
			elif src == "container":
				var orig_idx = drag_data.get("origin_index", -1)
				if orig_idx != -1 and target_inventory:
					target_inventory.remove_item_at(orig_idx, drag_amt)
					_update_container_list()
		else:
			item["amount"] = drag_amt - load_amt
			if src == "grid":
				if inventory_grid:
					var orig_it = inventory_grid.get_item_by_uid(item.get("uid", ""))
					if not orig_it.is_empty(): orig_it["amount"] = item["amount"]
					inventory_grid.grid_changed.emit()
			elif src == "split":
				var orig_sp = drag_data.get("split_source_item", {})
				if not orig_sp.is_empty():
					orig_sp["amount"] = int(orig_sp.get("amount", 0)) + item["amount"]
				drag_data["is_split"] = false
				if inventory_grid:
					inventory_grid.grid_changed.emit()
			elif src == "vicinity":
				var ground_node = drag_data.get("ground_ref")
				if is_instance_valid(ground_node):
					ground_node.amount = item["amount"]
					ground_node.update_visuals()
				_update_vicinity_list(true)
			elif src == "container":
				var orig_idx = drag_data.get("origin_index", -1)
				if orig_idx != -1 and target_inventory:
					target_inventory.remove_item_at(orig_idx, load_amt)
					_update_container_list()

		target_w["loaded_ammo"] = it_id
		target_w["current_magazine_ammo"] = final_mag_ammo
		target_w = WeaponPartsDatabase.compute_weapon_from_dict(target_w)
		equipment_data[slot_key] = target_w
		_sync_weapon_to_player(slot_key)
		_update_weapons_ui()
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			if is_same_ammo:
				EventBus.event_logged.emit("🔄 [%s] 탄약 추가 장전 완료! (%d/%d발)" % [it_data.get("name", it_id), final_mag_ammo, max_mag])
			else:
				EventBus.event_logged.emit("🔄 [%s] 탄약으로 교체 장전 완료! (%d/%d발)" % [it_data.get("name", it_id), final_mag_ammo, max_mag])
		_end_drag()
		return

	var eq_slot = ItemDatabase.get_item_equip_slot(item.get("id", ""))
	var valid = false
	if slot_key.begins_with("primary") and (eq_slot == "primary" or eq_slot == ""): valid = true
	elif slot_key == "sidearm" and (eq_slot == "sidearm" or eq_slot == "melee"): valid = true
	elif slot_key == "throwable" and eq_slot == "throwable": valid = true
	
	if not valid:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 해당 무기 슬롯에 호환되지 않는 아이템입니다.")
		_end_drag()
		return
		
	var src = drag_data.get("source", "")
	var orig_slot = drag_data.get("slot_name", "")
	
	# 같은 무기 슬롯에 다시 드롭한 경우 -> 복제 방지
	if (src == "weapon_slot" or src == "equipment") and orig_slot == slot_key:
		_end_drag()
		return
		
	if src == "grid": inventory_grid.remove_item_by_uid(item.get("uid", ""))
	elif src == "vicinity":
		var ground_node = drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx = drag_data.get("origin_index", -1)
		if orig_idx != -1 and target_inventory:
			target_inventory.remove_item_at(orig_idx, item.get("amount", 1))
			_update_container_list()
	elif src == "weapon_slot" or src == "equipment":
		equipment_data[orig_slot] = {}
		
	var prev = equipment_data.get(slot_key, {})
	if not item.has("parts"):
		item["parts"] = item.get("attachments", {}).duplicate(true)
	item["attachments"] = item["parts"]
	item = WeaponPartsDatabase.compute_weapon_from_dict(item)
	equipment_data[slot_key] = item
	
	if not prev.is_empty():
		inventory_grid.auto_add_item(prev.get("id", ""), prev.get("amount", 1), prev)
		
	_sync_weapon_to_player(slot_key)
	_update_weapons_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

func _try_equip_attachment(weapon_slot_key: String, attach_type: String, rail_index: int = -1) -> void:
	var item = drag_data.get("item", {})
	var part_id = item.get("id", "")
	
	if not WeaponPartsDatabase.PARTS.has(part_id):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 부착물 부품이 아닙니다.")
		_end_drag()
		return
		
	var part_data = WeaponPartsDatabase.PARTS[part_id]
	if part_data.get("slot", "") != attach_type:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 부착 슬롯이 일치하지 않습니다 (%s != %s)" % [part_data.get("slot", ""), attach_type])
		_end_drag()
		return

	var w = equipment_data.get(weapon_slot_key, {})
	if w.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 무기가 장착되어 있지 않습니다.")
		_end_drag()
		return

	var raw_id = w.get("receiver", w.get("id", ""))
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	var receiver_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	if not receiver_data.is_empty():
		var allowed_slots = receiver_data.get("slots", {})
		if not allowed_slots.has(attach_type):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 해당 무기에는 이 부품을 장착할 슬롯이 없습니다.")
			_end_drag()
			return
		var comp_cats = part_data.get("compatible_categories", ["all"])
		var rec_cat = receiver_data.get("category", "")
		if not ("all" in comp_cats or rec_cat in comp_cats):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 해당 무기 카테고리와 호환되지 않는 부품입니다.")
			_end_drag()
			return
		
	var src = drag_data.get("source", "")
	if src == "grid":
		inventory_grid.remove_item_by_uid(item.get("uid", ""))
	elif src == "vicinity":
		var ground_node = drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
	elif src == "container":
		var orig_idx = drag_data.get("origin_index", -1)
		if orig_idx != -1 and target_inventory:
			target_inventory.remove_item_at(orig_idx, 1)
			_update_container_list()
	elif src == "attachment":
		var old_w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", ""))
		var old_a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
		var old_rail_idx = drag_data.get("rail_index", item.get("rail_index", -1))
		if equipment_data.has(old_w_slot):
			var old_parts = equipment_data[old_w_slot].get("parts", {})
			if old_a_slot == "rail" and old_parts.get("rail") is Array:
				if old_rail_idx >= 0 and old_rail_idx < old_parts["rail"].size():
					old_parts["rail"].remove_at(old_rail_idx)
				else:
					old_parts["rail"].erase(part_id)
				if old_parts["rail"].is_empty():
					old_parts.erase("rail")
			else:
				old_parts.erase(old_a_slot)
			equipment_data[old_w_slot]["parts"] = old_parts
			equipment_data[old_w_slot]["attachments"] = old_parts
			equipment_data[old_w_slot] = WeaponPartsDatabase.compute_weapon_from_dict(equipment_data[old_w_slot])
			_clamp_weapon_excess_ammo(equipment_data[old_w_slot])
			_sync_weapon_to_player(old_w_slot)
		
	if not equipment_data[weapon_slot_key].has("parts"):
		equipment_data[weapon_slot_key]["parts"] = equipment_data[weapon_slot_key].get("attachments", {}).duplicate(true)
		
	var prev_part = ""
	if attach_type == "rail":
		var raw_rails = equipment_data[weapon_slot_key]["parts"].get("rail", [])
		var cur_rails: Array = raw_rails if (raw_rails is Array) else ([str(raw_rails)] if str(raw_rails) != "" else [])
		if rail_index >= 0 and rail_index < cur_rails.size():
			prev_part = cur_rails[rail_index]
			cur_rails[rail_index] = part_id
		elif rail_index >= 0:
			cur_rails.append(part_id)
		else:
			var max_r = receiver_data.get("slots", {}).get("rail", 1)
			if cur_rails.size() < max_r:
				cur_rails.append(part_id)
			else:
				prev_part = cur_rails[0]
				cur_rails[0] = part_id
		equipment_data[weapon_slot_key]["parts"]["rail"] = cur_rails
	else:
		prev_part = equipment_data[weapon_slot_key]["parts"].get(attach_type, "")
		equipment_data[weapon_slot_key]["parts"][attach_type] = part_id
		
	equipment_data[weapon_slot_key]["attachments"] = equipment_data[weapon_slot_key]["parts"]
	equipment_data[weapon_slot_key] = WeaponPartsDatabase.compute_weapon_from_dict(equipment_data[weapon_slot_key])
	_clamp_weapon_excess_ammo(equipment_data[weapon_slot_key])
	_sync_weapon_to_player(weapon_slot_key)
	
	if prev_part != "":
		inventory_grid.auto_add_item(prev_part, 1)
		
	_update_weapons_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

# ============================================================
# 5. UX & 인터랙션 (드래그, 회전, 분할, 우클릭 액션)
# ============================================================
func _start_drag(source_type: String, item: Dictionary, origin_pos: Vector2i = Vector2i.ZERO, slot_name: String = "", ground_ref: Node = null) -> void:
	if tooltip:
		tooltip.hide()
	is_dragging = true
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	if not item.has("w"):
		item["w"] = base_size.x
	if not item.has("h"):
		item["h"] = base_size.y
	drag_data = {
		"source": source_type,
		"item": item,
		"rotated": item.get("rotated", false),
		"origin_pos": origin_pos,
		"slot_name": slot_name,
		"ground_ref": ground_ref
	}
	
	_rebuild_drag_preview()
	if is_inside_tree() and grid_control:
		hovered_grid_cell = _calc_grid_hover_cell(get_global_mouse_position())
		grid_control.queue_redraw()
	_highlight_compatible_slots(item, null)

func _rebuild_drag_preview() -> void:
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
		
	var item = drag_data.get("item", {})
	if item.is_empty(): return
	
	var is_rot = drag_data.get("rotated", false)
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	var base_w = item.get("w", base_size.x)
	var base_h = item.get("h", base_size.y)
	var cur_w = base_h if is_rot else base_w
	var cur_h = base_w if is_rot else base_h
	
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 200
	add_child(drag_preview)
	
	var total_w = cur_w * CELL_SIZE
	var total_h = cur_h * CELL_SIZE
	drag_preview.custom_minimum_size = Vector2(total_w, total_h)
	
	var bg_panel = Panel.new()
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.position = Vector2(2, 2)
	bg_panel.size = Vector2(total_w - 4, total_h - 4)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.20, 0.85)
	sb.border_color = Color(0.92, 0.68, 0.24, 0.95)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_right = 3
	sb.corner_radius_bottom_left = 3
	bg_panel.add_theme_stylebox_override("panel", sb)
	drag_preview.add_child(bg_panel)
	
	var icon = TextureRect.new()
	var min_dim = min(total_w, total_h) * 0.72
	icon.custom_minimum_size = Vector2(min_dim, min_dim)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ItemIconManager: icon.texture = ItemIconManager.get_icon(item.get("id", ""))
	icon.position = (Vector2(total_w, total_h) - Vector2(min_dim, min_dim)) / 2.0
	drag_preview.add_child(icon)
	
	var amt = int(item.get("amount", 1))
	if amt > 1:
		var amt_lbl = Label.new()
		amt_lbl.text = "x%d" % amt
		amt_lbl.add_theme_font_size_override("font_size", 10)
		amt_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		amt_lbl.position = Vector2(6, total_h - 18)
		amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_preview.add_child(amt_lbl)
		
	_update_drag_preview_pos()

func _update_drag_preview_pos() -> void:
	if not drag_preview or not is_dragging or not is_inside_tree(): return
	var item = drag_data.get("item", {})
	var is_rot = drag_data.get("rotated", false)
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	var cur_w = item.get("h", base_size.y) if is_rot else item.get("w", base_size.x)
	var cur_h = item.get("w", base_size.x) if is_rot else item.get("h", base_size.y)
	var center_offset = Vector2(cur_w * CELL_SIZE * 0.5, cur_h * CELL_SIZE * 0.5)
	drag_preview.global_position = get_global_mouse_position() - center_offset

func _end_drag() -> void:
	if is_dragging and drag_data.get("is_split", false):
		var orig = drag_data.get("split_source_item", {})
		var split_amt = drag_data.get("split_amount", 0)
		if not orig.is_empty() and split_amt > 0:
			orig["amount"] = int(orig.get("amount", 0)) + split_amt
			if inventory_grid:
				inventory_grid.grid_changed.emit()
		drag_data["is_split"] = false
	is_dragging = false
	drag_data.clear()
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	_clear_slot_highlights()
	if grid_control:
		grid_control.queue_redraw()

func _highlight_compatible_slots(item: Dictionary, hovered_ctrl: Control = null) -> void:
	InventoryUIHelper.highlight_compatible_slots(drop_targets, item, hovered_ctrl)

func _clear_slot_highlights() -> void:
	InventoryUIHelper.clear_slot_highlights(drop_targets)

func _open_split_dialog(item: Dictionary, on_confirm: Callable) -> void:
	var diag = SplitDialogScene.instantiate()
	add_child(diag)
	diag.setup(item.get("amount", 1))
	diag.split_confirmed.connect(on_confirm)

func _handle_item_quick_action(item: Dictionary, ignore_container: bool = false) -> void:
	# 0. 파밍 상자나 보관함이 열려있다면 가방에서 보관함으로 빠른 전송 (단, 컨텍스트 메뉴 [사용/장착] 시에는 무시)
	if target_inventory != null and not ignore_container:
		_quick_transfer_grid_to_container(item)
		return

	var id = item.get("id", "")
	var idata = ItemDatabase.get_item_data(id)
	var cat = idata.get("category", -1)
	var equip_slot = ItemDatabase.get_item_equip_slot(id)
	
	# 0-B. 전술 무전기(장거리 무전기) 사용 시 인레이드 통신망 & 암시장 드론 호출 창 오픈
	if id == "장거리 무전기" or id.contains("무전기"):
		if player != null and is_inside_tree() and get_tree() != null:
			var cur_scene = get_tree().current_scene
			_on_close_pressed()
			if cur_scene and cur_scene.has_method("open_radio_window"):
				cur_scene.open_radio_window()
			return

	# 1. 음식/물/의약품이면 즉시 사용
	if cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or cat == ItemDatabase.ItemCategory.MEDICAL:
		_use_consumable_item(item, idata)
		return
		
	# 2. 방어구 및 장비 (헬멧, 방탄복, 배낭, 하의/신발)
	if cat == ItemDatabase.ItemCategory.EQUIPMENT or (equip_slot in ["helmet", "vest", "backpack", "bottom"]):
		var slot = equip_slot
		if slot != "":
			var prev_equipped = equipment_data.get(slot, {})
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			equipment_data[slot] = item
			if not prev_equipped.is_empty():
				inventory_grid.auto_add_item(prev_equipped.get("id", ""), prev_equipped.get("amount", 1), prev_equipped)
			_apply_backpack_grid_size()
			_update_equipment_ui()
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				if not prev_equipped.is_empty():
					EventBus.event_logged.emit("🔄 [%s] 장비 교체 완료!" % idata.get("name", id))
				else:
					EventBus.event_logged.emit("🪖 [%s] 장착 완료!" % idata.get("name", id))
			return

	# 3. 무기류 (주무기, 권총/보조무기, 투척무기)
	if cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or equip_slot in ["primary", "sidearm", "throwable", "melee"]:
		var target_slot = "primary1"
		if equip_slot == "throwable":
			target_slot = "throwable"
		elif equip_slot == "sidearm" or equip_slot == "melee":
			target_slot = "sidearm"
		else:
			if equipment_data.get("primary1", {}).is_empty():
				target_slot = "primary1"
			elif equipment_data.get("primary2", {}).is_empty():
				target_slot = "primary2"
			else:
				var active_slot = "primary1"
				if player and "weapon_handler" in player and player.weapon_handler:
					active_slot = player.weapon_handler.active_weapon_slot
				target_slot = active_slot if active_slot in ["primary1", "primary2"] else "primary1"

		var prev_weapon = equipment_data.get(target_slot, {})
		inventory_grid.remove_item_by_uid(item.get("uid", ""))
		if not item.has("parts"):
			item["parts"] = item.get("attachments", {}).duplicate(true)
		item["attachments"] = item["parts"]
		item = WeaponPartsDatabase.compute_weapon_from_dict(item)
		equipment_data[target_slot] = item
		if not prev_weapon.is_empty():
			inventory_grid.auto_add_item(prev_weapon.get("id", ""), prev_weapon.get("amount", 1), prev_weapon)
		_sync_weapon_to_player(target_slot)
		_update_weapons_ui()
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			if not prev_weapon.is_empty():
				EventBus.event_logged.emit("🔄 [%s] 무기 교체 완료!" % idata.get("name", id))
			else:
				EventBus.event_logged.emit("🔫 [%s] 무기 장착 완료!" % idata.get("name", id))
		return

	# 4. 총기 부착물 (조준경, 소음기, 손잡이, 탄창, 개머리판, 총열, 레일 등)
	if WeaponPartsDatabase.PARTS.has(id):
		var part_data = WeaponPartsDatabase.PARTS[id]
		var attach_type = part_data.get("slot", "")
		var candidate_slots = ["primary1", "primary2", "sidearm"]
		var best_slot = ""
		
		# 1차 탐색: 해당 부품 슬롯이 비어있는 무기 우선
		for s in candidate_slots:
			var w = equipment_data.get(s, {})
			if not w.is_empty():
				var raw_id = w.get("receiver", w.get("id", ""))
				var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
				var receiver_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
				if receiver_data.is_empty():
					continue
				var allowed_slots = receiver_data.get("slots", {})
				if not allowed_slots.has(attach_type):
					continue
				var comp_cats = part_data.get("compatible_categories", ["all"])
				var rec_cat = receiver_data.get("category", "")
				if not ("all" in comp_cats or rec_cat in comp_cats):
					continue
				var w_parts = w.get("parts", w.get("attachments", {}))
				var cur_val = w_parts.get(attach_type, null)
				var is_empty_slot = (cur_val == null or cur_val == "" or (cur_val is Array and cur_val.is_empty()))
				if is_empty_slot:
					best_slot = s
					break
					
		# 2차 탐색: 비어있는 곳이 없으면 이미 장착된 곳 대체
		if best_slot == "":
			for s in candidate_slots:
				var w = equipment_data.get(s, {})
				if not w.is_empty():
					var raw_id = w.get("receiver", w.get("id", ""))
					var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
					var receiver_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
					if receiver_data.is_empty():
						continue
					var allowed_slots = receiver_data.get("slots", {})
					if not allowed_slots.has(attach_type):
						continue
					var comp_cats = part_data.get("compatible_categories", ["all"])
					var rec_cat = receiver_data.get("category", "")
					if not ("all" in comp_cats or rec_cat in comp_cats):
						continue
					best_slot = s
					break
					
		if best_slot != "":
			if not equipment_data[best_slot].has("parts"):
				equipment_data[best_slot]["parts"] = equipment_data[best_slot].get("attachments", {}).duplicate(true)
			var w_parts = equipment_data[best_slot]["parts"]
			var prev_part = ""
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			if attach_type == "rail":
				var raw_rails = w_parts.get("rail", [])
				var cur_rails: Array = raw_rails if (raw_rails is Array) else ([str(raw_rails)] if str(raw_rails) != "" else [])
				var raw_id = equipment_data[best_slot].get("receiver", equipment_data[best_slot].get("id", ""))
				var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
				var receiver_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
				var max_rails = receiver_data.get("slots", {}).get("rail", 1)
				if cur_rails.size() < max_rails:
					cur_rails.append(id)
				else:
					prev_part = cur_rails[0]
					cur_rails[0] = id
				w_parts["rail"] = cur_rails
			else:
				prev_part = w_parts.get(attach_type, "")
				w_parts[attach_type] = id

			equipment_data[best_slot]["parts"] = w_parts
			equipment_data[best_slot]["attachments"] = w_parts
			equipment_data[best_slot] = WeaponPartsDatabase.compute_weapon_from_dict(equipment_data[best_slot])
			_sync_weapon_to_player(best_slot)
			
			if prev_part != "":
				inventory_grid.auto_add_item(prev_part, 1)
			_update_weapons_ui()
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🔧 [%s] 부착 완료!" % idata.get("name", id))
			return
		else:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 장착 가능한 무기가 없습니다.")
			return

func _use_consumable_item(item: Dictionary, idata: Dictionary) -> void:
	if not player: return
	
	var item_name = idata.get("name", item.get("id", ""))
	var item_id = item.get("id", "")
	var target_uid = item.get("uid", "")
	
	if player.has_method("start_channeling"):
		var duration = 2.0
		if player.has_method("get_channeling_duration_for"):
			duration = player.get_channeling_duration_for(item_id, idata)
		elif item_id.contains("붕대") or item_id.contains("지혈") or item_id == "bandage":
			duration = 1.5
		elif item_id.contains("구급") or item_id.contains("수술") or item_id.contains("키트") or item_id.contains("부목") or item_id == "medkit":
			duration = 3.0
			
		player.start_channeling(duration, item_name, func():
			var effects = idata.get("effects", {})
			if effects.has("hp"): player.hp = min(player.max_hp, player.hp + effects["hp"])
			if effects.has("hunger"): player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
			if effects.has("thirst"): player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
			if effects.has("stamina"): player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
			if effects.get("cures_bleeding", false): player.is_bleeding = false
			if effects.get("cures_fracture", false): player.is_fractured = false
			if effects.get("cures_infection", false) or effects.get("infection", 0) < 0: player.is_infected = false
			
			if inventory_grid:
				var cur_item: Dictionary = {}
				for it in inventory_grid.items:
					if it.get("uid", "") == target_uid:
						cur_item = it
						break
				if not cur_item.is_empty():
					var amt = int(cur_item.get("amount", 1))
					if amt > 1:
						cur_item["amount"] = amt - 1
						inventory_grid.grid_changed.emit()
					else:
						inventory_grid.remove_item_by_uid(target_uid)
				else:
					inventory_grid.remove_item_by_uid(target_uid)
					
			player.stats_changed.emit()
			if SoundManager: SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("✨ %s을(를) 사용 완료했습니다." % item_name)
		)
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⏳ %s 사용 시작 (%.1f초)..." % [item_name, duration])
		_on_close_pressed()
		return
		
	var effects = idata.get("effects", {})
	if effects.has("hp"): player.hp = min(player.max_hp, player.hp + effects["hp"])
	if effects.has("hunger"): player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
	if effects.has("thirst"): player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
	if effects.has("stamina"): player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
	if effects.get("cures_bleeding", false): player.is_bleeding = false
	if effects.get("cures_fracture", false): player.is_fractured = false
	if effects.get("cures_infection", false) or effects.get("infection", 0) < 0: player.is_infected = false
	
	player.stats_changed.emit()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("✨ %s을(를) 사용했습니다." % item_name)
		
	# 1개 소모
	var amt = item.get("amount", 1)
	if amt > 1:
		item["amount"] -= 1
		inventory_grid.grid_changed.emit()
	else:
		inventory_grid.remove_item_by_uid(item.get("uid", ""))

func _update_weight_ui() -> void:
	if not inventory_grid or not weight_label: return
	var cur_w = player.get_total_weight() if (player and player.has_method("get_total_weight")) else inventory_grid.get_total_weight()
	if cur_w > 50.0:
		weight_label.text = "%.1f / 50.0 kg [초과적]" % cur_w
		weight_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
	elif cur_w >= 35.0:
		weight_label.text = "%.1f / 50.0 kg [과적 주의]" % cur_w
		weight_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	else:
		weight_label.text = "%.1f / 50.0 kg" % cur_w
		weight_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if player and player.has_method("refresh_equipped_weapon"):
		player.refresh_equipped_weapon(false)
	elif player and player.has_method("switch_weapon_slot"):
		player.switch_weapon_slot(player.active_weapon_slot)
	get_tree().paused = false
	queue_free()
	window_closed.emit()
