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
const CharacterPaperdollPreviewScript = preload("res://scenes/hideout/components/character_paperdoll_preview.gd")

# 2D 인벤토리 그리드 시스템
var player_grid_mgr: InventoryGrid
var stash_grid_mgr: InventoryGrid
var equipment_data: Dictionary = {}

const CELL_SIZE: float = InventoryUIHelper.CELL_SIZE
var player_cell_size: float = CELL_SIZE
var stash_cell_size: float = CELL_SIZE
var sell_player_cell_size: float = CELL_SIZE
var sell_stash_cell_size: float = CELL_SIZE
var market_player_cell_size: float = CELL_SIZE
var market_stash_cell_size: float = CELL_SIZE
var _drag_preview_cell_size: float = CELL_SIZE
var character_paperdoll_preview: Control = null

# 드래그 앤 드롭 상태
var is_dragging: bool = false
var drag_data: Dictionary = {}
var drag_preview_node: Control = null
var hovered_player_cell: Vector2i = Vector2i(-1, -1)
var hovered_stash_cell: Vector2i = Vector2i(-1, -1)

var drop_targets: Array[Dictionary] = []
var current_trader_id: String = "prapor"
var open_container_popups: Dictionary = {}
var context_menu_panel: PanelContainer = null

# 상인 일괄 판매(Bulk Sell) & 마키 선택 상태
var selected_sell_uids: Dictionary = {}
var sell_player_grid_ctrl: Control = null
var sell_stash_grid_ctrl: Control = null
var hovered_sell_player_cell: Vector2i = Vector2i(-1, -1)
var hovered_sell_stash_cell: Vector2i = Vector2i(-1, -1)
var _is_marquee_selecting: bool = false
var _marquee_ctrl: Control = null
var _marquee_grid: InventoryGrid = null
var _marquee_is_stash: bool = false
var _marquee_start_local: Vector2 = Vector2.ZERO
var trader_loyalty_label: Label = null
var trader_loyalty_bar: ProgressBar = null
var sell_grid_header_lbl: Label = null
var sell_receipt_list_vbox: VBoxContainer = null
var sell_receipt_summary_lbl: Label = null
var sell_bulk_btn: Button = null
var trader_mode_tabs: TabContainer = null
var sell_grids_scroll: ScrollContainer = null
var trader_btn_valuables: Button = null
var trader_btn_non_gear: Button = null
var market_grids_scroll: ScrollContainer = null

# 암시장 등록 UI 상태 (좌/우 2단 분할 + 2D 그리드 + 검색/카테고리 필터)
var market_price_ratio: float = 1.0
var market_slot_label: Label = null
var market_search_text: String = ""
var market_filter_category: String = "all"
var market_search_input: LineEdit = null
var market_player_grid_ctrl: Control = null
var market_stash_grid_ctrl: Control = null
var hovered_market_player_cell: Vector2i = Vector2i(-1, -1)
var hovered_market_stash_cell: Vector2i = Vector2i(-1, -1)
var market_selected_uid: String = ""
var market_selected_is_stash: bool = false
var market_filter_buttons: Dictionary = {}
var market_ratio_buttons: Dictionary = {}
var market_preview_lbl: Label = null
var market_confirm_btn: Button = null
var market_result_count_lbl: Label = null

var insurance_btn: Button = null
var _hideout_event_log_vbox: VBoxContainer = null
var current_settings_window: Control = null

func _ready() -> void:
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)

	_hideout_event_log_vbox = VBoxContainer.new()
	_hideout_event_log_vbox.name = "HideoutEventLog"
	_hideout_event_log_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hideout_event_log_vbox.z_index = 260
	_hideout_event_log_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hideout_event_log_vbox.offset_left = -460.0
	_hideout_event_log_vbox.offset_top = 66.0
	_hideout_event_log_vbox.offset_right = -16.0
	_hideout_event_log_vbox.offset_bottom = 260.0
	_hideout_event_log_vbox.add_theme_constant_override("separation", 6)
	add_child(_hideout_event_log_vbox)
	if EventBus and EventBus.has_signal("event_logged"):
		EventBus.event_logged.connect(_on_hideout_event_logged)
	
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	result_close_btn.pressed.connect(_on_result_close_pressed)
	
	# 상단 바에 장비 보험 버튼, 샌드박스 도구, 사격장 버튼을 중앙 HBoxContainer로 정렬 배치 (DayLabel 겹침 방지)
	if has_node("TopBar"):
		var top_tools := HBoxContainer.new()
		top_tools.name = "TopToolBar"
		top_tools.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top_tools.offset_left = 240.0
		top_tools.offset_top = 12.0
		top_tools.offset_right = -260.0
		top_tools.offset_bottom = 48.0
		top_tools.alignment = BoxContainer.ALIGNMENT_CENTER
		top_tools.add_theme_constant_override("separation", 10)
		$TopBar.add_child(top_tools)
		
		insurance_btn = Button.new()
		insurance_btn.name = "InsuranceBtn"
		insurance_btn.custom_minimum_size = Vector2(0, 32)
		insurance_btn.pressed.connect(_on_insurance_pressed)
		top_tools.add_child(insurance_btn)
		
		var tool_btn = Button.new()
		tool_btn.text = "🛠️ 샌드박스/치트 도구 (F1)"
		tool_btn.custom_minimum_size = Vector2(0, 32)
		tool_btn.pressed.connect(_open_item_spawner)
		top_tools.add_child(tool_btn)
		
		var range_btn = Button.new()
		range_btn.text = "🎯 사격장 (F2)"
		range_btn.custom_minimum_size = Vector2(0, 32)
		range_btn.pressed.connect(_open_shooting_range)
		top_tools.add_child(range_btn)

		var settings_btn = Button.new()
		settings_btn.name = "SettingsBtn"
		settings_btn.text = "⚙️ 설정 (F11)"
		settings_btn.custom_minimum_size = Vector2(0, 32)
		settings_btn.pressed.connect(_open_settings_window)
		top_tools.add_child(settings_btn)
	
	# 상인 버튼 연결
	var prapor_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/PraporBtn
	var therapist_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/TherapistBtn
	var fence_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/FenceBtn
	
	prapor_btn.pressed.connect(func(): _select_trader("prapor"))
	therapist_btn.pressed.connect(func(): _select_trader("therapist"))
	fence_btn.pressed.connect(func(): _select_trader("fence"))
	
	# 2D 인벤토리 매니저 인스턴스화
	player_grid_mgr = InventoryGrid.new()
	player_grid_mgr.has_secure_container = true
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
		deposit_all_btn.tooltip_text = "배낭의 전리품을 창고로 일괄 보관합니다. (2x2 안전 파우치 내 열쇠/키카드/귀중품은 안전하게 보호됩니다)"
		deposit_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deposit_all_btn.add_theme_font_size_override("font_size", 11)
		deposit_all_btn.pressed.connect(func():
			_sync_all_open_popups()
			var copy_items = player_grid_mgr.items.duplicate(true)
			for it in copy_items:
				if bool(it.get("locked", false)):
					continue
				var ix = int(it.get("x", 99))
				var iy = int(it.get("y", 99))
				var is_rot = it.get("rotated", false)
				var base_size = ItemDatabase.get_item_grid_size(it.get("id", ""))
				var w = base_size.y if is_rot else base_size.x
				var h = base_size.x if is_rot else base_size.y
				# 2x2 안전 컨테이너 영역(Secure Pouch) 내 아이템은 창고 일괄 보관 대상에서 제외하여 안전 보존
				if player_grid_mgr.has_secure_container and ix < 2 and iy < 2 and ix + w <= 2 and iy + h <= 2:
					continue
				var rem = stash_grid_mgr.auto_add_item(it.get("id", ""), it.get("amount", 1), it)
				if rem <= 0:
					player_grid_mgr.remove_item_by_uid(it.get("uid", ""), false)
				else:
					var orig = player_grid_mgr.get_item_by_uid(it.get("uid", ""))
					if not orig.is_empty(): orig["amount"] = rem
			player_grid_mgr.grid_changed.emit()
			stash_grid_mgr.grid_changed.emit()
			_prune_stale_popups()
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
	_setup_character_paperdoll_ui()
	_setup_stash_grid_scaling()
	_setup_traders_bulk_ui()
	_setup_market_controls()
	
	# 작업대 탭 연결
	if workbench:
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
	service_record_tab = HideoutProgression.setup_service_record_tab(self, tab_container)
	
	_load_data()
	if workbench:
		workbench.setup(player_grid_mgr, stash_grid_mgr, equipment_data)
	_check_last_raid_result()
	_apply_backpack_grid_size()
	_update_equipment_ui()
	_refresh_stash_ui()
	_refresh_trader_ui()
	_refresh_market_ui()
	_refresh_workbench_ui()
	HideoutProgression.refresh_progression_tab(self, progression_tab)
	HideoutProgression.refresh_service_record_tab(self, service_record_tab)
	
	# 반응형 레이아웃 연결
	if ResponsiveManager:
		ResponsiveManager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		ResponsiveManager.window_resized.connect(_on_responsive_window_resized)
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, ResponsiveManager.current_viewport_size)
	call_deferred("_update_all_hideout_grid_sizes")

var progression_tab: Control = null
var service_record_tab: Control = null
var _is_loading_data: bool = false

func _compute_fit_cell_size(scroll_ctrl: Control, grid_cols: int, min_cell: float = CELL_SIZE, max_cell: float = 56.0) -> float:
	if not is_instance_valid(scroll_ctrl) or grid_cols <= 0:
		return min_cell
	var avail_w := scroll_ctrl.size.x - 14.0
	if avail_w <= 60.0:
		return min_cell
	return clampf(floorf(avail_w / float(grid_cols)), min_cell, max_cell)

func _get_grid_cell_size(ctrl: Control) -> float:
	if ctrl == player_grid_control:
		return player_cell_size
	elif ctrl == stash_grid_control:
		return stash_cell_size
	elif ctrl == sell_player_grid_ctrl:
		return sell_player_cell_size
	elif ctrl == sell_stash_grid_ctrl:
		return sell_stash_cell_size
	elif ctrl == market_player_grid_ctrl:
		return market_player_cell_size
	elif ctrl == market_stash_grid_ctrl:
		return market_stash_cell_size
	return CELL_SIZE

func _update_all_hideout_grid_sizes() -> void:
	if player_grid_control and player_grid_mgr:
		var p_scroll := player_grid_control.get_parent() as ScrollContainer
		player_cell_size = _compute_fit_cell_size(p_scroll, player_grid_mgr.grid_width, CELL_SIZE, 56.0)
		player_grid_control.custom_minimum_size = Vector2(player_grid_mgr.grid_width * player_cell_size, player_grid_mgr.grid_height * player_cell_size)
		player_grid_control.queue_redraw()
	if stash_grid_control and stash_grid_mgr:
		var s_scroll := stash_grid_control.get_parent() as ScrollContainer
		stash_cell_size = _compute_fit_cell_size(s_scroll, stash_grid_mgr.grid_width, CELL_SIZE, 56.0)
		stash_grid_control.custom_minimum_size = Vector2(stash_grid_mgr.grid_width * stash_cell_size, stash_grid_mgr.grid_height * stash_cell_size)
		stash_grid_control.queue_redraw()
	if sell_player_grid_ctrl and player_grid_mgr:
		sell_player_cell_size = _compute_fit_cell_size(sell_grids_scroll, player_grid_mgr.grid_width, CELL_SIZE, 54.0)
		sell_player_grid_ctrl.custom_minimum_size = Vector2(float(player_grid_mgr.grid_width) * sell_player_cell_size, float(player_grid_mgr.grid_height) * sell_player_cell_size)
		sell_player_grid_ctrl.queue_redraw()
	if sell_stash_grid_ctrl and stash_grid_mgr:
		sell_stash_cell_size = _compute_fit_cell_size(sell_grids_scroll, stash_grid_mgr.grid_width, CELL_SIZE, 54.0)
		sell_stash_grid_ctrl.custom_minimum_size = Vector2(float(stash_grid_mgr.grid_width) * sell_stash_cell_size, float(stash_grid_mgr.grid_height) * sell_stash_cell_size)
		sell_stash_grid_ctrl.queue_redraw()

func _setup_stash_grid_scaling() -> void:
	for ctrl in [player_grid_control, stash_grid_control]:
		if ctrl and ctrl.get_parent() is ScrollContainer:
			var sc := ctrl.get_parent() as ScrollContainer
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			if not sc.resized.is_connected(_update_all_hideout_grid_sizes):
				sc.resized.connect(_update_all_hideout_grid_sizes)

func _setup_character_paperdoll_ui() -> void:
	var equip_scroll := get_node_or_null("CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll") as ScrollContainer
	if equip_scroll:
		equip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var slots_vbox := get_node_or_null("CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Scroll/SlotsVBox") as VBoxContainer
	if not slots_vbox:
		return
	var top_hbox := HBoxContainer.new()
	top_hbox.name = "ArmorPaperdollHBox"
	top_hbox.add_theme_constant_override("separation", 8)
	slots_vbox.add_child(top_hbox)
	slots_vbox.move_child(top_hbox, 0)

	var armor_col := VBoxContainer.new()
	armor_col.name = "ArmorSlotsCol"
	armor_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_col.size_flags_stretch_ratio = 1.05
	armor_col.add_theme_constant_override("separation", 6)
	top_hbox.add_child(armor_col)

	for slot_btn in [helmet_slot, vest_slot, backpack_slot, bottom_slot]:
		if is_instance_valid(slot_btn) and slot_btn.get_parent() == slots_vbox:
			slots_vbox.remove_child(slot_btn)
			armor_col.add_child(slot_btn)
			slot_btn.custom_minimum_size = Vector2(118, 42)
			slot_btn.clip_text = true

	var doll_panel := PanelContainer.new()
	doll_panel.name = "PaperdollPanel"
	doll_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doll_panel.size_flags_stretch_ratio = 0.95
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.24, 0.34, 0.44, 0.85)
	sb.set_corner_radius_all(4)
	doll_panel.add_theme_stylebox_override("panel", sb)
	top_hbox.add_child(doll_panel)

	character_paperdoll_preview = CharacterPaperdollPreviewScript.new()
	character_paperdoll_preview.name = "CharacterPaperdollPreview"
	character_paperdoll_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_paperdoll_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_paperdoll_preview.custom_minimum_size = Vector2(126, 186)
	doll_panel.add_child(character_paperdoll_preview)

