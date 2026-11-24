# res://scenes/ui/inventory_window.gd
extends Control

## 4단 레이아웃 + WxH 2D 그리드 결합 전술 인벤토리 시스템

signal window_closed

const CELL_SIZE: float = InventoryUIHelper.CELL_SIZE
const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
const SplitDialogScene = preload("res://scenes/ui/split_dialog.tscn")
const GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")
const InventoryCorpseLootHelper = preload("res://systems/inventory_corpse_loot_helper.gd")
const InventoryEquipmentHelper = preload("res://systems/inventory_equipment_helper.gd")

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
var hideout_stash_grid: InventoryGrid = null
var target_inventory: Inventory = null
var target_title: String = ""
var corpse_equip_section: VBoxContainer = null
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
var open_container_popups: Dictionary = {}

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
		sort_btn.theme_type_variation = &"SmallButton"
		sort_btn.text = "정렬"
		sort_btn.tooltip_text = "동일 아이템 병합 및 빈 공간 자동 정렬"
		sort_btn.custom_minimum_size = Vector2(56, 24)
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
		loot_all_btn.text = "모두 획득 [F] (Ctrl+클릭: 이동)"
		loot_all_btn.tooltip_text = "모두 획득 [F]   (Ctrl+클릭: 빠른 이동)"
		loot_all_btn.clip_text = true
		loot_all_btn.custom_minimum_size = Vector2(0, 30)
		loot_all_btn.add_theme_font_size_override("font_size", 11)
		loot_all_btn.pressed.connect(_loot_all_from_container)
		container_section.add_child(loot_all_btn)
		container_section.move_child(loot_all_btn, 1)

		corpse_equip_section = VBoxContainer.new()
		corpse_equip_section.name = "CorpseEquipSection"
		corpse_equip_section.visible = false
		corpse_equip_section.add_theme_constant_override("separation", 4)
		container_section.add_child(corpse_equip_section)
		container_section.move_child(corpse_equip_section, 2)
	
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
	close_all_container_popups()
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
		
	var base_eq: Dictionary = GameManager.create_empty_equipment() if GameManager else {
		"helmet": {}, "vest": {}, "backpack": {}, "bottom": {},
		"primary1": {}, "primary2": {}, "sidearm": {}, "throwable": {}
	}
	if player and "equipment" in player:
		if not (player.equipment is Dictionary) or player.equipment.is_empty():
			player.equipment = base_eq.duplicate(true)
		else:
			for slot_k in base_eq.keys():
				if not player.equipment.has(slot_k):
					player.equipment[slot_k] = base_eq[slot_k]
		equipment_data = player.equipment
	elif p_equip is Dictionary and not p_equip.is_empty():
		equipment_data = p_equip
		for slot_k in base_eq.keys():
			if not equipment_data.has(slot_k):
				equipment_data[slot_k] = base_eq[slot_k]
	else:
		equipment_data = base_eq.duplicate(true)
		if player:
			player.set("equipment", equipment_data)
		
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
		
	if is_dragging:
		if bool(drag_data.get("started_with_lmb", false)) and not bool(drag_data.get("is_split", false)) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
			return
		if drag_preview:
			_update_drag_preview_pos()
			grid_control.queue_redraw()
	elif tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not visible):
		if is_dragging:
			_end_drag()
		_close_context_menu()
		if tooltip and is_instance_valid(tooltip):
			tooltip.hide()
		hovered_grid_cell = Vector2i(-1, -1)
		if is_instance_valid(grid_control):
			grid_control.queue_redraw()

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
	_prune_and_rebind_popups()
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
	grid_control.size = Vector2(total_w, total_h)
	grid_control.queue_redraw()
	if grid_title_label:
		grid_title_label.text = "BACKPACK (%d×%d, %d칸)" % [inventory_grid.grid_width, inventory_grid.grid_height, inventory_grid.grid_width * inventory_grid.grid_height]

func _on_grid_draw() -> void:
	InventoryUIHelper.draw_2d_grid(grid_control, inventory_grid, hovered_grid_cell, true, is_dragging, drag_data, CELL_SIZE)

