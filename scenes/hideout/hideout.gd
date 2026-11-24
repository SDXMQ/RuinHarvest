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
@onready var result_desc: RichTextLabel = $ResultDialog/VBox/Desc
@onready var result_close_btn: Button = $ResultDialog/VBox/CloseBtn

const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
const SplitDialogScene = preload("res://scenes/ui/split_dialog.tscn")
var tooltip: PanelContainer
const ShootingRangeScript = preload("res://scenes/ui/shooting_range_window.gd")
const CharacterPaperdollPreviewScript = preload("res://scenes/hideout/components/character_paperdoll_preview.gd")
const HideoutTraderHelper = preload("res://scenes/hideout/components/hideout_trader_helper.gd")
const HideoutMarketHelper = preload("res://scenes/hideout/components/hideout_market_helper.gd")

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
var sell_receipt_summary_lbl: RichTextLabel = null
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
var _current_inventory_window: Control = null

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
		
		if GameManager and GameManager.is_sandbox_mode():
			var tool_btn = Button.new()
			tool_btn.name = "SandboxToolBtn"
			if UiIconManager:
				UiIconManager.set_button(tool_btn, "sandbox", "샌드박스/치트 도구 (F1)", 15)
			else:
				tool_btn.text = "샌드박스/치트 도구 (F1)"
			tool_btn.custom_minimum_size = Vector2(0, 32)
			tool_btn.pressed.connect(_open_item_spawner)
			top_tools.add_child(tool_btn)
		
		var range_btn = Button.new()
		if UiIconManager:
			UiIconManager.set_button(range_btn, "target", "사격장 (F2)", 15)
		else:
			range_btn.text = "사격장 (F2)"
		range_btn.custom_minimum_size = Vector2(0, 32)
		range_btn.pressed.connect(_open_shooting_range)
		top_tools.add_child(range_btn)

		var settings_btn = Button.new()
		settings_btn.name = "SettingsBtn"
		if UiIconManager:
			UiIconManager.set_button(settings_btn, "settings", "설정 (F11)", 15)
		else:
			settings_btn.text = "설정 (F11)"
		settings_btn.custom_minimum_size = Vector2(0, 32)
		settings_btn.pressed.connect(_open_settings_window)
		top_tools.add_child(settings_btn)
	
	# 상인 버튼 연결 및 정적 씬 UI 아이콘 바인딩
	var prapor_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/PraporBtn
	var therapist_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/TherapistBtn
	var fence_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/FenceBtn
	
	prapor_btn.pressed.connect(func(): _select_trader("prapor"))
	therapist_btn.pressed.connect(func(): _select_trader("therapist"))
	fence_btn.pressed.connect(func(): _select_trader("fence"))

	tab_container.set_tab_title(0, "은신처 & 장비")
	tab_container.set_tab_title(1, "상인")
	tab_container.set_tab_title(2, "암시장")
	tab_container.set_tab_title(3, "총기 개조실")
	if UiIconManager:
		UiIconManager.set_tab_icon(tab_container, 0, "stash")
		UiIconManager.set_tab_icon(tab_container, 1, "shop")
		UiIconManager.set_tab_icon(tab_container, 2, "chart_up")
		UiIconManager.set_tab_icon(tab_container, 3, "wrench")
		UiIconManager.apply_button_icon(prapor_btn, "gun", "", 16)
		UiIconManager.apply_button_icon(therapist_btn, "syringe", "", 16)
		UiIconManager.apply_button_icon(fence_btn, "bolt", "", 16)
		var p_title := get_node_or_null("CenterArea/TabContainer/StashTab/HBox/PlayerPanel/VBox/Title") as Label
		if p_title: UiIconManager.set_label_icon(p_title, "backpack", "", 16, 6)
		var e_title := get_node_or_null("CenterArea/TabContainer/StashTab/HBox/EquipPanel/VBox/Title") as Label
		if e_title: UiIconManager.set_label_icon(e_title, "person", "", 16, 6)
		var s_title := get_node_or_null("CenterArea/TabContainer/StashTab/HBox/StashPanel/VBox/Title") as Label
		if s_title: UiIconManager.set_label_icon(s_title, "stash", "", 16, 6)
		var sell_title := get_node_or_null("CenterArea/TabContainer/TradersTab/VBox/SellArea/SellTitle") as Label
		if sell_title: UiIconManager.set_label_icon(sell_title, "money", "", 14, 5)
		var reg_title := get_node_or_null("CenterArea/TabContainer/MarketTab/VBox/RegisterArea/RegisterTitle") as Label
		if reg_title: UiIconManager.set_label_icon(reg_title, "money", "", 14, 5)
	
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
	player_grid_control.mouse_exited.connect(func():
		hovered_player_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if player_grid_control: player_grid_control.queue_redraw()
	)
	
	stash_grid_control.draw.connect(_on_stash_grid_draw)
	stash_grid_control.gui_input.connect(_on_stash_grid_gui_input)
	stash_grid_control.mouse_exited.connect(func():
		hovered_stash_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		if stash_grid_control: stash_grid_control.queue_redraw()
	)
	
	# 배낭 & 창고 정렬/빠른 보관 버튼 바 추가
	var player_vbox = get_node_or_null("CenterArea/TabContainer/StashTab/HBox/PlayerPanel/VBox")
	if player_vbox:
		var p_btn_row = HBoxContainer.new()
		p_btn_row.add_theme_constant_override("separation", 6)
		var p_sort_btn = Button.new()
		if UiIconManager:
			UiIconManager.set_button(p_sort_btn, "refresh", "배낭 정렬", 14)
		else:
			p_sort_btn.text = "배낭 정렬"
		p_sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_sort_btn.add_theme_font_size_override("font_size", 11)
		p_sort_btn.pressed.connect(func():
			player_grid_mgr.sort_items()
			if SoundManager: SoundManager.play("menu_select")
		)
		p_btn_row.add_child(p_sort_btn)
		
		var deposit_all_btn = Button.new()
		if UiIconManager:
			UiIconManager.set_button(deposit_all_btn, "deposit_all", "창고로 모두 보관", 14)
		else:
			deposit_all_btn.text = "창고로 모두 보관"
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
		if UiIconManager:
			UiIconManager.set_button(s_sort_btn, "refresh", "창고 자동 정렬 & 스택 병합  (Ctrl+클릭 / 우클릭: 빠른 이동)", 14)
		else:
			s_sort_btn.text = "창고 자동 정렬 & 스택 병합  (Ctrl+클릭 / 우클릭: 빠른 이동)"
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
	return InventoryUIHelper.compute_fit_cell_size(scroll_ctrl, grid_cols, min_cell, max_cell)

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
	if market_player_grid_ctrl and player_grid_mgr:
		market_player_cell_size = _compute_fit_cell_size(market_grids_scroll, player_grid_mgr.grid_width, CELL_SIZE, 54.0)
		market_player_grid_ctrl.custom_minimum_size = Vector2(float(player_grid_mgr.grid_width) * market_player_cell_size, float(player_grid_mgr.grid_height) * market_player_cell_size)
		market_player_grid_ctrl.queue_redraw()
	if market_stash_grid_ctrl and stash_grid_mgr:
		market_stash_cell_size = _compute_fit_cell_size(market_grids_scroll, stash_grid_mgr.grid_width, CELL_SIZE, 54.0)
		market_stash_grid_ctrl.custom_minimum_size = Vector2(float(stash_grid_mgr.grid_width) * market_stash_cell_size, float(stash_grid_mgr.grid_height) * market_stash_cell_size)
		market_stash_grid_ctrl.queue_redraw()

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
	if is_dragging:
		if bool(drag_data.get("started_with_lmb", false)) and not bool(drag_data.get("is_split", false)) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag()
			return
		if drag_preview_node:
			_update_drag_preview_pos()
	elif tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())
	if _is_marquee_selecting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_marquee_selection()

