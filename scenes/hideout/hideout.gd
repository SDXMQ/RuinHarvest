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

# 작업대 탭 컴포넌트 (Workbench Component)
@onready var workbench: HideoutWorkbench = $CenterArea/TabContainer/WorkbenchTab

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
const ShootingRangeScript = preload("res://scenes/ui/shooting_range_window.gd")

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

var insurance_btn: Button = null

func _ready() -> void:
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)
	
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	result_close_btn.pressed.connect(_on_result_close_pressed)
	
	# 상단 바에 장비 보험 버튼 및 샌드박스 도구 버튼 추가
	if has_node("TopBar"):
		insurance_btn = Button.new()
		insurance_btn.name = "InsuranceBtn"
		insurance_btn.pressed.connect(_on_insurance_pressed)
		$TopBar.add_child(insurance_btn)
		
		var tool_btn = Button.new()
		tool_btn.text = "🛠️ 샌드박스/치트 도구 (F1)"
		tool_btn.pressed.connect(_open_item_spawner)
		$TopBar.add_child(tool_btn)
		
		var range_btn = Button.new()
		range_btn.text = "🎯 사격장 (F2)"
		range_btn.pressed.connect(_open_shooting_range)
		$TopBar.add_child(range_btn)
	
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
	stash_grid_mgr.has_secure_container = false
	add_child(stash_grid_mgr)
	
	player_grid_mgr.grid_changed.connect(_on_grid_changed)
	stash_grid_mgr.grid_changed.connect(_on_grid_changed)
	
	# 2D 그리드 드로잉 및 입력 연결
	player_grid_control.draw.connect(_on_player_grid_draw)
	player_grid_control.gui_input.connect(_on_player_grid_gui_input)
	
	stash_grid_control.draw.connect(_on_stash_grid_draw)
	stash_grid_control.gui_input.connect(_on_stash_grid_gui_input)
	
	# 배낭 & 창고 정렬/빠른 보관 버튼 바 추가
	var player_vbox = get_node_or_null("CenterArea/TabContainer/StashTab/HBox/PlayerPanel/VBox")
	if player_vbox:
		var p_btn_row = HBoxContainer.new()
		p_btn_row.add_theme_constant_override("separation", 6)
		var p_sort_btn = Button.new()
		p_sort_btn.text = "🔄 배낭 정렬"
		p_sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_sort_btn.add_theme_font_size_override("font_size", 11)
		p_sort_btn.pressed.connect(func():
			player_grid_mgr.sort_items()
			if SoundManager: SoundManager.play("menu_select")
		)
		p_btn_row.add_child(p_sort_btn)
		
		var deposit_all_btn = Button.new()
		deposit_all_btn.text = "⏩ 창고로 모두 보관"
		deposit_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deposit_all_btn.add_theme_font_size_override("font_size", 11)
		deposit_all_btn.pressed.connect(func():
			var copy_items = player_grid_mgr.items.duplicate(true)
			for it in copy_items:
				var rem = stash_grid_mgr.auto_add_item(it.get("id", ""), it.get("amount", 1), it)
				if rem <= 0:
					player_grid_mgr.remove_item_by_uid(it.get("uid", ""), false)
				else:
					var orig = player_grid_mgr.get_item_by_uid(it.get("uid", ""))
					if not orig.is_empty(): orig["amount"] = rem
			player_grid_mgr.grid_changed.emit()
			stash_grid_mgr.grid_changed.emit()
			if SoundManager: SoundManager.play("item_pickup")
		)
		p_btn_row.add_child(deposit_all_btn)
		player_vbox.add_child(p_btn_row)
		player_vbox.move_child(p_btn_row, 1)

	var stash_vbox = get_node_or_null("CenterArea/TabContainer/StashTab/HBox/StashPanel/VBox")
	if stash_vbox:
		var s_sort_btn = Button.new()
		s_sort_btn.text = "🔄 창고 자동 정렬 & 스택 병합  (Ctrl+클릭 / 우클릭: 빠른 이동)"
		s_sort_btn.add_theme_font_size_override("font_size", 11)
		s_sort_btn.pressed.connect(func():
			stash_grid_mgr.sort_items()
			if SoundManager: SoundManager.play("menu_select")
		)
		stash_vbox.add_child(s_sort_btn)
		stash_vbox.move_child(s_sort_btn, 1)
	
	# 장비 슬롯 연결
	_connect_equipment_slots()
	
	# 작업대 탭 연결
	if workbench:
		workbench.setup(player_grid_mgr, stash_grid_mgr, equipment_data)
		workbench.weapon_saved.connect(func(_w, _s):
			_update_equipment_ui()
			_refresh_stash_ui()
			_sync_save_data()
		)
		workbench.money_spent.connect(func(_amt):
			_update_money_label()
			_sync_save_data()
		)
		
	tab_container.tab_changed.connect(_on_tab_changed)
	progression_tab = HideoutProgression.setup_progression_tab(self, tab_container)
	
	_load_data()
	_check_last_raid_result()
	_apply_backpack_grid_size()
	_update_equipment_ui()
	_refresh_stash_ui()
	_refresh_trader_ui()
	_refresh_market_ui()
	_refresh_workbench_ui()
	HideoutProgression.refresh_progression_tab(self, progression_tab)
	
	# 반응형 레이아웃 연결
	if ResponsiveManager:
		ResponsiveManager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		ResponsiveManager.window_resized.connect(_on_responsive_window_resized)
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, ResponsiveManager.current_viewport_size)