func _calc_grid_hover_cell(m_global_pos: Vector2) -> Vector2i:
	if not is_dragging or not inventory_grid:
		return Vector2i(-1, -1)
	return InventoryUIHelper.calc_drag_drop_cell(grid_control, m_global_pos, inventory_grid, drag_data, CELL_SIZE)

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
		elif not is_dragging and (event.keycode == KEY_L or event.physical_keycode == KEY_L):
			if _toggle_lock_at_mouse():
				get_viewport().set_input_as_handled()
				return
	
	# 드래그 중 R 키 누르면 W <-> H 회전
	if is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			drag_data["rotated"] = not drag_data.get("rotated", false)
			_rebuild_drag_preview()
			var m_pos := get_global_mouse_position()
			hovered_grid_cell = _calc_grid_hover_cell(m_pos)
			InventoryUIHelper.update_popup_drag_hover(open_container_popups, m_pos, drag_data)
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
		InventoryUIHelper.update_popup_drag_hover(open_container_popups, m_pos, drag_data)
		
		# 마우스 아래의 장비/무기 슬롯 감지 및 하이라이트
		var hovered_target_ctrl: Control = null
		for target in drop_targets:
			var ctrl: Control = target.get("control")
			if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
				hovered_target_ctrl = ctrl
				break
		_highlight_compatible_slots(drag_data.get("item", {}), hovered_target_ctrl)
		
	# 드래그 중 우클릭 취소 또는 분할 드래그 클릭 드롭 / 마우스 버튼 릴리즈 시 완벽한 드롭 처리
	if is_dragging and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_end_drag()
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and bool(drag_data.get("is_split", false)):
			_handle_global_drop()
			get_viewport().set_input_as_handled()
			return
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_global_drop()
			get_viewport().set_input_as_handled()

var drop_targets: Array[Dictionary] = []

func _handle_global_drop() -> void:
	if not is_dragging: return
	
	var m_pos = get_global_mouse_position()
	if not bool(drag_data.get("is_split", false)) and drag_data.has("start_mouse_pos"):
		var start_m: Vector2 = drag_data.get("start_mouse_pos", m_pos)
		if start_m.distance_to(m_pos) < 5.0 and bool(drag_data.get("rotated", false)) == bool(drag_data.get("orig_rotated", false)):
			_end_drag()
			return

	# 0. 열려있는 중첩 컨테이너 팝업(최상단 우선) 위인지 검사
	var children := get_children()
	for ci in range(children.size() - 1, -1, -1):
		var p_win := children[ci] as ContainerPopupWindow
		if p_win and is_instance_valid(p_win) and p_win.is_visible_in_tree():
			var d_cell: Vector2i = p_win.get_drop_cell(m_pos, drag_data.get("item", {}), drag_data.get("rotated", false))
			if d_cell != Vector2i(-1, -1):
				_try_drop_on_popup(p_win, d_cell.x, d_cell.y)
				return
			if p_win.get_global_rect().has_point(m_pos):
				_end_drag()
				return
	
	# 1. 2D 그리드 영역 위인지 검사 (중앙 포커스 좌표 반영)
	var grid_global_rect = grid_control.get_global_rect()
	if grid_global_rect.has_point(m_pos):
		var target_cell = _calc_grid_hover_cell(m_pos)
		if target_cell.x != -1 and target_cell.y != -1:
			_try_drop_on_grid(target_cell.x, target_cell.y)
		else:
			var local_pos = grid_control.get_local_mouse_position()
			var cell_x = int(floor(local_pos.x / CELL_SIZE))
			var cell_y = int(floor(local_pos.y / CELL_SIZE))
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
			
	# 4. 주변(Vicinity) 컬럼으로 드롭했는지 검사 (인레이드에서만 바닥에 버리기 허용)
	var vicinity_rect = vicinity_section.get_global_rect() if is_instance_valid(vicinity_section) else $MainLayout/VicinityCol.get_global_rect()
	if vicinity_rect.has_point(m_pos):
		if player == null:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 은신처 인벤토리 창에서는 바닥에 버릴 수 없습니다.")
			_end_drag()
			return
		var src = drag_data.get("source", "")
		var item = drag_data.get("item", {})
		if bool(item.get("locked", false)):
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:lock] 잠금된 아이템은 바닥에 버릴 수 없습니다. ([L] 키로 잠금 해제)")
			if SoundManager: SoundManager.play("hit_melee")
			_end_drag()
			return
		if src == "grid":
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			_drop_item_to_world(item)
		elif src == "popup_grid":
			var s_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
			if s_grid:
				s_grid.remove_item_by_uid(item.get("uid", ""))
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
			_remove_attachment_from_weapon_slot(str(w_slot), str(a_slot), int(r_idx), str(item.get("id", "")))
			_update_weapons_ui()
			_drop_item_to_world(item)
		elif src == "corpse_equip":
			_consume_corpse_equip_drag_source()
			_drop_item_to_world(item)
		_end_drag()
		return
		
	# 5. 그 외 영역에 놓쳤을 경우 원래대로 복귀
	_end_drag()