func _apply_stash_upgrade_size() -> void:
	if not stash_grid_mgr or not GameManager: return
	var new_h = HideoutProgression.get_stash_grid_height(GameManager.current_world_data)
	stash_grid_mgr.resize_grid(10, new_h)
	if stash_grid_control:
		var s_scroll := stash_grid_control.get_parent() as ScrollContainer
		stash_cell_size = _compute_fit_cell_size(s_scroll, 10, CELL_SIZE, 56.0)
		stash_grid_control.custom_minimum_size = Vector2(10 * stash_cell_size, new_h * stash_cell_size)
		stash_grid_control.queue_redraw()

func _on_responsive_breakpoint_changed(new_bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	_apply_responsive_layout(new_bp, vp_size)

func _on_responsive_window_resized(vp_size: Vector2) -> void:
	if ResponsiveManager:
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, vp_size)

func _apply_responsive_layout(bp: ResponsiveManager.Breakpoint, _vp_size: Vector2) -> void:
	if bp == ResponsiveManager.Breakpoint.COMPACT:
		if has_node("TopBar/DayLabel"):
			if PixelAssetManager:
				$TopBar/DayLabel.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
			$TopBar/DayLabel.add_theme_font_size_override("font_size", 12)
		if has_node("TopBar/MoneyLabel"):
			if PixelAssetManager:
				$TopBar/MoneyLabel.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
			$TopBar/MoneyLabel.add_theme_font_size_override("font_size", 12)
	else:
		if has_node("TopBar/DayLabel"):
			if PixelAssetManager:
				$TopBar/DayLabel.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
			$TopBar/DayLabel.add_theme_font_size_override("font_size", 24)
		if has_node("TopBar/MoneyLabel"):
			if PixelAssetManager:
				$TopBar/MoneyLabel.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
			$TopBar/MoneyLabel.add_theme_font_size_override("font_size", 24)
	call_deferred("_update_all_hideout_grid_sizes")

func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())
	if is_dragging and drag_preview_node:
		_update_drag_preview_pos()

func _on_tab_changed(tab: int) -> void:
	if tooltip: tooltip.hide()
	_close_context_menu()
	if tab != 0:
		_sync_all_open_popups()
		close_all_container_popups()
	if tab == 0:
		_refresh_stash_ui()
		call_deferred("_update_all_hideout_grid_sizes")
	elif tab == 1:
		_refresh_trader_ui()
		call_deferred("_update_all_hideout_grid_sizes")
	elif tab == 2:
		_refresh_market_ui()
		call_deferred("_update_all_hideout_grid_sizes")
	elif tab == 3:
		_refresh_workbench_ui()
	elif tab == 4 and progression_tab:
		HideoutProgression.refresh_progression_tab(self, progression_tab)
	elif tab == 5 and service_record_tab:
		HideoutProgression.refresh_service_record_tab(self, service_record_tab)

func _on_grid_changed() -> void:
	_prune_stale_popups()
	if player_grid_control: player_grid_control.queue_redraw()
	if stash_grid_control: stash_grid_control.queue_redraw()
	_refresh_trader_sell_ui()
	_refresh_market_register_ui()
	if progression_tab and tab_container and tab_container.current_tab == 4:
		HideoutProgression.refresh_progression_tab(self, progression_tab)
	if service_record_tab and tab_container and tab_container.current_tab == 5:
		HideoutProgression.refresh_service_record_tab(self, service_record_tab)
	_sync_save_data()

func _load_data() -> void:
	close_all_container_popups()
	if GameManager and not GameManager.current_world_data.is_empty():
		_is_loading_data = true
		var w_data = GameManager.current_world_data
		if FleaMarket:
			FleaMarket.load_from_save_dict(w_data.get("flea_market", {}))
		var day = w_data.get("current_day", 1)
		day_label.text = "생존 %d일차 (DAY %d)" % [day, day]
		_update_money_label()
		
		# resize_grid()가 grid_changed 시그널을 방출하기 전에 원본 인벤토리/창고 데이터를 미리 복제 보관
		var p_data = w_data.get("player", {})
		var p_items: Array = p_data.get("inventory", []).duplicate(true)
		var stash_items: Array = w_data.get("hideout", {}).get("stash", []).duplicate(true)
		
		# 장비 데이터 로드 (초기 시작 총기는 기본 조립 파츠 및 탄약 완비 상태로 생성)
		if p_data.has("equipment") and not p_data["equipment"].is_empty():
			equipment_data = p_data["equipment"].duplicate(true)
		else:
			var starter_m4 = WeaponPartsDatabase.compute_weapon_from_dict({
				"id": "M4_리시버",
				"type": "assembled_weapon",
				"name": WeaponPartsDatabase.RECEIVERS["M4_리시버"].get("name", "M4A1 카빈 리시버"),
				"receiver": "M4_리시버",
				"loaded_ammo": "5.56mm",
				"parts": {"barrel": "짧은_총열", "optic": "기본_아이언사이트", "magazine": "표준_탄창"},
				"durability": 100.0
			})
			starter_m4["current_magazine_ammo"] = int(starter_m4.get("computed_stats", {}).get("magazine_size", 30))
			var starter_m9 = WeaponPartsDatabase.create_default_weapon("M9_리시버")
			equipment_data = {
				"helmet": {"id": "1레벨_헬멧", "name": "1레벨 오토바이 헬멧"},
				"vest": {"id": "1레벨_방탄복", "name": "1레벨 경찰 조끼"},
				"backpack": {"id": "1레벨_가방", "name": "1레벨 소형 배낭"},
				"bottom": {"id": "운동화", "name": "운동화"},
				"primary1": starter_m4,
				"primary2": {},
				"sidearm": starter_m9,
				"throwable": {"id": "수류탄", "amount": 2}
			}
		
		# 착용 배낭 및 시설 업그레이드에 맞춰 그리드 크기 먼저 확장
		_apply_backpack_grid_size()
		_apply_stash_upgrade_size()
		
		# 배낭 2D 데이터 로드 (2x2 세이프 파우치 포함)
		if player_grid_mgr.has_method("load_items"):
			player_grid_mgr.load_items(p_items)
		else:
			player_grid_mgr.clear()
			for it in p_items:
				if it is Dictionary and it.has("id"):
					player_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)
				
		# 창고 2D 데이터 로드
		if stash_grid_mgr.has_method("load_items"):
			stash_grid_mgr.load_items(stash_items)
		else:
			stash_grid_mgr.clear()
			for it in stash_items:
				if it is Dictionary and it.has("id"):
					stash_grid_mgr.auto_add_item(it["id"], it.get("amount", 1), it)
					
		_is_loading_data = false
		_sync_save_data()

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
	if _is_loading_data:
		return
	_sync_all_open_popups()
	if GameManager and not GameManager.current_world_data.is_empty():
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		GameManager.current_world_data["player"]["inventory"] = player_grid_mgr.items.duplicate(true)
		GameManager.current_world_data["player"]["equipment"] = equipment_data.duplicate(true)
		
		if not GameManager.current_world_data.has("hideout"):
			GameManager.current_world_data["hideout"] = {}
		GameManager.current_world_data["hideout"]["stash"] = stash_grid_mgr.items.duplicate(true)
		if FleaMarket:
			GameManager.current_world_data["flea_market"] = FleaMarket.to_save_dict()
		
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
			var rem = stash_grid_mgr.auto_add_item(it.get("id", ""), it.get("amount", 1), it)
			if rem > 0:
				var overflow_it = it.duplicate(true)
				overflow_it["amount"] = rem
				var rem_p = player_grid_mgr.auto_add_item(overflow_it.get("id", ""), rem, overflow_it)
				if rem_p > 0 and EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 창고 공간이 부족하여 일부 아이템(%s)을 보관하지 못했습니다!" % overflow_it.get("name", overflow_it.get("id", "")))
			
	if player_grid_control:
		var p_scroll := player_grid_control.get_parent() as ScrollContainer
		player_cell_size = _compute_fit_cell_size(p_scroll, new_w, CELL_SIZE, 56.0)
		player_grid_control.custom_minimum_size = Vector2(new_w * player_cell_size, new_h * player_cell_size)
		player_grid_control.queue_redraw()

func _on_player_grid_draw() -> void:
	_draw_2d_grid(player_grid_control, player_grid_mgr, hovered_player_cell, true)

func _on_stash_grid_draw() -> void:
	_draw_2d_grid(stash_grid_control, stash_grid_mgr, hovered_stash_cell, false)

func _draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool) -> void:
	InventoryUIHelper.draw_2d_grid(ctrl, grid_mgr, hovered_cell, is_player_grid, is_dragging, drag_data, _get_grid_cell_size(ctrl))


# ============================================================
# 그리드 마우스 이벤트 처리
# ============================================================
func _on_player_grid_gui_input(event: InputEvent) -> void:
	_handle_grid_input(event, player_grid_control, player_grid_mgr, true)

func _on_stash_grid_gui_input(event: InputEvent) -> void:
	_handle_grid_input(event, stash_grid_control, stash_grid_mgr, false)

func _handle_grid_input(event: InputEvent, ctrl: Control, grid_mgr: InventoryGrid, is_player_grid: bool) -> void:
	var csz := _get_grid_cell_size(ctrl)
	var m_global: Vector2 = (event as InputEventMouse).global_position if event is InputEventMouse else get_global_mouse_position()
	var local_pos: Vector2 = m_global - ctrl.get_global_rect().position
	var cell_x = int(floor(local_pos.x / csz))
	var cell_y = int(floor(local_pos.y / csz))
	
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
				tooltip.update_position(m_global)
			else:
				tooltip.hide()
		ctrl.queue_redraw()
		
	elif event is InputEventMouseButton and event.pressed:
		_close_context_menu()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item = grid_mgr.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if event.double_click and InventoryGrid.is_container_item(item):
					if is_dragging:
						_end_drag()
					if tooltip: tooltip.hide()
					open_container_popup(item, grid_mgr)
				elif Input.is_key_pressed(KEY_CTRL):
					if tooltip: tooltip.hide()
					_handle_hideout_quick_action(item, is_player_grid, true)
				elif Input.is_key_pressed(KEY_SHIFT) and item.get("amount", 1) > 1:
					_open_split_dialog(item, func(split_amt):
						var split_item = item.duplicate(true)
						split_item["uid"] = InventoryGrid.next_uid()
						split_item["amount"] = split_amt
						item["amount"] -= split_amt
						grid_mgr.grid_changed.emit()
						_start_drag("split", split_item, Vector2i(cell_x, cell_y), "", grid_mgr)
						drag_data["is_split"] = true
						drag_data["split_source_item"] = item
						drag_data["split_source_grid"] = grid_mgr
						drag_data["split_amount"] = split_amt
					)
				else:
					_start_drag("player_grid" if is_player_grid else "stash_grid", item, Vector2i(cell_x, cell_y), "", grid_mgr)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var item = grid_mgr.get_item_at(cell_x, cell_y)
			if not item.is_empty():
				if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
					if tooltip: tooltip.hide()
					_show_context_menu(item, "player_grid" if is_player_grid else "stash_grid", "", grid_mgr)
				else:
					_handle_hideout_quick_action(item, is_player_grid)