func _cancel_marquee_selection() -> void:
	if is_instance_valid(_marquee_ctrl):
		_marquee_ctrl.remove_meta("marquee_rect")
		_marquee_ctrl.queue_redraw()
	_is_marquee_selecting = false
	_marquee_ctrl = null
	_marquee_grid = null

func _reset_all_hovered_cells() -> void:
	hovered_player_cell = Vector2i(-1, -1)
	hovered_stash_cell = Vector2i(-1, -1)
	hovered_sell_player_cell = Vector2i(-1, -1)
	hovered_sell_stash_cell = Vector2i(-1, -1)
	hovered_market_player_cell = Vector2i(-1, -1)
	hovered_market_stash_cell = Vector2i(-1, -1)
	for ctrl in [player_grid_control, stash_grid_control, sell_player_grid_ctrl, sell_stash_grid_ctrl, market_player_grid_ctrl, market_stash_grid_ctrl]:
		if is_instance_valid(ctrl):
			ctrl.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		if is_dragging:
			_end_drag()
		_cancel_marquee_selection()
		_close_context_menu()
		if tooltip and is_instance_valid(tooltip):
			tooltip.hide()
		_reset_all_hovered_cells()

func _on_tab_changed(tab: int) -> void:
	if is_dragging:
		_end_drag()
	_cancel_marquee_selection()
	_reset_all_hovered_cells()
	if tooltip: tooltip.hide()
	_close_context_menu()
	if tab != 3 and workbench:
		if workbench.has_method("_close_confirm_dialog"):
			workbench._close_confirm_dialog()
		if workbench.has_method("_cancel_pending_preset_preview"):
			workbench._cancel_pending_preset_preview()
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