func _on_grid_gui_input(event: InputEvent) -> void:
	var local_pos = grid_control.get_local_mouse_position()
	var cell_x = int(floor(local_pos.x / CELL_SIZE))
	var cell_y = int(floor(local_pos.y / CELL_SIZE))
	
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
		if is_dragging:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if event.double_click and InventoryGrid.is_container_item(item):
					if is_dragging:
						_end_drag()
					if tooltip: tooltip.hide()
					open_container_popup(item, inventory_grid)
				elif Input.is_key_pressed(KEY_CTRL):
					if tooltip: tooltip.hide()
					if target_inventory != null:
						_quick_transfer_grid_to_container(item)
					else:
						_handle_item_quick_action(item, false, true)
				elif Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
					_open_split_dialog(item, func(split_amt):
						var split_item: Dictionary = InventoryUIHelper.prepare_split_drag_item(item, int(split_amt), inventory_grid)
						_start_drag("split", split_item, Vector2i(cell_x, cell_y), "", null, inventory_grid)
						drag_data["is_split"] = true
						drag_data["split_source_item"] = item
						drag_data["split_source_grid"] = inventory_grid
						drag_data["split_amount"] = split_amt
					)
				else:
					_start_drag("grid", item, Vector2i(cell_x, cell_y), "", null, inventory_grid)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if Input.is_key_pressed(KEY_ALT):
					_show_context_menu(item, "grid", "", inventory_grid)
				else:
					_handle_item_quick_action(item)

func perform_item_repair(item: Dictionary, slot_ref: String = "") -> bool:
	return InventoryEquipmentHelper.perform_item_repair(self, item, slot_ref)

func _add_context_menu_btn(vbox: VBoxContainer, text_str: String, callback: Callable, is_disabled: bool = false, icon_key: String = "") -> Button:
	return InventoryUIHelper.add_context_menu_btn(vbox, text_str, callback, is_disabled, icon_key)

func _show_context_menu(item: Dictionary, source_type: String = "grid", slot_ref: String = "", source_grid: InventoryGrid = null) -> void:
	InventoryEquipmentHelper.show_context_menu(self, item, source_type, slot_ref, source_grid)

func _close_context_menu() -> void:
	if context_menu_panel and is_instance_valid(context_menu_panel):
		context_menu_panel.visible = false
		context_menu_panel.queue_free()
	context_menu_panel = null

func _spawn_ground_item(p_id: String, amount: int = 1) -> void:
	_drop_item_to_world({"id": p_id, "amount": amount})

func _detach_all_item_parts(item: Dictionary) -> void:
	InventoryEquipmentHelper.detach_all_item_parts(self, item)

func _clamp_weapon_excess_ammo(w_dict: Dictionary) -> void:
	InventoryEquipmentHelper.clamp_weapon_excess_ammo(self, w_dict)

func _get_player_rubles() -> int:
	return InventoryEquipmentHelper.get_player_rubles()

func _deduct_player_rubles(cost: int) -> bool:
	return InventoryEquipmentHelper.deduct_player_rubles(cost)

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
	var mouse_cx = int(floor(m_local.x / CELL_SIZE))
	var mouse_cy = int(floor(m_local.y / CELL_SIZE))
	var target_item = inventory_grid.get_item_at(mouse_cx, mouse_cy)
	if target_item.is_empty():
		target_item = inventory_grid.get_item_at(cell_x, cell_y)
		
	if not target_item.is_empty() and InventoryGrid.is_same_item_id(str(target_item.get("id", "")), str(item.get("id", ""))) and target_item.get("uid", "") != uid:
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
					elif src == "popup_grid":
						var p_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
						if p_grid: p_grid.remove_item_by_uid(uid)
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
						_sync_weapon_to_player(s_name)
						_update_weapons_ui()
					elif src == "attachment":
						var w_slot = drag_data.get("weapon_slot", item.get("weapon_slot", "primary1"))
						var a_slot = drag_data.get("attach_slot", item.get("attach_slot", item.get("part_slot", "")))
						var r_idx = drag_data.get("rail_index", item.get("rail_index", -1))
						_remove_attachment_from_weapon_slot(str(w_slot), str(a_slot), int(r_idx), str(item.get("id", "")))
						_update_weapons_ui()
					elif src == "corpse_equip":
						_consume_corpse_equip_drag_source()
				else:
					item["amount"] = rem_amt
					if src == "grid":
						var orig_it = inventory_grid.get_item_by_uid(uid)
						if not orig_it.is_empty(): orig_it["amount"] = rem_amt
					elif src == "popup_grid":
						var p_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
						if p_grid:
							var p_it := p_grid.get_item_by_uid(uid)
							if not p_it.is_empty(): p_it["amount"] = rem_amt
							p_grid.grid_changed.emit()
					elif src == "split":
						var orig_sp = drag_data.get("split_source_item", {})
						if not orig_sp.is_empty():
							orig_sp["amount"] = int(orig_sp.get("amount", 0)) + rem_amt
						drag_data["is_split"] = false
						var sp_grid: InventoryGrid = drag_data.get("split_source_grid", inventory_grid) as InventoryGrid
						if sp_grid: sp_grid.grid_changed.emit()
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
	if inventory_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item.get("id", ""), item):
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
				if src == "popup_grid":
					var p_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
					if p_grid: p_grid.remove_item_by_uid(uid)
				elif src == "vicinity":
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
					_remove_attachment_from_weapon_slot(str(w_slot), str(a_slot), int(r_idx), str(item.get("id", "")))
					_update_weapons_ui()
				elif src == "corpse_equip":
					_consume_corpse_equip_drag_source()
					
				if SoundManager: SoundManager.play("menu_select")
			else:
				if SoundManager: SoundManager.play("hit_melee")
	else:
		# 배치 불가 사유 안내 (중첩 제한 & 2x2 세이프 파우치 구역)
		InventoryUIHelper.log_grid_place_failure(inventory_grid, item, cell_x, cell_y, place_w, place_h)
		if SoundManager: SoundManager.play("hit_melee")
		
	_end_drag()

