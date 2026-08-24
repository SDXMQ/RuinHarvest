# res://scenes/hideout/hideout.gd
extends Control

@onready var day_label: Label = $TopBar/DayLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var tab_container: TabContainer = $CenterArea/TabContainer

# 창고 탭 (2D 그리드 & 장비 슬롯)
@onready var player_grid_control: Control = $CenterArea/TabContainer/StashTab/HBox/PlayerPanel/VBox/Scroll/PlayerGridControl
@onready var stash_grid_control: Control = $CenterArea/TabContainer/StashTab/HBox/StashPanel/VBox/Scroll/StashGridControl

@onready var helmet_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/HelmetSlot
@onready var vest_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/VestSlot
@onready var backpack_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/BackpackSlot
@onready var bottom_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/BottomSlot

@onready var primary1_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/Primary1Slot
@onready var primary2_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/Primary2Slot
@onready var sidearm_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/SidearmSlot
@onready var throwable_slot: Button = $CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox/ThrowableSlot

# 상인 탭
@onready var trader_desc_label: Label = $CenterArea/TabContainer/TradersTab/VBox/Header/DescLabel
@onready var trader_items_vbox: VBoxContainer = $CenterArea/TabContainer/TradersTab/VBox/Scroll/ItemsVBox
@onready var trader_sell_grid: HBoxContainer = $CenterArea/TabContainer/TradersTab/VBox/SellArea/Scroll/SellGrid

# 플리마켓 탭
@onready var market_items_vbox: VBoxContainer = $CenterArea/TabContainer/MarketTab/VBox/Scroll/MarketItemsVBox
@onready var market_register_grid: HBoxContainer = $CenterArea/TabContainer/MarketTab/VBox/RegisterArea/Scroll/RegisterGrid

# 작업대 탭 (Workbench)
@onready var wb_weapon_list_vbox: VBoxContainer = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/WeaponListPanel/VBox/Scroll/WeaponListVBox
@onready var wb_preview: Control = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/ModdingCenterPanel/VBox/PreviewPanel/WorkbenchPreview
@onready var wb_slots_grid: GridContainer = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/ModdingCenterPanel/VBox/Scroll/SlotsGrid
@onready var wb_stats_vbox: VBoxContainer = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/StatsAndPresetPanel/VBox/StatsScroll/StatsVBox
@onready var wb_preset_vbox: VBoxContainer = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/StatsAndPresetPanel/VBox/PresetButtonsVBox
@onready var wb_preset_buy_btn: Button = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/StatsAndPresetPanel/VBox/PresetBuyButton
@onready var wb_save_btn: Button = $CenterArea/TabContainer/WorkbenchTab/VBox/MainHBox/StatsAndPresetPanel/VBox/SaveWeaponBtn
@onready var wb_compat_hbox: HBoxContainer = $CenterArea/TabContainer/WorkbenchTab/VBox/CompatPartsPanel/VBox/Scroll/CompatPartsHBox
@onready var wb_compat_title: Label = $CenterArea/TabContainer/WorkbenchTab/VBox/CompatPartsPanel/VBox/CompatTitle

# 하단 바
@onready var raid_button: Button = $BottomBar/RaidButton
@onready var menu_button: Button = $BottomBar/MenuButton

# 결과 팝업
@onready var result_dialog: Panel = $ResultDialog
@onready var result_title: Label = $ResultDialog/VBox/Title
@onready var result_desc: Label = $ResultDialog/VBox/Desc
@onready var result_close_btn: Button = $ResultDialog/VBox/CloseBtn

const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
const SplitDialogScene = preload("res://scenes/ui/split_dialog.tscn")
var tooltip: PanelContainer

# 2D 인벤토리 그리드 시스템
var player_grid_mgr: InventoryGrid
var stash_grid_mgr: InventoryGrid
var equipment_data: Dictionary = {}

const CELL_SIZE: float = 44.0

# 드래그 앤 드롭 상태
var is_dragging: bool = false
var drag_data: Dictionary = {}
var drag_preview_node: Control = null
var hovered_player_cell: Vector2i = Vector2i(-1, -1)
var hovered_stash_cell: Vector2i = Vector2i(-1, -1)

var drop_targets: Array[Dictionary] = []
var current_trader_id: String = "prapor"

# 총기 작업대(Workbench) 상태 변수
var wb_selected_weapon: Dictionary = {}
var wb_base_stats: Dictionary = {}
var wb_weapon_source: Dictionary = {}
var wb_active_slot: String = ""
var wb_current_preset_parts: Dictionary = {}
var wb_missing_preset_cost: int = 0
var wb_missing_preset_parts: Array = []

func _ready() -> void:
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)
	
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	result_close_btn.pressed.connect(_on_result_close_pressed)
	
	# 상단 바에 샌드박스 도구 버튼 추가
	if has_node("TopBar"):
		var tool_btn = Button.new()
		tool_btn.text = "🛠️ 샌드박스/치트 도구 (F1)"
		tool_btn.pressed.connect(_open_item_spawner)
		$TopBar.add_child(tool_btn)
	
	# 상인 버튼 연결
	var prapor_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/PraporBtn
	var therapist_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/TherapistBtn
	var fence_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/FenceBtn
	
	prapor_btn.pressed.connect(func(): _select_trader("prapor"))
	therapist_btn.pressed.connect(func(): _select_trader("therapist"))
	fence_btn.pressed.connect(func(): _select_trader("fence"))
	
	# 2D 인벤토리 매니저 인스턴스화
	player_grid_mgr = InventoryGrid.new()
	player_grid_mgr.grid_width = 6
	player_grid_mgr.grid_height = 4
	add_child(player_grid_mgr)
	
	stash_grid_mgr = InventoryGrid.new()
	stash_grid_mgr.grid_width = 10
	stash_grid_mgr.grid_height = 12
	add_child(stash_grid_mgr)
	
	player_grid_mgr.grid_changed.connect(_on_grid_changed)
	stash_grid_mgr.grid_changed.connect(_on_grid_changed)
	
	# 2D 그리드 드로잉 및 입력 연결
	player_grid_control.draw.connect(_on_player_grid_draw)
	player_grid_control.gui_input.connect(_on_player_grid_gui_input)
	
	stash_grid_control.draw.connect(_on_stash_grid_draw)
	stash_grid_control.gui_input.connect(_on_stash_grid_gui_input)
	
	# 장비 슬롯 연결
	_connect_equipment_slots()
	
	# 작업대 탭 연결
	if wb_preview:
		wb_preview.draw.connect(_on_workbench_preview_draw)
	if wb_preset_buy_btn:
		wb_preset_buy_btn.pressed.connect(_buy_and_assemble_preset)
	if wb_save_btn:
		wb_save_btn.pressed.connect(_save_workbench_weapon)
		
	tab_container.tab_changed.connect(_on_tab_changed)
	
	_load_data()
	_check_last_raid_result()
	_apply_backpack_grid_size()
	_update_equipment_ui()
	_refresh_stash_ui()
	_refresh_trader_ui()
	_refresh_market_ui()
	_refresh_workbench_ui()

func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())
	if is_dragging and drag_preview_node:
		drag_preview_node.global_position = get_global_mouse_position() - Vector2(22, 22)

func _on_tab_changed(tab: int) -> void:
	if tooltip: tooltip.hide()
	if tab == 0:
		_refresh_stash_ui()
	elif tab == 1:
		_refresh_trader_ui()
	elif tab == 2:
		_refresh_market_ui()
	elif tab == 3:
		_refresh_workbench_ui()

func _on_grid_changed() -> void:
	if player_grid_control: player_grid_control.queue_redraw()
	if stash_grid_control: stash_grid_control.queue_redraw()
	_refresh_trader_sell_ui()
	_sync_save_data()

