# res://scenes/test/ui_preview.gd
extends Control

## UI 테마 및 인벤토리/툴팁/컴포넌트 단독 검증 샌드박스 씬 (F6 실행용)

const InventoryWindowScene = preload("res://scenes/ui/inventory_window.tscn")
const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
const NewGameWindowScene = preload("res://scenes/main_menu/new_game_custom_window.tscn")
const SettingsWindowScene = preload("res://scenes/ui/settings_window.tscn")

@onready var preview_grid_ctrl: Control = $MainMargin/VBox/ContentHBox/RightCol/GridPanel/Center/PreviewGridControl
@onready var open_inv_btn: Button = $MainMargin/VBox/HeaderPanel/HeaderHBox/OpenInvBtn
@onready var open_newgame_btn: Button = $MainMargin/VBox/HeaderPanel/HeaderHBox/OpenNewGameBtn
@onready var open_settings_btn: Button = $MainMargin/VBox/HeaderPanel/HeaderHBox/OpenSettingsBtn
@onready var repopulate_btn: Button = $MainMargin/VBox/ContentHBox/RightCol/RightHeader/HBox/RepopulateBtn
@onready var sort_btn: Button = $MainMargin/VBox/ContentHBox/RightCol/RightHeader/HBox/SortBtn
@onready var equip_helmet_btn: Button = $MainMargin/VBox/ContentHBox/LeftCol/ComponentsPanel/VBox/EquipRow/HelmetBtn
@onready var equip_vest_btn: Button = $MainMargin/VBox/ContentHBox/LeftCol/ComponentsPanel/VBox/EquipRow/VestBtn
@onready var equip_pack_btn: Button = $MainMargin/VBox/ContentHBox/LeftCol/ComponentsPanel/VBox/EquipRow/PackBtn

var sample_grid: InventoryGrid = null
var sample_container: Inventory = null
var hovered_cell: Vector2i = Vector2i(-1, -1)
var tooltip: PanelContainer = null

func _ready() -> void:
	InventoryUIHelper.init_cached_styleboxes()
	
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)
	tooltip.hide()
	
	sample_grid = InventoryGrid.new()
	sample_grid.grid_width = 6
	sample_grid.grid_height = 5
	add_child(sample_grid)
	sample_grid.grid_changed.connect(func(): preview_grid_ctrl.queue_redraw())
	
	sample_container = Inventory.new()
	sample_container.max_slots = 12
	add_child(sample_container)
	
	_populate_sample_items()
	_setup_sample_equip_icons()
	
	var cell_px = InventoryUIHelper.CELL_SIZE
	preview_grid_ctrl.custom_minimum_size = Vector2(sample_grid.grid_width * cell_px, sample_grid.grid_height * cell_px)
	preview_grid_ctrl.draw.connect(_on_preview_grid_draw)
	preview_grid_ctrl.gui_input.connect(_on_preview_grid_input)
	preview_grid_ctrl.mouse_exited.connect(func():
		hovered_cell = Vector2i(-1, -1)
		if tooltip: tooltip.hide()
		preview_grid_ctrl.queue_redraw()
	)
	
	open_inv_btn.pressed.connect(_on_open_full_inventory)
	open_newgame_btn.pressed.connect(_on_open_new_game_modal)
	open_settings_btn.pressed.connect(_on_open_settings_modal)
	repopulate_btn.pressed.connect(_populate_sample_items)
	sort_btn.pressed.connect(func():
		sample_grid.sort_items()
		if SoundManager: SoundManager.play("menu_select")
	)