var progression_tab: Control = null

func _apply_stash_upgrade_size() -> void:
	if not stash_grid_mgr or not GameManager: return
	var new_h = HideoutProgression.get_stash_grid_height(GameManager.current_world_data)
	stash_grid_mgr.resize_grid(10, new_h)
	if stash_grid_control:
		stash_grid_control.custom_minimum_size = Vector2(10 * CELL_SIZE, new_h * CELL_SIZE)
		stash_grid_control.queue_redraw()

func _on_responsive_breakpoint_changed(new_bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	_apply_responsive_layout(new_bp, vp_size)

func _on_responsive_window_resized(vp_size: Vector2) -> void:
	if ResponsiveManager:
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, vp_size)

func _apply_responsive_layout(bp: ResponsiveManager.Breakpoint, _vp_size: Vector2) -> void:
	if bp == ResponsiveManager.Breakpoint.COMPACT:
		if has_node("TopBar/DayLabel"):
			$TopBar/DayLabel.add_theme_font_size_override("font_size", 14)
		if has_node("TopBar/MoneyLabel"):
			$TopBar/MoneyLabel.add_theme_font_size_override("font_size", 14)
	else:
		if has_node("TopBar/DayLabel"):
			$TopBar/DayLabel.add_theme_font_size_override("font_size", 20)
		if has_node("TopBar/MoneyLabel"):
			$TopBar/MoneyLabel.add_theme_font_size_override("font_size", 18)

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
	elif tab == 4 and progression_tab:
		HideoutProgression.refresh_progression_tab(self, progression_tab)

func _on_grid_changed() -> void:
	if player_grid_control: player_grid_control.queue_redraw()
	if stash_grid_control: stash_grid_control.queue_redraw()
	_refresh_trader_sell_ui()
	if progression_tab and tab_container and tab_container.current_tab == 4:
		HideoutProgression.refresh_progression_tab(self, progression_tab)
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
		
		# 착용 배낭 및 시설 업그레이드에 맞춰 그리드 크기 먼저 확장
		_apply_backpack_grid_size()
		_apply_stash_upgrade_size()
		
		# 배낭 2D 데이터 로드
		var p_items = p_data.get("inventory", [])
		if player_grid_mgr.has_method("load_items"):
			player_grid_mgr.load_items(p_items)
		else:
			player_grid_mgr.clear()
			for it in p_items:
				if it is Dictionary and it.has("id"):
					player_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)
				
		# 창고 2D 데이터 로드
		var stash_items = w_data.get("hideout", {}).get("stash", [])
		if stash_grid_mgr.has_method("load_items"):
			stash_grid_mgr.load_items(stash_items)
		else:
			stash_grid_mgr.clear()
			for it in stash_items:
				if it is Dictionary and it.has("id"):
					stash_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)

func _update_money_label() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var rubles = GameManager.current_world_data.get("player", {}).get("rubles", 5000)
		money_label.text = "자금: %d RUB" % rubles
		_update_insurance_ui()

func _update_insurance_ui() -> void:
	if not insurance_btn or not GameManager or GameManager.current_world_data.is_empty():
		return
	var is_insured = GameManager.current_world_data.get("player", {}).get("insured", false)
	if is_insured:
		insurance_btn.text = "🛡️ 장비 보험 적용됨 (사망 시 장착 장비 보존)"
		insurance_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
		insurance_btn.disabled = true
	else:
		insurance_btn.text = "🛡️ 장비 보험 가입 (1,500 RUB)"
		insurance_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		var rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))
		insurance_btn.disabled = (rubles < 1500)

