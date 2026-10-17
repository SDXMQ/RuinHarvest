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

# 외부 주입 의존성
var player_grid_mgr: InventoryGrid = null
var stash_grid_mgr: InventoryGrid = null
var equipment_data: Dictionary = {}

# 총기 작업대(Workbench) 상태 변수
var wb_selected_weapon: Dictionary = {}
var wb_base_stats: Dictionary = {}
var wb_weapon_source: Dictionary = {}
var wb_active_slot: String = ""
var wb_current_preset_parts: Dictionary = {}
var wb_missing_preset_cost: int = 0
var wb_missing_preset_parts: Array = []

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
		money_spent.emit(wb_missing_preset_cost)
		
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
		# equipment_data updated
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
		var font = ThemeDB.fallback_font
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
