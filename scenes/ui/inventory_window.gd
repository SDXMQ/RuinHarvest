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

func _ready() -> void:
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
			"primary1": {"id": "M4_리시버", "name": "M4A1 소총", "attachments": {}},
			"primary2": {},
			"sidearm": {"id": "M9_리시버", "name": "M9 권총", "attachments": {}},
			"throwable": {"id": "수류탄", "amount": 2}
		}
		if player: player.set("equipment", equipment_data)
		
	_apply_backpack_grid_size()
	_refresh_all()

func _process(delta: float) -> void:
	vicinity_update_timer -= delta
	if vicinity_update_timer <= 0.0:
		vicinity_update_timer = 0.25 # 0.25초마다 주변 탐색 갱신
		_update_vicinity_list()
		
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - Vector2(20, 20)
		grid_control.queue_redraw()

func _refresh_all() -> void:
	_update_grid_ui_size()
	_update_container_list()
	_update_vicinity_list()
	_update_equipment_ui()
	_update_weapons_ui()
	_update_weight_ui()
	grid_control.queue_redraw()

func _on_grid_changed() -> void:
	_update_weight_ui()
	grid_control.queue_redraw()

# ============================================================
# 1. 타르코프식 2D 그리드 (WxH) 렌더링 및 인터랙션
# ============================================================
func _update_grid_ui_size() -> void:
	if not inventory_grid: return
	var total_w = inventory_grid.grid_width * CELL_SIZE
	var total_h = inventory_grid.grid_height * CELL_SIZE
	grid_control.custom_minimum_size = Vector2(total_w, total_h)
	grid_title_label.text = "🎒 가방 (%d x %d, 총 %d칸)" % [inventory_grid.grid_width, inventory_grid.grid_height, inventory_grid.grid_width * inventory_grid.grid_height]