func _load_data() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var w_data = GameManager.current_world_data
		var day = w_data.get("current_day", 1)
		day_label.text = "생존 %d일차 (DAY %d)" % [day, day]
		_update_money_label()
		
		# 장비 데이터 로드
		var p_data = w_data.get("player", {})
		if p_data.has("equipment") and not p_data["equipment"].is_empty():
			equipment_data = p_data["equipment"].duplicate(true)
		else:
			equipment_data = {
				"helmet": {"id": "1레벨_헬멧", "name": "1레벨 오토바이 헬멧"},
				"vest": {"id": "1레벨_방탄복", "name": "1레벨 경찰 조끼"},
				"backpack": {"id": "1레벨_가방", "name": "1레벨 소형 배낭"},
				"bottom": {"id": "운동화", "name": "운동화"},
				"primary1": {"id": "M4_리시버", "name": "M4A1 소총", "attachments": {}},
				"primary2": {},
				"sidearm": {"id": "M9_리시버", "name": "M9 베레타", "attachments": {}},
				"throwable": {"id": "수류탄", "amount": 2}
			}
		
		# 배낭 2D 데이터 로드
		var p_items = p_data.get("inventory", [])
		player_grid_mgr.clear()
		for it in p_items:
			if it is Dictionary and it.has("id"):
				player_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)
				
		# 창고 2D 데이터 로드
		var stash_items = w_data.get("hideout", {}).get("stash", [])
		stash_grid_mgr.clear()
		for it in stash_items:
			if it is Dictionary and it.has("id"):
				stash_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)

func _update_money_label() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var rubles = GameManager.current_world_data.get("player", {}).get("rubles", 5000)
		money_label.text = "자금: %d RUB" % rubles

func _sync_save_data() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		GameManager.current_world_data["player"]["inventory"] = player_grid_mgr.items.duplicate(true)
		GameManager.current_world_data["player"]["equipment"] = equipment_data.duplicate(true)
		
		if not GameManager.current_world_data.has("hideout"):
			GameManager.current_world_data["hideout"] = {}
		GameManager.current_world_data["hideout"]["stash"] = stash_grid_mgr.items.duplicate(true)
		
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)

# ============================================================
# 2D 그리드 렌더링 및 UI
# ============================================================
func _refresh_stash_ui() -> void:
	_apply_backpack_grid_size()
	_update_equipment_ui()
	if player_grid_control: player_grid_control.queue_redraw()
	if stash_grid_control: stash_grid_control.queue_redraw()

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
		
	if player_grid_mgr:
		var dropped = player_grid_mgr.resize_grid(new_w, new_h)
		for it in dropped:
			stash_grid_mgr.auto_add_item(it.get("id", ""), it.get("amount", 1), it)
			
	if player_grid_control:
		player_grid_control.custom_minimum_size = Vector2(new_w * CELL_SIZE, new_h * CELL_SIZE)
		player_grid_control.queue_redraw()

func _on_player_grid_draw() -> void:
	_draw_2d_grid(player_grid_control, player_grid_mgr, hovered_player_cell, true)

func _on_stash_grid_draw() -> void:
	_draw_2d_grid(stash_grid_control, stash_grid_mgr, hovered_stash_cell, false)

