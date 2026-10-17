# res://systems/hideout_progression.gd
class_name HideoutProgression
extends RefCounted

## 은신처 시설 업그레이드 및 상인 의뢰(퀘스트) 관리 모듈

const FACILITIES: Dictionary = {
	"stash_expansion": {
		"name": "📦 보관함 확장 설비",
		"desc": "창고 그리드 세로 공간을 레벨당 +4줄 확장합니다. (기본 10x12 -> 최대 10x24)",
		"max_level": 3,
		"levels": [
			{"rubles": 4000, "items": {"나무": 2, "못": 2}, "bonus_rows": 4},
			{"rubles": 9000, "items": {"나무": 3, "고철": 2, "못": 3}, "bonus_rows": 8},
			{"rubles": 18000, "items": {"고철": 4, "기계_부품": 2}, "bonus_rows": 12}
		]
	},
	"med_station": {
		"name": "🏥 응급 의료 스테이션",
		"desc": "출격 시 최대 체력(Max HP) 보너스를 부여하고 복귀 시 부상을 완화합니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 3500, "items": {"붕대": 2, "생수": 1}, "bonus_hp": 15.0},
			{"rubles": 8000, "items": {"구급상자": 1, "약초": 2, "진통제": 1}, "bonus_hp": 30.0},
			{"rubles": 16000, "items": {"고급 치료킷": 1, "구급상자": 2}, "bonus_hp": 50.0}
		]
	},
	"bitcoin_farm": {
		"name": "⚡ 발전기 & 채굴 서버렉",
		"desc": "레이드에서 생존 복귀할 때마다 고정 패시브 수익(RUB)을 창출합니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 5000, "items": {"폐전선": 2, "비상용_배터리": 1}, "income": 1500},
			{"rubles": 12000, "items": {"기계_부품": 2, "CPU": 1}, "income": 3500},
			{"rubles": 25000, "items": {"그래픽카드": 1, "CPU": 1}, "income": 7500}
		]
	},
	"intel_center": {
		"name": "📡 통신 & 거래소 인텔 센터",
		"desc": "상인 구매 가격을 할인받고 아이템 매각 단가 비율을 높입니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 4500, "items": {"라디오_부품": 1, "폐전선": 1}, "discount": 0.05, "sell_bonus": 0.06},
			{"rubles": 10000, "items": {"장거리_무전기": 1, "라디오_부품": 2}, "discount": 0.10, "sell_bonus": 0.12},
			{"rubles": 22000, "items": {"암호화된_SSD": 1, "장거리_무전기": 1}, "discount": 0.15, "sell_bonus": 0.20}
		]
	}
}