func _on_grid_draw() -> void:
	if not inventory_grid: return
	
	var gw = inventory_grid.grid_width
	var gh = inventory_grid.grid_height
	
	# 1. 격자 배경 그리기
	for y in range(gh):
		for x in range(gw):
			var cell_rect = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			var bg_col = Color(0.1, 0.12, 0.16, 0.6) if (x + y) % 2 == 0 else Color(0.08, 0.1, 0.13, 0.6)
			grid_control.draw_rect(cell_rect, bg_col, true)
			grid_control.draw_rect(cell_rect, Color(0.2, 0.25, 0.32, 0.4), false, 1.0)
			
	# 2. 배치된 아이템 그리기
	for item in inventory_grid.items:
		if is_dragging and drag_data.get("source") == "grid" and drag_data.get("item", {}).get("uid") == item.get("uid"):
			continue # 드래그 중인 원본은 투명하게 숨김
			
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		var item_rect = Rect2(item.get("x", 0) * CELL_SIZE + 2, item.get("y", 0) * CELL_SIZE + 2, cur_w * CELL_SIZE - 4, cur_h * CELL_SIZE - 4)
		
		# 아이템 배경
		var item_bg = Color(0.16, 0.22, 0.3, 0.85)
		grid_control.draw_rect(item_rect, item_bg, true)
		grid_control.draw_rect(item_rect, Color(0.3, 0.6, 0.9, 0.9), false, 1.5)
		
		# 아이콘 그리기
		var icon_tex = ItemIconManager.get_icon(item.get("id", "")) if ItemIconManager else null
		if icon_tex:
			var icon_size = Vector2(min(item_rect.size.x, item_rect.size.y) * 0.75, min(item_rect.size.x, item_rect.size.y) * 0.75)
			var icon_pos = item_rect.position + (item_rect.size - icon_size) / 2.0
			grid_control.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		# 수량 텍스트
		var amt = item.get("amount", 1)
		if amt > 1:
			var font = ThemeDB.fallback_font
			grid_control.draw_string(font, item_rect.position + Vector2(4, item_rect.size.y - 4), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 0.4))
			
		# 이름 텍스트
		var font = ThemeDB.fallback_font
		var d = ItemDatabase.get_item_data(item.get("id", ""))
		grid_control.draw_string(font, item_rect.position + Vector2(4, 12), d.get("name", item.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 8, 10, Color(0.9, 0.9, 0.9, 0.8))

	# 3. 드래그 중 고스트 프리뷰 (초록색 / 빨간색)
	if is_dragging and hovered_grid_cell.x >= 0 and hovered_grid_cell.y >= 0:
		var item = drag_data.get("item", {})
		var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
		var base_w = item.get("w", base_size.x)
		var base_h = item.get("h", base_size.y)
		var is_rot = drag_data.get("rotated", false)
		var place_w = base_h if is_rot else base_w
		var place_h = base_w if is_rot else base_h
		
		var src = drag_data.get("source", "")
		var uid = item.get("uid", "")
		var ignore_uid = uid if src == "grid" else ""
		var can_place = inventory_grid.can_place_item(place_w, place_h, hovered_grid_cell.x, hovered_grid_cell.y, ignore_uid)
		var ghost_rect = Rect2(hovered_grid_cell.x * CELL_SIZE, hovered_grid_cell.y * CELL_SIZE, place_w * CELL_SIZE, place_h * CELL_SIZE)
		
		var col = Color(0.2, 0.8, 0.3, 0.4) if can_place else Color(0.9, 0.2, 0.2, 0.4)
		var border_col = Color(0.3, 1.0, 0.4, 0.9) if can_place else Color(1.0, 0.3, 0.3, 0.9)
		
		grid_control.draw_rect(ghost_rect, col, true)
		grid_control.draw_rect(ghost_rect, border_col, false, 2.0)

func _input(event: InputEvent) -> void:
	if not visible: return
	
	# Tab, ESC, 인벤토리 단축키 입력 시 인벤토리 창 닫기 (포커스 상태와 무관하게 즉시 닫힘 보장)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB or event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE or event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
			if is_dragging:
				_end_drag()
			_on_close_pressed()
			get_viewport().set_input_as_handled()
			return
	
	# 드래그 중 R 키 누르면 W <-> H 회전
	if is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			drag_data["rotated"] = not drag_data.get("rotated", false)
			grid_control.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	# 드래그 중 마우스 이동 시 실시간 그리드 좌표 갱신, 드래그 프리뷰 위치 및 슬롯 하이라이트 갱신
	if is_dragging and event is InputEventMouseMotion:
		var m_pos = get_global_mouse_position()
		if drag_preview:
			drag_preview.global_position = m_pos - Vector2(20, 20)
			
		var g_mouse = grid_control.get_local_mouse_position()
		var cell_x = int(g_mouse.x / CELL_SIZE)
		var cell_y = int(g_mouse.y / CELL_SIZE)
		if cell_x >= 0 and cell_x < inventory_grid.grid_width and cell_y >= 0 and cell_y < inventory_grid.grid_height:
			hovered_grid_cell = Vector2i(cell_x, cell_y)
		else:
			hovered_grid_cell = Vector2i(-1, -1)
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
	
	# 1. 2D 그리드 영역 위인지 검사
	var grid_global_rect = grid_control.get_global_rect()
	if grid_global_rect.has_point(m_pos):
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
				_try_equip_attachment(target.get("weapon_slot_key", ""), target.get("attach_type", ""))
				return
				
	# 3. 수색 대상(ContainerSection) 위로 드롭했는지 검사
	if target_inventory and container_section.is_visible_in_tree() and container_section.get_global_rect().has_point(m_pos):
		_try_drop_on_container()
		return
			
	# 4. 주변(Vicinity) 컬럼 또는 화면 바깥으로 드롭했는지 검사 (월드에 버리기)
	var vicinity_rect = vicinity_section.get_global_rect() if is_instance_valid(vicinity_section) else $MainLayout/VicinityCol.get_global_rect()
	var window_rect = get_rect()
	if vicinity_rect.has_point(m_pos) or not window_rect.has_point(m_pos):
		var src = drag_data.get("source", "")
		var item = drag_data.get("item", {})
		if src == "grid":
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			_drop_item_to_world(item)
		elif src == "equipment":
			equipment_data[drag_data.get("slot_name", "")] = {}
			_apply_backpack_grid_size()
			_update_equipment_ui()
			_drop_item_to_world(item)
		elif src == "weapon_slot":
			equipment_data[drag_data.get("slot_name", "")] = {}
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
		if cell_x >= 0 and cell_x < inventory_grid.grid_width and cell_y >= 0 and cell_y < inventory_grid.grid_height:
			hovered_grid_cell = Vector2i(cell_x, cell_y)
		else:
			hovered_grid_cell = Vector2i(-1, -1)
			
		if not is_dragging:
			var hovered_item = inventory_grid.get_item_at(cell_x, cell_y)
			if not hovered_item.is_empty():
				var idata = ItemDatabase.get_item_data(hovered_item.get("id", ""))
				tooltip.display_item(hovered_item, idata)
				tooltip.update_position(get_global_mouse_position())
			else:
				tooltip.hide()
		grid_control.queue_redraw()
		
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
					_open_split_dialog(item, func(split_amt):
						var split_item = item.duplicate()
						split_item["amount"] = split_amt
						item["amount"] -= split_amt
						inventory_grid.grid_changed.emit()
						_start_drag("grid", split_item, Vector2i(cell_x, cell_y))
					)
				else:
					_start_drag("grid", item, Vector2i(cell_x, cell_y))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var item = inventory_grid.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				_handle_item_quick_action(item)

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
	
	if inventory_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid):
		if src == "grid":
			inventory_grid.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
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
					_update_weapons_ui()
				elif src == "attachment":
					var w_slot = drag_data.get("weapon_slot", "primary1")
					var a_slot = drag_data.get("attach_slot", "")
					if equipment_data.has(w_slot) and equipment_data[w_slot].has("attachments"):
						equipment_data[w_slot]["attachments"].erase(a_slot)
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
	container_title_label.text = "📦 " + (target_title if target_title != "" else "수색 대상")
	
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
	
	# 드래그 및 우클릭 픽업
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var base_size = ItemDatabase.get_item_grid_size(slot_item.get("id", ""))
				var item_dict = {
					"id": slot_item.get("id", ""),
					"amount": amt,
					"w": base_size.x,
					"h": base_size.y,
					"custom_data": slot_item.get("custom_data", {})
				}
				_start_drag("container", item_dict, Vector2i(index, 0))
				drag_data["origin_index"] = index
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# 우클릭 시 가방으로 즉시 픽업 (Auto-Fit)
				var rem = inventory_grid.auto_add_item(slot_item.get("id", ""), amt, slot_item.get("custom_data", {}))
				var added = amt - rem
				if added > 0:
					target_inventory.remove_item_at(index, added)
					if SoundManager: SoundManager.play("menu_select")
					_update_container_list()
				if rem > 0:
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
	)
	
	container_list.add_child(btn)