func _draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool) -> void:
	if not grid_mgr: return
	
	var w = grid_mgr.grid_width
	var h = grid_mgr.grid_height
	
	# 1. 배경 격자선
	var line_col = Color(0.24, 0.28, 0.35, 0.7)
	for x in range(w + 1):
		ctrl.draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, h * CELL_SIZE), line_col, 1.0)
	for y in range(h + 1):
		ctrl.draw_line(Vector2(0, y * CELL_SIZE), Vector2(w * CELL_SIZE, y * CELL_SIZE), line_col, 1.0)
		
	# 2. 배치된 아이템 렌더링
	for item in grid_mgr.items:
		if item.is_empty(): continue
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		var item_rect = Rect2(item.get("x", 0) * CELL_SIZE + 2, item.get("y", 0) * CELL_SIZE + 2, cur_w * CELL_SIZE - 4, cur_h * CELL_SIZE - 4)
		
		var item_bg = Color(0.18, 0.22, 0.28, 0.95) if is_player_grid else Color(0.16, 0.20, 0.24, 0.95)
		var item_border = Color(0.35, 0.65, 0.95, 0.9) if is_player_grid else Color(0.9, 0.7, 0.3, 0.9)
		ctrl.draw_rect(item_rect, item_bg, true)
		ctrl.draw_rect(item_rect, item_border, false, 1.5)
		
		# 아이콘
		var icon_tex = ItemIconManager.get_icon(item.get("id", "")) if ItemIconManager else null
		if icon_tex:
			var icon_size = Vector2(min(item_rect.size.x, item_rect.size.y) * 0.75, min(item_rect.size.x, item_rect.size.y) * 0.75)
			var icon_pos = item_rect.position + (item_rect.size - icon_size) / 2.0
			ctrl.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		# 수량
		var amt = item.get("amount", 1)
		if amt > 1:
			var font = ThemeDB.fallback_font
			ctrl.draw_string(font, item_rect.position + Vector2(4, item_rect.size.y - 4), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 0.4))
			
		# 이름
		var font = ThemeDB.fallback_font
		var d = ItemDatabase.get_item_data(item.get("id", ""))
		ctrl.draw_string(font, item_rect.position + Vector2(4, 12), d.get("name", item.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 8, 10, Color(0.9, 0.9, 0.9, 0.8))

	# 3. 드래그 중 고스트 프리뷰 (초록 / 빨강)
	if is_dragging and hovered_cell.x >= 0 and hovered_cell.y >= 0:
		var item = drag_data.get("item", {})
		var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
		var base_w = item.get("w", base_size.x)
		var base_h = item.get("h", base_size.y)
		var is_rot = drag_data.get("rotated", false)
		var place_w = base_h if is_rot else base_w
		var place_h = base_w if is_rot else base_h
		
		var src = drag_data.get("source", "")
		var uid = item.get("uid", "")
		var ignore_uid = uid if (src == ("player_grid" if is_player_grid else "stash_grid")) else ""
		var can_place = grid_mgr.can_place_item(place_w, place_h, hovered_cell.x, hovered_cell.y, ignore_uid)
		var ghost_rect = Rect2(hovered_cell.x * CELL_SIZE, hovered_cell.y * CELL_SIZE, place_w * CELL_SIZE, place_h * CELL_SIZE)
		
		var col = Color(0.2, 0.8, 0.3, 0.4) if can_place else Color(0.9, 0.2, 0.2, 0.4)
		var border_col = Color(0.3, 1.0, 0.4, 0.9) if can_place else Color(1.0, 0.3, 0.3, 0.9)
		
		ctrl.draw_rect(ghost_rect, col, true)
		ctrl.draw_rect(ghost_rect, border_col, false, 2.0)

# ============================================================
# 그리드 마우스 이벤트 처리
# ============================================================
func _on_player_grid_gui_input(event: InputEvent) -> void:
	_handle_grid_input(event, player_grid_control, player_grid_mgr, true)

func _on_stash_grid_gui_input(event: InputEvent) -> void:
	_handle_grid_input(event, stash_grid_control, stash_grid_mgr, false)

func _handle_grid_input(event: InputEvent, ctrl: Control, grid_mgr: InventoryGrid, is_player_grid: bool) -> void:
	var local_pos = ctrl.get_local_mouse_position()
	var cell_x = int(local_pos.x / CELL_SIZE)
	var cell_y = int(local_pos.y / CELL_SIZE)
	
	if event is InputEventMouseMotion:
		if cell_x >= 0 and cell_x < grid_mgr.grid_width and cell_y >= 0 and cell_y < grid_mgr.grid_height:
			if is_player_grid: hovered_player_cell = Vector2i(cell_x, cell_y)
			else: hovered_stash_cell = Vector2i(cell_x, cell_y)
		else:
			if is_player_grid: hovered_player_cell = Vector2i(-1, -1)
			else: hovered_stash_cell = Vector2i(-1, -1)
			
		if not is_dragging:
			var hovered_item = grid_mgr.get_item_at(cell_x, cell_y)
			if not hovered_item.is_empty():
				var idata = ItemDatabase.get_item_data(hovered_item.get("id", ""))
				tooltip.display_item(hovered_item, idata)
				tooltip.update_position(get_global_mouse_position())
			else:
				tooltip.hide()
		ctrl.queue_redraw()
		
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item = grid_mgr.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
					_open_split_dialog(item, func(split_amt):
						var split_item = item.duplicate(true)
						split_item["amount"] = split_amt
						item["amount"] -= split_amt
						grid_mgr.grid_changed.emit()
						_start_drag("player_grid" if is_player_grid else "stash_grid", split_item, Vector2i(cell_x, cell_y))
					)
				else:
					_start_drag("player_grid" if is_player_grid else "stash_grid", item, Vector2i(cell_x, cell_y))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 우클릭 퀵 액션: 배낭 <-> 창고 간 자동 이동 또는 장비 장착
			var item = grid_mgr.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				_handle_hideout_quick_action(item, is_player_grid)

func _handle_hideout_quick_action(item: Dictionary, is_from_player: bool) -> void:
	var item_id = item.get("id", "")
	var target_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	# 1. 장비 아이템이면 장비 슬롯으로 퀵 장착 시도
	if target_slot != "" and equipment_data.has(target_slot) and equipment_data[target_slot].is_empty():
		if is_from_player: player_grid_mgr.remove_item_by_uid(item.get("uid", ""))
		else: stash_grid_mgr.remove_item_by_uid(item.get("uid", ""))
		equipment_data[target_slot] = item
		_apply_backpack_grid_size()
		_update_equipment_ui()
		if SoundManager: SoundManager.play("menu_select")
		return
		
	# 2. 배낭 <-> 창고 간 상호 자동 이동 (Auto-Fit)
	var dest_grid = stash_grid_mgr if is_from_player else player_grid_mgr
	var src_grid = player_grid_mgr if is_from_player else stash_grid_mgr
	
	var rem = dest_grid.auto_add_item(item.get("id", ""), item.get("amount", 1), item)
	if rem <= 0:
		src_grid.remove_item_by_uid(item.get("uid", ""))
		if SoundManager: SoundManager.play("menu_select")
	else:
		item["amount"] = rem
		src_grid.grid_changed.emit()

# ============================================================
# 드래그 앤 드롭 전역 제어
# ============================================================
func _input(event: InputEvent) -> void:
	# R 키 회전
	if is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			drag_data["rotated"] = not drag_data.get("rotated", false)
			if player_grid_control: player_grid_control.queue_redraw()
			if stash_grid_control: stash_grid_control.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	if is_dragging and event is InputEventMouseMotion:
		var m_pos = get_global_mouse_position()
		if drag_preview_node:
			drag_preview_node.global_position = m_pos - Vector2(22, 22)
			
		if player_grid_control:
			var p_m = player_grid_control.get_local_mouse_position()
			var p_x = int(p_m.x / CELL_SIZE)
			var p_y = int(p_m.y / CELL_SIZE)
			hovered_player_cell = Vector2i(p_x, p_y) if (p_x >= 0 and p_x < player_grid_mgr.grid_width and p_y >= 0 and p_y < player_grid_mgr.grid_height) else Vector2i(-1, -1)
			player_grid_control.queue_redraw()
		if stash_grid_control:
			var s_m = stash_grid_control.get_local_mouse_position()
			var s_x = int(s_m.x / CELL_SIZE)
			var s_y = int(s_m.y / CELL_SIZE)
			hovered_stash_cell = Vector2i(s_x, s_y) if (s_x >= 0 and s_x < stash_grid_mgr.grid_width and s_y >= 0 and s_y < stash_grid_mgr.grid_height) else Vector2i(-1, -1)
			stash_grid_control.queue_redraw()
			
		# 마우스 아래의 장비 슬롯 감지 및 하이라이트
		var hovered_target_ctrl: Control = null
		for target in drop_targets:
			var ctrl: Control = target.get("control")
			if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
				hovered_target_ctrl = ctrl
				break
		_highlight_compatible_slots(drag_data.get("item", {}), hovered_target_ctrl)
			
	if is_dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_hideout_global_drop()
		get_viewport().set_input_as_handled()

func _start_drag(src_name: String, item_dict: Dictionary, cell_pos: Vector2i, slot_key: String = "") -> void:
	is_dragging = true
	var base_size = ItemDatabase.get_item_grid_size(item_dict.get("id", ""))
	if not item_dict.has("w"):
		item_dict["w"] = base_size.x
	if not item_dict.has("h"):
		item_dict["h"] = base_size.y
	drag_data = {
		"source": src_name,
		"item": item_dict,
		"cell": cell_pos,
		"slot_name": slot_key,
		"rotated": item_dict.get("rotated", false)
	}
	
	if tooltip: tooltip.hide()
	
	if drag_preview_node: drag_preview_node.queue_free()
	drag_preview_node = Control.new()
	drag_preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var preview_tex = TextureRect.new()
	preview_tex.texture = ItemIconManager.get_icon(item_dict.get("id", "")) if ItemIconManager else null
	preview_tex.custom_minimum_size = Vector2(44, 44)
	preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_tex.modulate = Color(1, 1, 1, 0.8)
	drag_preview_node.add_child(preview_tex)
	
	add_child(drag_preview_node)
	drag_preview_node.global_position = get_global_mouse_position() - Vector2(22, 22)
	_highlight_compatible_slots(item_dict, null)

func _end_drag() -> void:
	is_dragging = false
	drag_data.clear()
	hovered_player_cell = Vector2i(-1, -1)
	hovered_stash_cell = Vector2i(-1, -1)
	if drag_preview_node:
		drag_preview_node.queue_free()
		drag_preview_node = null
	_clear_slot_highlights()
	if player_grid_control: player_grid_control.queue_redraw()
	if stash_grid_control: stash_grid_control.queue_redraw()

func _highlight_compatible_slots(item: Dictionary, hovered_ctrl: Control = null) -> void:
	var item_id = item.get("id", "")
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree(): continue
		
		var slot_name = target.get("slot_name", "")
		var is_compat = _is_slot_compatible(item_id, slot_name)
		
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

func _handle_hideout_global_drop() -> void:
	if not is_dragging: return
	
	var m_pos = get_global_mouse_position()
	
	# 1. 플레이어 배낭 2D 그리드 위인지 검사
	if player_grid_control.get_global_rect().has_point(m_pos):
		var l_pos = player_grid_control.get_local_mouse_position()
		var cx = int(l_pos.x / CELL_SIZE)
		var cy = int(l_pos.y / CELL_SIZE)
		_try_drop_on_hideout_grid(player_grid_mgr, cx, cy, true)
		return
		
	# 2. 은신처 창고 2D 그리드 위인지 검사
	if stash_grid_control.get_global_rect().has_point(m_pos):
		var l_pos = stash_grid_control.get_local_mouse_position()
		var cx = int(l_pos.x / CELL_SIZE)
		var cy = int(l_pos.y / CELL_SIZE)
		_try_drop_on_hideout_grid(stash_grid_mgr, cx, cy, false)
		return
		
	# 3. 캐릭터 장비 슬롯 위인지 검사
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if is_instance_valid(ctrl) and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
			_try_equip_hideout_item(target.get("slot_name", ""))
			return
			
	_end_drag()

func _try_drop_on_hideout_grid(dest_grid: InventoryGrid, cell_x: int, cell_y: int, is_dest_player: bool) -> void:
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
	var ignore_uid = uid if (src == ("player_grid" if is_dest_player else "stash_grid")) else ""
	
	if dest_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid):
		if dest_grid.place_item(item, cell_x, cell_y, is_rot):
			# 배치 성공 시 이전 위치에서 안전하게 제거
			if src == "player_grid":
				if not is_dest_player or dest_grid != player_grid_mgr:
					player_grid_mgr.remove_item_by_uid(uid)
			elif src == "stash_grid":
				if is_dest_player or dest_grid != stash_grid_mgr:
					stash_grid_mgr.remove_item_by_uid(uid)
			elif src == "equipment":
				equipment_data[drag_data.get("slot_name", "")] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
				
			if SoundManager: SoundManager.play("menu_select")
		else:
			if SoundManager: SoundManager.play("hit_melee")
	else:
		if SoundManager: SoundManager.play("hit_melee")
		
	_end_drag()