func _on_insurance_pressed() -> void:
	if not GameManager or GameManager.current_world_data.is_empty():
		return
	var p = GameManager.current_world_data.get("player", {})
	if p.get("insured", false) or int(p.get("rubles", 0)) < 1500:
		return
	p["rubles"] = int(p.get("rubles", 0)) - 1500
	p["insured"] = true
	if SoundManager: SoundManager.play("craft_complete")
	_update_money_label()
	_sync_save_data()

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
	var new_w = 6
	var new_h = 3
	
	if not bp.is_empty():
		var id = bp.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var b_grid = d.get("backpack_grid", Vector2i(6, 5))
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
	InventoryUIHelper.draw_2d_grid(ctrl, grid_mgr, hovered_cell, is_player_grid, is_dragging, drag_data)


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
				if Input.is_key_pressed(KEY_CTRL):
					if tooltip: tooltip.hide()
					_handle_hideout_quick_action(item, is_player_grid)
				elif Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
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
			if drag_preview_node:
				drag_preview_node.rotation = PI * 0.5 if drag_data["rotated"] else 0.0
			if SoundManager: SoundManager.play("menu_move")
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
	InventoryUIHelper.highlight_compatible_slots(drop_targets, item, hovered_ctrl)

func _clear_slot_highlights() -> void:
	InventoryUIHelper.clear_slot_highlights(drop_targets)

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
	
	if dest_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item.get("id", "")):
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
	return InventoryUIHelper.is_slot_compatible(item_id, slot_name)

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
	InventoryUIHelper.render_equip_slot_button(btn, slot_name, default_text, equipment_data)

func _open_split_dialog(item: Dictionary, on_confirm_callback: Callable) -> void:
	var dialog = SplitDialogScene.instantiate()
	add_child(dialog)
	dialog.setup(int(item.get("amount", 1)))
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
	var discount = HideoutProgression.get_trader_discount(GameManager.current_world_data) if GameManager else 0.0
	
	for stock_item in t_data.get("stock", []):
		var item_id = stock_item["id"]
		var price = max(1, int(stock_item["price"] * (1.0 - discount)))
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
		
	# 가방과 보관함(창고)의 아이템들을 판매 가능 목록으로 표시
	var sellable_sources = [
		{"mgr": player_grid_mgr, "tag": "🎒가방", "is_stash": false},
		{"mgr": stash_grid_mgr, "tag": "📦창고", "is_stash": true}
	]
	var sell_ratio = HideoutProgression.get_trader_sell_ratio(GameManager.current_world_data) if GameManager else 0.60
	
	for src in sellable_sources:
		var mgr = src["mgr"]
		if not mgr: continue
		var tag = src["tag"]
		var is_stash = src["is_stash"]
		
		for item in mgr.items:
			if item and not item.is_empty():
				var data = ItemDatabase.get_item_data(item.get("id", ""))
				var sell_price = max(1, int(data.get("value", 500) * sell_ratio))
				var uid = item.get("uid", "")
				
				var btn = Button.new()
				btn.custom_minimum_size = Vector2(110, 50)
				
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
				btn.text = "[%s] %s\n+%d RUB" % [tag, data.get("name", item.get("id", "")), sell_price * item.get("amount", 1)]
				btn.add_theme_font_size_override("font_size", 9)
				btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
				btn.pressed.connect(func(): _sell_item(uid, is_stash, item.get("id", ""), item.get("amount", 1), sell_price))
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

func _sell_item(uid: String, is_stash: bool, _item_id: String, amount: int, unit_price: int) -> void:
	var total_gain = unit_price * amount
	GameManager.current_world_data["player"]["rubles"] += total_gain
	_update_money_label()
	
	if is_stash:
		stash_grid_mgr.remove_item_by_uid(uid)
		_refresh_stash_ui()
	else:
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
		
	var registerable_sources = [
		{"mgr": player_grid_mgr, "tag": "🎒가방", "is_stash": false},
		{"mgr": stash_grid_mgr, "tag": "📦창고", "is_stash": true}
	]
	
	for src in registerable_sources:
		var mgr = src["mgr"]
		if not mgr: continue
		var tag = src["tag"]
		var is_stash = src["is_stash"]
		
		for item in mgr.items:
			if item and not item.is_empty():
				var item_id = item.get("id", "")
				var uid = item.get("uid", "")
				var data = ItemDatabase.get_item_data(item_id)
				if item_id == "Scav 식별줄(Dogtag)":
					continue
					
				var current_price = FleaMarket.get_current_price(item_id)
				
				var btn = Button.new()
				btn.custom_minimum_size = Vector2(110, 50)
				
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
				btn.text = "[%s] %s\n시장가 %d RUB" % [tag, data.get("name", item_id), current_price]
				btn.add_theme_font_size_override("font_size", 9)
				btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
				btn.pressed.connect(func(): _register_market_item(uid, is_stash, item_id, item.get("amount", 1), current_price))
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