func _try_drop_on_container() -> void:
	if not target_inventory:
		_end_drag()
		return
		
	var src = drag_data.get("source", "")
	var item = drag_data.get("item", {})
	var item_id = item.get("id", "")
	var amt = item.get("amount", 1)
	
	var rem = target_inventory.add_item(item_id, amt)
	var added = amt - rem
	
	if added > 0:
		if src == "grid":
			if rem <= 0:
				inventory_grid.remove_item_by_uid(item.get("uid", ""))
			else:
				item["amount"] = rem
				inventory_grid.grid_changed.emit()
		elif src == "equipment":
			if rem <= 0:
				equipment_data[drag_data.get("slot_name", "")] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
			else:
				item["amount"] = rem
		elif src == "weapon_slot":
			if rem <= 0:
				equipment_data[drag_data.get("slot_name", "")] = {}
				_update_weapons_ui()
			else:
				item["amount"] = rem
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

func _update_vicinity_list() -> void:
	for c in vicinity_list.get_children():
		if c != vicinity_empty_label:
			c.queue_free()
			
	var p_pos = player.global_position if player else Vector2.ZERO
	var ground_items = get_tree().get_nodes_in_group("ground_items")
	var nearby_items: Array = []
	
	for g_item in ground_items:
		if is_instance_valid(g_item) and g_item is GroundItem:
			var dist = p_pos.distance_to(g_item.global_position)
			if dist <= 140.0: # 반경 약 140px 내 아이템
				nearby_items.append(g_item)
				
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
	
	# 드래그 및 우클릭 픽업
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var base_size = ItemDatabase.get_item_grid_size(g_item.item_id)
				var item_dict = {
					"id": g_item.item_id,
					"amount": g_item.amount,
					"w": base_size.x,
					"h": base_size.y,
					"custom_data": g_item.custom_data
				}
				_start_drag("vicinity", item_dict, Vector2i.ZERO, "", g_item)
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				# 우클릭 시 가방으로 즉시 픽업 (Auto-Fit)
				var rem = inventory_grid.auto_add_item(g_item.item_id, g_item.amount, g_item.custom_data)
				if rem <= 0:
					g_item.queue_free()
					if SoundManager: SoundManager.play("menu_select")
					_update_vicinity_list()
				else:
					g_item.amount = rem
					g_item.update_visuals()
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
	)
	
	vicinity_list.add_child(btn)