func _handle_hideout_quick_action(item: Dictionary, is_from_player: bool, allow_popup_transfer: bool = false) -> void:
	var item_id = item.get("id", "")
	var src_grid = player_grid_mgr if is_from_player else stash_grid_mgr

	# 0. Ctrl+좌클릭 시 열려있는 호환 중첩 컨테이너 팝업으로 빠른 수납 시도
	if allow_popup_transfer and not open_container_popups.is_empty():
		var children := get_children()
		for ci in range(children.size() - 1, -1, -1):
			var p_win := children[ci] as ContainerPopupWindow
			if p_win and is_instance_valid(p_win) and p_win.inner_grid:
				var acc := p_win.inner_grid.can_accept_item(item, item_id)
				if bool(acc.get("ok", false)):
					var amt := maxi(1, int(item.get("amount", 1)))
					var p_rem := p_win.inner_grid.auto_add_item(item_id, amt, item)
					if amt - p_rem > 0:
						if p_rem <= 0:
							src_grid.remove_item_by_uid(str(item.get("uid", "")))
						else:
							item["amount"] = p_rem
							src_grid.grid_changed.emit()
						if SoundManager: SoundManager.play("menu_select")
						return

	var target_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	# 1. 장비 아이템이면 장비 슬롯으로 퀵 장착 시도
	if target_slot != "" and equipment_data.has(target_slot) and equipment_data[target_slot].is_empty():
		if target_slot == "backpack":
			var inner_arr = item.get("inner_items", [])
			if inner_arr is Array and not inner_arr.is_empty():
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
				if SoundManager: SoundManager.play("hit_melee")
				return
		src_grid.remove_item_by_uid(item.get("uid", ""))
		equipment_data[target_slot] = item
		_apply_backpack_grid_size()
		_update_equipment_ui()
		if SoundManager: SoundManager.play("menu_select")
		return
		
	# 2. 배낭 <-> 창고 간 상호 자동 이동 (Auto-Fit)
	var dest_grid = stash_grid_mgr if is_from_player else player_grid_mgr
	
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
	if is_instance_valid(context_menu_panel) and context_menu_panel.is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed:
			if not context_menu_panel.get_global_rect().has_point(get_global_mouse_position()):
				_close_context_menu()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_close_context_menu()
				get_viewport().set_input_as_handled()
				return

	# 검색창(LineEdit) 포커스 중에는 단축키 가로채기 차단 (ESC로 포커스 해제)
	var focus_owner := get_viewport().gui_get_focus_owner() if (is_inside_tree() and get_viewport()) else null
	if focus_owner is LineEdit:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
			focus_owner.release_focus()
			get_viewport().set_input_as_handled()
		return

	# [L] 키 아이템 잠금/해제 & TradersTab [Space] 일괄 판매
	if not is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L or event.physical_keycode == KEY_L:
			if _toggle_lock_at_mouse():
				get_viewport().set_input_as_handled()
				return
		elif (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE) and tab_container and tab_container.current_tab == 1 and (trader_mode_tabs == null or trader_mode_tabs.current_tab == 1):
			if not selected_sell_uids.is_empty():
				_execute_bulk_sell()
				get_viewport().set_input_as_handled()
				return

	# R 키 회전
	if is_dragging and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			drag_data["rotated"] = not drag_data.get("rotated", false)
			_rebuild_drag_preview()
			var m_pos := get_global_mouse_position()
			for p in open_container_popups.values():
				if is_instance_valid(p):
					p.update_drag_hover(m_pos, drag_data.get("item", {}), drag_data.get("rotated", false))
			if SoundManager: SoundManager.play("menu_move")
			if player_grid_control: player_grid_control.queue_redraw()
			if stash_grid_control: stash_grid_control.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	if is_dragging and event is InputEventMouseMotion:
		var m_pos = event.global_position
		_update_drag_preview_pos()
		for p in open_container_popups.values():
			if is_instance_valid(p):
				p.update_drag_hover(m_pos, drag_data.get("item", {}), drag_data.get("rotated", false))
			
		if player_grid_control:
			hovered_player_cell = InventoryUIHelper.calc_drag_drop_cell(player_grid_control, m_pos, player_grid_mgr, drag_data, player_cell_size)
			player_grid_control.queue_redraw()
		if stash_grid_control:
			hovered_stash_cell = InventoryUIHelper.calc_drag_drop_cell(stash_grid_control, m_pos, stash_grid_mgr, drag_data, stash_cell_size)
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
		_handle_hideout_global_drop(event.global_position)
		get_viewport().set_input_as_handled()

func _start_drag(src_name: String, item_dict: Dictionary, cell_pos: Vector2i, slot_key: String = "", source_grid: InventoryGrid = null) -> void:
	is_dragging = true
	var base_size = ItemDatabase.get_item_grid_size(item_dict.get("id", ""))
	if not item_dict.has("w"):
		item_dict["w"] = base_size.x
	if not item_dict.has("h"):
		item_dict["h"] = base_size.y
	var resolved_grid: InventoryGrid = source_grid
	if resolved_grid == null:
		if src_name == "player_grid": resolved_grid = player_grid_mgr
		elif src_name == "stash_grid": resolved_grid = stash_grid_mgr
	drag_data = {
		"source": src_name,
		"item": item_dict,
		"cell": cell_pos,
		"slot_name": slot_key,
		"rotated": item_dict.get("rotated", false),
		"orig_rotated": item_dict.get("rotated", false),
		"start_mouse_pos": get_global_mouse_position(),
		"source_grid": resolved_grid
	}
	
	if tooltip: tooltip.hide()
	_rebuild_drag_preview()
	_highlight_compatible_slots(item_dict, null)

func _rebuild_drag_preview() -> void:
	if drag_preview_node:
		drag_preview_node.queue_free()
		drag_preview_node = null
	var item_dict: Dictionary = drag_data.get("item", {})
	if item_dict.is_empty():
		return
	var src_grid = drag_data.get("source_grid")
	if src_grid == player_grid_mgr:
		_drag_preview_cell_size = player_cell_size
	elif src_grid == stash_grid_mgr:
		_drag_preview_cell_size = stash_cell_size
	else:
		_drag_preview_cell_size = CELL_SIZE
	drag_preview_node = InventoryUIHelper.build_drag_preview(item_dict, bool(drag_data.get("rotated", false)), _drag_preview_cell_size)
	add_child(drag_preview_node)
	_update_drag_preview_pos()

func _update_drag_preview_pos() -> void:
	if not drag_preview_node or not is_dragging or not is_inside_tree():
		return
	var item_dict: Dictionary = drag_data.get("item", {})
	var is_rot := bool(drag_data.get("rotated", false))
	var base_size := ItemDatabase.get_item_grid_size(str(item_dict.get("id", "")))
	var cur_w := int(item_dict.get("h", base_size.y)) if is_rot else int(item_dict.get("w", base_size.x))
	var cur_h := int(item_dict.get("w", base_size.x)) if is_rot else int(item_dict.get("h", base_size.y))
	var center_offset := Vector2(float(cur_w) * _drag_preview_cell_size * 0.5, float(cur_h) * _drag_preview_cell_size * 0.5)
	drag_preview_node.global_position = get_global_mouse_position() - center_offset

func _end_drag() -> void:
	if is_dragging and drag_data.get("is_split", false):
		var orig = drag_data.get("split_source_item", {})
		var split_amt = int(drag_data.get("split_amount", 0))
		if not orig.is_empty() and split_amt > 0:
			orig["amount"] = int(orig.get("amount", 0)) + split_amt
			var sp_grid: InventoryGrid = drag_data.get("split_source_grid") as InventoryGrid
			if sp_grid: sp_grid.grid_changed.emit()
		drag_data["is_split"] = false
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
	for p in open_container_popups.values():
		if is_instance_valid(p) and p.grid_control:
			p.hovered_cell = Vector2i(-1, -1)
			p.grid_control.queue_redraw()

func _highlight_compatible_slots(item: Dictionary, hovered_ctrl: Control = null) -> void:
	InventoryUIHelper.highlight_compatible_slots(drop_targets, item, hovered_ctrl)

func _clear_slot_highlights() -> void:
	InventoryUIHelper.clear_slot_highlights(drop_targets)

func _handle_hideout_global_drop(drop_pos: Vector2 = Vector2.INF) -> void:
	if not is_dragging: return
	
	var m_pos = drop_pos if drop_pos != Vector2.INF else get_global_mouse_position()
	if drop_pos == Vector2.INF and drag_data.has("start_mouse_pos"):
		pass
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
	
	# 1. 플레이어 배낭 2D 그리드 위인지 검사
	if player_grid_control.get_global_rect().has_point(m_pos):
		var p_cell := InventoryUIHelper.calc_drag_drop_cell(player_grid_control, m_pos, player_grid_mgr, drag_data, player_cell_size)
		_try_drop_on_hideout_grid(player_grid_mgr, p_cell.x, p_cell.y, true)
		return
		
	# 2. 은신처 창고 2D 그리드 위인지 검사
	if stash_grid_control.get_global_rect().has_point(m_pos):
		var s_cell := InventoryUIHelper.calc_drag_drop_cell(stash_grid_control, m_pos, stash_grid_mgr, drag_data, stash_cell_size)
		_try_drop_on_hideout_grid(stash_grid_mgr, s_cell.x, s_cell.y, false)
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
	
	if dest_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item.get("id", ""), item):
		if src == "player_grid" and is_dest_player:
			player_grid_mgr.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
		elif src == "stash_grid" and not is_dest_player:
			stash_grid_mgr.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
		else:
			if dest_grid.place_item(item, cell_x, cell_y, is_rot):
				if src == "split":
					drag_data["is_split"] = false
				elif src == "player_grid":
					player_grid_mgr.remove_item_by_uid(uid)
				elif src == "stash_grid":
					stash_grid_mgr.remove_item_by_uid(uid)
				elif src == "popup_grid":
					var p_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
					if p_grid: p_grid.remove_item_by_uid(uid)
				elif src == "equipment":
					equipment_data[drag_data.get("slot_name", "")] = {}
					_apply_backpack_grid_size()
					_update_equipment_ui()
				if SoundManager: SoundManager.play("menu_select")
			else:
				if SoundManager: SoundManager.play("hit_melee")
	else:
		# 배치 불가 사유 안내 (중첩 제한 & 2x2 세이프 파우치 구역)
		var accept := dest_grid.can_accept_item(item, str(item.get("id", "")))
		if not bool(accept.get("ok", true)):
			_log_container_reject_reason(str(accept.get("reason", "")))
		elif dest_grid.has_secure_container and cell_x < 2 and cell_y < 2:
			if not dest_grid.is_allowed_in_secure_container(item.get("id", "")):
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🔒 [보안 컨테이너] 무기, 방어구 및 리시버는 세이프 파우치에 보관할 수 없습니다.")
			elif cell_x + place_w > 2 or cell_y + place_h > 2:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🔒 [보안 컨테이너] 2x2 안전 파우치 경계를 벗어나는 크기의 아이템입니다.")
			else:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 해당 슬롯에 이미 다른 아이템이 있습니다.")
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
				_close_context_menu()
				if event.button_index == MOUSE_BUTTON_LEFT:
					if is_dragging:
						_try_equip_hideout_item(captured_slot)
					else:
						var equipped = equipment_data.get(captured_slot, {})
						if event.double_click and captured_slot == "vest" and not equipped.is_empty():
							if tooltip: tooltip.hide()
							open_container_popup(equipped, null)
						elif not equipped.is_empty():
							if tooltip: tooltip.hide()
							_start_drag("equipment", equipped, Vector2i.ZERO, captured_slot)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					var equipped = equipment_data.get(captured_slot, {})
					if not equipped.is_empty():
						if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
							if tooltip: tooltip.hide()
							_show_context_menu(equipped, "equipment", captured_slot, null)
						else:
							# 우클릭 시 창고로 탈착
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

	if slot_name == "backpack":
		var inner_arr = item.get("inner_items", [])
		if inner_arr is Array and not inner_arr.is_empty():
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
			if SoundManager: SoundManager.play("hit_melee")
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
	elif src == "popup_grid":
		var p_grid: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
		if p_grid: p_grid.remove_item_by_uid(item.get("uid", ""))
	elif src == "equipment":
		equipment_data[orig_slot] = {}
		
	var prev_equipped = equipment_data.get(slot_name, {})
	equipment_data[slot_name] = item
	
	_apply_backpack_grid_size()
	if not prev_equipped.is_empty():
		var rem = stash_grid_mgr.auto_add_item(prev_equipped.get("id", ""), prev_equipped.get("amount", 1), prev_equipped)
		if rem > 0:
			var overflow_eq = prev_equipped.duplicate(true)
			overflow_eq["amount"] = rem
			var rem_p = player_grid_mgr.auto_add_item(overflow_eq.get("id", ""), rem, overflow_eq)
			if rem_p > 0:
				equipment_data[slot_name] = prev_equipped
				_apply_backpack_grid_size()
				var restore_rem = item.get("amount", 1)
				if src == "popup_grid":
					var p_grid_back: InventoryGrid = drag_data.get("source_grid") as InventoryGrid
					if p_grid_back:
						restore_rem = p_grid_back.auto_add_item(item.get("id", ""), restore_rem, item)
				if restore_rem > 0:
					restore_rem = stash_grid_mgr.auto_add_item(item.get("id", ""), restore_rem, item)
				if restore_rem > 0:
					player_grid_mgr.auto_add_item(item.get("id", ""), restore_rem, item)
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("⚠️ 창고와 가방 공간이 부족하여 장비를 교체할 수 없습니다.")
				_update_equipment_ui()
				_end_drag()
				return
		
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
	if is_instance_valid(character_paperdoll_preview):
		character_paperdoll_preview.update_equipment(equipment_data)

func _render_equip_slot_button(btn: Button, slot_name: String, default_text: String) -> void:
	InventoryUIHelper.render_equip_slot_button(btn, slot_name, default_text, equipment_data)

func _open_split_dialog(item: Dictionary, on_confirm_callback: Callable) -> void:
	var dialog = SplitDialogScene.instantiate()
	add_child(dialog)
	dialog.setup(int(item.get("amount", 1)))
	dialog.split_confirmed.connect(on_confirm_callback)
	_refresh_stash_ui()