func on_progression_state_changed(stash_resized: bool = false) -> void:
	if stash_resized:
		_apply_stash_upgrade_size()
	_refresh_stash_ui()
	_update_money_label()
	_on_grid_changed()

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
		
		# 장비 데이터 로드 (최초 새 게임 1회만 기본 스타터 장비 지급, 사망/초기화 이후 재지급 금지)
		var base_eq: Dictionary = GameManager.create_empty_equipment() if GameManager else {"helmet": {}, "vest": {}, "backpack": {}, "bottom": {}, "primary1": {}, "primary2": {}, "sidearm": {}, "throwable": {}}
		var p_eq_raw = p_data.get("equipment", {})
		var p_eq_dict: Dictionary = p_eq_raw if p_eq_raw is Dictionary else {}
		var is_fresh_uninitialized: bool = (not bool(p_data.get("equipment_initialized", false))) and int(w_data.get("current_day", 1)) <= 1 and int(p_data.get("raids_survived", 0)) <= 0 and (not GameManager or GameManager.last_raid_result.is_empty())
		if p_eq_dict.is_empty() and is_fresh_uninitialized:
			equipment_data = GameManager.create_starter_equipment() if GameManager else base_eq.duplicate(true)
			p_data["equipment"] = equipment_data.duplicate(true)
			p_data["equipment_initialized"] = true
		else:
			equipment_data = p_eq_dict.duplicate(true)
			for eq_k in base_eq.keys():
				if not equipment_data.has(eq_k):
					equipment_data[eq_k] = base_eq[eq_k]
		
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
		if UiIconManager:
			UiIconManager.set_button(insurance_btn, "shield_green", "장비 보험 적용됨 (사망 시 장착 장비 보존)", 15)
		else:
			insurance_btn.text = "장비 보험 적용됨 (사망 시 장착 장비 보존)"
		insurance_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
		insurance_btn.disabled = true
	else:
		if UiIconManager:
			UiIconManager.set_button(insurance_btn, "shield", "장비 보험 가입 (1,500 RUB)", 15)
		else:
			insurance_btn.text = "장비 보험 가입 (1,500 RUB)"
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
					EventBus.event_logged.emit("[icon:warn] 창고 공간이 부족하여 일부 아이템(%s)을 보관하지 못했습니다!" % overflow_it.get("name", overflow_it.get("id", "")))
			
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
		if is_dragging:
			return
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
						var split_item: Dictionary = InventoryUIHelper.prepare_split_drag_item(item, int(split_amt), grid_mgr)
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
	if allow_popup_transfer and InventoryUIHelper.try_quick_transfer_to_open_popup(self, open_container_popups, item, src_grid):
		return

	var target_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	# 1. 장비 아이템이면 장비 슬롯으로 퀵 장착 시도
	if target_slot != "" and equipment_data.has(target_slot) and equipment_data[target_slot].is_empty():
		if target_slot == "backpack":
			var inner_arr = item.get("inner_items", [])
			if inner_arr is Array and not inner_arr.is_empty():
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("[icon:warn] 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
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
			InventoryUIHelper.update_popup_drag_hover(open_container_popups, m_pos, drag_data)
			if SoundManager: SoundManager.play("menu_move")
			if player_grid_control: player_grid_control.queue_redraw()
			if stash_grid_control: stash_grid_control.queue_redraw()
			get_viewport().set_input_as_handled()
			return
			
	if is_dragging and event is InputEventMouseMotion:
		var m_pos = event.global_position
		_update_drag_preview_pos()
		InventoryUIHelper.update_popup_drag_hover(open_container_popups, m_pos, drag_data)
			
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
			
	if is_dragging and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_end_drag()
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and bool(drag_data.get("is_split", false)):
			_handle_hideout_global_drop(event.global_position)
			get_viewport().set_input_as_handled()
			return
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_hideout_global_drop(event.global_position)
			get_viewport().set_input_as_handled()

	if _is_marquee_selecting and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ctrl_ref := _marquee_ctrl
		var grid_ref := _marquee_grid
		var is_stash_ref := _marquee_is_stash
		var raw_rect: Variant = ctrl_ref.get_meta("marquee_rect", Rect2()) if is_instance_valid(ctrl_ref) else Rect2()
		var m_rect: Rect2 = raw_rect if raw_rect is Rect2 else Rect2()
		_cancel_marquee_selection()
		if is_instance_valid(ctrl_ref) and grid_ref:
			if m_rect.size.x >= 6.0 or m_rect.size.y >= 6.0:
				_apply_marquee_selection(m_rect, grid_ref, is_stash_ref, ctrl_ref)
			ctrl_ref.queue_redraw()
		get_viewport().set_input_as_handled()

func _start_drag(src_name: String, item_dict: Dictionary, cell_pos: Vector2i, slot_key: String = "", source_grid: InventoryGrid = null) -> void:
	if is_dragging:
		_end_drag()
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
		"started_with_lmb": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"source_grid": resolved_grid
	}
	
	if tooltip: tooltip.hide()
	_rebuild_drag_preview()
	_highlight_compatible_slots(item_dict, null)