func _drop_item_to_world(item: Dictionary) -> void:
	if not player or not get_parent(): return
	
	var g_item = GroundItemScene.instantiate()
	var spawn_pos = player.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	g_item.global_position = spawn_pos
	
	var world_node = get_tree().current_scene
	if world_node and world_node.has_node("Entities"):
		world_node.get_node("Entities").add_child(g_item)
	else:
		world_node.add_child(g_item)
		
	g_item.setup(item.get("id", ""), item.get("amount", 1), item.get("custom_data", {}))
	
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📦 %s을(를) 바닥에 버렸습니다." % ItemDatabase.get_item_data(item.get("id", "")).get("name", item.get("id", "")))
	_update_vicinity_list()

# ============================================================
# 3. 캐릭터 장비 슬롯 & 가방 용량 연동
# ============================================================
func _connect_equipment_slot(btn: Button, slot_name: String) -> void:
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
				# 우클릭 시 가방으로 탈착
				var equipped = equipment_data.get(slot_name, {})
				if not equipped.is_empty():
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
	var idata = ItemDatabase.get_item_data(item_id)
	var cat = idata.get("category", -1)
	var e_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	if slot_name == "helmet":
		return e_slot == "helmet" or item_id.contains("헬멧") or item_id.contains("방독면")
	elif slot_name == "vest":
		return e_slot == "vest" or item_id.contains("방탄") or item_id.contains("조끼")
	elif slot_name == "backpack":
		return e_slot == "backpack" or item_id.contains("가방") or item_id.contains("배낭")
	elif slot_name == "bottom":
		return e_slot == "bottom" or item_id.contains("운동화") or item_id.contains("신발")
	elif slot_name.begins_with("primary"):
		return cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or e_slot == "primary"
	elif slot_name == "sidearm":
		return idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or e_slot == "sidearm" or e_slot == "melee"
	elif slot_name == "throwable":
		return item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or e_slot == "throwable"
	return false

func _apply_backpack_grid_size() -> void:
	var bp = equipment_data.get("backpack", {})
	var new_w = 4
	var new_h = 4
	
	if not bp.is_empty():
		var id = bp.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var b_grid = d.get("backpack_grid", Vector2i(6, 4))
		new_w = b_grid.x
		new_h = b_grid.y
		
	if inventory_grid:
		var dropped = inventory_grid.resize_grid(new_w, new_h)
		for it in dropped:
			_drop_item_to_world(it)
	_update_grid_ui_size()

func _update_equipment_ui() -> void:
	_render_equip_slot_button(helmet_slot, "helmet", "🪖 헬멧")
	_render_equip_slot_button(vest_slot, "vest", "🦺 방탄복")
	_render_equip_slot_button(backpack_slot, "backpack", "🎒 배낭")
	_render_equip_slot_button(bottom_slot, "bottom", "👟 하의/신발")
	
	_rebuild_drop_targets()
	
	# 플레이어 방어력 스탯 동기화
	if player:
		var total_defense = 0.0
		for slot in ["helmet", "vest"]:
			var it = equipment_data.get(slot, {})
			if not it.is_empty():
				var d = ItemDatabase.get_item_data(it.get("id", ""))
				total_defense += d.get("defense", 0.0)
		player.set("armor_defense", total_defense)