# ============================================================
# 상인 거래소 & 3단 일괄 판매 UI 로직
# ============================================================
func _setup_traders_bulk_ui() -> void:
	var t_vbox := get_node_or_null("CenterArea/TabContainer/TradersTab/VBox") as VBoxContainer
	if not t_vbox:
		return

	# 상인 헤더 하단에 우호도(Loyalty Level) 정보 바 추가
	var loyalty_panel := PanelContainer.new()
	loyalty_panel.name = "TraderLoyaltyPanel"
	loyalty_panel.theme_type_variation = &"HeaderPanel"
	var l_hbox := HBoxContainer.new()
	l_hbox.add_theme_constant_override("separation", 14)
	loyalty_panel.add_child(l_hbox)

	trader_loyalty_label = Label.new()
	trader_loyalty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trader_loyalty_label.clip_text = true
	trader_loyalty_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trader_loyalty_label.add_theme_font_size_override("font_size", 12)
	trader_loyalty_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.38))
	l_hbox.add_child(trader_loyalty_label)

	trader_loyalty_bar = ProgressBar.new()
	trader_loyalty_bar.custom_minimum_size = Vector2(210, 16)
	trader_loyalty_bar.show_percentage = true
	l_hbox.add_child(trader_loyalty_bar)

	t_vbox.add_child(loyalty_panel)
	t_vbox.move_child(loyalty_panel, 2)

	# 기존 스크롤(상점)과 판매 영역을 구매/판매 서브 탭으로 분리 (기존 @onready 참조 유지)
	var old_shop_scroll := t_vbox.get_node_or_null("Scroll") as Control
	var old_sell_area := t_vbox.get_node_or_null("SellArea") as Control
	if old_sell_area:
		old_sell_area.hide()

	trader_mode_tabs = TabContainer.new()
	trader_mode_tabs.name = "TraderModeTabs"
	trader_mode_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trader_mode_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trader_mode_tabs.tab_changed.connect(func(_t: int): call_deferred("_update_all_hideout_grid_sizes"))
	t_vbox.add_child(trader_mode_tabs)

	# [서브 탭 0] 상인 공급 품목 구매
	var buy_tab := VBoxContainer.new()
	buy_tab.name = "🛒 물품 구매"
	buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_tab.add_theme_constant_override("separation", 6)
	trader_mode_tabs.add_child(buy_tab)

	var shop_hdr := Label.new()
	shop_hdr.text = "🛒 상인 공급 품목 (안정 공급 · 등급별 해금)"
	shop_hdr.add_theme_font_size_override("font_size", 12)
	shop_hdr.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	buy_tab.add_child(shop_hdr)

	if old_shop_scroll:
		t_vbox.remove_child(old_shop_scroll)
		old_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		old_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if old_shop_scroll is ScrollContainer:
			(old_shop_scroll as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if trader_items_vbox:
			trader_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_tab.add_child(old_shop_scroll)

	# [서브 탭 1] 아이템 일괄 판매 (2D 다중 선택 + 영수증 정산)
	var sell_tab := HBoxContainer.new()
	sell_tab.name = "💰 아이템 판매"
	sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_tab.add_theme_constant_override("separation", 12)
	trader_mode_tabs.add_child(sell_tab)

	# [판매 좌측 컬럼] 자동 담기 토글 + 배낭/창고 2D 다중 선택 & Marquee 드래그 영역
	var center_col := VBoxContainer.new()
	center_col.name = "BulkSelectCol"
	center_col.custom_minimum_size = Vector2(360, 0)
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.size_flags_stretch_ratio = 1.25
	center_col.add_theme_constant_override("separation", 6)
	sell_tab.add_child(center_col)

	var btn_bar := HBoxContainer.new()
	btn_bar.add_theme_constant_override("separation", 6)
	center_col.add_child(btn_bar)

	trader_btn_valuables = Button.new()
	trader_btn_valuables.theme_type_variation = &"SmallButton"
	trader_btn_valuables.text = "🧹 환금템 모두 담기"
	trader_btn_valuables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trader_btn_valuables.add_theme_font_size_override("font_size", 11)
	trader_btn_valuables.pressed.connect(func(): _auto_select_bulk_sell("valuables"))
	btn_bar.add_child(trader_btn_valuables)

	trader_btn_non_gear = Button.new()
	trader_btn_non_gear.theme_type_variation = &"SmallButton"
	trader_btn_non_gear.text = "📦 장비/무기 제외 모두 담기"
	trader_btn_non_gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trader_btn_non_gear.add_theme_font_size_override("font_size", 11)
	trader_btn_non_gear.pressed.connect(func(): _auto_select_bulk_sell("non_gear"))
	btn_bar.add_child(trader_btn_non_gear)

	var btn_clear := Button.new()
	btn_clear.theme_type_variation = &"DangerButton"
	btn_clear.text = "✖ 해제"
	btn_clear.custom_minimum_size = Vector2(64, 0)
	btn_clear.add_theme_font_size_override("font_size", 11)
	btn_clear.pressed.connect(func():
		selected_sell_uids.clear()
		_refresh_trader_sell_ui()
	)
	btn_bar.add_child(btn_clear)

	sell_grid_header_lbl = Label.new()
	sell_grid_header_lbl.text = "💡 Alt+좌클릭 / 우클릭: 담기 토글 | 빈 공간 드래그: 범위(Marquee) 선택 | [L]: 잠금"
	sell_grid_header_lbl.add_theme_font_size_override("font_size", 10)
	sell_grid_header_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	center_col.add_child(sell_grid_header_lbl)

	sell_grids_scroll = ScrollContainer.new()
	sell_grids_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_grids_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_grids_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sell_grids_scroll.resized.connect(_update_all_hideout_grid_sizes)
	center_col.add_child(sell_grids_scroll)

	var grids_vbox := VBoxContainer.new()
	grids_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_vbox.add_theme_constant_override("separation", 8)
	sell_grids_scroll.add_child(grids_vbox)

	var p_hdr := Label.new()
	p_hdr.text = "🎒 내 배낭 (좌상단 2x2 SECURE & 🔒잠금 자동 보호)"
	p_hdr.add_theme_font_size_override("font_size", 11)
	p_hdr.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35))
	grids_vbox.add_child(p_hdr)

	var p_panel := PanelContainer.new()
	p_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(p_panel)

	sell_player_grid_ctrl = Control.new()
	sell_player_grid_ctrl.name = "SellPlayerGridControl"
	sell_player_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_player_grid_ctrl.draw.connect(func():
		if sell_player_grid_ctrl and player_grid_mgr:
			InventoryUIHelper.draw_2d_grid(sell_player_grid_ctrl, player_grid_mgr, hovered_sell_player_cell, true, false, {}, sell_player_cell_size)
	)
	sell_player_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		_handle_sell_grid_input(ev, sell_player_grid_ctrl, player_grid_mgr, false)
	)
	sell_player_grid_ctrl.mouse_exited.connect(func():
		hovered_sell_player_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if sell_player_grid_ctrl: sell_player_grid_ctrl.queue_redraw()
	)
	p_panel.add_child(sell_player_grid_ctrl)

	var s_hdr := Label.new()
	s_hdr.text = "📦 은신처 창고 (🔒잠금 아이템 제외)"
	s_hdr.add_theme_font_size_override("font_size", 11)
	s_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	grids_vbox.add_child(s_hdr)

	var s_panel := PanelContainer.new()
	s_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(s_panel)

	sell_stash_grid_ctrl = Control.new()
	sell_stash_grid_ctrl.name = "SellStashGridControl"
	sell_stash_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_stash_grid_ctrl.draw.connect(func():
		if sell_stash_grid_ctrl and stash_grid_mgr:
			InventoryUIHelper.draw_2d_grid(sell_stash_grid_ctrl, stash_grid_mgr, hovered_sell_stash_cell, false, false, {}, sell_stash_cell_size)
	)
	sell_stash_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		_handle_sell_grid_input(ev, sell_stash_grid_ctrl, stash_grid_mgr, true)
	)
	sell_stash_grid_ctrl.mouse_exited.connect(func():
		hovered_sell_stash_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if sell_stash_grid_ctrl: sell_stash_grid_ctrl.queue_redraw()
	)
	s_panel.add_child(sell_stash_grid_ctrl)

	# [판매 우측 컬럼] 판매 트레이 영수증 & 일괄 정산 패널
	var right_panel := PanelContainer.new()
	right_panel.name = "ReceiptCol"
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.85
	if PixelAssetManager:
		var r_sb := PixelAssetManager.get_pixel_stylebox("receipt_panel", 8.0, 8.0, 8.0, 8.0, 4)
		if r_sb != null:
			right_panel.add_theme_stylebox_override("panel", r_sb)
	sell_tab.add_child(right_panel)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(r_vbox)

	var r_title := Label.new()
	r_title.text = "🧾 일괄 판매 정산 영수증"
	if PixelAssetManager:
		r_title.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	r_title.add_theme_font_size_override("font_size", 12)
	r_title.add_theme_color_override("font_color", Color(0.38, 0.98, 0.72))
	r_vbox.add_child(r_title)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_vbox.add_child(r_scroll)

	sell_receipt_list_vbox = VBoxContainer.new()
	sell_receipt_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_receipt_list_vbox.add_theme_constant_override("separation", 4)
	r_scroll.add_child(sell_receipt_list_vbox)

	sell_receipt_summary_lbl = Label.new()
	sell_receipt_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_receipt_summary_lbl.add_theme_font_size_override("font_size", 12)
	sell_receipt_summary_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	r_vbox.add_child(sell_receipt_summary_lbl)

	sell_bulk_btn = Button.new()
	sell_bulk_btn.theme_type_variation = &"PrimaryButton"
	sell_bulk_btn.custom_minimum_size = Vector2(0, 38)
	sell_bulk_btn.text = "💰 일괄 판매 정산 (Space)"
	sell_bulk_btn.pressed.connect(_execute_bulk_sell)
	r_vbox.add_child(sell_bulk_btn)

