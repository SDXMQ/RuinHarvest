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
	if wb_save_btn:
		wb_save_btn.pressed.connect(_save_workbench_weapon)

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

	var title_lbl := Label.new()
	title_lbl.name = "ConfirmTitleLabel"
	title_lbl.text = title_text
	if PixelAssetManager:
		title_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(title_lbl)

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
		wb_preset_buy_btn.text = "🛒 프리셋을 선택해 주세요"
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

func _flatten_parts_dict(parts_dict: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot_k in parts_dict.keys():
		var v = parts_dict[slot_k]
		if v is Array:
			for sub in v:
				var s := String(sub)
				if s != "":
					out.append(s)
		else:
			var s := String(v)
			if s != "":
				out.append(s)
	return out

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
		wb_preset_buy_btn.text = "🛒 프리셋을 선택해 주세요"
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
			EventBus.event_logged.emit("⚠️ 보유 중인 [%s] 부품이 없습니다." % part_id)
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
			EventBus.event_logged.emit("⚠️ 부품 차감에 실패했습니다.")
		return

	if not to_return.is_empty() and not _return_parts_to_storage(to_return):
		# 공간 부족 시 새 부품 복구 후 중단
		_return_parts_to_storage([part_id])
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 창고와 배낭 공간이 부족하여 기존 부품을 교체할 수 없습니다.")
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
			EventBus.event_logged.emit("ℹ️ 프리셋 미리보기가 취소되어 실제 장착 상태로 복원되었습니다.")
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
			EventBus.event_logged.emit("⚠️ 창고와 배낭 공간이 부족하여 부품을 분리할 수 없습니다.")
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
	
	_add_stat_compare_row("💥 데미지", base.get("damage", 20.0), cur_stats.get("damage", 20.0), "%.1f", true)
	_add_stat_compare_row("🎯 정확도", base.get("accuracy", 70.0), cur_stats.get("accuracy", 70.0), "%d%%", true)
	_add_stat_compare_row("⚡ 연사력 (RPM)", base.get("rpm", 150), cur_stats.get("rpm", 150), "%d", true)
	_add_stat_compare_row("🔄 반동 제어", base.get("recoil", 30.0), cur_stats.get("recoil", 30.0), "%.1f", false) # 반동 감소가 좋음
	_add_stat_compare_row("🔭 유효 사거리", base.get("range", 10.0), cur_stats.get("range", 10.0), "%.1fm", true)
	_add_stat_compare_row("🔍 조준경 줌", base.get("zoom", 1.0), cur_stats.get("zoom", 1.0), "%.1fx", true)
	_add_stat_compare_row("📦 탄창 용량", base.get("magazine_size", 15), cur_stats.get("magazine_size", 15), "%d발", true)
	_add_stat_compare_row("🔊 사격 소음", base.get("noise_radius", 600.0), cur_stats.get("noise_radius", 600.0), "%dpx", false) # 소음 감소가 좋음
	_add_stat_compare_row("⚖️ 총기 무게", base.get("weight", 2.0), cur_stats.get("weight", 2.0), "%.2fkg", false) # 무게 감소가 좋음
	_build_repair_controls()
	
	if not wb_selected_weapon.is_empty():
		var sep2 = HSeparator.new()
		wb_stats_vbox.add_child(sep2)
		var test_btn = Button.new()
		test_btn.text = "🎯 사격 시험 (Test Fire)"
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

static func calculate_repair_cost_rubles(cur_dur: float, max_dur: float = 100.0) -> int:
	var missing = max(0.0, max_dur - cur_dur)
	return int(round(missing * 35.0))

static func calculate_repair_cost_scrap(cur_dur: float, max_dur: float = 100.0) -> int:
	var missing = max(0.0, max_dur - cur_dur)
	if missing <= 0.001:
		return 0
	return int(ceil(missing / 20.0))

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
	dur_lbl.text = "🛠️ 총기 내구도: %.1f / %.0f" % [cur_dur, max_dur]
	dur_lbl.add_theme_font_size_override("font_size", 11)
	dur_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if missing <= 0.1 else Color(1.0, 0.78, 0.3))
	wb_stats_vbox.add_child(dur_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	
	var rub_btn = Button.new()
	rub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rub_btn.add_theme_font_size_override("font_size", 10)
	rub_btn.text = "🔧 루블 수리 (%d RUB)" % rub_cost if missing > 0.1 else "✅ 내구도 100%"
	rub_btn.disabled = (missing <= 0.1 or cur_rubles < rub_cost)
	rub_btn.pressed.connect(func(): _repair_selected_weapon(false))
	btn_hbox.add_child(rub_btn)
	
	var scrap_btn = Button.new()
	scrap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrap_btn.add_theme_font_size_override("font_size", 10)
	scrap_btn.text = "🔩 고철 수리 (%d/%d)" % [cur_scrap, scrap_cost] if missing > 0.1 else "🔩 수리 불필요"
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
		var slot_title = "🪖 헬멧" if a_slot == "helmet" else "🦺 방탄복"
		
		var a_row = HBoxContainer.new()
		a_row.add_theme_constant_override("separation", 4)
		var a_lbl = Label.new()
		a_lbl.text = "%s (%.0f/%.0f)" % [slot_title, a_cur, a_max]
		a_lbl.custom_minimum_size = Vector2(92, 0)
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
			"🔧 무기 수리 확인",
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
			"🔧 무기 수리 확인",
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

	if use_scrap:
		var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
		if _get_total_scrap_count() < scrap_cost:
			return
		_consume_scrap(scrap_cost)
	else:
		var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
		var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
		if cur_rubles < rub_cost:
			return
		if GameManager and GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"]["rubles"] = cur_rubles - rub_cost
		money_spent.emit(rub_cost)

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
			"🛡️ 방어구 수리 확인",
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
			"🛡️ 방어구 수리 확인",
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

	if use_scrap:
		var scrap_cost = calculate_repair_cost_scrap(cur_dur, max_dur)
		if _get_total_scrap_count() < scrap_cost:
			return
		_consume_scrap(scrap_cost)
	else:
		var rub_cost = calculate_repair_cost_rubles(cur_dur, max_dur)
		var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
		if cur_rubles < rub_cost:
			return
		if GameManager and GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"]["rubles"] = cur_rubles - rub_cost
		money_spent.emit(rub_cost)

	armor_dict["durability"] = max_dur
	equipment_data[slot_key] = armor_dict
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
	_refresh_workbench_stats_comparison()

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
	if not wb_preset_pending_assembly:
		wb_committed_parts = wb_selected_weapon.get("parts", {}).duplicate(true)
	wb_current_preset_parts = preset_dict.get("parts", {}).duplicate(true)
	wb_missing_preset_parts.clear()
	wb_missing_preset_cost = 0
	
	# 이미 총기에 장착 중인 부품(wb_committed_parts)은 그대로 재사용하고, 나머지 필요 부품만 인벤토리와 대조
	var committed_counts := {}
	for cp in _flatten_parts_dict(wb_committed_parts):
		committed_counts[cp] = int(committed_counts.get(cp, 0)) + 1

	var owned_pool = _get_owned_parts_list()
	for tp in _flatten_parts_dict(wb_current_preset_parts):
		if int(committed_counts.get(tp, 0)) > 0:
			committed_counts[tp] -= 1
		elif not owned_pool.has(tp) or owned_pool[tp] <= 0:
			wb_missing_preset_parts.append(tp)
			var p_val = WeaponPartsDatabase.PARTS.get(tp, {}).get("value", 5000)
			wb_missing_preset_cost += p_val
		else:
			owned_pool[tp] -= 1
				
	# 무기 파츠에 프리셋 적용 (가상 미리보기 — [구매 후 조립] 완료 전까지 실제 저장 차단)
	wb_preset_pending_assembly = true
	wb_selected_weapon["parts"] = wb_current_preset_parts.duplicate(true)
	wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
	
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_current_preset_parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	
	if wb_preset_buy_btn:
		if wb_missing_preset_parts.is_empty():
			wb_preset_buy_btn.text = "🔧 보유 부품으로 프리셋 조립 확정 (0 RUB)"
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

	var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	if wb_missing_preset_cost > 0:
		if cur_rubles < wb_missing_preset_cost:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("❌ 자금이 부족합니다! (필요: %d RUB / 보유: %d RUB)" % [wb_missing_preset_cost, cur_rubles])
			if SoundManager: SoundManager.play("hit_melee")
			return
		var part_names: Array[String] = []
		for i in range(mini(5, wb_missing_preset_parts.size())):
			var pid := str(wb_missing_preset_parts[i])
			part_names.append(str(WeaponPartsDatabase.PARTS.get(pid, {}).get("name", pid)))
		var extra_cnt := wb_missing_preset_parts.size() - part_names.size()
		var list_txt := ", ".join(part_names) + (" 외 %d종" % extra_cnt if extra_cnt > 0 else "")
		_show_confirm_dialog(
			"🛒 부족 부품 구매 후 조립 확인",
			"미보유 부품 %d종(%s)을 시장가 %d RUB에 즉시 구매하여 조립하시겠습니까?\n(현재 보유 자금: %d RUB → 결제 후: %d RUB)" % [
				wb_missing_preset_parts.size(), list_txt, wb_missing_preset_cost, cur_rubles, cur_rubles - wb_missing_preset_cost
			],
			"%d RUB 구매·조립" % wb_missing_preset_cost,
			func(): _execute_buy_and_assemble_preset()
		)
		return

	_execute_buy_and_assemble_preset()

func _execute_buy_and_assemble_preset() -> void:
	if wb_current_preset_parts.is_empty():
		return

	# committed vs target multiset 계산
	var committed_counts := {}
	for cp in _flatten_parts_dict(wb_committed_parts):
		committed_counts[cp] = int(committed_counts.get(cp, 0)) + 1

	var needed_parts: Array[String] = []
	for tp in _flatten_parts_dict(wb_current_preset_parts):
		if int(committed_counts.get(tp, 0)) > 0:
			committed_counts[tp] -= 1
		else:
			needed_parts.append(tp)

	var surplus_parts: Array[String] = []
	for cp in committed_counts.keys():
		var rem_cnt := int(committed_counts[cp])
		for _k in range(rem_cnt):
			surplus_parts.append(String(cp))

	# 미보유/보유 비용 재검증
	var owned_pool := _get_owned_parts_list()
	var inv_consume_parts: Array[String] = []
	var missing_buy_parts: Array[String] = []
	var recalc_cost: int = 0
	for np in needed_parts:
		if int(owned_pool.get(np, 0)) > 0:
			owned_pool[np] -= 1
			inv_consume_parts.append(np)
		else:
			missing_buy_parts.append(np)
			recalc_cost += int(WeaponPartsDatabase.PARTS.get(np, {}).get("value", 5000))

	var cur_rubles = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	if recalc_cost > 0 and cur_rubles < recalc_cost:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("❌ 자금이 부족합니다! (필요: %d RUB / 보유: %d RUB)" % [recalc_cost, cur_rubles])
		if SoundManager: SoundManager.play("hit_melee")
		return

	# 기존 장착 잉여 부품 먼저 창고/배낭 반환 (공간 부족 시 거래 중단)
	if not surplus_parts.is_empty() and not _return_parts_to_storage(surplus_parts):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 창고와 배낭 공간이 부족하여 기존 장착 부품을 반환할 수 없습니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return

	# 자금 차감
	if recalc_cost > 0:
		cur_rubles -= recalc_cost
		if GameManager and GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"]["rubles"] = cur_rubles
		money_spent.emit(recalc_cost)
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("💰 %d RUB로 부족한 부품 %d종을 시장에서 즉시 구매하여 조립했습니다!" % [recalc_cost, missing_buy_parts.size()])
	else:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("✅ 보유 중인 부품으로 프리셋 조립을 완료했습니다.")

	# 보유 중이던 신규 부품만 인벤토리에서 차감
	for cid in inv_consume_parts:
		_remove_owned_part_from_inv(cid)

	wb_preset_pending_assembly = false
	wb_committed_parts = wb_current_preset_parts.duplicate(true)
	wb_selected_weapon["parts"] = wb_committed_parts.duplicate(true)
	wb_selected_weapon["attachments"] = wb_selected_weapon["parts"]
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var def_ammo = WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm")
	wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(rec_id, wb_committed_parts, wb_selected_weapon.get("loaded_ammo", def_ammo))
	_commit_selected_weapon_to_source()
	weapon_saved.emit(wb_selected_weapon, wb_weapon_source)
			
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
			EventBus.event_logged.emit("⚠️ 프리셋 미리보기 상태입니다. 먼저 [구매 후 조립] 버튼으로 조립을 완료하세요.")
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
		var font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else ThemeDB.fallback_font
		wb_preview.draw_string(font, center + Vector2(-60, 5), "총기를 선택해주세요", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.6, 0.7, 0.8))
		return
		
	var rec_id = wb_selected_weapon.get("receiver", "M4_리시버")
	var parts = wb_selected_weapon.get("parts", {})
	
	# 2. 총기 리시버 및 부품 실루엣 드로잉
	var metal_dark = Color(0.14, 0.16, 0.18, 0.95)
	var wood_col = Color(0.45, 0.25, 0.15, 0.95)
	
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