const QUESTS: Array = [
	{
		"id": "q_therapist_1",
		"trader": "테라피스트",
		"title": "[의뢰 1] 응급 의료 물자 확보",
		"desc": "생존자 치료를 위해 붕대 2개와 생수 1병을 창고나 가방에서 납품하십시오.",
		"req_items": {"붕대": 2, "생수": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 4500,
		"reward_items": [{"id": "구급상자", "amount": 2}, {"id": "진통제", "amount": 1}]
	},
	{
		"id": "q_prapor_1",
		"trader": "프라포",
		"title": "[의뢰 2] 폐허 정찰 및 감염체 토벌",
		"desc": "레이드에서 적(좀비 또는 약탈자)을 누적 5명 이상 처치하십시오.",
		"req_items": {},
		"req_kills": 5,
		"req_human_kills": 0,
		"reward_rubles": 6500,
		"reward_items": [{"id": "AK_리시버", "amount": 1}, {"id": "7.62mm", "amount": 60}]
	},
	{
		"id": "q_fence_1",
		"trader": "펜스",
		"title": "[의뢰 3] 은신처 보수용 고철 수거",
		"desc": "고철 2개와 폐전선 1개를 찾아 납품하십시오.",
		"req_items": {"고철": 2, "폐전선": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 6000,
		"reward_items": [{"id": "2레벨_가방", "amount": 1}, {"id": "수류탄", "amount": 2}]
	},
	{
		"id": "q_prapor_2",
		"trader": "프라포",
		"title": "[의뢰 4] 무장 스캐브 소탕 작전",
		"desc": "총기로 무장한 인간형 적(스캐브/레이더)을 누적 3명 이상 처치하십시오.",
		"req_items": {},
		"req_kills": 0,
		"req_human_kills": 3,
		"reward_rubles": 11000,
		"reward_items": [{"id": "2레벨_방탄복", "amount": 1}, {"id": "5.56mm", "amount": 60}]
	},
	{
		"id": "q_therapist_2",
		"trader": "테라피스트",
		"title": "[의뢰 5] 중증 외상 수술 키트 조달",
		"desc": "구급상자 1개와 진통제 2개를 조달하여 납품하십시오.",
		"req_items": {"구급상자": 1, "진통제": 2},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 14000,
		"reward_items": [{"id": "고급 치료킷", "amount": 2}, {"id": "2레벨_헬멧", "amount": 1}]
	},
	{
		"id": "q_fence_2",
		"trader": "펜스",
		"title": "[의뢰 6] 기밀 전자부품 회수",
		"desc": "CPU 1개 또는 암호화된 SSD 1개를 확보하여 CPU 1개를 납품하십시오.",
		"req_items": {"CPU": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 24000,
		"reward_items": [{"id": "SV98_리시버", "amount": 1}, {"id": "3레벨_방탄복", "amount": 1}]
	}
]

static func get_facility_level(world_data: Dictionary, fac_id: String) -> int:
	return int(world_data.get("hideout", {}).get("upgrades", {}).get(fac_id, 0))

static func get_stash_grid_height(world_data: Dictionary) -> int:
	var lv = get_facility_level(world_data, "stash_expansion")
	if lv <= 0: return 12
	var levels = FACILITIES["stash_expansion"]["levels"]
	return 12 + int(levels[min(lv - 1, levels.size() - 1)]["bonus_rows"])

static func get_bonus_max_hp(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "med_station")
	if lv <= 0: return 0.0
	var levels = FACILITIES["med_station"]["levels"]
	return float(levels[min(lv - 1, levels.size() - 1)]["bonus_hp"])

static func get_passive_raid_income(world_data: Dictionary) -> int:
	var lv = get_facility_level(world_data, "bitcoin_farm")
	if lv <= 0: return 0
	var levels = FACILITIES["bitcoin_farm"]["levels"]
	return int(levels[min(lv - 1, levels.size() - 1)]["income"])

static func get_trader_discount(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "intel_center")
	if lv <= 0: return 0.0
	var levels = FACILITIES["intel_center"]["levels"]
	return float(levels[min(lv - 1, levels.size() - 1)]["discount"])

static func get_trader_sell_ratio(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "intel_center")
	if lv <= 0: return 0.60
	var levels = FACILITIES["intel_center"]["levels"]
	return 0.60 + float(levels[min(lv - 1, levels.size() - 1)]["sell_bonus"])

static func count_total_item(item_id: String, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> int:
	var c = 0
	if player_grid: c += player_grid.get_item_count(item_id)
	if stash_grid: c += stash_grid.get_item_count(item_id)
	return c

static func consume_total_item(item_id: String, amount: int, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> void:
	var rem = amount
	if stash_grid:
		rem = stash_grid.remove_item(item_id, rem)
	if rem > 0 and player_grid:
		player_grid.remove_item(item_id, rem)

static func setup_progression_tab(hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root = HBoxContainer.new()
	tab_root.name = " 🏗️ 시설 & 의뢰 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)
	
	# 좌측: 은신처 시설 업그레이드
	var fac_panel = PanelContainer.new()
	fac_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_vbox_outer = VBoxContainer.new()
	fac_vbox_outer.add_theme_constant_override("separation", 10)
	fac_panel.add_child(fac_vbox_outer)
	
	var fac_title = Label.new()
	fac_title.text = "🏗️ 은신처 핵심 시설 업그레이드 (Facilities)"
	fac_title.add_theme_font_size_override("font_size", 16)
	fac_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	fac_vbox_outer.add_child(fac_title)
	
	var fac_scroll = ScrollContainer.new()
	fac_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_list = VBoxContainer.new()
	fac_list.name = "FacilitiesList"
	fac_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_list.add_theme_constant_override("separation", 10)
	fac_scroll.add_child(fac_list)
	fac_vbox_outer.add_child(fac_scroll)
	tab_root.add_child(fac_panel)
	
	# 우측: 상인 특별 의뢰 (퀘스트)
	var q_panel = PanelContainer.new()
	q_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_vbox_outer = VBoxContainer.new()
	q_vbox_outer.add_theme_constant_override("separation", 10)
	q_panel.add_child(q_vbox_outer)
	
	var q_title = Label.new()
	q_title.text = "📋 상인 계약 의뢰 & 임무 (Trader Quests)"
	q_title.add_theme_font_size_override("font_size", 16)
	q_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	q_vbox_outer.add_child(q_title)
	
	var q_scroll = ScrollContainer.new()
	q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_list = VBoxContainer.new()
	q_list.name = "QuestsList"
	q_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_list.add_theme_constant_override("separation", 10)
	q_scroll.add_child(q_list)
	q_vbox_outer.add_child(q_scroll)
	tab_root.add_child(q_panel)
	
	return tab_root

static func refresh_progression_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager: return
	var fac_list: VBoxContainer = tab_root.find_child("FacilitiesList", true, false)
	var q_list: VBoxContainer = tab_root.find_child("QuestsList", true, false)
	if not fac_list or not q_list: return
	
	for c in fac_list.get_children(): c.queue_free()
	for c in q_list.get_children(): c.queue_free()
	
	var w_data = GameManager.current_world_data
	if not w_data.has("player"): w_data["player"] = {}
	if not w_data.has("hideout"): w_data["hideout"] = {"stash": [], "upgrades": {}, "completed_quests": []}
	if not w_data["hideout"].has("upgrades"): w_data["hideout"]["upgrades"] = {}
	if not w_data["hideout"].has("completed_quests"): w_data["hideout"]["completed_quests"] = []
	
	var rubles = int(w_data["player"].get("rubles", 0))
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr")
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr")
	
	# 1. 시설 목록 렌더링
	for fac_id in FACILITIES.keys():
		var f_data = FACILITIES[fac_id]
		var cur_lv = get_facility_level(w_data, fac_id)
		var max_lv = int(f_data["max_level"])
		
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		
		var header = Label.new()
		header.text = "%s  [Lv.%d / %d]" % [f_data["name"], cur_lv, max_lv]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6) if cur_lv > 0 else Color(0.9, 0.9, 0.95))
		vbox.add_child(header)
		
		var desc = Label.new()
		desc.text = f_data["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		vbox.add_child(desc)
		
		if cur_lv < max_lv:
			var next_req = f_data["levels"][cur_lv]
			var req_rub = int(next_req["rubles"])
			var req_items: Dictionary = next_req["items"]
			var can_upgrade = (rubles >= req_rub)
			var req_parts = ["%d RUB" % req_rub]
			
			for it_id in req_items.keys():
				var need_c = int(req_items[it_id])
				var have_c = count_total_item(it_id, p_grid, s_grid)
				if have_c < need_c: can_upgrade = false
				req_parts.append("%s (%d/%d)" % [it_id, have_c, need_c])
				
			var req_lbl = Label.new()
			req_lbl.text = "필요 조건: " + ", ".join(req_parts)
			req_lbl.add_theme_font_size_override("font_size", 11)
			req_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_upgrade else Color(1.0, 0.55, 0.45))
			vbox.add_child(req_lbl)
			
			var up_btn = Button.new()
			up_btn.text = "⬆️ Lv.%d 업그레이드 시공" % (cur_lv + 1)
			up_btn.disabled = not can_upgrade
			var fid_cap = fac_id
			up_btn.pressed.connect(func():
				w_data["player"]["rubles"] = int(w_data["player"].get("rubles", 0)) - req_rub
				for it_id in req_items.keys():
					consume_total_item(it_id, int(req_items[it_id]), p_grid, s_grid)
				w_data["hideout"]["upgrades"][fid_cap] = cur_lv + 1
				if SoundManager: SoundManager.play("menu_select")
				if hideout.has_method("_apply_stash_upgrade_size"):
					hideout._apply_stash_upgrade_size()
				if hideout.has_method("_update_money_label"):
					hideout._update_money_label()
				if hideout.has_method("_on_grid_changed"):
					hideout._on_grid_changed()
				refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(up_btn)
		else:
			var max_lbl = Label.new()
			max_lbl.text = "★ 최고 단계 업그레이드 완료 (MAX)"
			max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			vbox.add_child(max_lbl)
			
		fac_list.add_child(card)
		
	# 2. 퀘스트 목록 렌더링
	var completed_list: Array = w_data["hideout"]["completed_quests"]
	var total_kills = int(w_data["player"].get("kills_total", 0))
	var human_kills = int(w_data["player"].get("human_kills", 0))
	
	for q in QUESTS:
		var q_id = q["id"]
		var is_done = q_id in completed_list
		
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		
		var header = Label.new()
		header.text = "[%s] %s %s" % [q["trader"], q["title"], "✅(완료)" if is_done else ""]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if is_done else Color(1.0, 0.88, 0.4))
		vbox.add_child(header)
		
		var desc = Label.new()
		desc.text = q["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
		vbox.add_child(desc)
		
		if not is_done:
			var can_complete = true
			var cond_strs = []
			var req_items: Dictionary = q.get("req_items", {})
			for it_id in req_items.keys():
				var need_c = int(req_items[it_id])
				var have_c = count_total_item(it_id, p_grid, s_grid)
				if have_c < need_c: can_complete = false
				cond_strs.append("%s (%d/%d)" % [it_id, have_c, need_c])
				
			var req_k = int(q.get("req_kills", 0))
			if req_k > 0:
				if total_kills < req_k: can_complete = false
				cond_strs.append("적 처치 (%d/%d)" % [total_kills, req_k])
				
			var req_hk = int(q.get("req_human_kills", 0))
			if req_hk > 0:
				if human_kills < req_hk: can_complete = false
				cond_strs.append("무장 적 처치 (%d/%d)" % [human_kills, req_hk])
				
			var rew_strs = ["+%d RUB" % int(q["reward_rubles"])]
			for r_it in q.get("reward_items", []):
				rew_strs.append("%s x%d" % [r_it["id"], int(r_it["amount"])])
				
			var prog_lbl = Label.new()
			prog_lbl.text = "진행도: %s  |  보상: %s" % [", ".join(cond_strs), ", ".join(rew_strs)]
			prog_lbl.add_theme_font_size_override("font_size", 11)
			prog_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_complete else Color(0.85, 0.7, 0.45))
			vbox.add_child(prog_lbl)
			
			var comp_btn = Button.new()
			comp_btn.text = "🎁 의뢰 완수 및 보상 수령"
			comp_btn.disabled = not can_complete
			var q_cap = q
			comp_btn.pressed.connect(func():
				for it_id in req_items.keys():
					consume_total_item(it_id, int(req_items[it_id]), p_grid, s_grid)
				w_data["player"]["rubles"] = int(w_data["player"].get("rubles", 0)) + int(q_cap["reward_rubles"])
				for r_it in q_cap.get("reward_items", []):
					var rem = s_grid.auto_add_item(r_it["id"], int(r_it["amount"])) if s_grid else int(r_it["amount"])
					if rem > 0 and p_grid:
						p_grid.auto_add_item(r_it["id"], rem)
				completed_list.append(q_cap["id"])
				if SoundManager: SoundManager.play("level_up")
				if hideout.has_method("_update_money_label"):
					hideout._update_money_label()
				if hideout.has_method("_on_grid_changed"):
					hideout._on_grid_changed()
				refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(comp_btn)
			
		q_list.add_child(card)