func _setup_market_controls() -> void:
	var m_vbox := get_node_or_null("CenterArea/TabContainer/MarketTab/VBox") as VBoxContainer
	if not m_vbox:
		return
	var old_market_scroll := m_vbox.get_node_or_null("Scroll") as Control
	var old_reg_area := m_vbox.get_node_or_null("RegisterArea") as Control
	if old_reg_area:
		old_reg_area.hide()

	var market_main_hbox := HBoxContainer.new()
	market_main_hbox.name = "MarketMainHBox"
	market_main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_main_hbox.add_theme_constant_override("separation", 12)
	m_vbox.add_child(market_main_hbox)

	# [좌측 컬럼] 긴급 수배 및 암시장 매물 목록
	var listings_col := VBoxContainer.new()
	listings_col.name = "MarketListingsCol"
	listings_col.custom_minimum_size = Vector2(540, 0)
	listings_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listings_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listings_col.size_flags_stretch_ratio = 1.05
	listings_col.add_theme_constant_override("separation", 6)
	market_main_hbox.add_child(listings_col)

	var listings_hdr := Label.new()
	listings_hdr.text = "🏪 오늘의 2.5x 긴급 수배 & 암시장 매물"
	listings_hdr.add_theme_font_size_override("font_size", 12)
	listings_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	listings_col.add_child(listings_hdr)

	if old_market_scroll:
		m_vbox.remove_child(old_market_scroll)
		old_market_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		old_market_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		listings_col.add_child(old_market_scroll)

	# [우측 컬럼] 검색/필터 + 배낭·창고 2D 그리드 + 선택 등록 확인 패널
	var reg_col := VBoxContainer.new()
	reg_col.name = "MarketRegisterCol"
	reg_col.custom_minimum_size = Vector2(460, 0)
	reg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reg_col.size_flags_stretch_ratio = 1.0
	reg_col.add_theme_constant_override("separation", 6)
	market_main_hbox.add_child(reg_col)

	market_slot_label = Label.new()
	market_slot_label.add_theme_font_size_override("font_size", 12)
	market_slot_label.add_theme_color_override("font_color", Color(0.45, 0.90, 1.0))
	reg_col.add_child(market_slot_label)

	# 1. 이름 검색창 + 초기화 + 매칭 개수 표시
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	reg_col.add_child(search_row)

	market_search_input = LineEdit.new()
	market_search_input.name = "MarketSearchInput"
	market_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_search_input.placeholder_text = "🔍 아이템 이름 검색 (예: 그래픽카드, 열쇠, SSD...)"
	market_search_input.clear_button_enabled = true
	market_search_input.text_changed.connect(func(new_txt: String):
		market_search_text = new_txt.strip_edges()
		_refresh_market_register_ui()
	)
	search_row.add_child(market_search_input)

	var clr_btn := Button.new()
	clr_btn.theme_type_variation = &"SmallButton"
	clr_btn.text = "초기화"
	clr_btn.custom_minimum_size = Vector2(56, 0)
	clr_btn.focus_mode = Control.FOCUS_NONE
	clr_btn.pressed.connect(func():
		market_search_text = ""
		market_filter_category = "all"
		if market_search_input:
			market_search_input.text = ""
		_refresh_market_register_ui()
	)
	search_row.add_child(clr_btn)

	market_result_count_lbl = Label.new()
	market_result_count_lbl.add_theme_font_size_override("font_size", 11)
	market_result_count_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	search_row.add_child(market_result_count_lbl)

	# 2. 카테고리 필터 버튼
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 4)
	reg_col.add_child(cat_row)

	market_filter_buttons.clear()
	var cat_defs := [
		["all", "전체"],
		["valuables", "고가/잡화"],
		["combat", "무기/부품/방어"],
		["medical_supply", "의료/식량"],
		["key_case", "열쇠/케이스"]
	]
	for c_def in cat_defs:
		var cid := str(c_def[0])
		var cname := str(c_def[1])
		var f_btn := Button.new()
		f_btn.theme_type_variation = &"SmallButton"
		f_btn.text = cname
		f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_btn.add_theme_font_size_override("font_size", 10)
		f_btn.focus_mode = Control.FOCUS_NONE
		var cap_cid := cid
		f_btn.pressed.connect(func():
			market_filter_category = cap_cid
			_refresh_market_register_ui()
		)
		cat_row.add_child(f_btn)
		market_filter_buttons[cid] = f_btn

	# 3. 등록 가격 배율 프리셋
	var ratio_row := HBoxContainer.new()
	ratio_row.add_theme_constant_override("separation", 6)
	reg_col.add_child(ratio_row)

	var ratio_lbl := Label.new()
	ratio_lbl.text = "등록 가격 배율:"
	ratio_lbl.add_theme_font_size_override("font_size", 11)
	ratio_row.add_child(ratio_lbl)

	market_ratio_buttons.clear()
	for r_val in [0.9, 1.0, 1.2, 1.5, 2.0]:
		var r_btn := Button.new()
		r_btn.theme_type_variation = &"SmallButton"
		r_btn.text = "x%.1f" % r_val
		r_btn.custom_minimum_size = Vector2(46, 24)
		r_btn.add_theme_font_size_override("font_size", 10)
		r_btn.focus_mode = Control.FOCUS_NONE
		var cap_r: float = r_val
		r_btn.pressed.connect(func():
			market_price_ratio = cap_r
			_refresh_market_register_ui()
		)
		ratio_row.add_child(r_btn)
		market_ratio_buttons[str(r_val)] = r_btn

	# 4. 배낭 & 창고 2D 그리드
	var grids_scroll := ScrollContainer.new()
	grids_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reg_col.add_child(grids_scroll)

	var grids_vbox := VBoxContainer.new()
	grids_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_vbox.add_theme_constant_override("separation", 8)
	grids_scroll.add_child(grids_vbox)

	var mp_hdr := Label.new()
	mp_hdr.text = "🎒 내 배낭 (클릭: 선택 | 더블클릭·Ctrl+클릭: 즉시 등록 | [L]: 잠금)"
	mp_hdr.add_theme_font_size_override("font_size", 11)
	mp_hdr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.36))
	grids_vbox.add_child(mp_hdr)

	var mp_panel := PanelContainer.new()
	mp_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(mp_panel)

	market_player_grid_ctrl = Control.new()
	market_player_grid_ctrl.name = "MarketPlayerGridControl"
	market_player_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	market_player_grid_ctrl.draw.connect(func():
		if market_player_grid_ctrl and player_grid_mgr:
			InventoryUIHelper.draw_2d_grid(market_player_grid_ctrl, player_grid_mgr, hovered_market_player_cell, true, false, {}, CELL_SIZE)
	)
	market_player_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		_handle_market_grid_input(ev, market_player_grid_ctrl, player_grid_mgr, false)
	)
	market_player_grid_ctrl.mouse_exited.connect(func():
		hovered_market_player_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if market_player_grid_ctrl: market_player_grid_ctrl.queue_redraw()
	)
	mp_panel.add_child(market_player_grid_ctrl)

	var ms_hdr := Label.new()
	ms_hdr.text = "📦 은신처 창고 (검색/필터 미일치 및 등록 불가 품목은 어둡게 표시됨)"
	ms_hdr.add_theme_font_size_override("font_size", 11)
	ms_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	grids_vbox.add_child(ms_hdr)

	var ms_panel := PanelContainer.new()
	ms_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(ms_panel)

	market_stash_grid_ctrl = Control.new()
	market_stash_grid_ctrl.name = "MarketStashGridControl"
	market_stash_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	market_stash_grid_ctrl.draw.connect(func():
		if market_stash_grid_ctrl and stash_grid_mgr:
			InventoryUIHelper.draw_2d_grid(market_stash_grid_ctrl, stash_grid_mgr, hovered_market_stash_cell, false, false, {}, CELL_SIZE)
	)
	market_stash_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		_handle_market_grid_input(ev, market_stash_grid_ctrl, stash_grid_mgr, true)
	)
	market_stash_grid_ctrl.mouse_exited.connect(func():
		hovered_market_stash_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if market_stash_grid_ctrl: market_stash_grid_ctrl.queue_redraw()
	)
	ms_panel.add_child(market_stash_grid_ctrl)

	# 5. 하단 선택 아이템 등록 확인 패널
	var confirm_panel := PanelContainer.new()
	confirm_panel.name = "MarketConfirmPanel"
	if PixelAssetManager:
		var c_sb := PixelAssetManager.get_pixel_stylebox("market_confirm_panel", 8.0, 6.0, 8.0, 6.0, 4)
		if c_sb != null:
			confirm_panel.add_theme_stylebox_override("panel", c_sb)
	reg_col.add_child(confirm_panel)

	var c_hbox := HBoxContainer.new()
	c_hbox.add_theme_constant_override("separation", 10)
	confirm_panel.add_child(c_hbox)

	market_preview_lbl = Label.new()
	market_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_preview_lbl.add_theme_font_size_override("font_size", 11)
	market_preview_lbl.text = "💡 2D 그리드에서 암시장에 등록할 아이템을 클릭하세요."
	c_hbox.add_child(market_preview_lbl)

	market_confirm_btn = Button.new()
	market_confirm_btn.theme_type_variation = &"PrimaryButton"
	market_confirm_btn.custom_minimum_size = Vector2(148, 36)
	market_confirm_btn.text = "📈 암시장 등록"
	market_confirm_btn.disabled = true
	market_confirm_btn.focus_mode = Control.FOCUS_NONE
	market_confirm_btn.pressed.connect(_try_register_selected_market_item)
	c_hbox.add_child(market_confirm_btn)

func _select_trader(trader_id: String) -> void:
	current_trader_id = trader_id
	_refresh_trader_ui()

func _refresh_trader_ui() -> void:
	var t_data = ItemDatabase.traders.get(current_trader_id, {})
	if t_data.is_empty(): return
	
	trader_desc_label.text = "[%s] %s" % [t_data["name"], t_data["desc"]]

	var w_data := GameManager.current_world_data if GameManager else {}
	if trader_loyalty_label and trader_loyalty_bar:
		var l_info := HideoutProgression.get_trader_loyalty_info(w_data, current_trader_id)
		var cur_lv := int(l_info.get("level", 1))
		var q_cnt := int(l_info.get("quests", 0))
		var spent := int(l_info.get("spent", 0))
		var spec_hint := "잡화/기타 매입 55%"
		if current_trader_id == "therapist":
			spec_hint = "특화 매입: 의료·식량·식수 75% (기타 50%)"
		elif current_trader_id == "prapor":
			spec_hint = "특화 매입: 무기·탄약·장비·부품 70% (기타 48%)"
		if cur_lv >= 4:
			trader_loyalty_label.text = "⭐ 우호도 Lv.4 (최고 등급)  |  완료 의뢰 %d건  |  누적 거래 %d RUB  |  %s" % [q_cnt, spent, spec_hint]
			trader_loyalty_bar.max_value = 100.0
			trader_loyalty_bar.value = 100.0
		else:
			var nq := int(l_info.get("next_quests", 1))
			var ns := maxi(1, int(l_info.get("next_spent", 15000)))
			trader_loyalty_label.text = "⭐ 우호도 Lv.%d ➔ 다음 Lv.%d (의뢰 %d/%d건 · 누적 거래 %d/%d RUB)  |  %s" % [cur_lv, cur_lv + 1, q_cnt, nq, spent, ns, spec_hint]
			trader_loyalty_bar.max_value = float(ns)
			trader_loyalty_bar.value = float(mini(spent, ns))
		trader_loyalty_label.tooltip_text = trader_loyalty_label.text
	
	# 상품 목록 생성
	for child in trader_items_vbox.get_children():
		child.queue_free()
		
	var user_rubles = int(w_data.get("player", {}).get("rubles", 0))
	var discount = HideoutProgression.get_trader_discount(w_data) if GameManager else 0.0
	
	for stock_item in t_data.get("stock", []):
		var item_id = stock_item["id"]
		var price = max(1, int(stock_item["price"] * (1.0 - discount)))
		var amount = int(stock_item.get("amount", 1))
		var req_lv := maxi(1, int(stock_item.get("min_level", 1)))
		var is_unlocked := HideoutProgression.is_trader_item_unlocked(w_data, current_trader_id, stock_item)
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)
		panel.add_child(hbox)
		
		# 아이템 아이콘
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(30, 30)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			if not is_unlocked:
				icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.75)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		var lv_tag := "[Lv.%d] " % req_lv if req_lv > 1 else ""
		name_lbl.text = "%s%s (x%d)" % [lv_tag, item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(0, 0)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.tooltip_text = name_lbl.text
		name_lbl.add_theme_font_size_override("font_size", 12)
		if not is_unlocked:
			name_lbl.add_theme_color_override("font_color", Color(0.58, 0.62, 0.68))
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % price
		price_lbl.add_theme_font_size_override("font_size", 12)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_unlocked else Color(0.6, 0.55, 0.45))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.theme_type_variation = &"SmallButton"
		buy_btn.text = ("구매" if is_unlocked else "🔒 Lv.%d" % req_lv)
		buy_btn.custom_minimum_size = Vector2(68, 30)
		buy_btn.disabled = (not is_unlocked) or (user_rubles < price)
		if not is_unlocked:
			buy_btn.tooltip_text = "우호도 Lv.%d 달성 시 해금됩니다." % req_lv
		buy_btn.pressed.connect(func(): _buy_item(item_id, amount, price))
		hbox.add_child(buy_btn)
		
		trader_items_vbox.add_child(panel)
		
	_refresh_trader_sell_ui()

func _refresh_trader_sell_ui() -> void:
	# 1. 선택 목록에서 더 이상 존재하지 않거나 보호(잠금/2x2 안전) 대상이 된 아이템 정리
	var to_erase: Array[String] = []
	for uid_key in selected_sell_uids.keys():
		var uid_s := str(uid_key)
		var entry: Dictionary = selected_sell_uids[uid_key]
		var src_grid: InventoryGrid = player_grid_mgr
		if bool(entry.get("is_stash", false)):
			src_grid = stash_grid_mgr
		var it := src_grid.get_item_by_uid(uid_s) if src_grid else {}
		if it.is_empty() or bool(it.get("locked", false)) or (src_grid and src_grid.is_item_in_secure_zone(it)):
			to_erase.append(uid_s)
	for ek in to_erase:
		selected_sell_uids.erase(ek)

	# 2. 2D 선택 그리드 크기 및 하이라이트 메타 동기화
	if sell_player_grid_ctrl and player_grid_mgr:
		sell_player_cell_size = _compute_fit_cell_size(sell_grids_scroll, player_grid_mgr.grid_width, CELL_SIZE, 54.0)
		sell_player_grid_ctrl.custom_minimum_size = Vector2(float(player_grid_mgr.grid_width) * sell_player_cell_size, float(player_grid_mgr.grid_height) * sell_player_cell_size)
		sell_player_grid_ctrl.set_meta("selected_sell_uids", selected_sell_uids)
		sell_player_grid_ctrl.queue_redraw()
	if sell_stash_grid_ctrl and stash_grid_mgr:
		sell_stash_cell_size = _compute_fit_cell_size(sell_grids_scroll, stash_grid_mgr.grid_width, CELL_SIZE, 54.0)
		sell_stash_grid_ctrl.custom_minimum_size = Vector2(float(stash_grid_mgr.grid_width) * sell_stash_cell_size, float(stash_grid_mgr.grid_height) * sell_stash_cell_size)
		sell_stash_grid_ctrl.set_meta("selected_sell_uids", selected_sell_uids)
		sell_stash_grid_ctrl.queue_redraw()

	_update_bulk_sell_toggle_buttons()
	_refresh_sell_receipt_panel()

func _are_all_bulk_candidates_selected(cands: Array) -> bool:
	if cands.is_empty():
		return false
	for c in cands:
		var uid := str(c.get("uid", ""))
		if uid != "" and not selected_sell_uids.has(uid):
			return false
	return true

func _update_bulk_sell_toggle_buttons() -> void:
	if trader_btn_valuables:
		var v_cands := HideoutProgression.collect_bulk_sell_candidates("valuables", player_grid_mgr, stash_grid_mgr)
		var v_all := _are_all_bulk_candidates_selected(v_cands)
		trader_btn_valuables.text = "✓ 환금템 모두 해제" if v_all else "🧹 환금템 모두 담기"
		trader_btn_valuables.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72) if v_all else Color(0.92, 0.94, 0.96))
	if trader_btn_non_gear:
		var ng_cands := HideoutProgression.collect_bulk_sell_candidates("non_gear", player_grid_mgr, stash_grid_mgr)
		var ng_all := _are_all_bulk_candidates_selected(ng_cands)
		trader_btn_non_gear.text = "✓ 장비/무기 제외 해제" if ng_all else "📦 장비/무기 제외 모두 담기"
		trader_btn_non_gear.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72) if ng_all else Color(0.92, 0.94, 0.96))

