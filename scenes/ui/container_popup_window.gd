# res://scenes/ui/container_popup_window.gd
class_name ContainerPopupWindow
extends PanelContainer

## 타르코프식 중첩 컨테이너('가방 안 가방' / 조끼 / 특수 보관함) 드래그 가능 팝업 창

signal popup_closed(container_uid: String)
signal popup_grid_changed(container_uid: String)
signal item_drag_started(popup: ContainerPopupWindow, item: Dictionary, cell_pos: Vector2i)
signal item_split_requested(popup: ContainerPopupWindow, item: Dictionary, cell_pos: Vector2i)
signal item_quick_action_requested(popup: ContainerPopupWindow, item: Dictionary, is_ctrl: bool)
signal item_context_menu_requested(popup: ContainerPopupWindow, item: Dictionary)
signal item_hovered(popup: ContainerPopupWindow, item: Dictionary)
signal item_unhovered(popup: ContainerPopupWindow)

const POPUP_CELL_SIZE: float = InventoryUIHelper.POPUP_CELL_SIZE
const SEARCH_DURATION_PER_ITEM: float = 0.65

var container_item: Dictionary = {}
var _searching_uid: String = ""
var _search_elapsed: float = 0.0
var _search_status_label: Label = null
var container_uid: String = ""
var source_grid: InventoryGrid = null
var inner_grid: InventoryGrid = null
var parent_host: Control = null

var hovered_cell: Vector2i = Vector2i(-1, -1)
var _is_dragging_window: bool = false
var _window_drag_offset: Vector2 = Vector2.ZERO
var _syncing_back: bool = false

var header_panel: PanelContainer = null
var title_label: Label = null
var filter_label: Label = null
var sort_btn: Button = null
var close_btn: Button = null
var scroll_container: ScrollContainer = null
var grid_panel: PanelContainer = null
var grid_control: Control = null

func _init() -> void:
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func setup(p_container_item: Dictionary, p_source_grid: InventoryGrid, p_host: Control) -> void:
	container_item = p_container_item
	container_uid = str(p_container_item.get("uid", ""))
	if container_uid == "":
		container_uid = "equip_" + str(p_container_item.get("id", "container"))
	source_grid = p_source_grid
	parent_host = p_host

	var item_id := str(p_container_item.get("id", ""))
	var item_data: Dictionary = ItemDatabase.get_item_data(item_id) if ItemDatabase else {}
	var spec := InventoryGrid.get_container_spec(p_container_item)
	var gw := maxi(1, int(spec.get("grid_w", 4)))
	var gh := maxi(1, int(spec.get("grid_h", 4)))
	var filter_kind := str(spec.get("allowed_filter", ""))

	inner_grid = InventoryGrid.new()
	inner_grid.name = "PopupInnerGrid"
	inner_grid.grid_width = gw
	inner_grid.grid_height = gh
	inner_grid.has_secure_container = false
	inner_grid.container_depth = 1
	inner_grid.owner_container_uid = container_uid
	inner_grid.allowed_filter = filter_kind
	add_child(inner_grid)

	var saved_inner = p_container_item.get("inner_items", [])
	if saved_inner is Array:
		inner_grid.load_items(saved_inner)
	InventoryGrid.sync_container_item_contents(container_item, inner_grid)

	inner_grid.grid_changed.connect(_on_inner_grid_changed)

	_build_ui(item_id, item_data, gw, gh, filter_kind)
	_refresh_header_text()
	_advance_search_target()