# ============================================================
# 2. 수색 대상(Container) & 주변(Vicinity) 탐색 & 월드 드롭/픽업
# ============================================================
func _get_corpse_equipment() -> Dictionary:
	return InventoryCorpseLootHelper.get_corpse_equipment(self)

func _close_popup_by_uid(cuid: String) -> void:
	if cuid == "" or not open_container_popups.has(cuid):
		return
	var p = open_container_popups[cuid]
	open_container_popups.erase(cuid)
	if is_instance_valid(p):
		p.queue_free()

func _is_corpse_equipment_popup(popup: ContainerPopupWindow) -> bool:
	return InventoryCorpseLootHelper.is_corpse_equipment_popup(self, popup)

func _has_corpse_equipment_items(corpse_eq: Dictionary) -> bool:
	return InventoryCorpseLootHelper.has_corpse_equipment_items(corpse_eq)

func _consume_corpse_equip_drag_source() -> void:
	InventoryCorpseLootHelper.consume_corpse_equip_drag_source(self)

func _update_corpse_equipment_ui() -> void:
	InventoryCorpseLootHelper.update_corpse_equipment_ui(self)

func _update_container_list() -> void:
	InventoryCorpseLootHelper.update_container_list(self)

func _create_container_entry(slot_item: Dictionary, index: int) -> void:
	InventoryCorpseLootHelper.create_container_entry(self, slot_item, index)

func _loot_all_from_container() -> void:
	InventoryCorpseLootHelper.loot_all_from_container(self)

func _quick_transfer_grid_to_container(item: Dictionary) -> void:
	InventoryCorpseLootHelper.quick_transfer_grid_to_container(self, item)

func _try_drop_on_container() -> void:
	InventoryCorpseLootHelper.try_drop_on_container(self)

func _update_vicinity_list(force_rebuild: bool = false) -> void:
	InventoryCorpseLootHelper.update_vicinity_list(self, force_rebuild)

func _create_vicinity_entry(g_item: GroundItem) -> void:
	InventoryCorpseLootHelper.create_vicinity_entry(self, g_item)

func _handle_overflow_item(item: Dictionary) -> void:
	InventoryCorpseLootHelper.handle_overflow_item(self, item)

func _drop_item_to_world(item: Dictionary) -> void:
	InventoryCorpseLootHelper.drop_item_to_world(self, item)

# ============================================================
# 3. 캐릭터 장비 슬롯 & 가방 용량 연동
# ============================================================
func _connect_equipment_slot(btn: Button, slot_name: String) -> void:
	InventoryEquipmentHelper.connect_equipment_slot(self, btn, slot_name)

func _try_equip_dragged_item(slot_name: String) -> void:
	InventoryEquipmentHelper.try_equip_dragged_item(self, slot_name)

func _is_slot_compatible(item_id: String, slot_name: String) -> bool:
	return InventoryUIHelper.is_slot_compatible(item_id, slot_name)

func _apply_backpack_grid_size() -> void:
	InventoryEquipmentHelper.apply_backpack_grid_size(self)

func _update_equipment_ui() -> void:
	InventoryEquipmentHelper.update_equipment_ui(self)

func _rebuild_drop_targets(preserve_non_equip: bool = false) -> void:
	InventoryEquipmentHelper.rebuild_drop_targets(self, preserve_non_equip)

func _render_equip_slot_button(btn: Button, slot_name: String, default_text: String) -> void:
	InventoryUIHelper.render_equip_slot_button(btn, slot_name, default_text, equipment_data)

# ============================================================
# 4. 무기 슬롯 & 부착물 서브 슬롯 모딩
# ============================================================
func _sync_weapon_to_player(slot_key: String = "") -> void:
	InventoryEquipmentHelper.sync_weapon_to_player(self, slot_key)

func _update_weapons_ui() -> void:
	InventoryEquipmentHelper.update_weapons_ui(self)

func _remove_attachment_from_weapon_slot(w_slot: String, a_slot: String, r_idx: int, part_id: String = "") -> void:
	InventoryEquipmentHelper.remove_attachment_from_weapon_slot(self, w_slot, a_slot, r_idx, part_id)

func _create_weapon_card(title: String, slot_key: String, weapon_dict: Dictionary) -> void:
	InventoryEquipmentHelper.create_weapon_card(self, title, slot_key, weapon_dict)