func _refresh_sell_receipt_panel() -> void:
	if not sell_receipt_list_vbox or not sell_receipt_summary_lbl or not sell_bulk_btn:
		return
	for ch in sell_receipt_list_vbox.get_children():
		ch.queue_free()

	var w_data := GameManager.current_world_data if GameManager else {}
	var preview := HideoutProgression.preview_bulk_sell_receipt(current_trader_id, selected_sell_uids.values(), w_data, player_grid_mgr, stash_grid_mgr)
	var line_items: Array = preview.get("line_items", [])

	if line_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "판매 트레이가 비어 있습니다.\n\n좌측 배낭/창고 그리드에서\nAlt+좌클릭 / 우클릭 또는 드래그로\n아이템을 담아 주세요."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
		sell_receipt_list_vbox.add_child(empty_lbl)
	else:
		for ln in line_items:
			var it_id := str(ln.get("id", ""))
			var idata := ItemDatabase.get_item_data(it_id)
			var disp_name := str(idata.get("name", it_id))
			var amt := int(ln.get("amount", 1))
			var fin := int(ln.get("final_total", 0))
			var drop_amt := int(ln.get("drop_amount", 0))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var name_l := Label.new()
			name_l.text = "%s%s" % [disp_name, (" x%d" % amt if amt > 1 else "")]
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.clip_text = true
			name_l.add_theme_font_size_override("font_size", 11)
			row.add_child(name_l)

			var price_l := Label.new()
			price_l.text = "+%d RUB" % fin if drop_amt <= 0 else "+%d (-%d)" % [fin, drop_amt]
			price_l.add_theme_font_size_override("font_size", 11)
			price_l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if drop_amt <= 0 else Color(1.0, 0.80, 0.35))
			row.add_child(price_l)

			sell_receipt_list_vbox.add_child(row)

	var valid_cnt := int(preview.get("valid_count", 0))
	var total_units := int(preview.get("total_units", 0))
	var final_rubles := int(preview.get("total_final_rubles", 0))
	var loss_rubles := int(preview.get("elasticity_loss_rubles", 0))
	var loss_pct := float(preview.get("elasticity_loss_pct", 0.0))

	var sum_lines: Array[String] = []
	sum_lines.append("──────────────────────────")
	sum_lines.append("📦 선택 품목: %d슬롯 (총 %d개)" % [valid_cnt, total_units])
	if loss_rubles > 0:
		sum_lines.append("📉 대량 매각 시세 하락: -%d RUB (-%.1f%%)" % [loss_rubles, loss_pct])
	sum_lines.append("💵 예상 정산 금액: %d RUB" % final_rubles)
	sell_receipt_summary_lbl.text = "\n".join(sum_lines)
	sell_receipt_summary_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if loss_rubles > 0 else Color(0.88, 0.96, 0.92))
	sell_bulk_btn.disabled = (valid_cnt <= 0)

func _toggle_sell_selection(item: Dictionary, mgr: InventoryGrid, is_stash: bool) -> void:
	if item.is_empty() or not mgr:
		return
	var uid := str(item.get("uid", ""))
	if uid == "":
		return
	if selected_sell_uids.has(uid):
		selected_sell_uids.erase(uid)
		_refresh_trader_sell_ui()
		if SoundManager: SoundManager.play("menu_move")
		return
	if bool(item.get("locked", false)):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🔒 잠금된 아이템은 판매 트레이에 담을 수 없습니다. ([L] 키로 해제)")
		if SoundManager: SoundManager.play("hit_melee")
		return
	if mgr.is_item_in_secure_zone(item):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🔒 2x2 안전 컨테이너 내 아이템은 일괄 판매에서 보호됩니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	var inner = item.get("inner_items", [])
	if inner is Array and not inner.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 내부에 아이템이 든 컨테이너는 먼저 비워 주세요.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	selected_sell_uids[uid] = {
		"uid": uid,
		"is_stash": is_stash,
		"source_grid": mgr
	}
	_refresh_trader_sell_ui()
	if SoundManager: SoundManager.play("menu_select")

func _auto_select_bulk_sell(mode: String) -> void:
	var cands := HideoutProgression.collect_bulk_sell_candidates(mode, player_grid_mgr, stash_grid_mgr)
	if _are_all_bulk_candidates_selected(cands):
		for c in cands:
			var uid := str(c.get("uid", ""))
			if uid != "":
				selected_sell_uids.erase(uid)
	else:
		for c in cands:
			var uid := str(c.get("uid", ""))
			if uid != "":
				selected_sell_uids[uid] = c
	_refresh_trader_sell_ui()
	if SoundManager:
		SoundManager.play("menu_select" if not cands.is_empty() else "menu_move")

func _execute_bulk_sell() -> void:
	if selected_sell_uids.is_empty() or not GameManager:
		return
	var entries: Array = selected_sell_uids.values()
	var res := HideoutProgression.execute_bulk_sell(current_trader_id, entries, GameManager.current_world_data, player_grid_mgr, stash_grid_mgr)
	if bool(res.get("success", false)):
		selected_sell_uids.clear()
		if SoundManager: SoundManager.play("level_up")
		_update_money_label()
		_refresh_stash_ui()
		_refresh_trader_ui()
		_sync_save_data()

func _handle_sell_grid_input(event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	if not ctrl or not mgr:
		return
	var csz := _get_grid_cell_size(ctrl)
	var local_pos := ctrl.get_local_mouse_position()
	var cx := int(floor(local_pos.x / csz))
	var cy := int(floor(local_pos.y / csz))

	if event is InputEventMouseMotion:
		var in_bounds := (cx >= 0 and cx < mgr.grid_width and cy >= 0 and cy < mgr.grid_height)
		if is_stash:
			hovered_sell_stash_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		else:
			hovered_sell_player_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)

		if _is_marquee_selecting and _marquee_ctrl == ctrl:
			var x0 := minf(_marquee_start_local.x, local_pos.x)
			var y0 := minf(_marquee_start_local.y, local_pos.y)
			var x1 := maxf(_marquee_start_local.x, local_pos.x)
			var y1 := maxf(_marquee_start_local.y, local_pos.y)
			ctrl.set_meta("marquee_rect", Rect2(x0, y0, x1 - x0, y1 - y0))
			if tooltip: tooltip.hide()
		elif in_bounds:
			var h_item := mgr.get_item_at(cx, cy)
			if not h_item.is_empty() and tooltip:
				var idata := ItemDatabase.get_item_data(str(h_item.get("id", "")))
				tooltip.display_item(h_item, idata)
				tooltip.update_position(get_global_mouse_position())
			elif tooltip:
				tooltip.hide()
		elif tooltip:
			tooltip.hide()
		ctrl.queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var r_item := mgr.get_item_at(cx, cy)
			if not r_item.is_empty():
				_toggle_sell_selection(r_item, mgr, is_stash)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var l_item := mgr.get_item_at(cx, cy)
				if (event.alt_pressed or Input.is_key_pressed(KEY_ALT)) and not l_item.is_empty():
					_toggle_sell_selection(l_item, mgr, is_stash)
				else:
					_is_marquee_selecting = true
					_marquee_ctrl = ctrl
					_marquee_grid = mgr
					_marquee_is_stash = is_stash
					_marquee_start_local = local_pos
					ctrl.set_meta("marquee_rect", Rect2(local_pos, Vector2.ZERO))
					ctrl.queue_redraw()
			elif _is_marquee_selecting and _marquee_ctrl == ctrl:
				var raw_rect = ctrl.get_meta("marquee_rect", Rect2())
				var m_rect: Rect2 = raw_rect if raw_rect is Rect2 else Rect2()
				ctrl.remove_meta("marquee_rect")
				_is_marquee_selecting = false
				_marquee_ctrl = null
				_marquee_grid = null
				if m_rect.size.x < 6.0 and m_rect.size.y < 6.0:
					var click_item := mgr.get_item_at(cx, cy)
					if not click_item.is_empty():
						_toggle_sell_selection(click_item, mgr, is_stash)
				else:
					_apply_marquee_selection(m_rect, mgr, is_stash, ctrl)
				ctrl.queue_redraw()

func _apply_marquee_selection(m_rect: Rect2, mgr: InventoryGrid, is_stash: bool, ctrl: Control = null) -> void:
	if not mgr:
		return
	var csz := _get_grid_cell_size(ctrl)
	var added_cnt := 0
	for it in mgr.items:
		if it.is_empty():
			continue
		if bool(it.get("locked", false)) or mgr.is_item_in_secure_zone(it):
			continue
		var inner = it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			continue
		var is_rot := bool(it.get("rotated", false))
		var cw := int(it.get("h", 1)) if is_rot else int(it.get("w", 1))
		var ch := int(it.get("w", 1)) if is_rot else int(it.get("h", 1))
		var item_rect := Rect2(float(it.get("x", 0)) * csz, float(it.get("y", 0)) * csz, float(cw) * csz, float(ch) * csz)
		if m_rect.intersects(item_rect):
			var uid := str(it.get("uid", ""))
			if uid != "" and not selected_sell_uids.has(uid):
				selected_sell_uids[uid] = {
					"uid": uid,
					"is_stash": is_stash,
					"source_grid": mgr
				}
				added_cnt += 1
	_refresh_trader_sell_ui()
	if SoundManager:
		SoundManager.play("menu_select" if added_cnt > 0 else "menu_move")

func _buy_item(item_id: String, amount: int, price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < price: return
	
	# 자금 차감 및 거래자 누적 거래액 & 시세 탄력성 반영
	GameManager.current_world_data["player"]["rubles"] -= price
	HideoutProgression.record_trader_transaction(GameManager.current_world_data, current_trader_id, price)
	if FleaMarket:
		FleaMarket.record_player_purchase(item_id, amount)
	_update_money_label()
	
	# 배낭 또는 창고에 아이템 지급 (Auto-Fit)
	var remaining = player_grid_mgr.auto_add_item(item_id, amount)
	if remaining > 0:
		stash_grid_mgr.auto_add_item(item_id, remaining)
		
	if SoundManager: SoundManager.play("menu_select")
	_refresh_trader_ui()
	_sync_save_data()

func _sell_item(uid: String, is_stash: bool, item_id: String, amount: int, unit_price: int) -> void:
	var total_gain = unit_price * amount
	GameManager.current_world_data["player"]["rubles"] += total_gain
	HideoutProgression.record_trader_transaction(GameManager.current_world_data, current_trader_id, total_gain)
	if FleaMarket:
		FleaMarket.record_player_sale(item_id, amount)
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
	var cur_day = int(GameManager.current_world_data.get("current_day", FleaMarket.current_day)) if GameManager else FleaMarket.current_day
	var bounties = FleaMarket.get_daily_bounties(cur_day)
	if not bounties.is_empty():
		var bounty_panel = PanelContainer.new()
		bounty_panel.name = "BountyOrderPanel"
		if PixelAssetManager:
			var bounty_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("bounty_panel", 12.0, 10.0, 12.0, 10.0, 4)
			if bounty_sb != null:
				bounty_panel.add_theme_stylebox_override("panel", bounty_sb)

		var b_vbox = VBoxContainer.new()
		b_vbox.add_theme_constant_override("separation", 8)
		bounty_panel.add_child(b_vbox)
		
		var b_title = Label.new()
		b_title.text = "[🔥 오늘의 2.5x 긴급 수배] 암시장 특수 상인 고가 매입 품목"
		if PixelAssetManager:
			b_title.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
		b_title.add_theme_font_size_override("font_size", 12)
		b_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
		b_vbox.add_child(b_title)
		
		for b_entry in bounties:
			var b_id = String(b_entry.get("item_id", ""))
			var b_name = String(b_entry.get("name", b_id))
			var b_price = int(b_entry.get("bounty_price", 0))
			var m_price = int(b_entry.get("market_price", 0))
			var owned_cnt = HideoutProgression.count_total_item(b_id, player_grid_mgr, stash_grid_mgr)
			
			var b_row = HBoxContainer.new()
			b_row.add_theme_constant_override("separation", 12)
			if ItemIconManager:
				var b_icon := TextureRect.new()
				b_icon.custom_minimum_size = Vector2(28, 28)
				b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				b_icon.texture = ItemIconManager.get_icon(b_id)
				b_row.add_child(b_icon)

			var b_lbl = Label.new()
			b_lbl.text = "★ [%s]  일반 시세: %d RUB ➔ 수배 매입가: %d RUB (x2.5)  |  보유: %d개" % [b_name, m_price, b_price, owned_cnt]
			b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if owned_cnt > 0 else Color(0.92, 0.88, 0.76))
			b_row.add_child(b_lbl)
			
			var sell_b_btn = Button.new()
			sell_b_btn.text = "🔥 즉시 납품 (+%d RUB)" % b_price
			sell_b_btn.disabled = (owned_cnt <= 0)
			var cap_id = b_id
			sell_b_btn.pressed.connect(func():
				var res = FleaMarket.fulfill_bounty_order(cap_id, 1, GameManager.current_world_data, player_grid_mgr, stash_grid_mgr)
				if bool(res.get("success", false)):
					if SoundManager: SoundManager.play("level_up")
					_update_money_label()
					_refresh_stash_ui()
					_refresh_market_ui()
					_sync_save_data()
			)
			b_row.add_child(sell_b_btn)
			b_vbox.add_child(b_row)
		market_items_vbox.add_child(bounty_panel)
	
	for listing in FleaMarket.listings:
		var item_id = listing["item_name"]
		var price = int(listing["price"])
		var amount = int(listing["count"])
		var is_player_listing := bool(listing.get("is_player", false))
		var stock_rem := int(listing.get("stock_remaining", 1))
		var is_sold_out := bool(listing.get("sold_out", false)) or stock_rem <= 0
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		panel.add_child(hbox)
		
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			if is_sold_out:
				icon_rect.modulate = Color(0.45, 0.45, 0.45, 0.65)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		var stock_txt := ("[내 등록 매물 · 대기 중]" if is_player_listing else ("[품절]" if is_sold_out else "재고 %d개" % stock_rem))
		name_lbl.text = "%s (x%d)  [%s]" % [item_meta.get("name", item_id), amount, stock_txt]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_sold_out:
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
		elif is_player_listing:
			name_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % (price * amount)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if not is_sold_out else Color(0.5, 0.48, 0.45))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.text = "품절" if is_sold_out else ("등록중" if is_player_listing else "구매")
		buy_btn.custom_minimum_size = Vector2(68, 32)
		buy_btn.disabled = is_sold_out or is_player_listing or (user_rubles < price * amount)
		var cap_listing = listing
		buy_btn.pressed.connect(func(): _buy_market_item(cap_listing, price * amount))
		hbox.add_child(buy_btn)
		
		market_items_vbox.add_child(panel)
		
	_refresh_market_register_ui()

