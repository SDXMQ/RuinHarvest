# res://scenes/hideout/components/workbench_preview_helper.gd
extends RefCounted

## 총기 작업대 프리셋 조립·구매 및 픽셀아트 총기 실루엣 프리뷰 드로잉 헬퍼

const WEAPON_PRESETS: Dictionary = {
	"M4_리시버": [
		{
			"icon": "target",
			"name": "무반동 레이저 세팅",
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
			"icon": "stealth",
			"name": "소음 암살 저격 세팅",
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
			"icon": "power",
			"name": "초경량 CQC 돌격 세팅",
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
			"icon": "target",
			"name": "스페츠나츠 무반동 세팅",
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
			"icon": "stealth",
			"name": "소음 야간 침투 세팅",
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
			"icon": "stealth",
			"name": "비밀 요원 소음 권총",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "소음기",
				"optic": "레드닷_사이트",
				"magazine": "대용량_확장_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"icon": "power",
			"name": "컴팩트 속사 권총",
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
			"icon": "explosion",
			"name": "파쇄 벅샷 산탄 세팅",
			"parts": {
				"barrel": "짧은_총열",
				"muzzle": "컴펜세이터",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"rail": ["전술_손전등"]
			}
		},
		{
			"icon": "target",
			"name": "정밀 슬러그 스나이퍼",
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
			"icon": "bullseye",
			"name": "카우보이 헌터 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": []
			}
		},
		{
			"icon": "stealth",
			"name": "전술 택티컬 소음 레버액션",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"icon": "power",
			"name": "단축 기동형 카빈 세팅",
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
			"icon": "bullseye",
			"name": "카우보이 헌터 세팅",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": []
			}
		},
		{
			"icon": "stealth",
			"name": "전술 택티컬 소음 레버액션",
			"parts": {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"rail": ["적색_레이저_표적지시기"]
			}
		},
		{
			"icon": "power",
			"name": "단축 기동형 카빈 세팅",
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
			"icon": "scope",
			"name": "8배율 초장거리 저격 세팅",
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


static func flatten_parts_dict(parts_dict: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot_k in parts_dict.keys():
		var v: Variant = parts_dict[slot_k]
		if v is Array:
			for sub in v:
				var s: String = String(sub)
				if s != "":
					out.append(s)
		else:
			var s: String = String(v)
			if s != "":
				out.append(s)
	return out


static func populate_workbench_presets(wb: Control) -> void:
	if not wb or not wb.wb_preset_vbox:
		return
	for c in wb.wb_preset_vbox.get_children():
		c.queue_free()

	if wb.wb_selected_weapon.is_empty():
		return
	var rec_id: String = String(wb.wb_selected_weapon.get("receiver", "M4_리시버"))
	var presets: Array = WEAPON_PRESETS.get(rec_id, [])

	for p in presets:
		var btn := Button.new()
		if UiIconManager:
			UiIconManager.set_button(btn, String(p.get("icon", "preset")), String(p["name"]), 15)
		else:
			btn.text = String(p["name"])
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var p_capture: Dictionary = p
		btn.pressed.connect(func(): wb._apply_workbench_preset(p_capture))
		wb.wb_preset_vbox.add_child(btn)


static func apply_workbench_preset(wb: Control, preset_dict: Dictionary) -> void:
	if not wb:
		return
	if not wb.wb_preset_pending_assembly:
		wb.wb_committed_parts = wb.wb_selected_weapon.get("parts", {}).duplicate(true)
	wb.wb_current_preset_parts = preset_dict.get("parts", {}).duplicate(true)
	wb.wb_missing_preset_parts.clear()
	wb.wb_missing_preset_cost = 0

	# 이미 총기에 장착 중인 부품(wb_committed_parts)은 그대로 재사용하고, 나머지 필요 부품만 인벤토리와 대조
	var committed_counts: Dictionary = {}
	for cp in flatten_parts_dict(wb.wb_committed_parts):
		committed_counts[cp] = int(committed_counts.get(cp, 0)) + 1

	var owned_pool: Dictionary = wb._get_owned_parts_list()
	for tp in flatten_parts_dict(wb.wb_current_preset_parts):
		if int(committed_counts.get(tp, 0)) > 0:
			committed_counts[tp] = int(committed_counts[tp]) - 1
		elif not owned_pool.has(tp) or int(owned_pool[tp]) <= 0:
			wb.wb_missing_preset_parts.append(tp)
			var p_val: int = int(WeaponPartsDatabase.PARTS.get(tp, {}).get("value", 5000))
			wb.wb_missing_preset_cost += p_val
		else:
			owned_pool[tp] = int(owned_pool[tp]) - 1

	# 무기 파츠에 프리셋 적용 (가상 미리보기 — [구매 후 조립] 완료 전까지 실제 저장 차단)
	wb.wb_preset_pending_assembly = true
	wb.wb_selected_weapon["parts"] = wb.wb_current_preset_parts.duplicate(true)
	wb.wb_selected_weapon["attachments"] = wb.wb_selected_weapon["parts"]

	var rec_id: String = String(wb.wb_selected_weapon.get("receiver", "M4_리시버"))
	var def_ammo: String = String(WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm"))
	wb.wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(
		rec_id,
		wb.wb_current_preset_parts,
		String(wb.wb_selected_weapon.get("loaded_ammo", def_ammo))
	)

	if wb.wb_preset_buy_btn:
		if wb.wb_missing_preset_parts.is_empty():
			if UiIconManager:
				UiIconManager.set_button(wb.wb_preset_buy_btn, "wrench_blue", "보유 부품으로 프리셋 조립 확정 (0 RUB)", 15)
			else:
				wb.wb_preset_buy_btn.text = "보유 부품으로 프리셋 조립 확정 (0 RUB)"
			wb.wb_preset_buy_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			var buy_txt: String = "부족 부품 %d종 구매 후 조립: %d RUB" % [wb.wb_missing_preset_parts.size(), wb.wb_missing_preset_cost]
			if UiIconManager:
				UiIconManager.set_button(wb.wb_preset_buy_btn, "cart", buy_txt, 15)
			else:
				wb.wb_preset_buy_btn.text = buy_txt
			wb.wb_preset_buy_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	if SoundManager:
		SoundManager.play("menu_select")
	wb._build_workbench_slots()
	wb._refresh_workbench_stats_comparison()
	wb._populate_workbench_compat_parts(wb.wb_active_slot)
	if wb.wb_preview:
		wb.wb_preview.queue_redraw()


static func buy_and_assemble_preset(wb: Control) -> void:
	if not wb:
		return
	if wb.wb_current_preset_parts.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 먼저 적용할 프리셋을 선택해주세요.")
		return

	var cur_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	if wb.wb_missing_preset_cost > 0:
		if cur_rubles < wb.wb_missing_preset_cost:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:error] 자금이 부족합니다! (필요: %d RUB / 보유: %d RUB)" % [wb.wb_missing_preset_cost, cur_rubles])
			if SoundManager:
				SoundManager.play("hit_melee")
			return
		var part_names: Array[String] = []
		for i in range(mini(5, wb.wb_missing_preset_parts.size())):
			var pid: String = str(wb.wb_missing_preset_parts[i])
			part_names.append(str(WeaponPartsDatabase.PARTS.get(pid, {}).get("name", pid)))
		var extra_cnt: int = wb.wb_missing_preset_parts.size() - part_names.size()
		var list_txt: String = ", ".join(part_names) + (" 외 %d종" % extra_cnt if extra_cnt > 0 else "")
		wb._show_confirm_dialog(
			"[icon:cart] 부족 부품 구매 후 조립 확인",
			"미보유 부품 %d종(%s)을 시장가 %d RUB에 즉시 구매하여 조립하시겠습니까?\n(현재 보유 자금: %d RUB → 결제 후: %d RUB)" % [
				wb.wb_missing_preset_parts.size(), list_txt, wb.wb_missing_preset_cost, cur_rubles, cur_rubles - wb.wb_missing_preset_cost
			],
			"%d RUB 구매·조립" % wb.wb_missing_preset_cost,
			func(): wb._execute_buy_and_assemble_preset()
		)
		return

	execute_buy_and_assemble_preset(wb)


static func execute_buy_and_assemble_preset(wb: Control) -> void:
	if not wb or wb.wb_current_preset_parts.is_empty():
		return

	# committed vs target multiset 계산
	var committed_counts: Dictionary = {}
	for cp in flatten_parts_dict(wb.wb_committed_parts):
		committed_counts[cp] = int(committed_counts.get(cp, 0)) + 1

	var needed_parts: Array[String] = []
	for tp in flatten_parts_dict(wb.wb_current_preset_parts):
		if int(committed_counts.get(tp, 0)) > 0:
			committed_counts[tp] = int(committed_counts[tp]) - 1
		else:
			needed_parts.append(tp)

	var surplus_parts: Array[String] = []
	for cp in committed_counts.keys():
		var rem_cnt: int = int(committed_counts[cp])
		for _k in range(rem_cnt):
			surplus_parts.append(String(cp))

	# 미보유/보유 비용 재검증
	var owned_pool: Dictionary = wb._get_owned_parts_list()
	var inv_consume_parts: Array[String] = []
	var missing_buy_parts: Array[String] = []
	var recalc_cost: int = 0
	for np in needed_parts:
		if int(owned_pool.get(np, 0)) > 0:
			owned_pool[np] = int(owned_pool[np]) - 1
			inv_consume_parts.append(np)
		else:
			missing_buy_parts.append(np)
			recalc_cost += int(WeaponPartsDatabase.PARTS.get(np, {}).get("value", 5000))

	var cur_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	if recalc_cost > 0 and cur_rubles < recalc_cost:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:error] 자금이 부족합니다! (필요: %d RUB / 보유: %d RUB)" % [recalc_cost, cur_rubles])
		if SoundManager:
			SoundManager.play("hit_melee")
		return

	# 기존 장착 잉여 부품 먼저 창고/배낭 반환 (공간 부족 시 거래 중단)
	if not surplus_parts.is_empty() and not wb._return_parts_to_storage(surplus_parts):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 부족하여 기존 장착 부품을 반환할 수 없습니다.")
		if SoundManager:
			SoundManager.play("hit_melee")
		return

	# 자금 차감
	if recalc_cost > 0:
		cur_rubles -= recalc_cost
		if GameManager and GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"]["rubles"] = cur_rubles
		wb.money_spent.emit(recalc_cost)
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:money] %d RUB로 부족한 부품 %d종을 시장에서 즉시 구매하여 조립했습니다!" % [recalc_cost, missing_buy_parts.size()])
	else:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:ok] 보유 중인 부품으로 프리셋 조립을 완료했습니다.")

	# 보유 중이던 신규 부품만 인벤토리에서 차감
	for cid in inv_consume_parts:
		wb._remove_owned_part_from_inv(cid)

	wb.wb_preset_pending_assembly = false
	wb.wb_committed_parts = wb.wb_current_preset_parts.duplicate(true)
	wb.wb_selected_weapon["parts"] = wb.wb_committed_parts.duplicate(true)
	wb.wb_selected_weapon["attachments"] = wb.wb_selected_weapon["parts"]
	var rec_id: String = String(wb.wb_selected_weapon.get("receiver", "M4_리시버"))
	var def_ammo: String = String(WeaponPartsDatabase.RECEIVERS.get(rec_id, {}).get("default_ammo", "9mm"))
	wb.wb_selected_weapon["computed_stats"] = WeaponPartsDatabase.compute_weapon_stats(
		rec_id,
		wb.wb_committed_parts,
		String(wb.wb_selected_weapon.get("loaded_ammo", def_ammo))
	)
	wb._commit_selected_weapon_to_source()
	wb.weapon_saved.emit(wb.wb_selected_weapon, wb.wb_weapon_source)

	wb.wb_missing_preset_cost = 0
	wb.wb_missing_preset_parts.clear()
	if wb.wb_preset_buy_btn:
		if UiIconManager:
			UiIconManager.set_button(wb.wb_preset_buy_btn, "ok", "프리셋 조립 완료", 15)
		else:
			wb.wb_preset_buy_btn.text = "프리셋 조립 완료"
		wb.wb_preset_buy_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	if SoundManager:
		SoundManager.play("menu_select")
	wb._build_workbench_slots()
	wb._refresh_workbench_stats_comparison()
	wb._populate_workbench_compat_parts(wb.wb_active_slot)
	if wb.wb_preview:
		wb.wb_preview.queue_redraw()