func _create_attachment_sub_slot(parent: Container, weapon_slot_key: String, attach_type: String, current_part_id: String, rail_index: int = -1) -> void:
	InventoryEquipmentHelper.create_attachment_sub_slot(self, parent, weapon_slot_key, attach_type, current_part_id, rail_index)

func _try_equip_weapon(slot_key: String) -> void:
	InventoryEquipmentHelper.try_equip_weapon(self, slot_key)

func _try_equip_attachment(weapon_slot_key: String, attach_type: String, rail_index: int = -1) -> void:
	InventoryEquipmentHelper.try_equip_attachment(self, weapon_slot_key, attach_type, rail_index)

# ============================================================
# 5. UX & 인터랙션 (드래그, 회전, 분할, 우클릭 액션)
# ============================================================
func _start_drag(source_type: String, item: Dictionary, origin_pos: Vector2i = Vector2i.ZERO, slot_name: String = "", ground_ref: Node = null, source_grid: InventoryGrid = null) -> void:
	if is_dragging:
		_end_drag()
	if tooltip:
		tooltip.hide()
	is_dragging = true
	var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
	if not item.has("w"):
		item["w"] = base_size.x
	if not item.has("h"):
		item["h"] = base_size.y
	var resolved_grid: InventoryGrid = source_grid
	if resolved_grid == null and source_type == "grid":
		resolved_grid = inventory_grid
	drag_data = {
		"source": source_type,
		"item": item,
		"rotated": item.get("rotated", false),
		"orig_rotated": item.get("rotated", false),
		"start_mouse_pos": get_global_mouse_position(),
		"started_with_lmb": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"origin_pos": origin_pos,
		"slot_name": slot_name,
		"ground_ref": ground_ref,
		"source_grid": resolved_grid
	}
	
	_rebuild_drag_preview()
	if is_inside_tree() and grid_control:
		hovered_grid_cell = _calc_grid_hover_cell(get_global_mouse_position())
		grid_control.queue_redraw()
	_highlight_compatible_slots(item, null)

func _rebuild_drag_preview() -> void:
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.visible = false
		drag_preview.queue_free()
	drag_preview = null
	var item = drag_data.get("item", {})
	if item.is_empty():
		return
	var is_rot = drag_data.get("rotated", false)
	drag_preview = InventoryUIHelper.build_drag_preview(item, is_rot, CELL_SIZE)
	add_child(drag_preview)
	_update_drag_preview_pos()

func _update_drag_preview_pos() -> void:
	if not drag_preview or not is_dragging or not is_inside_tree(): return
	InventoryUIHelper.update_drag_preview_position(drag_preview, drag_data, get_global_mouse_position(), CELL_SIZE)

func _end_drag() -> void:
	if is_dragging:
		InventoryUIHelper.rollback_split_drag(drag_data, inventory_grid)
	is_dragging = false
	drag_data.clear()
	hovered_grid_cell = Vector2i(-1, -1)
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.visible = false
		drag_preview.queue_free()
	drag_preview = null
	if tooltip and is_instance_valid(tooltip):
		tooltip.hide()
	_clear_slot_highlights()
	if grid_control and is_instance_valid(grid_control):
		grid_control.queue_redraw()
	InventoryUIHelper.clear_popup_drag_hover(open_container_popups)

func _highlight_compatible_slots(item: Dictionary, hovered_ctrl: Control = null) -> void:
	InventoryUIHelper.highlight_compatible_slots(drop_targets, item, hovered_ctrl)

func _clear_slot_highlights() -> void:
	InventoryUIHelper.clear_slot_highlights(drop_targets)

func _open_split_dialog(item: Dictionary, on_confirm: Callable) -> void:
	InventoryUIHelper.open_split_dialog(self, SplitDialogScene, item, on_confirm)

func _handle_item_quick_action(item: Dictionary, ignore_container: bool = false, allow_popup_transfer: bool = false) -> void:
	InventoryEquipmentHelper.handle_item_quick_action(self, item, ignore_container, allow_popup_transfer)

func _use_consumable_item(item: Dictionary, idata: Dictionary) -> void:
	InventoryEquipmentHelper.use_consumable_item(self, item, idata)

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

func _find_main_world_node() -> Node:
	if has_meta("main_world") and is_instance_valid(get_meta("main_world")):
		return get_meta("main_world")
	if player != null and player.has_meta("main_world") and is_instance_valid(player.get_meta("main_world")):
		return player.get_meta("main_world")
	if is_inside_tree() and get_tree() and get_tree().current_scene and get_tree().current_scene.has_method("open_radio_window"):
		return get_tree().current_scene
	var p: Node = get_parent()
	while p != null:
		if p.has_method("open_radio_window"):
			return p
		p = p.get_parent()
	if player != null:
		var pp: Node = player.get_parent()
		while pp != null:
			if pp.has_method("open_radio_window"):
				return pp
			pp = pp.get_parent()
	if is_inside_tree() and get_tree() and get_tree().root:
		for ch in get_tree().root.get_children():
			if ch.has_method("open_radio_window"):
				return ch
			for sub in ch.get_children():
				if sub.has_method("open_radio_window"):
					return sub
	return null