func _rebuild_drop_targets() -> void:
	drop_targets.clear()
	drop_targets.append({"control": helmet_slot, "type": "equipment", "slot_name": "helmet"})
	drop_targets.append({"control": vest_slot, "type": "equipment", "slot_name": "vest"})
	drop_targets.append({"control": backpack_slot, "type": "equipment", "slot_name": "backpack"})
	drop_targets.append({"control": bottom_slot, "type": "equipment", "slot_name": "bottom"})

func _render_equip_slot_button(btn: Button, slot_name: String, default_text: String) -> void:
	var it = equipment_data.get(slot_name, {})
	if it.is_empty():
		btn.text = default_text
		btn.icon = null
	else:
		var d = ItemDatabase.get_item_data(it.get("id", ""))
		btn.text = d.get("name", it.get("id", ""))
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(it.get("id", ""))
			btn.expand_icon = true

# ============================================================
# 4. 무기 슬롯 & 부착물 서브 슬롯 모딩
# ============================================================
func _update_weapons_ui() -> void:
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
		wep_btn.text = "🔫 %s" % d.get("name", weapon_dict.get("id", ""))
		if ItemIconManager: wep_btn.icon = ItemIconManager.get_icon(weapon_dict.get("id", ""))
	top_hbox.add_child(wep_btn)
	
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
				# 우클릭 시 가방으로 탈착
				var rem = inventory_grid.auto_add_item(weapon_dict.get("id", ""), weapon_dict.get("amount", 1), weapon_dict)
				if rem <= 0:
					equipment_data[slot_key] = {}
					_update_weapons_ui()
					if tooltip: tooltip.hide()
					if SoundManager: SoundManager.play("menu_select")
	)
	
	# 총기일 경우 5개 부착물 서브 슬롯 노출
	if not weapon_dict.is_empty() and slot_key.begins_with("primary"):
		var attach_hbox = HBoxContainer.new()
		attach_hbox.add_theme_constant_override("separation", 4)
		vbox.add_child(attach_hbox)
		
		var attach_dict = weapon_dict.get("attachments", {})
		for a_type in ["optic", "muzzle", "grip", "magazine", "stock"]:
			_create_attachment_sub_slot(attach_hbox, slot_key, a_type, attach_dict.get(a_type, ""))
			
	weapons_vbox.add_child(panel)