func _rebuild_drag_preview() -> void:
	if drag_preview_node and is_instance_valid(drag_preview_node):
		drag_preview_node.visible = false
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
	InventoryUIHelper.update_drag_preview_position(drag_preview_node, drag_data, get_global_mouse_position(), _drag_preview_cell_size)

func _end_drag() -> void:
	if is_dragging:
		InventoryUIHelper.rollback_split_drag(drag_data)
	is_dragging = false
	drag_data.clear()
	hovered_player_cell = Vector2i(-1, -1)
	hovered_stash_cell = Vector2i(-1, -1)
	if drag_preview_node and is_instance_valid(drag_preview_node):
		drag_preview_node.visible = false
		drag_preview_node.queue_free()
	drag_preview_node = null
	if tooltip and is_instance_valid(tooltip):
		tooltip.hide()
	_clear_slot_highlights()
	if player_grid_control and is_instance_valid(player_grid_control): player_grid_control.queue_redraw()
	if stash_grid_control and is_instance_valid(stash_grid_control): stash_grid_control.queue_redraw()
	InventoryUIHelper.clear_popup_drag_hover(open_container_popups)

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
		InventoryUIHelper.log_grid_place_failure(dest_grid, item, cell_x, cell_y, place_w, place_h)
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
			EventBus.event_logged.emit("[icon:warn] [%s] 슬롯에 장착할 수 없는 아이템입니다." % slot_name)
		_end_drag()
		return

	if slot_name == "backpack":
		var inner_arr = item.get("inner_items", [])
		if inner_arr is Array and not inner_arr.is_empty():
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 내부에 아이템이 들어있는 가방은 비운 후 장착할 수 있습니다.")
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
					EventBus.event_logged.emit("[icon:warn] 창고와 가방 공간이 부족하여 장비를 교체할 수 없습니다.")
				_update_equipment_ui()
				_end_drag()
				return
		
	_update_equipment_ui()
	if SoundManager: SoundManager.play("menu_select")
	_end_drag()