# ============================================================
# 캐릭터 장비 슬롯 연동
# ============================================================
func _connect_equipment_slots() -> void:
	var slots = [
		[helmet_slot, "helmet"], [vest_slot, "vest"], [backpack_slot, "backpack"], [bottom_slot, "bottom"],
		[primary1_slot, "primary1"], [primary2_slot, "primary2"], [sidearm_slot, "sidearm"], [throwable_slot, "throwable"]
	]
	
	drop_targets.clear()
	for s_pair in slots:
		var btn: Button = s_pair[0]
		var s_name: String = s_pair[1]
		drop_targets.append({"control": btn, "slot_name": s_name})
		
		var captured_btn = btn
		var captured_slot = s_name
		
		btn.mouse_entered.connect(func():
			if not is_dragging and tooltip:
				var equipped = equipment_data.get(captured_slot, {})
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
						_try_equip_hideout_item(captured_slot)
					else:
						var equipped = equipment_data.get(captured_slot, {})
						if not equipped.is_empty():
							if tooltip: tooltip.hide()
							_start_drag("equipment", equipped, Vector2i.ZERO, captured_slot)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					# 우클릭 시 창고로 탈착
					var equipped = equipment_data.get(captured_slot, {})
					if not equipped.is_empty():
						var rem = stash_grid_mgr.auto_add_item(equipped.get("id", ""), equipped.get("amount", 1), equipped)
						if rem <= 0:
							equipment_data[captured_slot] = {}
							_apply_backpack_grid_size()
							_update_equipment_ui()
							if tooltip: tooltip.hide()
							if SoundManager: SoundManager.play("menu_select")
		)

func _try_equip_hideout_item(slot_name: String) -> void:
	var item = drag_data.get("item", {})
	var item_id = item.get("id", "")
	
	if not _is_slot_compatible(item_id, slot_name):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ [%s] 슬롯에 장착할 수 없는 아이템입니다." % slot_name)
		_end_drag()
		return
		
	var src = drag_data.get("source", "")
	var orig_slot = drag_data.get("slot_name", "")
	
	# 같은 장비 슬롯에 다시 드롭한 경우 -> 복제 방지
	if src == "equipment" and orig_slot == slot_name:
		_end_drag()
		return
		
	if src == "player_grid":
		player_grid_mgr.remove_item_by_uid(item.get("uid", ""))
	elif src == "stash_grid":
		stash_grid_mgr.remove_item_by_uid(item.get("uid", ""))
	elif src == "equipment":
		equipment_data[orig_slot] = {}
		
	var prev_equipped = equipment_data.get(slot_name, {})
	equipment_data[slot_name] = item
	
	if not prev_equipped.is_empty():
		stash_grid_mgr.auto_add_item(prev_equipped.get("id", ""), prev_equipped.get("amount", 1), prev_equipped)
		
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

func _update_equipment_ui() -> void:
	_render_equip_slot_button(helmet_slot, "helmet", "🪖 헬멧")
	_render_equip_slot_button(vest_slot, "vest", "🦺 방탄복")
	_render_equip_slot_button(backpack_slot, "backpack", "🎒 배낭 (용량 결정)")
	_render_equip_slot_button(bottom_slot, "bottom", "👟 하의/신발")
	
	_render_equip_slot_button(primary1_slot, "primary1", "🔫 주무기 1")
	_render_equip_slot_button(primary2_slot, "primary2", "🔫 주무기 2")
	_render_equip_slot_button(sidearm_slot, "sidearm", "🗡️ 보조 무기")
	_render_equip_slot_button(throwable_slot, "throwable", "💣 투척 무기")

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

func _open_split_dialog(item: Dictionary, on_confirm_callback: Callable) -> void:
	var dialog = SplitDialogScene.instantiate()
	add_child(dialog)
	dialog.setup(item.get("id", ""), item.get("amount", 1))
	dialog.split_confirmed.connect(on_confirm_callback)
	_refresh_stash_ui()

# ============================================================
# 상인 거래소 UI 로직
# ============================================================
func _select_trader(trader_id: String) -> void:
	current_trader_id = trader_id
	_refresh_trader_ui()

func _refresh_trader_ui() -> void:
	var t_data = ItemDatabase.traders.get(current_trader_id, {})
	if t_data.is_empty(): return
	
	trader_desc_label.text = "[%s] %s" % [t_data["name"], t_data["desc"]]
	
	# 상품 목록 생성
	for child in trader_items_vbox.get_children():
		child.queue_free()
		
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	for stock_item in t_data.get("stock", []):
		var item_id = stock_item["id"]
		var price = stock_item["price"]
		var amount = stock_item.get("amount", 1)
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		panel.add_child(hbox)
		
		# 아이템 아이콘
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % price
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(60, 32)
		buy_btn.disabled = (user_rubles < price)
		buy_btn.pressed.connect(func(): _buy_item(item_id, amount, price))
		hbox.add_child(buy_btn)
		
		trader_items_vbox.add_child(panel)
		
	_refresh_trader_sell_ui()

func _refresh_trader_sell_ui() -> void:
	for child in trader_sell_grid.get_children():
		child.queue_free()
		
	# 배낭의 아이템들을 판매 가능 목록으로 표시
	for item in player_grid_mgr.items:
		if item and not item.is_empty():
			var data = ItemDatabase.get_item_data(item.get("id", ""))
			var sell_price = int(data.get("value", 500) * 0.6) # 기본가의 60%에 매입
			var uid = item.get("uid", "")
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(100, 50)
			
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
			btn_style.border_color = Color(0.35, 0.40, 0.48, 1.0)
			btn_style.corner_radius_top_left = 4
			btn_style.corner_radius_top_right = 4
			btn_style.corner_radius_bottom_right = 4
			btn_style.corner_radius_bottom_left = 4
			btn.add_theme_stylebox_override("normal", btn_style)
			
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item.get("id", ""))
				btn.expand_icon = true
			btn.text = "%s\n+%d RUB" % [data.get("name", item.get("id", "")), sell_price * item.get("amount", 1)]
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			btn.pressed.connect(func(): _sell_item(uid, item.get("id", ""), item.get("amount", 1), sell_price))
			trader_sell_grid.add_child(btn)