func _create_attachment_sub_slot(parent: HBoxContainer, weapon_slot_key: String, attach_type: String, current_part_id: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(58, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	
	var slot_labels = {
		"optic": "조준경", "muzzle": "총구", "grip": "손잡이", "magazine": "탄창", "stock": "개머리판"
	}
	
	if current_part_id == "":
		btn.text = slot_labels.get(attach_type, attach_type)
		btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		btn.add_theme_font_size_override("font_size", 10)
	else:
		var p_data = WeaponPartsDatabase.PARTS.get(current_part_id, {})
		btn.text = p_data.get("name", current_part_id)
		btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		btn.add_theme_font_size_override("font_size", 10)
		
	drop_targets.append({"control": btn, "type": "attachment", "weapon_slot_key": weapon_slot_key, "attach_type": attach_type})
		
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_dragging:
					_try_equip_attachment(weapon_slot_key, attach_type)
			elif event.button_index == MOUSE_BUTTON_RIGHT and current_part_id != "":
				# 부착물 가방으로 탈착
				var rem = inventory_grid.auto_add_item(current_part_id, 1)
				if rem <= 0:
					equipment_data[weapon_slot_key]["attachments"].erase(attach_type)
					_update_weapons_ui()
					if SoundManager: SoundManager.play("menu_select")
	)
	
	parent.add_child(btn)

func _try_equip_weapon(slot_key: String) -> void:
	var item = drag_data.get("item", {})
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
	if not item.has("attachments"): item["attachments"] = {}
	equipment_data[slot_key] = item
	
	if not prev.is_empty():
		inventory_grid.auto_add_item(prev.get("id", ""), prev.get("amount", 1), prev)
		
	_update_weapons_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

func _try_equip_attachment(weapon_slot_key: String, attach_type: String) -> void:
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
		
	var src = drag_data.get("source", "")
	if src == "grid": inventory_grid.remove_item_by_uid(item.get("uid", ""))
	elif src == "vicinity":
		var ground_node = drag_data.get("ground_ref")
		if is_instance_valid(ground_node): ground_node.queue_free()
		
	if not equipment_data[weapon_slot_key].has("attachments"):
		equipment_data[weapon_slot_key]["attachments"] = {}
		
	var prev_part = equipment_data[weapon_slot_key]["attachments"].get(attach_type, "")
	equipment_data[weapon_slot_key]["attachments"][attach_type] = part_id
	
	if prev_part != "":
		inventory_grid.auto_add_item(prev_part, 1)
		
	_update_weapons_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

# ============================================================
# 5. UX & 인터랙션 (드래그, 회전, 분할, 우클릭 액션)
# ============================================================
func _start_drag(source_type: String, item: Dictionary, origin_pos: Vector2i = Vector2i.ZERO, slot_name: String = "", ground_ref: Node = null) -> void:
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
	
	# 드래그 고스트 프리뷰 위젯 생성
	if drag_preview: drag_preview.queue_free()
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 200
	add_child(drag_preview)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ItemIconManager: icon.texture = ItemIconManager.get_icon(item.get("id", ""))
	icon.modulate = Color(1, 1, 1, 0.8)
	drag_preview.add_child(icon)
	
	drag_preview.global_position = get_global_mouse_position() - Vector2(20, 20)
	grid_control.queue_redraw()
	_highlight_compatible_slots(item, null)

func _end_drag() -> void:
	is_dragging = false
	drag_data.clear()
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	_clear_slot_highlights()
	grid_control.queue_redraw()

func _highlight_compatible_slots(item: Dictionary, hovered_ctrl: Control = null) -> void:
	var item_id = item.get("id", "")
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree(): continue
		
		var t_type = target.get("type", "")
		var is_compat = false
		
		if t_type == "equipment":
			is_compat = _is_slot_compatible(item_id, target.get("slot_name", ""))
		elif t_type == "weapon":
			var slot_key = target.get("slot_key", "")
			var eq_slot = ItemDatabase.get_item_equip_slot(item_id)
			var idata = ItemDatabase.get_item_data(item_id)
			var cat = idata.get("category", -1)
			if slot_key.begins_with("primary"):
				is_compat = (cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or eq_slot == "primary" or eq_slot == "")
			elif slot_key == "sidearm":
				is_compat = (idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or eq_slot == "sidearm" or eq_slot == "melee")
			elif slot_key == "throwable":
				is_compat = (item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or eq_slot == "throwable")
		elif t_type == "attachment":
			var attach_type = target.get("attach_type", "")
			var p_data = WeaponPartsDatabase.PARTS.get(item_id, {})
			is_compat = (p_data.get("slot", "") == attach_type)
			
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		
		if ctrl == hovered_ctrl:
			if is_compat:
				# 마우스 호버 + 장착 가능 -> 선명한 네온 초록 테두리 & 밝은 배경
				sb.bg_color = Color(0.12, 0.42, 0.18, 0.9)
				sb.border_color = Color(0.3, 1.0, 0.5, 1.0)
				sb.set_border_width_all(2)
			else:
				# 마우스 호버 + 장착 불가 -> 빨간색 경고 테두리
				sb.bg_color = Color(0.42, 0.12, 0.12, 0.9)
				sb.border_color = Color(1.0, 0.3, 0.3, 1.0)
				sb.set_border_width_all(2)
		else:
			if is_compat:
				# 장착 가능 슬롯 안내 가이드 -> 은은한 초록 테두리
				sb.bg_color = Color(0.08, 0.24, 0.14, 0.65)
				sb.border_color = Color(0.2, 0.85, 0.4, 0.85)
				sb.set_border_width_all(2)
			else:
				# 일반 비호환 슬롯 -> 기본
				sb.bg_color = Color(0.14, 0.15, 0.18, 0.5)
				sb.border_color = Color(0.25, 0.28, 0.32, 0.4)
				sb.set_border_width_all(1)
				
		ctrl.add_theme_stylebox_override("normal", sb)
		ctrl.add_theme_stylebox_override("hover", sb)

func _clear_slot_highlights() -> void:
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if is_instance_valid(ctrl):
			ctrl.remove_theme_stylebox_override("normal")
			ctrl.remove_theme_stylebox_override("hover")

func _open_split_dialog(item: Dictionary, on_confirm: Callable) -> void:
	var diag = SplitDialogScene.instantiate()
	add_child(diag)
	diag.setup(item.get("amount", 1))
	diag.split_confirmed.connect(on_confirm)

func _handle_item_quick_action(item: Dictionary) -> void:
	var id = item.get("id", "")
	var idata = ItemDatabase.get_item_data(id)
	var cat = idata.get("category", -1)
	
	# 1. 장비 아이템이면 빈 장비 슬롯에 퀵 장착
	if cat == ItemDatabase.ItemCategory.EQUIPMENT:
		var slot = ItemDatabase.get_item_equip_slot(id)
		if slot != "" and equipment_data.get(slot, {}).is_empty():
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			equipment_data[slot] = item
			_apply_backpack_grid_size()
			_update_equipment_ui()
			if SoundManager: SoundManager.play("menu_select")
			return
			
	# 2. 음식/의약품이면 즉시 사용
	if cat == ItemDatabase.ItemCategory.FOOD or cat == ItemDatabase.ItemCategory.WATER or cat == ItemDatabase.ItemCategory.MEDICAL:
		_use_consumable_item(item, idata)
		return
		
	# 3. 무기면 빈 무기 슬롯에 퀵 장착
	if cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver":
		if equipment_data.get("primary1", {}).is_empty():
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			equipment_data["primary1"] = item
			_update_weapons_ui()
			return
		elif equipment_data.get("primary2", {}).is_empty():
			inventory_grid.remove_item_by_uid(item.get("uid", ""))
			equipment_data["primary2"] = item
			_update_weapons_ui()
			return

func _use_consumable_item(item: Dictionary, idata: Dictionary) -> void:
	if not player: return
	
	var effects = idata.get("effects", {})
	if effects.has("hp"): player.hp = min(player.max_hp, player.hp + effects["hp"])
	if effects.has("hunger"): player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
	if effects.has("thirst"): player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
	if effects.has("stamina"): player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
	if effects.get("cures_bleeding", false): player.is_bleeding = false
	if effects.get("cures_fracture", false): player.is_fractured = false
	
	player.stats_changed.emit()
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("✨ %s을(를) 사용했습니다." % idata.get("name", item.get("id", "")))
		
	# 1개 소모
	var amt = item.get("amount", 1)
	if amt > 1:
		item["amount"] -= 1
		inventory_grid.grid_changed.emit()
	else:
		inventory_grid.remove_item_by_uid(item.get("uid", ""))

func _update_weight_ui() -> void:
	if not inventory_grid: return
	var cur_w = inventory_grid.get_total_weight()
	weight_label.text = "무게: %.1f / 50.0 kg" % cur_w

func _gui_input(event: InputEvent) -> void:
	# UI 바깥 영역으로 마우스 놓으면 바닥에 아이템 드롭
	if is_dragging and event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var src = drag_data.get("source", "")
			var item = drag_data.get("item", {})
			if src == "grid":
				inventory_grid.remove_item_by_uid(item.get("uid", ""))
				_drop_item_to_world(item)
			elif src == "equipment":
				equipment_data[drag_data.get("slot_name", "")] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
				_drop_item_to_world(item)
			_end_drag()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if player and player.has_method("switch_weapon_slot"):
		player.switch_weapon_slot(player.active_weapon_slot)
	get_tree().paused = false
	queue_free()
	window_closed.emit()