func _register_market_item(uid: String, is_stash: bool, item_id: String, amount: int, current_price: int) -> void:
	# 5% 수수료 (선불)
	var fee = max(1, int(current_price * amount * 0.05))
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	if user_rubles < fee:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 등록 수수료(%d RUB)가 부족합니다." % fee)
		return
		
	GameManager.current_world_data["player"]["rubles"] -= fee
	_update_money_label()
	
	if is_stash:
		stash_grid_mgr.remove_item_by_uid(uid)
		_refresh_stash_ui()
	else:
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
			result_desc.text = "안전하게 은신처로 복귀했습니다.\n획득한 전리품이 배낭에 보존되었습니다."
		elif res["result"] == "kia":
			result_title.text = "💀 작전 중 사망 (KIA)"
			result_title.add_theme_color_override("font_color", Color.RED)
			result_desc.text = "레이드 도중 사망했습니다.\n2x2 안전 파우치 외의 일반 배낭 아이템을 잃었습니다."
		elif res["result"] == "mia":
			result_title.text = "⏳ 작전 시간 초과 (MIA)"
			result_title.add_theme_color_override("font_color", Color.ORANGE)
			result_desc.text = "제한 시간 내에 탈출하지 못해 실종되었습니다."
			
		var kills_cnt = int(res.get("kills", 0))
		var t_spent = int(res.get("time_spent", 0.0))
		result_desc.text += "\n\n⚔️ 이번 레이드 처치: %d명  |  ⏱️ 작전 시간: %d분 %d초" % [kills_cnt, int(float(t_spent) / 60.0), t_spent % 60]
		
		if res.get("insurance_claimed", false):
			result_desc.text += "\n🛡️ 장비 보험 적용 완료: 장착 중이던 무기 및 방어구가 안전하게 회수되었습니다."
		var pouch_cnt = int(res.get("pouch_saved_count", 0))
		if pouch_cnt > 0:
			result_desc.text += "\n🔒 2x2 안전 파우치 보호: 귀중품 %d종이 분실되지 않고 보존되었습니다." % pouch_cnt
		
		var passive_inc = int(res.get("passive_income", 0))
		var landmark_bon = int(res.get("landmark_bonus", 0))
		if landmark_bon > 0:
			result_desc.text += "\n📡 랜드마크 현장 단말기 작전 보너스: +%d RUB" % landmark_bon
			_update_money_label()
			
		if passive_inc > 0:
			result_desc.text += "\n⚡ 발전기/채굴 서버 패시브 수익: +%d RUB" % passive_inc
			_update_money_label()
			
		var sales_report = res.get("sales_report", {})
		var completed_sales = sales_report.get("completed", [])
		if not completed_sales.is_empty():
			var total_earned = 0
			for s in completed_sales:
				total_earned += int(s.get("earned", 0))
			result_desc.text += "\n\n📈 플리마켓 정산: 등록 물품 %d건 판매 완료 (+%d RUB)" % [completed_sales.size(), total_earned]
			_update_money_label()
			
		GameManager.last_raid_result.clear()
		_update_insurance_ui()
	else:
		result_dialog.visible = false

func _on_result_close_pressed() -> void:
	result_dialog.visible = false

func _on_raid_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	_sync_save_data()
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
		elif event.physical_keycode == KEY_F2:
			_open_shooting_range()
		elif event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I:
			_open_inventory_window()

func _open_shooting_range() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var target_wep = equipment_data.get("primary1", {})
	if target_wep.is_empty():
		target_wep = equipment_data.get("primary2", {})
	if target_wep.is_empty():
		target_wep = equipment_data.get("sidearm", {})
	var win = ShootingRangeScript.new()
	add_child(win)
	win.setup(target_wep)

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


func _refresh_workbench_ui() -> void:
	if workbench:
		workbench.refresh_workbench_ui()