func _buy_item(item_id: String, amount: int, price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < price: return
	
	# 자금 차감
	GameManager.current_world_data["player"]["rubles"] -= price
	_update_money_label()
	
	# 배낭 또는 창고에 아이템 지급 (Auto-Fit)
	var remaining = player_grid_mgr.auto_add_item(item_id, amount)
	if remaining > 0:
		stash_grid_mgr.auto_add_item(item_id, remaining)
		
	if SoundManager: SoundManager.play("menu_select")
	_refresh_trader_ui()
	_sync_save_data()

func _sell_item(uid: String, item_id: String, amount: int, unit_price: int) -> void:
	var total_gain = unit_price * amount
	GameManager.current_world_data["player"]["rubles"] += total_gain
	_update_money_label()
	
	player_grid_mgr.remove_item_by_uid(uid)
	
	if SoundManager: SoundManager.play("menu_select")
	_refresh_trader_ui()
	_sync_save_data()

# ============================================================
# 플리마켓 UI 로직
# ============================================================
func _refresh_market_ui() -> void:
	if not FleaMarket: return
	
	for child in market_items_vbox.get_children():
		child.queue_free()
		
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	for listing in FleaMarket.listings:
		var item_id = listing["item_name"]
		var price = listing["price"]
		var amount = listing["count"]
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		panel.add_child(hbox)
		
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % (price * amount)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(60, 32)
		buy_btn.disabled = (user_rubles < price * amount)
		buy_btn.pressed.connect(func(): _buy_market_item(listing, price * amount))
		hbox.add_child(buy_btn)
		
		market_items_vbox.add_child(panel)
		
	_refresh_market_register_ui()

func _refresh_market_register_ui() -> void:
	for child in market_register_grid.get_children():
		child.queue_free()
		
	for item in player_grid_mgr.items:
		if item and not item.is_empty():
			var item_id = item.get("id", "")
			var uid = item.get("uid", "")
			var data = ItemDatabase.get_item_data(item_id)
			if item_id == "Scav 식별줄(Dogtag)":
				continue
				
			var current_price = FleaMarket.get_current_price(item_id)
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(100, 50)
			
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.18, 0.20, 0.25, 0.95)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
			btn_style.border_color = Color(0.35, 0.40, 0.48, 1.0)
			btn_style.corner_radius_top_left = 4
			btn_style.corner_radius_top_right = 4
			btn_style.corner_radius_bottom_right = 4
			btn_style.corner_radius_bottom_left = 4
			btn.add_theme_stylebox_override("normal", btn_style)
			
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item_id)
				btn.expand_icon = true
			btn.text = "%s\n시장가 %d RUB" % [data.get("name", item_id), current_price]
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			btn.pressed.connect(func(): _register_market_item(uid, item_id, item.get("amount", 1), current_price))
			market_register_grid.add_child(btn)

func _buy_market_item(listing: Dictionary, total_price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < total_price: return
	
	GameManager.current_world_data["player"]["rubles"] -= total_price
	_update_money_label()
	
	var remaining = player_grid_mgr.auto_add_item(listing["item_name"], listing["count"])
	if remaining > 0:
		stash_grid_mgr.auto_add_item(listing["item_name"], remaining)
		
	FleaMarket.listings.erase(listing)
	if SoundManager: SoundManager.play("menu_select")
	
	_refresh_market_ui()
	_sync_save_data()

func _register_market_item(uid: String, item_id: String, amount: int, current_price: int) -> void:
	# 5% 수수료 (선불)
	var fee = max(1, int(current_price * amount * 0.05))
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	if user_rubles < fee:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 등록 수수료(%d RUB)가 부족합니다." % fee)
		return
		
	GameManager.current_world_data["player"]["rubles"] -= fee
	_update_money_label()
	
	player_grid_mgr.remove_item_by_uid(uid)
	
	FleaMarket.add_listing({
		"item_name": item_id,
		"count": amount,
		"price": current_price,
		"seller": "플레이어",
		"time_left": 1800
	})
	
	if SoundManager: SoundManager.play("menu_select")
	_refresh_market_ui()
	_sync_save_data()

# ============================================================
# 결과 팝업 및 네비게이션
# ============================================================
func _check_last_raid_result() -> void:
	if GameManager and not GameManager.last_raid_result.is_empty():
		var res = GameManager.last_raid_result
		result_dialog.visible = true
		if res["result"] == "survived":
			result_title.text = "🎉 탈출 성공! (SURVIVED)"
			result_title.add_theme_color_override("font_color", Color.GREEN)
			result_desc.text = "안전하게 은신처로 복귀했습니다.\n획득한 전리품이 창고로 안전하게 이관되었습니다."
		elif res["result"] == "kia":
			result_title.text = "💀 작전 중 사망 (KIA)"
			result_title.add_theme_color_override("font_color", Color.RED)
			result_desc.text = "레이드 도중 사망했습니다.\n소지하고 있던 모든 배낭 아이템을 잃었습니다."
		elif res["result"] == "mia":
			result_title.text = "⏳ 작전 시간 초과 (MIA)"
			result_title.add_theme_color_override("font_color", Color.ORANGE)
			result_desc.text = "제한 시간 내에 탈출하지 못해 실종되었습니다."
			
		GameManager.last_raid_result.clear()
	else:
		result_dialog.visible = false

func _on_result_close_pressed() -> void:
	result_dialog.visible = false

func _on_raid_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager: GameManager.start_raid()

func _on_menu_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager:
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)
		GameManager.change_state(GameManager.GameState.MAIN_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			_open_weapon_modding_window()
		elif event.physical_keycode == KEY_F1:
			_open_item_spawner()
		elif event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I:
			_open_inventory_window()

func _open_inventory_window() -> void:
	var inv_scene = preload("res://scenes/ui/inventory_window.tscn")
	if inv_scene:
		var win = inv_scene.instantiate()
		add_child(win)
		win.setup(null, player_grid_mgr, equipment_data)
		win.window_closed.connect(func(): _on_grid_changed())

func _open_item_spawner() -> void:
	var spawner_scene = preload("res://scenes/ui/item_spawner_window.tscn")
	if spawner_scene:
		var win = spawner_scene.instantiate()
		add_child(win)
		win.window_closed.connect(func(): _on_grid_changed())

func _open_weapon_modding_window() -> void:
	# B 키를 누르면 바로 4번째 탭(총기 작업대)으로 전환
	if tab_container:
		tab_container.current_tab = 3
		_refresh_workbench_ui()

# ============================================================
# 총기 커스텀 작업대 (Workbench & Smart Presets)
# ============================================================
const WEAPON_PRESETS = {
	"M4_리시버": [
		{
			"name": "🎯 무반동 레이저 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "RK-1_인체공학_그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"name": "🤫 소음 암살 저격 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "수직_포어그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["전술_손전등"]
			}
		},
		{
			"name": "⚡ 초경량 CQC 돌격 세팅",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "플래시_소염기",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"grip": "수직_포어그립",
				"magazine": "50발_드럼_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		}
	],
	"AK_리시버": [
		{
			"name": "🎯 스페츠나츠 무반동 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "RK-1_인체공학_그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"name": "🤫 소음 야간 침투 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "2배율_조준경",
				"stock": "경량_접이식_스톡",
				"grip": "수직_포어그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["전술_손전등"]
			}
		}
	],
	"M9_리시버": [
		{
			"name": "🤫 비밀 요원 소음 권총",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "소음기",
				"optic": "레드닷_사이트",
				"magazine": "대용량_확장_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"name": "⚡ 컴팩트 속사 권총",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "컴펜세이터",
				"optic": "기본_아이언사이트",
				"magazine": "대용량_확장_탄창",
				"rail": ["전술_손전등"]
			}
		}
	],
	"레밍턴_리시버": [
		{
			"name": "💥 파쇄 벅샷 산탄 세팅",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"rail": ["전술_손전등"]
			}
		},
		{
			"name": "🎯 정밀 슬러그 스나이퍼",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": ["적색_레이저_표적지시기"]
			}
		}
	],
	"레버액션_리시버": [
		{
			"name": "🤠 카우보이 헌터 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": []
			}
		},
		{
			"name": "🤫 전술 택티컬 소음 레버액션",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"name": "⚡ 단축 기동형 카빈 세팅",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"rail": ["전술_손전등"]
			}
		}
	],
	"레버액션 소총": [
		{
			"name": "🤠 카우보이 헌터 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": []
			}
		},
		{
			"name": "🤫 전술 택티컬 소음 레버액션",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"name": "⚡ 단축 기동형 카빈 세팅",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"rail": ["전술_손전등"]
			}
		}
	],
	"SV98_리시버": [
		{
			"name": "🔭 8배율 초장거리 저격 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "8배율_스나이퍼_스코프",
				"stock": "PRS_정밀_저격_스톡",
				"magazine": "표준_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		}
	]
}

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
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(raw_id)
			btn.expand_icon = true
			
		var is_cur = (wb_selected_weapon.get("uid", "") == w_dict.get("uid", "") and not w_dict.get("uid", "").is_empty()) or (src == wb_weapon_source and not src.is_empty())
		if is_cur:
			var cur_style = StyleBoxFlat.new()
			cur_style.bg_color = Color(0.15, 0.35, 0.22, 0.9)
			cur_style.border_color = Color(0.3, 1.0, 0.5, 1.0)
			cur_style.set_border_width_all(2)
			btn.add_theme_stylebox_override("normal", cur_style)
			
		btn.pressed.connect(func():
			_select_workbench_weapon(w_dict, src)
			_populate_workbench_weapon_list()
		)
		wb_weapon_list_vbox.add_child(btn)