func _is_slot_compatible(item_id: String, slot_name: String) -> bool:
	return InventoryUIHelper.is_slot_compatible(item_id, slot_name)

func _update_equipment_ui() -> void:
	_render_equip_slot_button(helmet_slot, "helmet", "헬멧")
	_render_equip_slot_button(vest_slot, "vest", "방탄복")
	_render_equip_slot_button(backpack_slot, "backpack", "배낭 (용량 결정)")
	_render_equip_slot_button(bottom_slot, "bottom", "하의/신발")
	
	_render_equip_slot_button(primary1_slot, "primary1", "주무기 1")
	_render_equip_slot_button(primary2_slot, "primary2", "주무기 2")
	_render_equip_slot_button(sidearm_slot, "sidearm", "보조 무기")
	_render_equip_slot_button(throwable_slot, "throwable", "투척 무기")
	if is_instance_valid(character_paperdoll_preview):
		character_paperdoll_preview.update_equipment(equipment_data)

func _render_equip_slot_button(btn: Button, slot_name: String, default_text: String) -> void:
	InventoryUIHelper.render_equip_slot_button(btn, slot_name, default_text, equipment_data)

func _open_split_dialog(item: Dictionary, on_confirm_callback: Callable) -> void:
	InventoryUIHelper.open_split_dialog(self, SplitDialogScene, item, on_confirm_callback)
	_refresh_stash_ui()

# ============================================================
# 상인 거래소 & 3단 일괄 판매 UI 로직
# ============================================================
func _setup_traders_bulk_ui() -> void:
	HideoutTraderHelper.setup_traders_bulk_ui(self)

func _setup_market_controls() -> void:
	HideoutMarketHelper.setup_market_controls(self)

func _select_trader(trader_id: String) -> void:
	current_trader_id = trader_id
	_refresh_trader_ui()

func _refresh_trader_ui() -> void:
	HideoutTraderHelper.refresh_trader_ui(self)

func _refresh_trader_sell_ui() -> void:
	HideoutTraderHelper.refresh_trader_sell_ui(self)

func _toggle_sell_selection(item: Dictionary, mgr: InventoryGrid, is_stash: bool) -> void:
	HideoutTraderHelper.toggle_sell_selection(self, item, mgr, is_stash)

func _auto_select_bulk_sell(mode: String) -> void:
	HideoutTraderHelper.auto_select_bulk_sell(self, mode)

func _execute_bulk_sell() -> void:
	HideoutTraderHelper.execute_bulk_sell(self)