func _on_close_pressed() -> void:
	if is_dragging:
		_end_drag()
	_close_context_menu()
	if tooltip and is_instance_valid(tooltip):
		tooltip.hide()
	_sync_all_open_popups()
	close_all_container_popups()
	if SoundManager: SoundManager.play("menu_select")
	if player and player.has_method("refresh_equipped_weapon"):
		player.refresh_equipped_weapon(false)
	elif player and player.has_method("switch_weapon_slot"):
		player.switch_weapon_slot(player.active_weapon_slot)
	queue_free()
	window_closed.emit()

# ============================================================
# 6. 타르코프식 중첩 컨테이너 팝업 & 잠금 [L] 제어
# ============================================================
func _sync_all_open_popups() -> void:
	InventoryUIHelper.sync_all_open_popups(open_container_popups)

func close_all_container_popups() -> void:
	InventoryUIHelper.close_all_container_popups(open_container_popups)

func _prune_and_rebind_popups() -> void:
	var eq_vest: Dictionary = equipment_data.get("vest", {})
	var eq_bp: Dictionary = equipment_data.get("backpack", {})
	var corpse_eq: Dictionary = _get_corpse_equipment()
	var corpse_vest: Dictionary = corpse_eq.get("vest", {}) if not corpse_eq.is_empty() else {}
	var corpse_bp: Dictionary = corpse_eq.get("backpack", {}) if not corpse_eq.is_empty() else {}
	InventoryUIHelper.prune_and_rebind_popups(
		open_container_popups,
		[inventory_grid],
		[eq_vest, eq_bp, corpse_vest, corpse_bp]
	)

func open_container_popup(container_item: Dictionary, src_grid: InventoryGrid = null) -> void:
	if container_item.is_empty() or not InventoryGrid.is_container_item(container_item):
		return
	var cuid := str(container_item.get("uid", ""))
	if cuid == "":
		cuid = "equip_vest_" + str(container_item.get("id", "container"))
	if open_container_popups.has(cuid):
		var existing: ContainerPopupWindow = open_container_popups[cuid] as ContainerPopupWindow
		if is_instance_valid(existing):
			existing.move_to_front()
			return
		open_container_popups.erase(cuid)

	var popup := ContainerPopupWindow.new()
	add_child(popup)
	popup.setup(container_item, src_grid, self)
	var idx := open_container_popups.size()
	var base_pos := Vector2(340.0 + float(idx) * 28.0, 64.0 + float(idx) * 24.0)
	popup.position = InventoryUIHelper.clamp_popup_position(popup, base_pos, size, 8.0)
	open_container_popups[cuid] = popup

	popup.popup_closed.connect(func(_closed_uid: String):
		open_container_popups.erase(cuid)
		if inventory_grid:
			inventory_grid.grid_changed.emit()
		_update_weight_ui()
		_update_corpse_equipment_ui()
	)
	popup.popup_grid_changed.connect(func(_changed_uid: String):
		if player:
			player.set("equipment", equipment_data)
			if player.has_signal("stats_changed"):
				player.stats_changed.emit()
		if target_inventory and bool(target_inventory.get_meta("is_corpse", false)):
			target_inventory.inventory_changed.emit()
			_update_corpse_equipment_ui()
		_update_weight_ui()
	)
	popup.item_drag_started.connect(func(p_win: ContainerPopupWindow, it: Dictionary, c_pos: Vector2i):
		_start_drag("popup_grid", it, c_pos, "", null, p_win.inner_grid)
	)
	popup.item_split_requested.connect(func(p_win: ContainerPopupWindow, it: Dictionary, c_pos: Vector2i):
		_open_split_dialog(it, func(split_amt):
			var split_item: Dictionary = InventoryUIHelper.prepare_split_drag_item(it, int(split_amt), p_win.inner_grid)
			_start_drag("split", split_item, c_pos, "", null, p_win.inner_grid)
			drag_data["is_split"] = true
			drag_data["split_source_item"] = it
			drag_data["split_source_grid"] = p_win.inner_grid
			drag_data["split_amount"] = split_amt
		)
	)
	popup.item_quick_action_requested.connect(_handle_popup_quick_action)
	popup.item_context_menu_requested.connect(func(p_win: ContainerPopupWindow, it: Dictionary):
		if tooltip: tooltip.hide()
		_show_context_menu(it, "popup_grid", "", p_win.inner_grid)
	)
	popup.item_hovered.connect(func(_p_win: ContainerPopupWindow, it: Dictionary):
		if not is_dragging and tooltip and not it.is_empty():
			var d := ItemDatabase.get_item_data(str(it.get("id", "")))
			tooltip.display_item(it, d)
			tooltip.update_position(get_global_mouse_position())
	)
	popup.item_unhovered.connect(func(_p_win: ContainerPopupWindow):
		if tooltip: tooltip.hide()
	)
	if SoundManager: SoundManager.play("menu_select")