func _setup_sample_equip_icons() -> void:
	if not ItemIconManager:
		return
	equip_helmet_btn.icon = ItemIconManager.get_icon("2레벨_헬멧")
	equip_helmet_btn.expand_icon = true
	_connect_preview_equip_tooltip(equip_helmet_btn, "2레벨_헬멧")
	
	equip_vest_btn.icon = ItemIconManager.get_icon("2레벨_방탄복")
	equip_vest_btn.expand_icon = true
	_connect_preview_equip_tooltip(equip_vest_btn, "2레벨_방탄복")
	
	equip_pack_btn.icon = ItemIconManager.get_icon("2레벨_가방")
	equip_pack_btn.expand_icon = true
	_connect_preview_equip_tooltip(equip_pack_btn, "2레벨_가방")

func _connect_preview_equip_tooltip(btn: Button, item_id: String) -> void:
	btn.mouse_entered.connect(func():
		if tooltip:
			var idata = ItemDatabase.get_item_data(item_id)
			tooltip.display_item({"id": item_id}, idata)
			tooltip.update_position(get_global_mouse_position())
	)
	btn.mouse_exited.connect(func():
		if tooltip: tooltip.hide()
	)

func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())

func _populate_sample_items() -> void:
	sample_grid.clear()
	sample_grid.auto_add_item("M4_리시버", 1, {"durability": 92.0})
	sample_grid.auto_add_item("구급상자", 1, {"durability": 100.0})
	sample_grid.auto_add_item("5.56mm", 20)
	sample_grid.auto_add_item("전투_식량", 2)
	sample_grid.auto_add_item("수류탄", 2)
	sample_grid.auto_add_item("암호화된 SSD", 1)
	
	sample_container.clear()
	sample_container.add_item("5.56mm", 15)
	sample_container.add_item("5.56mm", 25)
	sample_container.add_item("AK_리시버", 1)
	sample_container.add_item("7.62mm", 30)
	sample_container.add_item("고급_치료킷", 1)
	sample_container.add_item("그래픽카드", 1)
	preview_grid_ctrl.queue_redraw()

func _on_preview_grid_draw() -> void:
	InventoryUIHelper.draw_2d_grid(preview_grid_ctrl, sample_grid, hovered_cell, true, false, {}, InventoryUIHelper.CELL_SIZE)

func _on_preview_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos = preview_grid_ctrl.get_local_mouse_position()
		var cx = int(local_pos.x / InventoryUIHelper.CELL_SIZE)
		var cy = int(local_pos.y / InventoryUIHelper.CELL_SIZE)
		if cx >= 0 and cx < sample_grid.grid_width and cy >= 0 and cy < sample_grid.grid_height:
			hovered_cell = Vector2i(cx, cy)
			var it = sample_grid.get_item_at(cx, cy)
			if not it.is_empty():
				var idata = ItemDatabase.get_item_data(it.get("id", ""))
				tooltip.display_item(it, idata)
				tooltip.update_position(get_global_mouse_position())
			else:
				tooltip.hide()
		else:
			hovered_cell = Vector2i(-1, -1)
			tooltip.hide()
		preview_grid_ctrl.queue_redraw()

func _on_open_full_inventory() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var inv_win = InventoryWindowScene.instantiate()
	add_child(inv_win)
	var sample_equip = {
		"helmet": {"id": "2레벨_헬멧", "name": "2레벨 군용 헬멧"},
		"vest": {"id": "2레벨_방탄복", "name": "2레벨 전술 방탄복"},
		"backpack": {"id": "2레벨_가방", "name": "2레벨 전술 배낭"},
		"bottom": {"id": "운동화", "name": "전술 부츠"},
		"primary1": {"id": "M4_리시버", "name": "M4A1 전술 소총", "attachments": {}},
		"primary2": {},
		"sidearm": {"id": "M9_리시버", "name": "M9 권총", "attachments": {}},
		"throwable": {"id": "수류탄", "amount": 2}
	}
	inv_win.setup(null, sample_grid, sample_equip, sample_container, "군용 무기 보관함 (Supply Crate)")

func _on_open_new_game_modal() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var win = NewGameWindowScene.instantiate()
	add_child(win)

func _on_open_settings_modal() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var win = SettingsWindowScene.instantiate()
	add_child(win)