func _handle_sell_grid_input(event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	HideoutTraderHelper.handle_sell_grid_input(self, event, ctrl, mgr, is_stash)

func _apply_marquee_selection(m_rect: Rect2, mgr: InventoryGrid, is_stash: bool, ctrl: Control = null) -> void:
	HideoutTraderHelper.apply_marquee_selection(self, m_rect, mgr, is_stash, ctrl)

func _buy_item(item_id: String, amount: int, price: int) -> void:
	HideoutTraderHelper.buy_item(self, item_id, amount, price)

func _sell_item(uid: String, is_stash: bool, item_id: String, amount: int, unit_price: int) -> void:
	HideoutTraderHelper.sell_item(self, uid, is_stash, item_id, amount, unit_price)

# ============================================================
# 플리마켓 UI 로직
# ============================================================
func _refresh_market_ui() -> void:
	HideoutMarketHelper.refresh_market_ui(self)

func _is_market_item_registerable(item: Dictionary) -> Dictionary:
	return HideoutMarketHelper.is_market_item_registerable(item)

func _does_market_item_match_filter(item: Dictionary) -> bool:
	return HideoutMarketHelper.does_market_item_match_filter(self, item)

func _refresh_market_register_ui() -> void:
	HideoutMarketHelper.refresh_market_register_ui(self)

func _refresh_market_selection_preview() -> void:
	HideoutMarketHelper.refresh_market_selection_preview(self)

func _handle_market_grid_input(event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	HideoutMarketHelper.handle_market_grid_input(self, event, ctrl, mgr, is_stash)

func _try_register_selected_market_item() -> void:
	HideoutMarketHelper.try_register_selected_market_item(self)

func _buy_market_item(listing: Dictionary, total_price: int) -> void:
	HideoutMarketHelper.buy_market_item(self, listing, total_price)

func _register_market_item(uid: String, is_stash: bool, item_id: String, amount: int, ask_unit_price: int) -> void:
	HideoutMarketHelper.register_market_item(self, uid, is_stash, item_id, amount, ask_unit_price)

# ============================================================
# 중첩 컨테이너 팝업창 & 잠금 [L] & 컨텍스트 메뉴
# ============================================================
func _sync_all_open_popups() -> void:
	InventoryUIHelper.sync_all_open_popups(open_container_popups)

func close_all_container_popups() -> void:
	InventoryUIHelper.close_all_container_popups(open_container_popups)

func _prune_stale_popups() -> void:
	var eq_vest: Dictionary = equipment_data.get("vest", {})
	InventoryUIHelper.prune_and_rebind_popups(
		open_container_popups,
		[player_grid_mgr, stash_grid_mgr],
		[eq_vest]
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
			var split_item: Dictionary = InventoryUIHelper.prepare_split_drag_item(it, int(split_amt), p_win.inner_grid)
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
	var pop_lock: int = InventoryUIHelper.toggle_lock_in_top_popup(self, m_pos, tooltip, false)
	if pop_lock != 0:
		return pop_lock > 0
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
		context_menu_panel.visible = false
		context_menu_panel.queue_free()
	context_menu_panel = null

func _show_context_menu(item: Dictionary, source_type: String, slot_ref: String = "", source_grid: InventoryGrid = null) -> void:
	_close_context_menu()
	var item_id := str(item.get("id", ""))
	var idata := ItemDatabase.get_item_data(item_id)
	var item_name := str(idata.get("name", item_id))

	var shell: Dictionary = InventoryUIHelper.create_context_menu_shell(item_name, "ContextMenuPanel", Color(0.92, 0.86, 0.42))
	context_menu_panel = shell["panel"] as PanelContainer
	var vbox: VBoxContainer = shell["vbox"] as VBoxContainer

	if InventoryGrid.is_container_item(item) and (source_type in ["player_grid", "stash_grid"] or (source_type == "equipment" and slot_ref == "vest")):
		_add_context_menu_btn(vbox, "포켓 열기" if source_type == "equipment" else "컨테이너 열기", func():
			_close_context_menu()
			open_container_popup(item, source_grid if source_type in ["player_grid", "stash_grid"] else null)
		, "folder")

	if source_type in ["player_grid", "stash_grid", "popup_grid"] and source_grid:
		var is_locked := bool(item.get("locked", false))
		_add_context_menu_btn(vbox, "잠금 해제 (L)" if is_locked else "아이템 잠금 (L)", func():
			_close_context_menu()
			source_grid.toggle_item_lock(str(item.get("uid", "")))
			if SoundManager: SoundManager.play("menu_select")
		, "unlock" if is_locked else "lock")

	if source_type in ["player_grid", "stash_grid"]:
		_add_context_menu_btn(vbox, "빠른 이동 / 장착", func():
			_close_context_menu()
			_handle_hideout_quick_action(item, source_type == "player_grid")
		, "export_out")
	elif source_type == "popup_grid" and source_grid:
		var pop_ref: ContainerPopupWindow = open_container_popups.get(source_grid.owner_container_uid, null) as ContainerPopupWindow
		if pop_ref:
			_add_context_menu_btn(vbox, "밖으로 꺼내기", func():
				_close_context_menu()
				_handle_popup_quick_action(pop_ref, item, true)
			, "export_out")
	elif source_type == "equipment" and slot_ref != "":
		_add_context_menu_btn(vbox, "창고/가방으로 장착 해제", func():
			_close_context_menu()
			var equipped: Dictionary = equipment_data.get(slot_ref, {})
			if equipped.is_empty():
				return
			var rem := stash_grid_mgr.auto_add_item(equipped.get("id", ""), equipped.get("amount", 1), equipped)
			if rem > 0:
				var overflow := equipped.duplicate(true)
				overflow["amount"] = rem
				rem = player_grid_mgr.auto_add_item(overflow.get("id", ""), rem, overflow)
			if rem <= 0:
				equipment_data[slot_ref] = {}
				_apply_backpack_grid_size()
				_update_equipment_ui()
				if SoundManager: SoundManager.play("menu_select")
			elif EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:warn] 창고와 가방 공간이 부족하여 장착을 해제할 수 없습니다.")
		, "export_out")

	add_child(context_menu_panel)
	var mpos := get_global_mouse_position() - global_position
	context_menu_panel.position = InventoryUIHelper.clamp_popup_position(context_menu_panel, mpos, size, 8.0)

func _add_context_menu_btn(vbox: VBoxContainer, text_str: String, cb: Callable, icon_key: String = "") -> void:
	InventoryUIHelper.add_context_menu_btn(vbox, text_str, cb, false, icon_key)

# ============================================================
# 결과 팝업 및 네비게이션
# ============================================================
func _check_last_raid_result() -> void:
	if GameManager and not GameManager.last_raid_result.is_empty():
		var res = GameManager.last_raid_result
		result_dialog.visible = true
		var desc_lines: Array[String] = []
		if res["result"] == "survived":
			if UiIconManager:
				UiIconManager.set_label_icon(result_title, "celebrate", "탈출 성공! (SURVIVED)", 22, 8, true)
			else:
				result_title.text = "탈출 성공! (SURVIVED)"
			result_title.add_theme_color_override("font_color", Color.GREEN)
			desc_lines.append("안전하게 은신처로 복귀했습니다.\n획득한 전리품이 배낭에 보존되었습니다.")
		elif res["result"] == "kia":
			if UiIconManager:
				UiIconManager.set_label_icon(result_title, "skull", "작전 중 사망 (KIA)", 22, 8, true)
			else:
				result_title.text = "작전 중 사망 (KIA)"
			result_title.add_theme_color_override("font_color", Color.RED)
			desc_lines.append("레이드 도중 사망했습니다.\n2x2 안전 파우치 외의 일반 배낭 아이템을 잃었습니다.")
		elif res["result"] == "mia":
			if UiIconManager:
				UiIconManager.set_label_icon(result_title, "hourglass", "작전 시간 초과 (MIA)", 22, 8, true)
			else:
				result_title.text = "작전 시간 초과 (MIA)"
			result_title.add_theme_color_override("font_color", Color.ORANGE)
			desc_lines.append("제한 시간 내에 탈출하지 못해 실종되었습니다.")
			
		var ic := func(k: String) -> String:
			return (UiIconManager.bbcode_icon(k, 14) + " ") if UiIconManager else ""
		var kills_cnt = int(res.get("kills", 0))
		var t_spent = int(res.get("time_spent", 0.0))
		desc_lines.append("")
		desc_lines.append("%s이번 레이드 처치: %d명  |  %s작전 시간: %d분 %d초" % [ic.call("swords"), kills_cnt, ic.call("stopwatch"), int(float(t_spent) / 60.0), t_spent % 60])
		
		if res.get("insurance_claimed", false):
			desc_lines.append("%s장비 보험 적용 완료: 장착 중이던 무기 및 방어구가 안전하게 회수되었습니다." % ic.call("shield_green"))
		var pouch_cnt = int(res.get("pouch_saved_count", 0))
		if pouch_cnt > 0:
			desc_lines.append("%s2x2 안전 파우치 보호: 귀중품 %d종이 분실되지 않고 보존되었습니다." % [ic.call("lock_gold"), pouch_cnt])
		
		var passive_inc = int(res.get("passive_income", 0))
		var landmark_bon = int(res.get("landmark_bonus", 0))
		if landmark_bon > 0:
			desc_lines.append("%s랜드마크 현장 단말기 작전 보너스: +%d RUB" % [ic.call("signal"), landmark_bon])
			_update_money_label()
			
		if passive_inc > 0:
			desc_lines.append("%s발전기/채굴 서버 패시브 수익: +%d RUB" % [ic.call("power"), passive_inc])
			_update_money_label()
			
		var sales_report = res.get("sales_report", {})
		var completed_sales = sales_report.get("completed", [])
		if not completed_sales.is_empty():
			var total_earned = 0
			for s in completed_sales:
				total_earned += int(s.get("earned", 0))
			desc_lines.append("")
			desc_lines.append("%s플리마켓 정산: 등록 물품 %d건 판매 완료 (+%d RUB)" % [ic.call("chart_up"), completed_sales.size(), total_earned])
			_update_money_label()
		var returned_sales = sales_report.get("returned_items", [])
		if returned_sales is Array and not returned_sales.is_empty():
			desc_lines.append("%s플리마켓 기간 만료 물품 %d건이 은신처 창고로 반송되었습니다." % [ic.call("box"), returned_sales.size()])
		
		result_desc.text = "[center]%s[/center]" % "\n".join(desc_lines)
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

func _cleanup_transient_ui_state() -> void:
	if is_dragging:
		_end_drag()
	_cancel_marquee_selection()
	_close_context_menu()
	if tooltip and is_instance_valid(tooltip):
		tooltip.hide()

func _on_raid_pressed() -> void:
	_cleanup_transient_ui_state()
	if workbench and workbench.has_method("_cancel_pending_preset_preview"):
		workbench._cancel_pending_preset_preview()
	if SoundManager: SoundManager.play("menu_select")
	_sync_save_data()
	if GameManager: GameManager.start_raid()

func _on_menu_pressed() -> void:
	_cleanup_transient_ui_state()
	if SoundManager: SoundManager.play("menu_select")
	if GameManager:
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)
		GameManager.change_state(GameManager.GameState.MAIN_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_current_inventory_window) or is_instance_valid(current_settings_window):
		return
	var focus_owner := get_viewport().gui_get_focus_owner() if (is_inside_tree() and get_viewport()) else null
	if focus_owner is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			_open_weapon_modding_window()
		elif event.physical_keycode == KEY_F1:
			if GameManager and GameManager.is_sandbox_mode():
				_open_item_spawner()
		elif event.physical_keycode == KEY_F2:
			_open_shooting_range()
		elif event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I:
			_open_inventory_window()

func _open_shooting_range() -> void:
	_cleanup_transient_ui_state()
	if workbench and workbench.has_method("_close_confirm_dialog"):
		workbench._close_confirm_dialog()
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
	if is_instance_valid(_current_inventory_window):
		return
	_cleanup_transient_ui_state()
	_sync_all_open_popups()
	close_all_container_popups()
	var inv_scene = preload("res://scenes/ui/inventory_window.tscn")
	if inv_scene:
		var win = inv_scene.instantiate()
		_current_inventory_window = win
		add_child(win)
		win.set("hideout_stash_grid", stash_grid_mgr)
		win.setup(null, player_grid_mgr, equipment_data)
		win.window_closed.connect(func():
			_current_inventory_window = null
			_on_grid_changed()
		)

func _open_item_spawner() -> void:
	if not (GameManager and GameManager.is_sandbox_mode()):
		return
	_cleanup_transient_ui_state()
	if workbench and workbench.has_method("_close_confirm_dialog"):
		workbench._close_confirm_dialog()
	var spawner_scene = preload("res://scenes/ui/item_spawner_window.tscn")
	if spawner_scene:
		var win = spawner_scene.instantiate()
		add_child(win)
		win.window_closed.connect(func(): _on_grid_changed())

func _open_settings_window() -> void:
	if is_instance_valid(current_settings_window):
		return
	_cleanup_transient_ui_state()
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