func _build_ui(item_id: String, item_data: Dictionary, gw: int, gh: int, filter_kind: String) -> void:
	if PixelAssetManager:
		var frame_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("popup_frame", 6.0, 6.0, 6.0, 6.0, 4)
		if frame_sb != null:
			add_theme_stylebox_override("panel", frame_sb)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# 상단 드래그 가능 타이틀 바
	header_panel = PanelContainer.new()
	header_panel.theme_type_variation = &"HeaderPanel"
	header_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_panel.gui_input.connect(_on_header_gui_input)
	root_vbox.add_child(header_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_child(hbox)

	if ItemIconManager:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = ItemIconManager.get_icon(item_id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if PixelAssetManager:
		title_label.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
		title_label.add_theme_font_size_override("font_size", 12)
	else:
		title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.42))
	title_label.text = str(item_data.get("name", item_id))
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_label)

	sort_btn = Button.new()
	sort_btn.theme_type_variation = &"SmallButton"
	sort_btn.text = "정렬"
	sort_btn.custom_minimum_size = Vector2(38, 22)
	if PixelAssetManager:
		sort_btn.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
	sort_btn.add_theme_font_size_override("font_size", 10)
	sort_btn.focus_mode = Control.FOCUS_NONE
	sort_btn.pressed.connect(func():
		if inner_grid:
			inner_grid.sort_items()
			if SoundManager: SoundManager.play("menu_select")
	)
	hbox.add_child(sort_btn)

	close_btn = Button.new()
	close_btn.theme_type_variation = &"DangerButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 22)
	if PixelAssetManager:
		close_btn.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_popup)
	hbox.add_child(close_btn)

	if filter_kind != "":
		var filter_names := {
			"ammo": "수납 제한: 탄약 전용",
			"medical": "수납 제한: 의약품 전용",
			"weapon_part": "수납 제한: 총기 부품 전용",
			"dogtag_key": "수납 제한: 인식표·열쇠·키카드 전용"
		}
		filter_label = Label.new()
		filter_label.text = filter_names.get(filter_kind, "")
		filter_label.add_theme_font_size_override("font_size", 10)
		filter_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		root_vbox.add_child(filter_label)
		if UiIconManager and filter_label.text != "":
			UiIconManager.set_label_icon(filter_label, "lock", "", 12, 4)

	# 2D 내부 그리드 영역
	var grid_px_w := float(gw) * POPUP_CELL_SIZE
	var grid_px_h := float(gh) * POPUP_CELL_SIZE
	custom_minimum_size.x = maxf(minf(grid_px_w + 26.0, 316.0), 272.0)

	_search_status_label = Label.new()
	_search_status_label.name = "SearchStatusLabel"
	_search_status_label.add_theme_font_size_override("font_size", 11)
	_search_status_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.34, 1.0))
	_search_status_label.visible = false
	root_vbox.add_child(_search_status_label)

	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(minf(grid_px_w + 14.0, 290.0), minf(grid_px_h + 14.0, 290.0))
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll_container)

	grid_panel = PanelContainer.new()
	grid_panel.theme_type_variation = &"GridSurfacePanel"
	scroll_container.add_child(grid_panel)

	grid_control = Control.new()
	grid_control.name = "PopupGridControl"
	grid_control.custom_minimum_size = Vector2(grid_px_w, grid_px_h)
	grid_control.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_control.draw.connect(_on_grid_draw)
	grid_control.gui_input.connect(_on_grid_gui_input)
	grid_control.mouse_exited.connect(func():
		hovered_cell = Vector2i(-1, -1)
		item_unhovered.emit(self)
		grid_control.queue_redraw()
	)
	grid_panel.add_child(grid_control)
	_update_search_ui()
	reset_size()