func _toggle_lock_at_mouse() -> bool:
	var m_pos := get_global_mouse_position()
	var pop_lock: int = InventoryUIHelper.toggle_lock_in_top_popup(self, m_pos, tooltip, true)
	if pop_lock != 0:
		return pop_lock > 0
	if grid_control and inventory_grid and grid_control.get_global_rect().has_point(m_pos) and hovered_grid_cell != Vector2i(-1, -1):
		var h_it := inventory_grid.get_item_at(hovered_grid_cell.x, hovered_grid_cell.y)
		if not h_it.is_empty():
			var now_l := inventory_grid.toggle_item_lock(str(h_it.get("uid", "")))
			var d := ItemDatabase.get_item_data(str(h_it.get("id", "")))
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit(("[icon:lock] [%s] 잠금됨" if now_l else "[icon:unlock] [%s] 잠금 해제") % str(d.get("name", h_it.get("id", ""))))
			if tooltip and tooltip.visible:
				tooltip.display_item(h_it, d)
			if SoundManager: SoundManager.play("menu_select")
			return true
	return false

func _log_container_reject_reason(reason: String) -> void:
	InventoryUIHelper.log_container_reject_reason(reason)

func _try_drop_on_popup(popup: ContainerPopupWindow, cell_x: int, cell_y: int) -> void:
	if not is_dragging or not popup or not popup.inner_grid:
		_end_drag()
		return
	var target_grid := popup.inner_grid
	var item: Dictionary = drag_data.get("item", {})
	var item_id := str(item.get("id", ""))
	var is_rot := bool(drag_data.get("rotated", false))
	var base_size := ItemDatabase.get_item_grid_size(item_id)
	var base_w := int(item.get("w", base_size.x))
	var base_h := int(item.get("h", base_size.y))
	var place_w := base_h if is_rot else base_w
	var place_h := base_w if is_rot else base_h
	var src := str(drag_data.get("source", ""))
	var src_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
	var uid := str(item.get("uid", ""))
	var same_grid := (src_grid == target_grid)
	var ignore_uid := uid if same_grid else ""

	# 1. 수납 제한 / 자기자신 / 중첩 깊이 사전 검사
	var accept := target_grid.can_accept_item(item, item_id)
	if not bool(accept.get("ok", true)):
		_log_container_reject_reason(str(accept.get("reason", "")))
		if SoundManager: SoundManager.play("hit_melee")
		_end_drag()
		return

	# 2. 같은 아이템 스택 병합 시도
	var m_local := popup.grid_control.get_local_mouse_position()
	var m_cx := int(floor(m_local.x / popup.POPUP_CELL_SIZE))
	var m_cy := int(floor(m_local.y / popup.POPUP_CELL_SIZE))
	var target_item := target_grid.get_item_at(m_cx, m_cy)
	if target_item.is_empty():
		target_item = target_grid.get_item_at(cell_x, cell_y)
	if not target_item.is_empty() and InventoryGrid.is_same_item_id(str(target_item.get("id", "")), item_id) and str(target_item.get("uid", "")) != uid:
		var idata := ItemDatabase.get_item_data(item_id)
		var max_stack := int(idata.get("max_stack", 1))
		if max_stack > 1:
			var cur_amt := int(target_item.get("amount", 1))
			var space := max_stack - cur_amt
			if space > 0:
				var drag_amt := int(item.get("amount", 1))
				var to_add := mini(space, drag_amt)
				target_item["amount"] = cur_amt + to_add
				var rem_amt := drag_amt - to_add
				if rem_amt <= 0:
					if src == "grid" and inventory_grid:
						inventory_grid.remove_item_by_uid(uid)
					elif src == "popup_grid" and src_grid:
						src_grid.remove_item_by_uid(uid)
					elif src == "split":
						drag_data["is_split"] = false
					elif src == "container":
						var orig_idx := int(drag_data.get("origin_index", -1))
						if orig_idx != -1 and target_inventory:
							target_inventory.remove_item_at(orig_idx, drag_amt)
							_update_container_list()
					elif src == "vicinity":
						var ground_node = drag_data.get("ground_ref")
						if is_instance_valid(ground_node): ground_node.queue_free()
						_update_vicinity_list(true)
					elif src == "equipment":
						equipment_data[drag_data.get("slot_name", "")] = {}
						_apply_backpack_grid_size()
						_update_equipment_ui()
					elif src == "weapon_slot":
						var s_name := str(drag_data.get("slot_name", ""))
						equipment_data[s_name] = {}
						_sync_weapon_to_player(s_name)
						_update_weapons_ui()
					elif src == "attachment":
						_remove_attachment_from_weapon_slot(str(drag_data.get("weapon_slot", "")), str(drag_data.get("attach_slot", "")), int(drag_data.get("rail_index", -1)), item_id)
						_update_weapons_ui()
					elif src == "corpse_equip":
						_consume_corpse_equip_drag_source()
				else:
					item["amount"] = rem_amt
					if src == "grid" and inventory_grid:
						var o_it := inventory_grid.get_item_by_uid(uid)
						if not o_it.is_empty(): o_it["amount"] = rem_amt
						inventory_grid.grid_changed.emit()
					elif src == "popup_grid" and src_grid:
						var p_it := src_grid.get_item_by_uid(uid)
						if not p_it.is_empty(): p_it["amount"] = rem_amt
						src_grid.grid_changed.emit()
					elif src == "split":
						var orig_sp = drag_data.get("split_source_item", {})
						if not orig_sp.is_empty():
							orig_sp["amount"] = int(orig_sp.get("amount", 0)) + rem_amt
						drag_data["is_split"] = false
						var sp_grid: InventoryGrid = drag_data.get("split_source_grid", inventory_grid) as InventoryGrid
						if sp_grid: sp_grid.grid_changed.emit()
					elif src == "container":
						var orig_idx := int(drag_data.get("origin_index", -1))
						if orig_idx != -1 and target_inventory:
							target_inventory.remove_item_at(orig_idx, to_add)
							_update_container_list()
					elif src == "vicinity":
						var ground_node = drag_data.get("ground_ref")
						if is_instance_valid(ground_node):
							ground_node.amount = rem_amt
							ground_node.update_visuals()
						_update_vicinity_list(true)
				target_grid.grid_changed.emit()
				if SoundManager: SoundManager.play("menu_select")
				_end_drag()
				return

	# 3. 빈 셀 배치
	if target_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item_id, item):
		if same_grid:
			target_grid.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
		elif target_grid.place_item(item, cell_x, cell_y, is_rot):
			if src == "split":
				drag_data["is_split"] = false
			elif src == "grid" and inventory_grid:
				inventory_grid.remove_item_by_uid(uid)
			elif src == "popup_grid" and src_grid:
				src_grid.remove_item_by_uid(uid)
			elif src == "vicinity":
				var ground_node = drag_data.get("ground_ref")
				if is_instance_valid(ground_node): ground_node.queue_free()
				_update_vicinity_list(true)
			elif src == "container":
				var orig_idx := int(drag_data.get("origin_index", -1))
				if orig_idx != -1 and target_inventory:
					target_inventory.remove_item_at(orig_idx, int(item.get("amount", 1)))
					_update_container_list()
			elif src == "equipment":
				equipment_data[drag_data.get("slot_name", "")] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
			elif src == "weapon_slot":
				var s_name := str(drag_data.get("slot_name", ""))
				equipment_data[s_name] = {}
				_sync_weapon_to_player(s_name)
				_update_weapons_ui()
			elif src == "attachment":
				_remove_attachment_from_weapon_slot(str(drag_data.get("weapon_slot", "")), str(drag_data.get("attach_slot", "")), int(drag_data.get("rail_index", -1)), item_id)
				_update_weapons_ui()
			elif src == "corpse_equip":
				_consume_corpse_equip_drag_source()
			if SoundManager: SoundManager.play("menu_select")
		else:
			if SoundManager: SoundManager.play("hit_melee")
	else:
		if SoundManager: SoundManager.play("hit_melee")
	_end_drag()