func _select_workbench_weapon(weapon_dict: Dictionary, source_info: Dictionary) -> void:
	wb_weapon_source = source_info
	wb_selected_weapon = weapon_dict.duplicate(true)
	
	var raw_id = wb_selected_weapon.get("receiver", wb_selected_weapon.get("id", "M4_리시버"))
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	wb_selected_weapon["receiver"] = rec_id
	if not wb_selected_weapon.has("parts"):
		wb_selected_weapon["parts"] = {}
	if not wb_selected_weapon.has("attachments"):
		wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
	else:
		wb_selected_weapon["parts"] = wb_selected_weapon["attachments"]
		
	# 모딩 전 기준 스탯 산출
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_base_stats = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_selected_weapon["parts"], wb_selected_weapon.get("loaded_ammo", def_ammo))
	wb_selected_weapon["computed_stats"] = wb_base_stats
	
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
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.22, 0.18, 0.9) if is_active else Color(0.12, 0.14, 0.18, 0.9)
		style.border_color = Color(0.3, 1.0, 0.5, 1.0) if is_active else Color(0.3, 0.35, 0.42, 0.6)
		style.set_border_width_all(2 if is_active else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_right = 8
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
		wb_compat_title.text = "🧰 호환 부품: 총기를 먼저 선택해주세요."
		return
		
	if slot_name == "":
		wb_compat_title.text = "🧰 위 슬롯 카드(총열, 총구, 스코프 등)를 클릭하면 내 창고/배낭의 호환 부품이 표시됩니다."
		return
		
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	var cat = r_data.get("category", "rifle")
	wb_compat_title.text = "🧰 [%s] 슬롯 호환 부품 목록 (내 창고/배낭 소지품):" % slot_name
	
	# 내 인벤토리에서 해당 슬롯에 맞는 부품 검색
	var owned_compat_parts = []
	
	# 1. 창고 탐색
	if stash_grid_mgr:
		for it in stash_grid_mgr.items:
			var it_id = it.get("id", "")
			if WeaponPartsDatabase.PARTS.has(it_id):
				var p_info = WeaponPartsDatabase.PARTS[it_id]
				if p_info.get("slot") == slot_name:
					var comps = p_info.get("compatible_categories", ["all"])
					if "all" in comps or cat in comps:
						owned_compat_parts.append({"id": it_id, "source": "stash", "item": it})
						
	# 2. 배낭 탐색
	if player_grid_mgr:
		for it in player_grid_mgr.items:
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
		detach_btn.text = "❌ 부품 분리(탈착)"
		detach_btn.custom_minimum_size = Vector2(110, 40)
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

func _attach_workbench_part(slot_name: String, part_id: String) -> void:
	if wb_selected_weapon.is_empty(): return
	var parts = wb_selected_weapon.get("parts", {})
	var prev_part = parts.get(slot_name, "")
	
	# 기존 부품이 있다면 창고로 반환
	if prev_part is Array:
		for p in prev_part:
			if p != "" and p != part_id and stash_grid_mgr:
				stash_grid_mgr.auto_add_item(p, 1)
	elif prev_part is String and prev_part != "" and prev_part != part_id:
		if stash_grid_mgr:
			stash_grid_mgr.auto_add_item(prev_part, 1)
			
	# 새 부품을 소지품에서 차감
	_remove_owned_part_from_inv(part_id)
	
	if slot_name == "rail":
		parts["rail"] = [part_id]
	else:
		parts[slot_name] = part_id
		
	wb_selected_weapon["parts"] = parts
	wb_selected_weapon["attachments"] = parts
	
	# 스탯 재계산
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(slot_name)
	if wb_preview: wb_preview.queue_redraw()

func _detach_workbench_part(slot_name: String) -> void:
	if wb_selected_weapon.is_empty(): return
	var parts = wb_selected_weapon.get("parts", {})
	if not parts.has(slot_name): return
	var prev_part = parts.get(slot_name)
	
	if prev_part is Array:
		for p in prev_part:
			if p != "" and stash_grid_mgr:
				stash_grid_mgr.auto_add_item(p, 1)
		parts.erase(slot_name)
	elif prev_part is String and prev_part != "":
		if stash_grid_mgr:
			stash_grid_mgr.auto_add_item(prev_part, 1)
		parts.erase(slot_name)
		
	wb_selected_weapon["parts"] = parts
	wb_selected_weapon["attachments"] = parts
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(slot_name)
	if wb_preview: wb_preview.queue_redraw()

func _remove_owned_part_from_inv(part_id: String) -> bool:
	if stash_grid_mgr:
		for it in stash_grid_mgr.items:
			if it.get("id", "") == part_id:
				var amt = it.get("amount", 1)
				if amt <= 1: stash_grid_mgr.remove_item_by_uid(it.get("uid", ""))
				else:
					it["amount"] -= 1
					stash_grid_mgr.grid_changed.emit()
				return true
	if player_grid_mgr:
		for it in player_grid_mgr.items:
			if it.get("id", "") == part_id:
				var amt = it.get("amount", 1)
				if amt <= 1: player_grid_mgr.remove_item_by_uid(it.get("uid", ""))
				else:
					it["amount"] -= 1
					player_grid_mgr.grid_changed.emit()
				return true
	return false

func _refresh_workbench_stats_comparison() -> void:
	if not wb_stats_vbox: return
	for c in wb_stats_vbox.get_children():
		c.queue_free()
		
	if wb_selected_weapon.is_empty(): return
	
	var cur_stats = wb_selected_weapon.get("computed_stats", {})
	var base = wb_base_stats if not wb_base_stats.is_empty() else cur_stats
	
	_add_stat_compare_row("💥 데미지", base.get("damage", 20.0), cur_stats.get("damage", 20.0), "%.1f", true)
	_add_stat_compare_row("🎯 정확도", base.get("accuracy", 70.0), cur_stats.get("accuracy", 70.0), "%d%%", true)
	_add_stat_compare_row("⚡ 연사력 (RPM)", base.get("rpm", 150), cur_stats.get("rpm", 150), "%d", true)
	_add_stat_compare_row("🔄 반동 제어", base.get("recoil", 30.0), cur_stats.get("recoil", 30.0), "%.1f", false) # 반동 감소가 좋음
	_add_stat_compare_row("🔭 유효 사거리", base.get("range", 10.0), cur_stats.get("range", 10.0), "%.1fm", true)
	_add_stat_compare_row("🔍 조준경 줌", base.get("zoom", 1.0), cur_stats.get("zoom", 1.0), "%.1fx", true)
	_add_stat_compare_row("📦 탄창 용량", base.get("magazine_size", 15), cur_stats.get("magazine_size", 15), "%d발", true)
	_add_stat_compare_row("🔊 사격 소음", base.get("noise_radius", 600.0), cur_stats.get("noise_radius", 600.0), "%dpx", false) # 소음 감소가 좋음
	_add_stat_compare_row("⚖️ 총기 무게", base.get("weight", 2.0), cur_stats.get("weight", 2.0), "%.2fkg", false) # 무게 감소가 좋음

func _add_stat_compare_row(title: String, base_val: float, cur_val: float, fmt: String, higher_is_better: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.custom_minimum_size = Vector2(100, 0)
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
	if not wb_preset_vbox: return
	for c in wb_preset_vbox.get_children():
		c.queue_free()
		
	if wb_selected_weapon.is_empty(): return
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var presets = WEAPON_PRESETS.get(rec_id, [])
	
	for p in presets:
		var btn = Button.new()
		btn.text = p["name"]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var p_capture = p
		btn.pressed.connect(func(): _apply_workbench_preset(p_capture))
		wb_preset_vbox.add_child(btn)

func _apply_workbench_preset(preset_dict: Dictionary) -> void:
	wb_current_preset_parts = preset_dict.get("parts", {}).duplicate(true)
	wb_missing_preset_parts.clear()
	wb_missing_preset_cost = 0
	
	# 내 인벤토리에서 보유한 부품 목록 수집
	var owned_pool = _get_owned_parts_list()
	
	for slot_name in wb_current_preset_parts.keys():
		var target_part = wb_current_preset_parts[slot_name]
		if target_part is Array:
			for tp in target_part:
				if not owned_pool.has(tp) or owned_pool[tp] <= 0:
					wb_missing_preset_parts.append(tp)
					var p_val = WeaponPartsDatabase.PARTS.get(tp, {}).get("value", 5000)
					wb_missing_preset_cost += p_val
				else:
					owned_pool[tp] -= 1
		else:
			if not owned_pool.has(target_part) or owned_pool[target_part] <= 0:
				wb_missing_preset_parts.append(target_part)
				var p_val = WeaponPartsDatabase.PARTS.get(target_part, {}).get("value", 5000)
				wb_missing_preset_cost += p_val
			else:
				owned_pool[target_part] -= 1
				
	# 무기 파츠에 프리셋 적용 (가상 세팅)
	wb_selected_weapon["parts"] = wb_current_preset_parts.duplicate(true)
	wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_current_preset_parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	
	if wb_preset_buy_btn:
		if wb_missing_preset_parts.is_empty():
			wb_preset_buy_btn.text = "✅ 모든 부품 보유 중 (즉시 조립 완료)"
			wb_preset_buy_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			wb_preset_buy_btn.text = "🛒 부족 부품 %d종 구매 후 조립: %d RUB" % [wb_missing_preset_parts.size(), wb_missing_preset_cost]
			wb_preset_buy_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(wb_active_slot)
	if wb_preview: wb_preview.queue_redraw()

func _buy_and_assemble_preset() -> void:
	if wb_current_preset_parts.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 먼저 적용할 프리셋을 선택해주세요.")
		return
		
	var cur_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0) if GameManager else 0
	
	if wb_missing_preset_cost > 0:
		if cur_rubles < wb_missing_preset_cost:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("❌ 자금이 부족합니다! (필요: %d RUB / 보유: %d RUB)" % [wb_missing_preset_cost, cur_rubles])
			if SoundManager: SoundManager.play("hit_melee")
			return
			
		# 자금 차감
		cur_rubles -= wb_missing_preset_cost
		if GameManager and GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"]["rubles"] = cur_rubles
		_update_money_label()
		
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("💰 %d RUB로 부족한 부품 %d종을 시장에서 즉시 구매하여 조립했습니다!" % [wb_missing_preset_cost, wb_missing_preset_parts.size()])
	else:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("✅ 보유 중인 부품으로 프리셋 조립을 완료했습니다.")
			
	# 내 인벤토리에서 실제 보유 중이던 부품들 차감
	for slot in wb_current_preset_parts.keys():
		var p = wb_current_preset_parts[slot]
		if p is Array:
			for single_p in p:
				_remove_owned_part_from_inv(single_p)
		else:
			_remove_owned_part_from_inv(p)
			
	wb_missing_preset_cost = 0
	wb_missing_preset_parts.clear()
	if wb_preset_buy_btn:
		wb_preset_buy_btn.text = "✅ 프리셋 조립 완료"
		wb_preset_buy_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		
	if SoundManager: SoundManager.play("menu_select")
	_build_workbench_slots()
	_refresh_workbench_stats_comparison()
	_populate_workbench_compat_parts(wb_active_slot)
	if wb_preview: wb_preview.queue_redraw()

func _get_owned_parts_list() -> Dictionary:
	var pool = {}
	if stash_grid_mgr:
		for it in stash_grid_mgr.items:
			var id = it.get("id", "")
			pool[id] = pool.get(id, 0) + it.get("amount", 1)
	if player_grid_mgr:
		for it in player_grid_mgr.items:
			var id = it.get("id", "")
			pool[id] = pool.get(id, 0) + it.get("amount", 1)
	return pool

func _save_workbench_weapon() -> void:
	if wb_selected_weapon.is_empty(): return
	
	var src_type = wb_weapon_source.get("type", "")
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var r_data = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	wb_selected_weapon["name"] = r_data.get("name", rec_id) + " (모딩)"
	wb_selected_weapon["attachments"] = wb_selected_weapon.get("parts", {}).duplicate(true)
	
	if src_type == "equipment":
		var s_key = wb_weapon_source.get("slot", "primary1")
		equipment_data[s_key] = wb_selected_weapon.duplicate(true)
		_update_equipment_ui()
	elif src_type == "stash":
		var uid = wb_weapon_source.get("uid", "")
		if stash_grid_mgr:
			for i in range(stash_grid_mgr.items.size()):
				if stash_grid_mgr.items[i].get("uid", "") == uid:
					stash_grid_mgr.items[i] = wb_selected_weapon.duplicate(true)
					stash_grid_mgr.grid_changed.emit()
					break
	elif src_type == "player":
		var uid = wb_weapon_source.get("uid", "")
		if player_grid_mgr:
			for i in range(player_grid_mgr.items.size()):
				if player_grid_mgr.items[i].get("uid", "") == uid:
					player_grid_mgr.items[i] = wb_selected_weapon.duplicate(true)
					player_grid_mgr.grid_changed.emit()
					break
					
	_sync_save_data()
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("💾 [%s] 총기 모딩이 성공적으로 저장/장착되었습니다!" % wb_selected_weapon["name"])
	if SoundManager: SoundManager.play("menu_select")
	_populate_workbench_weapon_list()

# ============================================================
# 픽셀아트 실루엣 + 부착물 오버레이 총기 프리뷰 드로잉
# ============================================================
func _on_workbench_preview_draw() -> void:
	if not wb_preview: return
	var rect = wb_preview.get_rect()
	var center = rect.size / 2.0
	
	# 1. 블루프린트 테크니컬 격자 배경
	var grid_col = Color(0.1, 0.18, 0.25, 0.35)
	for x in range(0, int(rect.size.x), 20):
		wb_preview.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_col, 1.0)
	for y in range(0, int(rect.size.y), 20):
		wb_preview.draw_line(Vector2(0, y), Vector2(rect.size.x, y), grid_col, 1.0)
		
	# 십자 조준선 가이드
	wb_preview.draw_line(Vector2(center.x - 40, center.y), Vector2(center.x + 40, center.y), Color(0.2, 0.5, 0.7, 0.5), 1.0)
	wb_preview.draw_line(Vector2(center.x, center.y - 25), Vector2(center.x, center.y + 25), Color(0.2, 0.5, 0.7, 0.5), 1.0)
	
	if wb_selected_weapon.is_empty():
		var font = ThemeDB.fallback_font
		wb_preview.draw_string(font, center + Vector2(-60, 5), "총기를 선택해주세요", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.6, 0.7, 0.8))
		return
		
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var parts = wb_selected_weapon.get("parts", {})
	
	# 2. 총기 리시버 및 부품 실루엣 드로잉
	var body_col = Color(0.25, 0.28, 0.32, 0.95)
	var metal_dark = Color(0.14, 0.16, 0.18, 0.95)
	var wood_col = Color(0.45, 0.25, 0.15, 0.95)
	var accent_col = Color(0.3, 0.7, 0.9, 0.8)
	
	# 리시버 본체 (Base Upper/Lower Receiver)
	var rec_w = 90.0
	var rec_h = 24.0
	var rec_pos = center + Vector2(-30, -12)
	
	if rec_id == "M4_리시버":
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, rec_h)), metal_dark)
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(10, -6), Vector2(70, 6)), Color(0.2, 0.22, 0.26)) # 피카티니 레일
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(25, 20), Vector2(16, 22)), Color(0.18, 0.18, 0.2)) # 권총 손잡이
	elif rec_id == "AK_리시버":
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, rec_h)), metal_dark)
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(50, -4), Vector2(40, 16)), wood_col) # 목재 핸드가드
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(20, 20), Vector2(16, 22)), wood_col) # 목재 손잡이
	elif rec_id == "SV98_리시버":
		rec_w = 120.0
		rec_pos = center + Vector2(-45, -10)
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, 20)), Color(0.18, 0.28, 0.2)) # 올리브 드랩 저격 총몸
	elif rec_id == "레버액션_리시버" or rec_id == "레버액션 소총":
		rec_w = 110.0
		rec_pos = center + Vector2(-35, -8)
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, 18)), metal_dark) # 총몸 메탈
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(40, 2), Vector2(60, 12)), wood_col) # 목재 포어엔드
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(12, 14), Vector2(18, 14)), Color(0.12, 0.12, 0.14), false, 2.0) # 레버 루프
		wb_preview.draw_polygon(PackedVector2Array([
			rec_pos + Vector2(0, 0), rec_pos + Vector2(-42, 4),
			rec_pos + Vector2(-42, 22), rec_pos + Vector2(0, 18)
		]), PackedColorArray([wood_col, wood_col, wood_col, wood_col])) # 목재 개머리판
	elif rec_id == "레밍턴_리시버":
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, 26)), metal_dark)
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(55, 12), Vector2(30, 12)), wood_col) # 펌프 액션 포어엔드
	else: # M9 권총
		rec_w = 55.0
		rec_pos = center + Vector2(-15, -10)
		wb_preview.draw_rect(Rect2(rec_pos, Vector2(rec_w, 18)), metal_dark)
		wb_preview.draw_rect(Rect2(rec_pos + Vector2(10, 16), Vector2(18, 26)), Color(0.12, 0.12, 0.14)) # 권총 그립
		
	# 3. 부착물 실시간 오버레이
	# [총열 & 총구]
	var barrel_p = parts.get("barrel", "")
	var muzzle_p = parts.get("muzzle", "")
	var b_len = 50.0 if barrel_p.contains("롱헤비") else 30.0
	var barrel_tip = rec_pos + Vector2(rec_w, 6)
	wb_preview.draw_rect(Rect2(barrel_tip, Vector2(b_len, 8)), Color(0.12, 0.13, 0.15))
	
	if muzzle_p.contains("소음기"):
		wb_preview.draw_rect(Rect2(barrel_tip + Vector2(b_len, -4), Vector2(38, 16)), Color(0.08, 0.09, 0.1))
	elif muzzle_p.contains("컴펜세이터"):
		wb_preview.draw_rect(Rect2(barrel_tip + Vector2(b_len, -2), Vector2(14, 12)), Color(0.3, 0.35, 0.4))
	elif muzzle_p.contains("소염기"):
		wb_preview.draw_rect(Rect2(barrel_tip + Vector2(b_len, -1), Vector2(10, 10)), Color(0.2, 0.2, 0.25))
		
	# [조준경 / 스코프]
	var optic_p = parts.get("optic", "")
	var optic_mount = rec_pos + Vector2(rec_w * 0.4, -6)
	if optic_p.contains("8배율"):
		wb_preview.draw_rect(Rect2(optic_mount + Vector2(-25, -16), Vector2(65, 14)), Color(0.1, 0.12, 0.14)) # 대형 튜브
		wb_preview.draw_circle(optic_mount + Vector2(38, -9), 8.0, Color(0.3, 0.6, 0.9, 0.8)) # 대구경 렌즈
	elif optic_p.contains("4배율"):
		wb_preview.draw_polygon(PackedVector2Array([
			optic_mount + Vector2(-15, 0), optic_mount + Vector2(-10, -14),
			optic_mount + Vector2(25, -14), optic_mount + Vector2(30, 0)
		]), PackedColorArray([Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18)]))
	elif optic_p.contains("레드닷"):
		wb_preview.draw_rect(Rect2(optic_mount + Vector2(-8, -12), Vector2(22, 12)), Color(0.12, 0.12, 0.15))
		wb_preview.draw_circle(optic_mount + Vector2(3, -6), 2.0, Color.RED)
		
	# [손잡이]
	var grip_p = parts.get("grip", "")
	var grip_pos = rec_pos + Vector2(rec_w * 0.75, rec_h)
	if grip_p.contains("수직"):
		wb_preview.draw_rect(Rect2(grip_pos, Vector2(10, 22)), Color(0.12, 0.12, 0.14))
	elif grip_p.contains("인체공학") or grip_p.contains("RK-1"):
		wb_preview.draw_polygon(PackedVector2Array([
			grip_pos, grip_pos + Vector2(12, 0),
			grip_pos + Vector2(6, 20), grip_pos + Vector2(-6, 20)
		]), PackedColorArray([Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25)]))
		
	# [탄창]
	var mag_p = parts.get("magazine", "")
	var mag_pos = rec_pos + Vector2(rec_w * 0.45, rec_h)
	if mag_p.contains("드럼"):
		wb_preview.draw_circle(mag_pos + Vector2(8, 16), 16.0, Color(0.1, 0.12, 0.14))
	elif mag_p.contains("확장"):
		wb_preview.draw_polygon(PackedVector2Array([
			mag_pos, mag_pos + Vector2(14, 0),
			mag_pos + Vector2(22, 34), mag_pos + Vector2(8, 34)
		]), PackedColorArray([Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18)]))
	else:
		wb_preview.draw_rect(Rect2(mag_pos, Vector2(14, 24)), Color(0.18, 0.18, 0.2))
		
	# [개머리판]
	var stock_p = parts.get("stock", "")
	var stock_pos = rec_pos + Vector2(-45, 0)
	if stock_p.contains("PRS") or stock_p.contains("저격"):
		wb_preview.draw_rect(Rect2(stock_pos, Vector2(45, 20)), Color(0.15, 0.16, 0.18))
		wb_preview.draw_rect(Rect2(stock_pos + Vector2(-6, -4), Vector2(10, 28)), Color(0.1, 0.1, 0.12)) # 뺨 패드 & 버트패드
	elif stock_p.contains("접이식") or stock_p.contains("경량"):
		wb_preview.draw_line(rec_pos + Vector2(0, 4), stock_pos + Vector2(0, 4), Color(0.2, 0.2, 0.25), 3.0)
		wb_preview.draw_rect(Rect2(stock_pos + Vector2(-4, -2), Vector2(6, 24)), Color(0.12, 0.12, 0.15))
		
	# [레일 레이저/손전등]
	var rail_p = parts.get("rail", [])
	if rail_p is Array and rail_p.size() > 0:
		for rp in rail_p:
			if rp.contains("레이저"):
				wb_preview.draw_line(barrel_tip + Vector2(b_len, 2), barrel_tip + Vector2(b_len + 180, 2), Color(1.0, 0.2, 0.2, 0.65), 1.2)
				wb_preview.draw_circle(barrel_tip + Vector2(b_len + 180, 2), 2.5, Color.RED)
			elif rp.contains("손전등"):
				wb_preview.draw_polygon(PackedVector2Array([
					barrel_tip + Vector2(b_len, 6),
					barrel_tip + Vector2(b_len + 120, -30),
					barrel_tip + Vector2(b_len + 120, 42)
				]), PackedColorArray([Color(1.0, 1.0, 0.6, 0.25), Color(1.0, 1.0, 0.6, 0.0), Color(1.0, 1.0, 0.6, 0.0)]))