static func is_item_unsearched(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if bool(item.get("unsearched", false)):
		return true
	var cdata = item.get("custom_data", {})
	return cdata is Dictionary and bool(cdata.get("unsearched", false))

static func clear_item_unsearched(item: Dictionary) -> void:
	if item.is_empty():
		return
	item.erase("unsearched")
	var cdata = item.get("custom_data", {})
	if cdata is Dictionary:
		cdata.erase("unsearched")

func _find_sort_button() -> Button:
	var prop_btn = get("sort_btn")
	if prop_btn is Button:
		return prop_btn
	if header_panel and is_instance_valid(header_panel):
		for ch in header_panel.find_children("*", "Button", true, false):
			if ch is Button and (ch.name.to_lower().contains("sort") or ch.text.contains("정렬")):
				return ch
	return null

func get_unsearched_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if inner_grid == null:
		return out
	for it in inner_grid.items:
		if it is Dictionary and not it.is_empty() and is_item_unsearched(it):
			out.append(it)
	return out

func has_unsearched_items() -> bool:
	return not get_unsearched_items().is_empty()

func _update_search_ui() -> void:
	var rem := get_unsearched_items().size()
	var s_btn := _find_sort_button()
	if s_btn and is_instance_valid(s_btn):
		s_btn.disabled = (rem > 0)
	if _search_status_label and is_instance_valid(_search_status_label):
		if rem > 0:
			_search_status_label.visible = true
			_search_status_label.text = "가방 수색 중... (남은 물품 %d개)" % rem
		else:
			_search_status_label.visible = false
			_search_status_label.text = ""

func _advance_search_target() -> void:
	if inner_grid == null:
		_searching_uid = ""
		_search_elapsed = 0.0
		return
	var unsearched := get_unsearched_items()
	if unsearched.is_empty():
		_searching_uid = ""
		_search_elapsed = 0.0
	else:
		var keep_current := false
		if _searching_uid != "":
			for it in unsearched:
				if str(it.get("uid", "")) == _searching_uid:
					keep_current = true
					break
		if not keep_current:
			_searching_uid = str(unsearched[0].get("uid", ""))
			_search_elapsed = 0.0
	inner_grid.set_meta("searching_item_uid", _searching_uid)
	inner_grid.set_meta("search_progress", clampf(_search_elapsed / SEARCH_DURATION_PER_ITEM, 0.0, 1.0) if _searching_uid != "" else 0.0)
	_update_search_ui()
	if grid_control and is_instance_valid(grid_control):
		grid_control.queue_redraw()

func reveal_next_unsearched_item() -> Dictionary:
	_advance_search_target()
	if _searching_uid == "" or inner_grid == null:
		return {}
	var revealed: Dictionary = {}
	for it in inner_grid.items:
		if it is Dictionary and str(it.get("uid", "")) == _searching_uid and is_item_unsearched(it):
			clear_item_unsearched(it)
			revealed = it
			break
	if revealed.is_empty():
		return {}
	_searching_uid = ""
	_search_elapsed = 0.0
	if is_inside_tree() and SoundManager:
		SoundManager.play("menu_select")
	_on_inner_grid_changed()
	return revealed

func _process(delta: float) -> void:
	if not visible or inner_grid == null:
		return
	if not has_unsearched_items():
		if _searching_uid != "":
			_advance_search_target()
		return
	if _searching_uid == "":
		_advance_search_target()
	if _searching_uid == "":
		return
	_search_elapsed += delta
	inner_grid.set_meta("search_progress", clampf(_search_elapsed / SEARCH_DURATION_PER_ITEM, 0.0, 1.0))
	if _search_elapsed >= SEARCH_DURATION_PER_ITEM:
		reveal_next_unsearched_item()
	elif grid_control and is_instance_valid(grid_control):
		grid_control.queue_redraw()

func _refresh_header_text() -> void:
	if not title_label or container_item.is_empty() or inner_grid == null:
		return
	var item_id := str(container_item.get("id", ""))
	var d: Dictionary = ItemDatabase.get_item_data(item_id) if ItemDatabase else {}
	var disp := str(d.get("name", item_id))
	var inner_w := inner_grid.get_total_weight()
	title_label.text = "%s (%dx%d | %.1fkg)" % [disp, inner_grid.grid_width, inner_grid.grid_height, inner_w]

func _on_inner_grid_changed() -> void:
	if _syncing_back:
		return
	_syncing_back = true
	InventoryGrid.sync_container_item_contents(container_item, inner_grid)
	_refresh_header_text()
	_advance_search_target()
	if grid_control:
		grid_control.queue_redraw()
	if source_grid and is_instance_valid(source_grid):
		source_grid.grid_changed.emit()
	popup_grid_changed.emit(container_uid)
	_syncing_back = false

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			move_to_front()
			_is_dragging_window = true
			_window_drag_offset = get_global_mouse_position() - global_position
		else:
			_is_dragging_window = false
	elif event is InputEventMouseMotion and _is_dragging_window:
		var host_size := parent_host.size if (parent_host and is_instance_valid(parent_host)) else get_viewport_rect().size
		var desired := get_global_mouse_position() - _window_drag_offset
		if parent_host and is_instance_valid(parent_host):
			desired -= parent_host.global_position
		position = InventoryUIHelper.clamp_popup_position(self, desired, host_size, 8.0)

func _on_grid_draw() -> void:
	if not grid_control or not inner_grid:
		return
	var host_dragging := false
	var host_drag_data: Dictionary = {}
	if parent_host and is_instance_valid(parent_host):
		if "is_dragging" in parent_host:
			host_dragging = bool(parent_host.is_dragging)
		if "drag_data" in parent_host and parent_host.drag_data is Dictionary:
			host_drag_data = parent_host.drag_data
	InventoryUIHelper.draw_2d_grid(grid_control, inner_grid, hovered_cell, false, host_dragging, host_drag_data, POPUP_CELL_SIZE)

func _on_grid_gui_input(event: InputEvent) -> void:
	if not grid_control or not inner_grid:
		return
	var local_pos := grid_control.get_local_mouse_position()
	var cell_x := int(floor(local_pos.x / POPUP_CELL_SIZE))
	var cell_y := int(floor(local_pos.y / POPUP_CELL_SIZE))

	if event is InputEventMouseMotion:
		if cell_x >= 0 and cell_x < inner_grid.grid_width and cell_y >= 0 and cell_y < inner_grid.grid_height:
			hovered_cell = Vector2i(cell_x, cell_y)
			var h_item := inner_grid.get_item_at(cell_x, cell_y)
			if not h_item.is_empty() and not ContainerPopupWindow.is_item_unsearched(h_item):
				item_hovered.emit(self, h_item)
			else:
				item_unhovered.emit(self)
		else:
			hovered_cell = Vector2i(-1, -1)
			item_unhovered.emit(self)
		grid_control.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		move_to_front()
		var item := inner_grid.get_item_at(cell_x, cell_y)
		if item.is_empty() or ContainerPopupWindow.is_item_unsearched(item):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_CTRL):
				item_quick_action_requested.emit(self, item, true)
			elif Input.is_key_pressed(KEY_SHIFT) and int(item.get("amount", 1)) > 1:
				item_split_requested.emit(self, item, Vector2i(cell_x, cell_y))
			else:
				item_drag_started.emit(self, item, Vector2i(cell_x, cell_y))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.alt_pressed or Input.is_key_pressed(KEY_ALT):
				item_context_menu_requested.emit(self, item)
			else:
				item_quick_action_requested.emit(self, item, false)