func _handle_popup_quick_action(popup: ContainerPopupWindow, item: Dictionary, is_ctrl: bool) -> void:
	if not popup or not popup.inner_grid or item.is_empty():
		return
	var item_id := str(item.get("id", ""))
	var amt := maxi(1, int(item.get("amount", 1)))
	var uid := str(item.get("uid", ""))
	if (is_ctrl or _is_corpse_equipment_popup(popup)) and inventory_grid:
		var rem := inventory_grid.auto_add_item(item_id, amt, item)
		var added := amt - rem
		if added > 0:
			if rem <= 0:
				popup.inner_grid.remove_item_by_uid(uid)
			else:
				item["amount"] = rem
				popup.inner_grid.grid_changed.emit()
			if SoundManager: SoundManager.play("menu_select")
		else:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 메인 가방 공간이 부족합니다.")
	elif target_inventory != null:
		var rem := target_inventory.add_item(item_id, amt, item)
		var added := amt - rem
		if added > 0:
			if rem <= 0:
				popup.inner_grid.remove_item_by_uid(uid)
			else:
				item["amount"] = rem
				popup.inner_grid.grid_changed.emit()
			_update_container_list()
			if SoundManager: SoundManager.play("menu_select")
	else:
		if inventory_grid:
			var rem := inventory_grid.auto_add_item(item_id, amt, item)
			var added := amt - rem
			if added > 0:
				if rem <= 0:
					popup.inner_grid.remove_item_by_uid(uid)
				else:
					item["amount"] = rem
					popup.inner_grid.grid_changed.emit()
				if SoundManager: SoundManager.play("menu_select")