static func draw_workbench_preview(wb: Control, canvas: Control) -> void:
	if not wb or not canvas:
		return
	var rect: Rect2 = canvas.get_rect()
	var center: Vector2 = rect.size / 2.0

	# 1. 블루프린트 테크니컬 격자 배경
	var grid_col := Color(0.1, 0.18, 0.25, 0.35)
	for x in range(0, int(rect.size.x), 20):
		canvas.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_col, 1.0)
	for y in range(0, int(rect.size.y), 20):
		canvas.draw_line(Vector2(0, y), Vector2(rect.size.x, y), grid_col, 1.0)

	# 십자 조준선 가이드
	canvas.draw_line(Vector2(center.x - 40, center.y), Vector2(center.x + 40, center.y), Color(0.2, 0.5, 0.7, 0.5), 1.0)
	canvas.draw_line(Vector2(center.x, center.y - 25), Vector2(center.x, center.y + 25), Color(0.2, 0.5, 0.7, 0.5), 1.0)

	if wb.wb_selected_weapon.is_empty():
		var font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else null
		if font:
			canvas.draw_string(font, center + Vector2(-60, 5), "총기를 선택해주세요", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.6, 0.7, 0.8))
		return

	var rec_id: String = String(wb.wb_selected_weapon.get("receiver", "M4_리시버"))
	var parts: Dictionary = wb.wb_selected_weapon.get("parts", {})

	# 2. 총기 리시버 및 부품 실루엣 드로잉
	var metal_dark := Color(0.14, 0.16, 0.18, 0.95)
	var wood_col := Color(0.45, 0.25, 0.15, 0.95)

	# 리시버 본체 (Base Upper/Lower Receiver)
	var rec_w: float = 90.0
	var rec_h: float = 24.0
	var rec_pos: Vector2 = center + Vector2(-30, -12)

	if rec_id == "M4_리시버":
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, rec_h)), metal_dark)
		canvas.draw_rect(Rect2(rec_pos + Vector2(10, -6), Vector2(70, 6)), Color(0.2, 0.22, 0.26))
		canvas.draw_rect(Rect2(rec_pos + Vector2(25, 20), Vector2(16, 22)), Color(0.18, 0.18, 0.2))
	elif rec_id == "AK_리시버":
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, rec_h)), metal_dark)
		canvas.draw_rect(Rect2(rec_pos + Vector2(50, -4), Vector2(40, 16)), wood_col)
		canvas.draw_rect(Rect2(rec_pos + Vector2(20, 20), Vector2(16, 22)), wood_col)
	elif rec_id == "SV98_리시버":
		rec_w = 120.0
		rec_pos = center + Vector2(-45, -10)
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, 20)), Color(0.18, 0.28, 0.2))
	elif rec_id == "레버액션_리시버" or rec_id == "레버액션 소총":
		rec_w = 110.0
		rec_pos = center + Vector2(-35, -8)
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, 18)), metal_dark)
		canvas.draw_rect(Rect2(rec_pos + Vector2(40, 2), Vector2(60, 12)), wood_col)
		canvas.draw_rect(Rect2(rec_pos + Vector2(12, 14), Vector2(18, 14)), Color(0.12, 0.12, 0.14), false, 2.0)
		canvas.draw_polygon(PackedVector2Array([
			rec_pos + Vector2(0, 0), rec_pos + Vector2(-42, 4),
			rec_pos + Vector2(-42, 22), rec_pos + Vector2(0, 18)
		]), PackedColorArray([wood_col, wood_col, wood_col, wood_col]))
	elif rec_id == "레밍턴_리시버":
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, 26)), metal_dark)
		canvas.draw_rect(Rect2(rec_pos + Vector2(55, 12), Vector2(30, 12)), wood_col)
	else:
		rec_w = 55.0
		rec_pos = center + Vector2(-15, -10)
		canvas.draw_rect(Rect2(rec_pos, Vector2(rec_w, 18)), metal_dark)
		canvas.draw_rect(Rect2(rec_pos + Vector2(10, 16), Vector2(18, 26)), Color(0.12, 0.12, 0.14))

	# 3. 부착물 실시간 오버레이
	# [총열 & 총구]
	var barrel_p: String = String(parts.get("barrel", ""))
	var muzzle_p: String = String(parts.get("muzzle", ""))
	var b_len: float = 50.0 if barrel_p.contains("롱헤비") else 30.0
	var barrel_tip: Vector2 = rec_pos + Vector2(rec_w, 6)
	canvas.draw_rect(Rect2(barrel_tip, Vector2(b_len, 8)), Color(0.12, 0.13, 0.15))

	if muzzle_p.contains("소음기"):
		canvas.draw_rect(Rect2(barrel_tip + Vector2(b_len, -4), Vector2(38, 16)), Color(0.08, 0.09, 0.1))
	elif muzzle_p.contains("컴펜세이터"):
		canvas.draw_rect(Rect2(barrel_tip + Vector2(b_len, -2), Vector2(14, 12)), Color(0.3, 0.35, 0.4))
	elif muzzle_p.contains("소염기"):
		canvas.draw_rect(Rect2(barrel_tip + Vector2(b_len, -1), Vector2(10, 10)), Color(0.2, 0.2, 0.25))

	# [조준경 / 스코프]
	var optic_p: String = String(parts.get("optic", ""))
	var optic_mount: Vector2 = rec_pos + Vector2(rec_w * 0.4, -6)
	if optic_p.contains("8배율"):
		canvas.draw_rect(Rect2(optic_mount + Vector2(-25, -16), Vector2(65, 14)), Color(0.1, 0.12, 0.14))
		canvas.draw_circle(optic_mount + Vector2(38, -9), 8.0, Color(0.3, 0.6, 0.9, 0.8))
	elif optic_p.contains("4배율"):
		canvas.draw_polygon(PackedVector2Array([
			optic_mount + Vector2(-15, 0), optic_mount + Vector2(-10, -14),
			optic_mount + Vector2(25, -14), optic_mount + Vector2(30, 0)
		]), PackedColorArray([Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18)]))
	elif optic_p.contains("레드닷"):
		canvas.draw_rect(Rect2(optic_mount + Vector2(-8, -12), Vector2(22, 12)), Color(0.12, 0.12, 0.15))
		canvas.draw_circle(optic_mount + Vector2(3, -6), 2.0, Color.RED)

	# [손잡이]
	var grip_p: String = String(parts.get("grip", ""))
	var grip_pos: Vector2 = rec_pos + Vector2(rec_w * 0.75, rec_h)
	if grip_p.contains("수직"):
		canvas.draw_rect(Rect2(grip_pos, Vector2(10, 22)), Color(0.12, 0.12, 0.14))
	elif grip_p.contains("인체공학") or grip_p.contains("RK-1"):
		canvas.draw_polygon(PackedVector2Array([
			grip_pos, grip_pos + Vector2(12, 0),
			grip_pos + Vector2(6, 20), grip_pos + Vector2(-6, 20)
		]), PackedColorArray([Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25), Color(0.2, 0.22, 0.25)]))

	# [탄창]
	var mag_p: String = String(parts.get("magazine", ""))
	var mag_pos: Vector2 = rec_pos + Vector2(rec_w * 0.45, rec_h)
	if mag_p.contains("드럼"):
		canvas.draw_circle(mag_pos + Vector2(8, 16), 16.0, Color(0.1, 0.12, 0.14))
	elif mag_p.contains("확장"):
		canvas.draw_polygon(PackedVector2Array([
			mag_pos, mag_pos + Vector2(14, 0),
			mag_pos + Vector2(22, 34), mag_pos + Vector2(8, 34)
		]), PackedColorArray([Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18), Color(0.15, 0.15, 0.18)]))
	else:
		canvas.draw_rect(Rect2(mag_pos, Vector2(14, 24)), Color(0.18, 0.18, 0.2))

	# [개머리판]
	var stock_p: String = String(parts.get("stock", ""))
	var stock_pos: Vector2 = rec_pos + Vector2(-45, 0)
	if stock_p.contains("PRS") or stock_p.contains("저격"):
		canvas.draw_rect(Rect2(stock_pos, Vector2(45, 20)), Color(0.15, 0.16, 0.18))
		canvas.draw_rect(Rect2(stock_pos + Vector2(-6, -4), Vector2(10, 28)), Color(0.1, 0.1, 0.12))
	elif stock_p.contains("접이식") or stock_p.contains("경량"):
		canvas.draw_line(rec_pos + Vector2(0, 4), stock_pos + Vector2(0, 4), Color(0.2, 0.2, 0.25), 3.0)
		canvas.draw_rect(Rect2(stock_pos + Vector2(-4, -2), Vector2(6, 24)), Color(0.12, 0.12, 0.15))

	# [레일 레이저/손전등]
	var rail_p: Variant = parts.get("rail", [])
	if rail_p is Array and rail_p.size() > 0:
		for rp in rail_p:
			var rp_str: String = String(rp)
			if rp_str.contains("레이저"):
				canvas.draw_line(barrel_tip + Vector2(b_len, 2), barrel_tip + Vector2(b_len + 180, 2), Color(1.0, 0.2, 0.2, 0.65), 1.2)
				canvas.draw_circle(barrel_tip + Vector2(b_len + 180, 2), 2.5, Color.RED)
			elif rp_str.contains("손전등"):
				canvas.draw_polygon(PackedVector2Array([
					barrel_tip + Vector2(b_len, 6),
					barrel_tip + Vector2(b_len + 120, -30),
					barrel_tip + Vector2(b_len + 120, 42)
				]), PackedColorArray([Color(1.0, 1.0, 0.6, 0.25), Color(1.0, 1.0, 0.6, 0.0), Color(1.0, 1.0, 0.6, 0.0)]))
