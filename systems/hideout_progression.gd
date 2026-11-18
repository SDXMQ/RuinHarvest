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
			{"rubles": 18000, "items": {"고철": 4, "기계 부품": 2}, "bonus_rows": 12}
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
			{"rubles": 5000, "items": {"폐전선": 2, "비상용 배터리": 1}, "income": 1500},
			{"rubles": 12000, "items": {"기계 부품": 2, "CPU": 1}, "income": 3500},
			{"rubles": 25000, "items": {"그래픽카드": 1, "CPU": 1}, "income": 7500}
		]
	},
	"intel_center": {
		"name": "📡 통신 & 거래소 인텔 센터",
		"desc": "상인 구매 가격을 할인받고 아이템 매각 단가 비율을 높입니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 4500, "items": {"라디오 부품": 1, "폐전선": 1}, "discount": 0.05, "sell_bonus": 0.06},
			{"rubles": 10000, "items": {"장거리 무전기": 1, "라디오 부품": 2}, "discount": 0.10, "sell_bonus": 0.12},
			{"rubles": 22000, "items": {"암호화된 SSD": 1, "장거리 무전기": 1}, "discount": 0.15, "sell_bonus": 0.20}
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
	},
	{
		"id": "q_field_terminal_1",
		"trader": "펜스",
		"title": "[의뢰 7] 랜드마크 기밀 단말기 해킹 작전",
		"desc": "레이드 현장의 랜드마크 단말기에서 [E] 키를 3.0초간 홀드해 신호를 송출하고 암호화된 SSD를 회수하십시오.",
		"req_items": {"암호화된 SSD": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"req_field_objectives": 1,
		"reward_rubles": 15000,
		"reward_items": [{"id": "M4_리시버", "amount": 1}, {"id": "3레벨_헬멧", "amount": 1}]
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

static func setup_progression_tab(_hideout: Control, tab_container: TabContainer) -> Control:
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
				
			var req_fo = int(q.get("req_field_objectives", 0))
			if req_fo > 0:
				var fo_cnt = int(w_data["player"].get("field_objectives_completed", 0))
				if fo_cnt < req_fo: can_complete = false
				cond_strs.append("현장 단말기 해킹 (%d/%d)" % [fo_cnt, req_fo])
				
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

const WEAPON_MASTERY_LV1_KILLS: int = 15
const WEAPON_MASTERY_LV2_KILLS: int = 35
const WEAPON_MASTERY_LV3_KILLS: int = 70
const WEAPON_MASTERY_KILL_THRESHOLD: int = 15
const TRACKED_MASTERY_WEAPONS: Array[String] = [
	"M4_리시버", "AK_리시버", "SV98_리시버", "MP5_리시버", "레버액션_리시버", "레밍턴_리시버", "M9_리시버"
]

const DOGTAG_BARTER_TRADES: Array[Dictionary] = [
	{
		"id": "barter_keycard",
		"cost_tags": 5,
		"reward_id": "보안 키카드",
		"reward_amount": 1,
		"title": "보안 키카드 (Security Keycard)",
		"desc": "병원 원장실 및 특수 보안 잠금문을 개방하는 마그네틱 키카드"
	},
	{
		"id": "barter_armor3",
		"cost_tags": 10,
		"reward_id": "3레벨_방탄복",
		"reward_amount": 1,
		"title": "3레벨 중갑 방탄복 (Lv.3 Heavy Armor)",
		"desc": "최고 등급의 방탄 플레이트 캐리어 (방어력 +60)"
	},
	{
		"id": "barter_scope8x",
		"cost_tags": 10,
		"reward_id": "8배율_스나이퍼_스코프",
		"reward_amount": 1,
		"title": "8배율 초장거리 저격 스코프 (8.0x Scope)",
		"desc": "소총 및 저격총에 장착 가능한 최고배율 정밀 조준경"
	}
]

static func normalize_weapon_id(weapon_id: String) -> String:
	if weapon_id == "":
		return ""
	if weapon_id == "레버액션 소총" or weapon_id == "레버액션_소총":
		return "레버액션_리시버"
	return WeaponPartsDatabase.resolve_receiver_id(weapon_id)

static func execute_dogtag_barter(trade_id: String, _world_data: Dictionary, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> Dictionary:
	var trade: Dictionary = {}
	for t in DOGTAG_BARTER_TRADES:
		if String(t.get("id", "")) == trade_id:
			trade = t
			break
	if trade.is_empty():
		return {"success": false, "reason": "invalid_trade"}
	var cost_tags := int(trade.get("cost_tags", 5))
	var have_tags := count_total_item("Scav 인식표", player_grid, stash_grid)
	if have_tags < cost_tags:
		return {"success": false, "reason": "not_enough_tags", "have": have_tags, "need": cost_tags}
	var reward_id := String(trade.get("reward_id", ""))
	var reward_amt := int(trade.get("reward_amount", 1))
	var target_grid: InventoryGrid = stash_grid if stash_grid != null else player_grid
	var fallback_grid: InventoryGrid = player_grid if target_grid == stash_grid else stash_grid
	if target_grid == null and fallback_grid == null:
		return {"success": false, "reason": "no_grid"}
	consume_total_item("Scav 인식표", cost_tags, player_grid, stash_grid)
	var rem := reward_amt
	if target_grid:
		rem = target_grid.auto_add_item(reward_id, rem)
	if rem > 0 and fallback_grid:
		rem = fallback_grid.auto_add_item(reward_id, rem)
	if rem >= reward_amt:
		# 공간 부족 시 인식표 복구
		if target_grid:
			target_grid.auto_add_item("Scav 인식표", cost_tags)
		return {"success": false, "reason": "inventory_full"}
	return {
		"success": true,
		"trade_id": trade_id,
		"spent_tags": cost_tags,
		"reward_id": reward_id,
		"reward_amount": reward_amt - rem
	}

static func record_weapon_kill(world_data: Dictionary, weapon_id: String, count: int = 1) -> int:
	if weapon_id == "" or weapon_id == "맨손":
		return 0
	var norm_id := normalize_weapon_id(weapon_id)
	if not world_data.has("player"):
		world_data["player"] = {}
	if not (world_data["player"].get("weapon_kills") is Dictionary):
		world_data["player"]["weapon_kills"] = {}
	var w_kills: Dictionary = world_data["player"]["weapon_kills"]
	var prev_cnt: int = int(w_kills.get(norm_id, 0))
	var next_cnt: int = prev_cnt + maxi(1, count)
	w_kills[norm_id] = next_cnt
	if EventBus and EventBus.has_signal("event_logged"):
		var w_data := ItemDatabase.get_item_data(norm_id) if ItemDatabase else {}
		var w_name := String(w_data.get("name", norm_id))
		if prev_cnt < WEAPON_MASTERY_LV3_KILLS and next_cnt >= WEAPON_MASTERY_LV3_KILLS:
			EventBus.event_logged.emit("★ 🏆 [총기 숙련도 Lv.3 Мастер] %s 70킬 달성! 기능고장 확률 50%% 감소 및 황금 테두리가 해금되었습니다!" % w_name)
		elif prev_cnt < WEAPON_MASTERY_LV2_KILLS and next_cnt >= WEAPON_MASTERY_LV2_KILLS:
			EventBus.event_logged.emit("★ 🎖️ [총기 숙련도 Lv.2] %s 35킬 달성! 반동 제어 +5%% 보너스가 해금되었습니다!" % w_name)
		elif prev_cnt < WEAPON_MASTERY_LV1_KILLS and next_cnt >= WEAPON_MASTERY_LV1_KILLS:
			EventBus.event_logged.emit("★ 🎖️ [총기 숙련도 Lv.1] %s 15킬 달성! 재장전 속도 +3%% 보너스가 해금되었습니다!" % w_name)
	return next_cnt

static func get_weapon_kill_count(world_data: Dictionary, weapon_id: String) -> int:
	if weapon_id == "":
		return 0
	var norm_id := normalize_weapon_id(weapon_id)
	var w_kills: Dictionary = world_data.get("player", {}).get("weapon_kills", {})
	return int(w_kills.get(norm_id, w_kills.get(weapon_id, 0)))

static func get_weapon_mastery_bonus(world_data: Dictionary, weapon_id: String) -> Dictionary:
	var kills := get_weapon_kill_count(world_data, weapon_id)
	var lv := 0
	var next_th := WEAPON_MASTERY_LV1_KILLS
	var reload_mult := 1.0
	var recoil_mult := 1.0
	var jam_mult := 1.0
	var title_tag := "미숙련"
	if kills >= WEAPON_MASTERY_LV3_KILLS:
		lv = 3
		next_th = WEAPON_MASTERY_LV3_KILLS
		reload_mult = 0.95
		recoil_mult = 0.95
		jam_mult = 0.50
		title_tag = "Lv.3 Мастер"
	elif kills >= WEAPON_MASTERY_LV2_KILLS:
		lv = 2
		next_th = WEAPON_MASTERY_LV3_KILLS
		reload_mult = 0.97
		recoil_mult = 0.95
		jam_mult = 1.0
		title_tag = "Lv.2 전문"
	elif kills >= WEAPON_MASTERY_LV1_KILLS:
		lv = 1
		next_th = WEAPON_MASTERY_LV2_KILLS
		reload_mult = 0.97
		recoil_mult = 1.0
		jam_mult = 1.0
		title_tag = "Lv.1 숙련"
	var mastered := (lv >= 1)
	return {
		"weapon_id": normalize_weapon_id(weapon_id),
		"kills": kills,
		"level": lv,
		"title": title_tag,
		"threshold": WEAPON_MASTERY_KILL_THRESHOLD,
		"next_threshold": next_th,
		"max_threshold": WEAPON_MASTERY_LV3_KILLS,
		"mastered": mastered,
		"is_grandmaster": lv >= 3,
		"gold_border": lv >= 3,
		"reload_speed_mult": reload_mult,
		"recoil_mult": recoil_mult,
		"jam_chance_mult": jam_mult,
		"bonus_pct": 5 if lv >= 2 else (3 if lv == 1 else 0)
	}

static func get_service_record_data(world_data: Dictionary, player_grid: InventoryGrid = null, stash_grid: InventoryGrid = null) -> Dictionary:
	var p_data: Dictionary = world_data.get("player", {})
	var raids_survived := int(p_data.get("raids_survived", 0))
	var kills_total := int(p_data.get("kills_total", 0))
	var human_kills := int(p_data.get("human_kills", 0))
	var boss_kills := int(p_data.get("boss_kills", 0))
	var dogtag_count := count_total_item("Scav 인식표", player_grid, stash_grid)
	var mastered: Array[String] = []
	for w_id in TRACKED_MASTERY_WEAPONS:
		if get_weapon_kill_count(world_data, w_id) >= WEAPON_MASTERY_KILL_THRESHOLD:
			mastered.append(w_id)
	return {
		"raids_survived": raids_survived,
		"kills_total": kills_total,
		"human_kills": human_kills,
		"boss_kills": boss_kills,
		"dogtag_count": dogtag_count,
		"weapon_kills": p_data.get("weapon_kills", {}).duplicate(true) if p_data.get("weapon_kills") is Dictionary else {},
		"mastered_weapons": mastered
	}

static func setup_service_record_tab(_hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root := HBoxContainer.new()
	tab_root.name = " 🎖️ 전술 기록실 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)

	# 좌측: 레이드 전적 아카이브 & 인식표 휘장
	var rec_panel := PanelContainer.new()
	rec_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rec_vbox := VBoxContainer.new()
	rec_vbox.name = "ServiceStatsVBox"
	rec_vbox.add_theme_constant_override("separation", 10)
	rec_panel.add_child(rec_vbox)
	tab_root.add_child(rec_panel)

	# 우측: 총기별 킬 카운트 & 총기 숙련도(Weapon Mastery)
	var mas_panel := PanelContainer.new()
	mas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_vbox_outer := VBoxContainer.new()
	mas_vbox_outer.add_theme_constant_override("separation", 10)
	mas_panel.add_child(mas_vbox_outer)

	var mas_title := Label.new()
	mas_title.text = "🔫 총기 숙련도 3단계 (Lv.1 15킬 · Lv.2 35킬 · Lv.3 70킬 Мастер)"
	mas_title.add_theme_font_size_override("font_size", 16)
	mas_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	mas_vbox_outer.add_child(mas_title)

	var mas_scroll := ScrollContainer.new()
	mas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_list := VBoxContainer.new()
	mas_list.name = "WeaponMasteryList"
	mas_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_list.add_theme_constant_override("separation", 8)
	mas_scroll.add_child(mas_list)
	mas_vbox_outer.add_child(mas_scroll)
	tab_root.add_child(mas_panel)

	return tab_root

static func refresh_service_record_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager:
		return
	var rec_vbox: VBoxContainer = tab_root.find_child("ServiceStatsVBox", true, false)
	var mas_list: VBoxContainer = tab_root.find_child("WeaponMasteryList", true, false)
	if not rec_vbox or not mas_list:
		return
	for c in rec_vbox.get_children():
		c.queue_free()
	for c in mas_list.get_children():
		c.queue_free()

	var w_data: Dictionary = GameManager.current_world_data
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr")
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr")
	var summary := get_service_record_data(w_data, p_grid, s_grid)

	var title := Label.new()
	title.text = "🎖️ 전술 기록실 (Service Record & Dogtag Archive)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	rec_vbox.add_child(title)

	var stat_lines := [
		["🚁 누적 레이드 생환 횟수", "%d 회" % int(summary["raids_survived"]), Color(0.45, 1.0, 0.55)],
		["⚔️ 누적 전체 적 사살 수", "%d 명" % int(summary["kills_total"]), Color(0.92, 0.94, 0.98)],
		["🎯 무장 세력(Scav/Raider) 사살", "%d 명" % int(summary["human_kills"]), Color(1.0, 0.82, 0.4)],
		["💀 구역 지휘관(Boss) 사살", "%d 회" % int(summary["boss_kills"]), Color(1.0, 0.45, 0.45)],
		["🏷️ 보유 중인 Scav 인식표 (Dogtag)", "%d 개" % int(summary["dogtag_count"]), Color(0.4, 0.92, 1.0)],
		["★ 마스터 달성 총기 수", "%d / %d 종" % [summary["mastered_weapons"].size(), TRACKED_MASTERY_WEAPONS.size()], Color(1.0, 0.88, 0.3)]
	]

	for row in stat_lines:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		card.add_child(hbox)
		var k_lbl := Label.new()
		k_lbl.text = String(row[0])
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = String(row[1])
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", row[2])
		hbox.add_child(v_lbl)
		rec_vbox.add_child(card)

	# === Scav 인식표 전용 암시장 물물교환소 (Dogtag Barter Shop) ===
	var barter_header := Label.new()
	barter_header.text = "🏷️ Scav 인식표 암시장 물물교환소 (보유 인식표: %d개)" % int(summary["dogtag_count"])
	barter_header.add_theme_font_size_override("font_size", 15)
	barter_header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	rec_vbox.add_child(barter_header)

	for b_trade in DOGTAG_BARTER_TRADES:
		var b_card := PanelContainer.new()
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.08, 0.10, 0.14, 0.96)
		b_sb.border_width_left = 3
		b_sb.border_width_top = 1
		b_sb.border_width_right = 1
		b_sb.border_width_bottom = 1
		b_sb.border_color = Color(1.0, 0.78, 0.22)
		b_sb.set_corner_radius_all(0)
		b_sb.corner_detail = 1
		b_sb.anti_aliasing = false
		b_sb.content_margin_left = 8
		b_sb.content_margin_right = 8
		b_sb.content_margin_top = 6
		b_sb.content_margin_bottom = 6
		b_card.add_theme_stylebox_override("panel", b_sb)

		var b_hbox := HBoxContainer.new()
		b_hbox.add_theme_constant_override("separation", 10)
		b_card.add_child(b_hbox)

		var r_id := String(b_trade["reward_id"])
		if ItemIconManager:
			var b_icon := TextureRect.new()
			b_icon.custom_minimum_size = Vector2(32, 32)
			b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b_icon.texture = ItemIconManager.get_icon(r_id)
			b_hbox.add_child(b_icon)

		var b_info_v := VBoxContainer.new()
		b_info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_name_lbl := Label.new()
		b_name_lbl.text = "%s (인식표 %d개 교환)" % [String(b_trade["title"]), int(b_trade["cost_tags"])]
		b_name_lbl.add_theme_font_size_override("font_size", 13)
		b_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
		b_info_v.add_child(b_name_lbl)

		var b_desc_lbl := Label.new()
		b_desc_lbl.text = String(b_trade["desc"])
		b_desc_lbl.add_theme_font_size_override("font_size", 11)
		b_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		b_info_v.add_child(b_desc_lbl)
		b_hbox.add_child(b_info_v)

		var cost_c := int(b_trade["cost_tags"])
		var can_barter := int(summary["dogtag_count"]) >= cost_c
		var b_btn := Button.new()
		b_btn.text = "🏷️ %d개 교환" % cost_c
		b_btn.disabled = not can_barter
		var cap_tid := String(b_trade["id"])
		b_btn.pressed.connect(func():
			var res := execute_dogtag_barter(cap_tid, w_data, p_grid, s_grid)
			if bool(res.get("success", false)):
				if SoundManager:
					SoundManager.play("level_up")
				if hideout.has_method("_refresh_stash_ui"):
					hideout._refresh_stash_ui()
				if hideout.has_method("_sync_save_data"):
					hideout._sync_save_data()
				refresh_service_record_tab(hideout, tab_root)
		)
		b_hbox.add_child(b_btn)
		rec_vbox.add_child(b_card)

	for w_id in TRACKED_MASTERY_WEAPONS:
		var m_info := get_weapon_mastery_bonus(w_data, w_id)
		var kills := int(m_info["kills"])
		var lv := int(m_info.get("level", 0))
		var is_gm := bool(m_info.get("gold_border", false))
		var idata := ItemDatabase.get_item_data(w_id) if ItemDatabase else {}
		var w_name := String(idata.get("name", w_id))

		var card := PanelContainer.new()
		if is_gm:
			var gm_sb := StyleBoxFlat.new()
			gm_sb.bg_color = Color(0.16, 0.13, 0.05, 0.96)
			gm_sb.border_width_left = 3
			gm_sb.border_width_top = 2
			gm_sb.border_width_right = 2
			gm_sb.border_width_bottom = 2
			gm_sb.border_color = Color(1.0, 0.84, 0.22, 0.98)
			gm_sb.set_corner_radius_all(0)
			gm_sb.corner_detail = 1
			gm_sb.anti_aliasing = false
			gm_sb.content_margin_left = 8
			gm_sb.content_margin_right = 8
			gm_sb.content_margin_top = 6
			gm_sb.content_margin_bottom = 6
			card.add_theme_stylebox_override("panel", gm_sb)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var h_row := HBoxContainer.new()
		h_row.add_theme_constant_override("separation", 8)
		vbox.add_child(h_row)

		if ItemIconManager:
			var icon_frame := PanelContainer.new()
			var ic_sb := StyleBoxFlat.new()
			ic_sb.bg_color = Color(0.06, 0.08, 0.11, 0.96)
			ic_sb.border_width_left = 2 if is_gm else 1
			ic_sb.border_width_top = 2 if is_gm else 1
			ic_sb.border_width_right = 2 if is_gm else 1
			ic_sb.border_width_bottom = 2 if is_gm else 1
			ic_sb.border_color = Color(1.0, 0.84, 0.22, 1.0) if is_gm else (Color(0.4, 0.85, 1.0, 0.85) if lv >= 1 else Color(0.25, 0.30, 0.38, 0.75))
			ic_sb.set_corner_radius_all(0)
			ic_sb.corner_detail = 1
			ic_sb.anti_aliasing = false
			icon_frame.add_theme_stylebox_override("panel", ic_sb)
			var w_icon := TextureRect.new()
			w_icon.custom_minimum_size = Vector2(28, 28)
			w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			w_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			w_icon.texture = ItemIconManager.get_icon(w_id)
			icon_frame.add_child(w_icon)
			h_row.add_child(icon_frame)

		var header := Label.new()
		var badge_str := " [🏆 Lv.3 Мастер]" if lv >= 3 else (" [★ Lv.%d]" % lv if lv >= 1 else "")
		header.text = "%s  —  처치: %d / %d 킬%s" % [
			w_name,
			kills,
			WEAPON_MASTERY_LV3_KILLS,
			badge_str
		]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25) if lv >= 3 else (Color(0.45, 0.95, 0.65) if lv >= 1 else Color(0.88, 0.9, 0.95)))
		h_row.add_child(header)

		var bar := ProgressBar.new()
		bar.max_value = float(WEAPON_MASTERY_LV3_KILLS)
		bar.value = float(min(kills, WEAPON_MASTERY_LV3_KILLS))
		bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(bar)

		var bonus_lbl := Label.new()
		if lv >= 3:
			bonus_lbl.text = "🏆 Lv.3 Мастер 달성: 재장전 +5% · 반동 제어 +5% · 기능고장(Jam) 확률 -50% · 황금 총기 테두리"
			bonus_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif lv == 2:
			bonus_lbl.text = "✅ Lv.2 활성화: 재장전 +3% & 반동 제어 +5%  |  다음 목표: 70킬 (Lv.3 Мастер: 기능고장 -50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
		elif lv == 1:
			bonus_lbl.text = "✅ Lv.1 활성화: 재장전 속도 +3%  |  다음 목표: 35킬 (Lv.2: 반동 제어 +5%)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
		else:
			bonus_lbl.text = "단계별 보너스: Lv.1(15킬: 재장전+3%) ➔ Lv.2(35킬: 반동+5%) ➔ Lv.3 Мастер(70킬: 잼-50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(bonus_lbl)

		mas_list.add_child(card)