func update_drag_hover(m_global_pos: Vector2, drag_item: Dictionary, is_rot: bool) -> bool:
	if not grid_control or not inner_grid or not is_visible_in_tree():
		return false
	var cell := InventoryUIHelper.calc_drag_drop_cell(grid_control, m_global_pos, inner_grid, {"item": drag_item, "rotated": is_rot}, POPUP_CELL_SIZE)
	if cell != Vector2i(-1, -1):
		hovered_cell = cell
		grid_control.queue_redraw()
		return true
	if hovered_cell != Vector2i(-1, -1):
		hovered_cell = Vector2i(-1, -1)
		grid_control.queue_redraw()
	return false

func get_drop_cell(m_global_pos: Vector2, drag_item: Dictionary, is_rot: bool) -> Vector2i:
	if not grid_control or not inner_grid:
		return Vector2i(-1, -1)
	return InventoryUIHelper.calc_drag_drop_cell(grid_control, m_global_pos, inner_grid, {"item": drag_item, "rotated": is_rot}, POPUP_CELL_SIZE)

func get_hovered_item() -> Dictionary:
	if not grid_control or not inner_grid:
		return {}
	if not grid_control.get_global_rect().has_point(get_global_mouse_position()):
		return {}
	var local_pos := grid_control.get_local_mouse_position()
	var cx := int(floor(local_pos.x / POPUP_CELL_SIZE))
	var cy := int(floor(local_pos.y / POPUP_CELL_SIZE))
	var h_item := inner_grid.get_item_at(cx, cy)
	return {} if ContainerPopupWindow.is_item_unsearched(h_item) else h_item

func _input(event: InputEvent) -> void:
	if _is_dragging_window and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging_window = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not visible):
		_is_dragging_window = false
		hovered_cell = Vector2i(-1, -1)
		if is_instance_valid(grid_control):
			grid_control.queue_redraw()
		item_unhovered.emit(self)

func close_popup() -> void:
	_is_dragging_window = false
	visible = false
	item_unhovered.emit(self)
	popup_closed.emit(container_uid)
	queue_free()