func _is_market_item_registerable(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {"ok": false, "reason": "아이템을 선택하세요."}
	if bool(item.get("locked", false)):
		return {"ok": false, "reason": "🔒 잠금된 아이템은 등록할 수 없습니다. ([L] 키로 해제)"}
	var inner = item.get("inner_items", [])
	if inner is Array and not inner.is_empty():
		return {"ok": false, "reason": "⚠️ 내부에 아이템이 든 컨테이너는 비운 뒤 등록할 수 있습니다."}
	var item_id := str(item.get("id", ""))
	if item_id in ["Scav 식별줄(Dogtag)", "Scav 인식표"]:
		return {"ok": false, "reason": "⚠️ Scav 인식표는 암시장에 등록할 수 없습니다."}
	return {"ok": true, "reason": ""}

func _does_market_item_match_filter(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var item_id := str(item.get("id", ""))
	var resolved := ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	if market_search_text != "":
		var disp_name := str(data.get("name", item_id))
		if not disp_name.containsn(market_search_text) and not item_id.containsn(market_search_text) and not resolved.containsn(market_search_text):
			return false
	if market_filter_category == "all":
		return true
	var cat := int(data.get("category", -1))
	var itype := str(data.get("type", item.get("type", "")))
	match market_filter_category:
		"valuables":
			return cat == ItemDatabase.ItemCategory.MISC or cat == ItemDatabase.ItemCategory.MATERIAL
		"combat":
			if itype == "storage_case":
				return false
			return (
				cat == ItemDatabase.ItemCategory.WEAPON
				or cat == ItemDatabase.ItemCategory.EQUIPMENT
				or itype in ["receiver", "assembled_weapon", "part", "ammo"]
				or (ItemDatabase and ItemDatabase.is_ammo_item(resolved))
				or (WeaponPartsDatabase and (WeaponPartsDatabase.PARTS.has(resolved) or WeaponPartsDatabase.RECEIVERS.has(resolved)))
			)
		"medical_supply":
			return cat in [ItemDatabase.ItemCategory.MEDICAL, ItemDatabase.ItemCategory.FOOD, ItemDatabase.ItemCategory.WATER]
		"key_case":
			return (
				itype in ["key", "keycard", "storage_case", "dogtag"]
				or resolved.contains("열쇠")
				or resolved.contains("키카드")
				or resolved.contains("케이스")
				or resolved.contains("상자")
				or resolved.contains("지갑")
				or resolved.contains("인식표")
			)
	return true

func _refresh_market_register_ui() -> void:
	if market_register_grid:
		for child in market_register_grid.get_children():
			child.queue_free()

	var used_slots := FleaMarket.player_listings.size() if FleaMarket else 0
	var max_slots := FleaMarket.MAX_PLAYER_LISTINGS if FleaMarket else 3
	var can_reg := FleaMarket.can_register_more_listings() if FleaMarket else false
	if market_slot_label:
		market_slot_label.text = "💰 암시장 위탁 판매 등록  |  보유 슬롯: %d / %d  |  누진 수수료 5%%~35%%" % [used_slots, max_slots]
		market_slot_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if not can_reg else Color(0.45, 0.90, 1.0))

	# 필터 및 배율 버튼 강조 갱신
	for cid in market_filter_buttons.keys():
		var b: Button = market_filter_buttons[cid] as Button
		if is_instance_valid(b):
			var is_on: bool = (str(cid) == market_filter_category)
			b.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72) if is_on else Color(0.84, 0.88, 0.92))
			b.modulate = Color(1.15, 1.15, 1.15) if is_on else Color(0.88, 0.88, 0.88)
	for r_key in market_ratio_buttons.keys():
		var rb: Button = market_ratio_buttons[r_key] as Button
		if is_instance_valid(rb):
			var is_r_on: bool = absf(float(r_key) - market_price_ratio) < 0.01
			rb.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if is_r_on else Color(0.84, 0.88, 0.92))
			rb.modulate = Color(1.15, 1.15, 1.15) if is_r_on else Color(0.88, 0.88, 0.88)

	var filter_active: bool = (market_search_text != "" or market_filter_category != "all")
	var total_matched := 0
	var selected_still_exists := false

	var pairs := [
		{"ctrl": market_player_grid_ctrl, "mgr": player_grid_mgr, "is_stash": false},
		{"ctrl": market_stash_grid_ctrl, "mgr": stash_grid_mgr, "is_stash": true}
	]
	for p in pairs:
		var ctrl: Control = p["ctrl"]
		var mgr: InventoryGrid = p["mgr"]
		if not mgr:
			continue
		var matched_uids: Dictionary = {}
		var unavail_uids: Dictionary = {}
		for it in mgr.items:
			if it.is_empty():
				continue
			var uid := str(it.get("uid", ""))
			if uid == "":
				continue
			if uid == market_selected_uid and bool(p["is_stash"]) == market_selected_is_stash:
				selected_still_exists = true
			var reg_chk := _is_market_item_registerable(it)
			if not bool(reg_chk["ok"]):
				unavail_uids[uid] = true
			elif _does_market_item_match_filter(it):
				matched_uids[uid] = true
				total_matched += 1
		if ctrl:
			ctrl.custom_minimum_size = Vector2(float(mgr.grid_width) * CELL_SIZE, float(mgr.grid_height) * CELL_SIZE)
			ctrl.set_meta("filter_active", filter_active)
			ctrl.set_meta("matched_uids", matched_uids)
			ctrl.set_meta("unavailable_uids", unavail_uids)
			ctrl.set_meta("active_focus_uid", market_selected_uid)
			ctrl.queue_redraw()

	if not selected_still_exists:
		market_selected_uid = ""
		if market_player_grid_ctrl:
			market_player_grid_ctrl.set_meta("active_focus_uid", "")
			market_player_grid_ctrl.queue_redraw()
		if market_stash_grid_ctrl:
			market_stash_grid_ctrl.set_meta("active_focus_uid", "")
			market_stash_grid_ctrl.queue_redraw()

	if market_result_count_lbl:
		market_result_count_lbl.text = "가능 %d개" % total_matched

	_refresh_market_selection_preview()

func _refresh_market_selection_preview() -> void:
	if not market_preview_lbl or not market_confirm_btn:
		return
	var mgr: InventoryGrid = stash_grid_mgr if market_selected_is_stash else player_grid_mgr
	var item: Dictionary = mgr.get_item_by_uid(market_selected_uid) if (mgr and market_selected_uid != "") else {}
	if item.is_empty():
		market_preview_lbl.text = "💡 2D 그리드에서 암시장에 등록할 아이템을 클릭하세요. (검색/카테고리 필터 지원 · 더블클릭 시 즉시 등록)"
		market_preview_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
		market_confirm_btn.disabled = true
		return

	var item_id := str(item.get("id", ""))
	var amt := maxi(1, int(item.get("amount", 1)))
	var data := ItemDatabase.get_item_data(item_id)
	var disp_name := str(data.get("name", item_id))
	var reg_chk := _is_market_item_registerable(item)
	if not bool(reg_chk["ok"]):
		market_preview_lbl.text = "[%s x%d]  %s" % [disp_name, amt, str(reg_chk["reason"])]
		market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		market_confirm_btn.disabled = true
		return

	var ref_price := FleaMarket.get_current_price(item_id) if FleaMarket else 100
	var ask_unit := maxi(10, int(round(float(ref_price) * market_price_ratio)))
	var total_ask := ask_unit * amt
	var fee := FleaMarket.calculate_listing_fee(item_id, amt, ask_unit) if FleaMarket else 1
	var fee_pct := int(round((FleaMarket.calculate_listing_fee_rate(item_id, ask_unit) if FleaMarket else 0.05) * 100.0))
	var user_rubles := int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	var can_reg := FleaMarket.can_register_more_listings() if FleaMarket else false
	var src_tag := "📦창고" if market_selected_is_stash else "🎒배낭"

	if not can_reg:
		market_preview_lbl.text = "[%s] %s x%d  |  ⚠️ 판매 슬롯(3/3)이 가득 찼습니다." % [src_tag, disp_name, amt]
		market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.48))
		market_confirm_btn.disabled = true
	elif user_rubles < fee:
		market_preview_lbl.text = "[%s] %s x%d  |  희망가: %d RUB (x%.1f)  |  ⚠️ 수수료 %d RUB 부족" % [src_tag, disp_name, amt, total_ask, market_price_ratio, fee]
		market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		market_confirm_btn.disabled = true
	else:
		market_preview_lbl.text = "[%s] %s x%d\n희망 판매가: %d RUB (시세 x%.1f)  |  선불 수수료: %d RUB (%d%%)  |  판매 순이익: +%d RUB" % [
			src_tag, disp_name, amt, total_ask, market_price_ratio, fee, fee_pct, total_ask - fee
		]
		market_preview_lbl.add_theme_color_override("font_color", Color(0.45, 0.98, 0.72))
		market_confirm_btn.disabled = false

func _handle_market_grid_input(event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	if not ctrl or not mgr:
		return
	var local_pos := ctrl.get_local_mouse_position()
	var cx := int(floor(local_pos.x / CELL_SIZE))
	var cy := int(floor(local_pos.y / CELL_SIZE))
	var in_bounds := (cx >= 0 and cx < mgr.grid_width and cy >= 0 and cy < mgr.grid_height)

	if event is InputEventMouseMotion:
		if is_stash:
			hovered_market_stash_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		else:
			hovered_market_player_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		if in_bounds:
			var h_item := mgr.get_item_at(cx, cy)
			if not h_item.is_empty() and tooltip:
				tooltip.display_item(h_item, ItemDatabase.get_item_data(str(h_item.get("id", ""))))
				tooltip.update_position(get_global_mouse_position())
			elif tooltip:
				tooltip.hide()
		elif tooltip:
			tooltip.hide()
		ctrl.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item := mgr.get_item_at(cx, cy)
			if item.is_empty():
				market_selected_uid = ""
				_refresh_market_register_ui()
				return
			market_selected_uid = str(item.get("uid", ""))
			market_selected_is_stash = is_stash
			_refresh_market_register_ui()
			if SoundManager: SoundManager.play("menu_move")
			if event.double_click or Input.is_key_pressed(KEY_CTRL):
				_try_register_selected_market_item()

func _try_register_selected_market_item() -> void:
	var mgr: InventoryGrid = stash_grid_mgr if market_selected_is_stash else player_grid_mgr
	var item: Dictionary = mgr.get_item_by_uid(market_selected_uid) if (mgr and market_selected_uid != "") else {}
	if item.is_empty():
		return
	var reg_chk := _is_market_item_registerable(item)
	if not bool(reg_chk["ok"]):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit(str(reg_chk["reason"]))
		if SoundManager: SoundManager.play("hit_melee")
		return
	var item_id := str(item.get("id", ""))
	var amt := maxi(1, int(item.get("amount", 1)))
	var ref_price := FleaMarket.get_current_price(item_id) if FleaMarket else 100
	var ask_price := maxi(10, int(round(float(ref_price) * market_price_ratio)))
	_register_market_item(market_selected_uid, market_selected_is_stash, item_id, amt, ask_price)

func _buy_market_item(listing: Dictionary, total_price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < total_price: return
	var res := FleaMarket.purchase_listing(listing, 1)
	if not bool(res.get("success", false)):
		_refresh_market_ui()
		return
	var actual_cost := int(res.get("total_price", total_price))
	GameManager.current_world_data["player"]["rubles"] -= actual_cost
	_update_money_label()
	
	var b_item := str(res.get("item_name", listing.get("item_name", "")))
	var b_amt := int(res.get("amount", listing.get("count", 1)))
	var remaining = player_grid_mgr.auto_add_item(b_item, b_amt)
	if remaining > 0:
		stash_grid_mgr.auto_add_item(b_item, remaining)
		
	if SoundManager: SoundManager.play("menu_select")
	
	_refresh_market_ui()
	_sync_save_data()

func _register_market_item(uid: String, is_stash: bool, item_id: String, amount: int, ask_unit_price: int) -> void:
	if not FleaMarket or not FleaMarket.can_register_more_listings():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 암시장 동시 판매 슬롯(최대 %d개)이 가득 찼습니다." % (FleaMarket.MAX_PLAYER_LISTINGS if FleaMarket else 3))
		return
	var fee := FleaMarket.calculate_listing_fee(item_id, amount, ask_unit_price)
	var user_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))
	
	if user_rubles < fee:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 등록 수수료(%d RUB)가 부족합니다." % fee)
		return
		
	if not FleaMarket.register_item(item_id, amount, ask_unit_price, true):
		return

	GameManager.current_world_data["player"]["rubles"] -= fee
	_update_money_label()
	
	if is_stash:
		stash_grid_mgr.remove_item_by_uid(uid)
		_refresh_stash_ui()
	else:
		player_grid_mgr.remove_item_by_uid(uid)
	
	if SoundManager: SoundManager.play("menu_select")
	_refresh_market_ui()
	_sync_save_data()

# ============================================================
# 중첩 컨테이너 팝업창 & 잠금 [L] & 컨텍스트 메뉴
# ============================================================
func _sync_all_open_popups() -> void:
	for p in open_container_popups.values():
		if is_instance_valid(p) and p.inner_grid and not p.container_item.is_empty():
			InventoryGrid.sync_container_item_contents(p.container_item, p.inner_grid)

func close_all_container_popups() -> void:
	for p in open_container_popups.values():
		if is_instance_valid(p):
			p.queue_free()
	open_container_popups.clear()

func _prune_stale_popups() -> void:
	var stale: Array[String] = []
	var eq_vest: Dictionary = equipment_data.get("vest", {})
	var eq_vest_uid: String = str(eq_vest.get("uid", ""))
	for cuid in open_container_popups.keys():
		var p = open_container_popups[cuid]
		if not is_instance_valid(p):
			stale.append(str(cuid))
			continue
		var s_uid := str(p.container_item.get("uid", ""))
		if s_uid != "":
			var live_item: Dictionary = {}
			var live_grid: InventoryGrid = null
			if player_grid_mgr:
				var pi := player_grid_mgr.get_item_by_uid(s_uid)
				if not pi.is_empty():
					live_item = pi
					live_grid = player_grid_mgr
			if live_item.is_empty() and stash_grid_mgr:
				var si := stash_grid_mgr.get_item_by_uid(s_uid)
				if not si.is_empty():
					live_item = si
					live_grid = stash_grid_mgr
			if live_item.is_empty() and not eq_vest.is_empty() and eq_vest_uid == s_uid:
				live_item = eq_vest
				live_grid = null
			if live_item.is_empty():
				stale.append(str(cuid))
			else:
				# sort_items() 등으로 딕셔너리 참조가 교체된 경우에도 열린 팝업 바인딩 유지
				p.container_item = live_item
				p.source_grid = live_grid
				if p.inner_grid:
					InventoryGrid.sync_container_item_contents(live_item, p.inner_grid)
	for ek in stale:
		var p = open_container_popups.get(ek, null)
		if is_instance_valid(p):
			p.queue_free()
		open_container_popups.erase(ek)

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
	var base_pos := Vector2(380.0 + float(idx) * 28.0, 90.0 + float(idx) * 24.0)
	popup.position = InventoryUIHelper.clamp_popup_position(popup, base_pos, size, 8.0)
	open_container_popups[cuid] = popup

	popup.popup_closed.connect(func(_closed_uid: String):
		open_container_popups.erase(cuid)
		_on_grid_changed()
	)
	popup.popup_grid_changed.connect(func(_changed_uid: String):
		_sync_save_data()
	)
	popup.item_drag_started.connect(func(p_win: ContainerPopupWindow, it: Dictionary, c_pos: Vector2i):
		_start_drag("popup_grid", it, c_pos, "", p_win.inner_grid)
	)
	popup.item_split_requested.connect(func(p_win: ContainerPopupWindow, it: Dictionary, c_pos: Vector2i):
		_open_split_dialog(it, func(split_amt):
			var split_item := it.duplicate(true)
			split_item["uid"] = InventoryGrid.next_uid()
			split_item["amount"] = split_amt
			it["amount"] -= split_amt
			if p_win.inner_grid:
				p_win.inner_grid.grid_changed.emit()
			_start_drag("split", split_item, c_pos, "", p_win.inner_grid)
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
	var children := get_children()
	for ci in range(children.size() - 1, -1, -1):
		var p_win := children[ci] as ContainerPopupWindow
		if p_win and is_instance_valid(p_win) and p_win.is_visible_in_tree() and p_win.get_global_rect().has_point(m_pos):
			var h_it: Dictionary = p_win.get_hovered_item()
			if not h_it.is_empty() and p_win.inner_grid:
				p_win.inner_grid.toggle_item_lock(str(h_it.get("uid", "")))
				if tooltip and tooltip.visible:
					tooltip.display_item(h_it, ItemDatabase.get_item_data(str(h_it.get("id", ""))))
				if SoundManager: SoundManager.play("menu_select")
				return true
			return false
	var targets := [
		[player_grid_control, player_grid_mgr],
		[stash_grid_control, stash_grid_mgr],
		[sell_player_grid_ctrl, player_grid_mgr],
		[sell_stash_grid_ctrl, stash_grid_mgr],
		[market_player_grid_ctrl, player_grid_mgr],
		[market_stash_grid_ctrl, stash_grid_mgr]
	]
	for pair in targets:
		var ctrl: Control = pair[0]
		var mgr: InventoryGrid = pair[1]
		if is_instance_valid(ctrl) and mgr and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(m_pos):
			var csz := _get_grid_cell_size(ctrl)
			var l_pos := m_pos - ctrl.get_global_rect().position
			var cx := int(floor(l_pos.x / csz))
			var cy := int(floor(l_pos.y / csz))
			var h_it := mgr.get_item_at(cx, cy)
			if not h_it.is_empty():
				mgr.toggle_item_lock(str(h_it.get("uid", "")))
				if tooltip and tooltip.visible:
					tooltip.display_item(h_it, ItemDatabase.get_item_data(str(h_it.get("id", ""))))
				if SoundManager: SoundManager.play("menu_select")
				return true
	return false

func _log_container_reject_reason(reason: String) -> void:
	if not EventBus.has_signal("event_logged"):
		return
	match reason:
		"self_drop":
			EventBus.event_logged.emit("⚠️ 자기 자신의 내부에는 수납할 수 없습니다.")
		"max_depth_exceeded":
			EventBus.event_logged.emit("⚠️ 컨테이너는 최대 2단계(가방 -> 서브 컨테이너)까지만 중첩할 수 있습니다.")
		"filter_mismatch":
			EventBus.event_logged.emit("🔒 해당 보관함 전용 카테고리 아이템만 넣을 수 있습니다.")
		_:
			EventBus.event_logged.emit("⚠️ 해당 위치에 보관할 수 없습니다.")

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

	var accept := target_grid.can_accept_item(item, item_id)
	if not bool(accept.get("ok", true)):
		_log_container_reject_reason(str(accept.get("reason", "")))
		if SoundManager: SoundManager.play("hit_melee")
		_end_drag()
		return

	# 같은 아이템 스택 병합 시도
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
					if src == "split":
						drag_data["is_split"] = false
					elif src == "player_grid" and player_grid_mgr:
						player_grid_mgr.remove_item_by_uid(uid)
					elif src == "stash_grid" and stash_grid_mgr:
						stash_grid_mgr.remove_item_by_uid(uid)
					elif src == "popup_grid" and src_grid:
						src_grid.remove_item_by_uid(uid)
					elif src == "equipment":
						equipment_data[drag_data.get("slot_name", "")] = {}
						_apply_backpack_grid_size()
						_update_equipment_ui()
				else:
					item["amount"] = rem_amt
					if src == "player_grid" and player_grid_mgr:
						var o_it := player_grid_mgr.get_item_by_uid(uid)
						if not o_it.is_empty(): o_it["amount"] = rem_amt
						player_grid_mgr.grid_changed.emit()
					elif src == "stash_grid" and stash_grid_mgr:
						var s_it := stash_grid_mgr.get_item_by_uid(uid)
						if not s_it.is_empty(): s_it["amount"] = rem_amt
						stash_grid_mgr.grid_changed.emit()
					elif src == "popup_grid" and src_grid:
						var p_it := src_grid.get_item_by_uid(uid)
						if not p_it.is_empty(): p_it["amount"] = rem_amt
						src_grid.grid_changed.emit()
					elif src == "split":
						var orig_sp = drag_data.get("split_source_item", {})
						if not orig_sp.is_empty():
							orig_sp["amount"] = int(orig_sp.get("amount", 0)) + rem_amt
						drag_data["is_split"] = false
						var sp_grid: InventoryGrid = drag_data.get("split_source_grid", player_grid_mgr) as InventoryGrid
						if sp_grid: sp_grid.grid_changed.emit()
				target_grid.grid_changed.emit()
				if SoundManager: SoundManager.play("menu_select")
				_end_drag()
				return

	if target_grid.can_place_item(place_w, place_h, cell_x, cell_y, ignore_uid, item_id, item):
		if same_grid:
			target_grid.move_item(uid, cell_x, cell_y, is_rot)
			if SoundManager: SoundManager.play("menu_select")
		elif target_grid.place_item(item, cell_x, cell_y, is_rot):
			if src == "split":
				drag_data["is_split"] = false
			elif src == "player_grid" and player_grid_mgr:
				player_grid_mgr.remove_item_by_uid(uid)
			elif src == "stash_grid" and stash_grid_mgr:
				stash_grid_mgr.remove_item_by_uid(uid)
			elif src == "popup_grid" and src_grid:
				src_grid.remove_item_by_uid(uid)
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

func _handle_popup_quick_action(popup: ContainerPopupWindow, item: Dictionary, _is_ctrl: bool) -> void:
	if not popup or not popup.inner_grid or item.is_empty():
		return
	var item_id := str(item.get("id", ""))
	var amt := maxi(1, int(item.get("amount", 1)))
	var uid := str(item.get("uid", ""))
	var dest := stash_grid_mgr if (popup.source_grid == player_grid_mgr) else player_grid_mgr
	if not dest:
		dest = stash_grid_mgr if stash_grid_mgr else player_grid_mgr
	if not dest:
		return
	var rem := dest.auto_add_item(item_id, amt, item)
	if amt - rem > 0:
		if rem <= 0:
			popup.inner_grid.remove_item_by_uid(uid)
		else:
			item["amount"] = rem
			popup.inner_grid.grid_changed.emit()
		if SoundManager: SoundManager.play("menu_select")

func _close_context_menu() -> void:
	if context_menu_panel and is_instance_valid(context_menu_panel):
		context_menu_panel.queue_free()
	context_menu_panel = null

func _show_context_menu(item: Dictionary, source_type: String, slot_ref: String = "", source_grid: InventoryGrid = null) -> void:
	_close_context_menu()
	var item_id := str(item.get("id", ""))
	var idata := ItemDatabase.get_item_data(item_id)
	var item_name := str(idata.get("name", item_id))

	context_menu_panel = PanelContainer.new()
	context_menu_panel.z_index = 300
	if PixelAssetManager:
		var sb: StyleBox = PixelAssetManager.get_pixel_stylebox("context_menu", 8.0, 6.0, 8.0, 6.0, 4)
		if sb != null:
			context_menu_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	context_menu_panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = item_name
	if PixelAssetManager:
		hdr.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.92, 0.86, 0.42))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hdr)
	vbox.add_child(HSeparator.new())

	if InventoryGrid.is_container_item(item) and (source_type in ["player_grid", "stash_grid"] or (source_type == "equipment" and slot_ref == "vest")):
		_add_context_menu_btn(vbox, "📂 포켓 열기" if source_type == "equipment" else "📂 컨테이너 열기", func():
			_close_context_menu()
			open_container_popup(item, source_grid if source_type in ["player_grid", "stash_grid"] else null)
		)

	if source_type in ["player_grid", "stash_grid", "popup_grid"] and source_grid:
		var is_locked := bool(item.get("locked", false))
		_add_context_menu_btn(vbox, "🔓 잠금 해제 (L)" if is_locked else "🔒 아이템 잠금 (L)", func():
			_close_context_menu()
			source_grid.toggle_item_lock(str(item.get("uid", "")))
			if SoundManager: SoundManager.play("menu_select")
		)

	if source_type in ["player_grid", "stash_grid"]:
		_add_context_menu_btn(vbox, "📤 빠른 이동 / 장착", func():
			_close_context_menu()
			_handle_hideout_quick_action(item, source_type == "player_grid")
		)
	elif source_type == "popup_grid" and source_grid:
		var pop_ref: ContainerPopupWindow = open_container_popups.get(source_grid.owner_container_uid, null) as ContainerPopupWindow
		if pop_ref:
			_add_context_menu_btn(vbox, "📤 밖으로 꺼내기", func():
				_close_context_menu()
				_handle_popup_quick_action(pop_ref, item, true)
			)

	add_child(context_menu_panel)
	var mpos := get_global_mouse_position() - global_position
	context_menu_panel.position = InventoryUIHelper.clamp_popup_position(context_menu_panel, mpos, size, 8.0)

func _add_context_menu_btn(vbox: VBoxContainer, text_str: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"SmallButton"
	btn.text = text_str
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(142, 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	vbox.add_child(btn)

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
		var returned_sales = sales_report.get("returned_items", [])
		if returned_sales is Array and not returned_sales.is_empty():
			result_desc.text += "\n📦 플리마켓 기간 만료 물품 %d건이 은신처 창고로 반송되었습니다." % returned_sales.size()
			
		GameManager.last_raid_result.clear()
		_update_insurance_ui()
	else:
		result_dialog.visible = false

func _on_hideout_event_logged(msg: String) -> void:
	if not is_inside_tree() or not _hideout_event_log_vbox:
		return
	HudTacticalHelper.spawn_event_toast(self, _hideout_event_log_vbox, msg)

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
	var focus_owner := get_viewport().gui_get_focus_owner() if (is_inside_tree() and get_viewport()) else null
	if focus_owner is LineEdit:
		return
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
	_sync_all_open_popups()
	close_all_container_popups()
	var inv_scene = preload("res://scenes/ui/inventory_window.tscn")
	if inv_scene:
		var win = inv_scene.instantiate()
		add_child(win)
		win.set("hideout_stash_grid", stash_grid_mgr)
		win.setup(null, player_grid_mgr, equipment_data)
		win.window_closed.connect(func(): _on_grid_changed())

func _open_item_spawner() -> void:
	var spawner_scene = preload("res://scenes/ui/item_spawner_window.tscn")
	if spawner_scene:
		var win = spawner_scene.instantiate()
		add_child(win)
		win.window_closed.connect(func(): _on_grid_changed())

func _open_settings_window() -> void:
	if is_instance_valid(current_settings_window):
		return
	if SoundManager: SoundManager.play("menu_select")
	var sett_scene = preload("res://scenes/ui/settings_window.tscn")
	if sett_scene:
		var win = sett_scene.instantiate()
		current_settings_window = win
		add_child(win)
		win.window_closed.connect(func(): current_settings_window = null)

func _open_weapon_modding_window() -> void:
	# B 키를 누르면 바로 4번째 탭(총기 작업대)으로 전환
	if tab_container:
		tab_container.current_tab = 3
		_refresh_workbench_ui()


func _refresh_workbench_ui() -> void:
	if workbench:
		workbench.refresh_workbench_ui()
