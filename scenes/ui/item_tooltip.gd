# res://scenes/ui/item_tooltip.gd
class_name ItemTooltip
extends PanelContainer

## 아이템 설명 및 제원에 맞춰 유동적으로 크기가 조절되는 전술 플로팅 툴팁

@onready var icon_rect: TextureRect = $VBox/HeaderHBox/IconRect
@onready var name_label: Label = $VBox/HeaderHBox/TitleVBox/NameLabel
@onready var meta_label: Label = $VBox/HeaderHBox/TitleVBox/MetaLabel
@onready var header_sep: HSeparator = $VBox/HeaderSep
@onready var desc_label: Label = $VBox/DescLabel
@onready var desc_sep: HSeparator = $VBox/DescSep
@onready var attachments_label: RichTextLabel = $VBox/AttachmentsLabel
@onready var stats_label: RichTextLabel = $VBox/StatsLabel
@onready var durability_sep: HSeparator = $VBox/DurabilitySep
@onready var durability_container: VBoxContainer = $VBox/DurabilityContainer
@onready var durability_label: Label = $VBox/DurabilityContainer/DurabilityLabel
@onready var durability_bar: ProgressBar = $VBox/DurabilityContainer/DurabilityBar

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func display_item(raw_item: Dictionary, data: Dictionary = {}) -> void:
	if raw_item.is_empty() and data.is_empty():
		hide()
		return
		
	var item: Dictionary = raw_item.duplicate(false)
	var cdata = item.get("custom_data", {})
	if cdata is Dictionary and not cdata.is_empty():
		var clean_cd := InventoryGrid.sanitize_custom_data(cdata)
		for k in ["parts", "attachments", "loaded_ammo", "current_magazine_ammo", "computed_stats", "durability", "max_durability", "receiver", "name", "type"]:
			if not item.has(k) and clean_cd.has(k):
				item[k] = clean_cd[k]
		
	var item_id: String = str(item.get("id", data.get("id", "")))
	if data.is_empty() and item_id != "" and ItemDatabase:
		data = ItemDatabase.get_item_data(item_id)
		
	# 1. 아이콘 표시
	if icon_rect:
		if ItemIconManager and item_id != "":
			var tex = ItemIconManager.get_icon(item_id)
			if tex:
				icon_rect.texture = tex
				icon_rect.show()
			else:
				icon_rect.hide()
		else:
			icon_rect.hide()

	# 2. 아이템 이름 및 희귀도 색상
	var item_name: String = str(data.get("name", item.get("name", item_id)))
	if item_name == "":
		item_name = "미확인 아이템"
	name_label.text = item_name
	
	var rarity: float = float(data.get("rarity", 0.5))
	var name_color: Color = Color(0.92, 0.94, 0.96)
	var border_color: Color = Color(0.28, 0.36, 0.46, 0.85)
	
	if rarity <= 0.05:
		name_color = Color(1.0, 0.78, 0.2) # 레전더리 (황금)
		border_color = Color(1.0, 0.78, 0.2, 0.95)
	elif rarity <= 0.15:
		name_color = Color(0.8, 0.45, 1.0) # 에픽 (보라)
		border_color = Color(0.8, 0.45, 1.0, 0.95)
	elif rarity <= 0.35:
		name_color = Color(0.3, 0.72, 1.0) # 레어 (파랑)
		border_color = Color(0.3, 0.72, 1.0, 0.95)
		
	name_label.add_theme_color_override("font_color", name_color)
	
	# 테두리 색상 갱신 (픽셀 코너 및 안티앨리어싱 비활성화)
	var current_sb = get_theme_stylebox("panel")
	if current_sb is StyleBoxFlat:
		var custom_sb = current_sb.duplicate() as StyleBoxFlat
		custom_sb.border_color = border_color
		custom_sb.corner_radius_top_left = 0
		custom_sb.corner_radius_top_right = 0
		custom_sb.corner_radius_bottom_left = 0
		custom_sb.corner_radius_bottom_right = 0
		custom_sb.corner_detail = 1
		custom_sb.anti_aliasing = false
		add_theme_stylebox_override("panel", custom_sb)
		
	# 3. 카테고리 / 무게 / 가격 메타데이터
	var cat_str = "일반"
	var cat = data.get("category", -1)
	match cat:
		0: cat_str = "식량"
		1: cat_str = "음료"
		2: cat_str = "의료"
		3: cat_str = "무기"
		4: cat_str = "도구"
		5: cat_str = "재료"
		6: cat_str = "장비"
		7: cat_str = "퀘스트"
		_: cat_str = "잡화"
		
	var weight: float = float(data.get("weight", 0.1))
	var value: int = int(data.get("value", 0))
	var amt: int = int(item.get("amount", 1))
	
	if amt > 1:
		meta_label.text = "[%s]  수량: %d개  |  무게: %.1fkg  |  가치: %d RUB" % [cat_str, amt, weight * amt, value * amt]
	else:
		meta_label.text = "[%s]  무게: %.1fkg  |  가치: %d RUB" % [cat_str, weight, value]
	
	# 4. 설명 텍스트
	var desc: String = str(data.get("description", ""))
	if desc != "":
		desc_label.text = desc
		desc_label.show()
	else:
		desc_label.text = ""
		desc_label.hide()
	
	# 5. 총기 개조 부착물 및 제원 or 일반 아이템 상세
	var raw_id = item.get("receiver", item.get("id", ""))
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(str(raw_id))
	var is_gun = WeaponPartsDatabase.is_modifiable_weapon(item) or WeaponPartsDatabase.RECEIVERS.has(rec_id)
	
	if is_gun:
		_display_gun_details(item, rec_id, data)
	else:
		_display_general_item_details(item, data)
		
	# 6. 내구도 바
	var max_dur = float(item.get("max_durability", data.get("max_durability", 0)))
	if max_dur > 0:
		durability_container.show()
		var cur_dur = float(item.get("durability", max_dur))
		durability_label.text = "내구도: %d / %d" % [int(cur_dur), int(max_dur)]
		durability_bar.max_value = max_dur
		durability_bar.value = cur_dur
		
		var ratio = cur_dur / max_dur
		var fill_style = StyleBoxFlat.new()
		fill_style.corner_radius_top_left = 0
		fill_style.corner_radius_top_right = 0
		fill_style.corner_radius_bottom_right = 0
		fill_style.corner_radius_bottom_left = 0
		fill_style.corner_detail = 1
		fill_style.anti_aliasing = false
		if ratio > 0.6:
			fill_style.bg_color = Color(0.2, 0.8, 0.3)
		elif ratio > 0.3:
			fill_style.bg_color = Color(0.9, 0.7, 0.1)
		else:
			fill_style.bg_color = Color(0.9, 0.2, 0.2)
		durability_bar.add_theme_stylebox_override("fill", fill_style)
	else:
		durability_container.hide()
		
	# 7. 구분선(Separator) 가시성 제어 (내용이 있는 섹션 사이에만 표시)
	var has_desc = desc_label.visible and desc_label.text != ""
	var has_attach = attachments_label.visible and attachments_label.text != ""
	var has_stats = stats_label.visible and stats_label.text != ""
	var has_dur = durability_container.visible
	
	if header_sep:
		header_sep.visible = has_desc or has_attach or has_stats or has_dur
	if desc_sep:
		desc_sep.visible = has_desc and (has_attach or has_stats or has_dur)
	if durability_sep:
		durability_sep.visible = (has_attach or has_stats) and has_dur
		
	# 8. 컨테이너 크기 즉시 재계산
	show()
	reset_size()

func _display_gun_details(item: Dictionary, rec_id: String, _data: Dictionary) -> void:
	var parts = item.get("parts", item.get("attachments", {}))
	var ammo = str(item.get("loaded_ammo", ""))
	
	var base_stats = WeaponPartsDatabase.compute_weapon_stats(rec_id, {}, ammo)
	var cur_stats = item.get("computed_stats", WeaponPartsDatabase.compute_weapon_stats(rec_id, parts, ammo))
	
	# === 1. 장착된 부착물 파츠 목록 ===
	var slot_korean_names = {
		"barrel": "총열",
		"muzzle": "총구",
		"optic": "조준경",
		"grip": "손잡이",
		"magazine": "탄창",
		"stock": "개머리판",
		"rail": "레일"
	}
	
	var attach_lines: Array[String] = []
	attach_lines.append("[color=#e09f3e][b]ATTACHMENTS // 장착 부착물[/b][/color]")
	
	var has_parts = false
	for slot_key in ["barrel", "muzzle", "optic", "grip", "magazine", "stock", "rail"]:
		if parts.has(slot_key):
			var val = parts[slot_key]
			var slot_name = slot_korean_names.get(slot_key, slot_key)
			if val is Array:
				for single_p in val:
					if single_p != "" and WeaponPartsDatabase.PARTS.has(single_p):
						var p_name = WeaponPartsDatabase.PARTS[single_p].get("name", single_p)
						attach_lines.append(" • %s: [color=#8be9fd]%s[/color]" % [slot_name, p_name])
						has_parts = true
			elif val is String and val != "" and WeaponPartsDatabase.PARTS.has(val):
				var p_name = WeaponPartsDatabase.PARTS[val].get("name", val)
				attach_lines.append(" • %s: [color=#8be9fd]%s[/color]" % [slot_name, p_name])
				has_parts = true
				
	if not has_parts:
		attach_lines.append(" [color=#6272a4]• 순정 상태 (장착된 부품 없음)[/color]")
		
	if attachments_label:
		attachments_label.text = "\n".join(attach_lines)
		attachments_label.show()
		
	# === 2. 스탯 및 버프 수치 표시 ===
	var stat_lines: Array[String] = []
	stat_lines.append("[color=#50fa7b][b]SPECIFICATIONS // 무기 제원[/b][/color]")
	
	_append_gun_stat_line(stat_lines, "대미지", base_stats.get("damage", 20.0), cur_stats.get("damage", 20.0), "%.1f", true)
	_append_gun_stat_line(stat_lines, "명중률", base_stats.get("accuracy", 70.0), cur_stats.get("accuracy", 70.0), "%d%%", true)
	_append_gun_stat_line(stat_lines, "연사속도 (RPM)", base_stats.get("rpm", 150), cur_stats.get("rpm", 150), "%d", true)
	_append_gun_stat_line(stat_lines, "반동 제어", base_stats.get("recoil", 30.0), cur_stats.get("recoil", 30.0), "%.1f", false)
	_append_gun_stat_line(stat_lines, "유효 사거리", base_stats.get("range", 10.0), cur_stats.get("range", 10.0), "%.1fm", true)
	
	var cur_zoom = cur_stats.get("zoom", 1.0)
	if cur_zoom > 1.05:
		stat_lines.append(" • 조준경 배율: [color=#bd93f9]%.1fx[/color]" % cur_zoom)
		
	_append_gun_stat_line(stat_lines, "탄창 용량", base_stats.get("magazine_size", 15), cur_stats.get("magazine_size", 15), "%d발", true)
	_append_gun_stat_line(stat_lines, "사격 소음", base_stats.get("noise_radius", 600.0), cur_stats.get("noise_radius", 600.0), "%dpx", false)
	_append_gun_stat_line(stat_lines, "총기 중량", base_stats.get("weight", 2.0), cur_stats.get("weight", 2.0), "%.2fkg", false)

	var rec_info = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
	var compat_ammos: Array = rec_info.get("ammo_types", cur_stats.get("ammo_types", []))
	if not compat_ammos.is_empty():
		var cal_names: Array[String] = []
		for cal in compat_ammos:
			var cal_s := str(cal)
			cal_names.append("9mm 탄약" if cal_s in ["9mm", "탄약"] else cal_s.replace("_", " "))
		stat_lines.append(" • 호환 탄약: [color=#f1fa8c]%s[/color]" % ", ".join(cal_names))

	stat_lines.append("")
	stat_lines.append("[color=#8be9fd][b]USAGE // 총기 사용법[/b][/color]")
	var slot_hint := "[보조무기 슬롯 (3)]" if rec_info.get("category", "") == "pistol" else "[주무기 슬롯 (1/2)]"
	stat_lines.append(" • 장착: %s에 드래그 또는 우클릭 장착" % slot_hint)
	stat_lines.append(" • 조작: [좌클릭] 사격 | [우클릭] 정조준 | [R] 재장전 | [Alt+R] 탄종변경 | [B] 총기개조")
	
	if stats_label:
		stats_label.text = "\n".join(stat_lines)
		stats_label.show()

func _append_gun_stat_line(lines: Array[String], title: String, base_val: float, cur_val: float, fmt: String, higher_is_better: bool) -> void:
	var diff = cur_val - base_val
	var cur_str = fmt % cur_val
	
	if abs(diff) < 0.05:
		lines.append(" • %s: %s" % [title, cur_str])
	else:
		var is_good = (diff > 0) if higher_is_better else (diff < 0)
		var sign_str = "+" if diff > 0 else ""
		var arrow = "▲" if diff > 0 else "▼"
		var delta_str = "%s%s %s" % [sign_str, fmt % diff, arrow]
		var color_tag = "#50fa7b" if is_good else "#ff5555"
		lines.append(" • %s: %s [color=%s][b](%s)[/b][/color]" % [title, cur_str, color_tag, delta_str])

func _display_general_item_details(item: Dictionary, data: Dictionary) -> void:
	if attachments_label:
		attachments_label.hide()
		attachments_label.text = ""
	
	var item_id = str(item.get("id", data.get("id", "")))
	var stats: Array[String] = []
	
	# 부착물 파츠인 경우
	if WeaponPartsDatabase.PARTS.has(item_id):
		var p_data = WeaponPartsDatabase.PARTS[item_id]
		var slot_kor = {
			"barrel": "총열", "muzzle": "총구", "optic": "조준경",
			"grip": "손잡이", "magazine": "탄창", "stock": "개머리판", "rail": "레일"
		}
		var slot_name = slot_kor.get(p_data.get("slot", ""), p_data.get("slot", "기타"))
		stats.append("[color=#e09f3e][b]PART INFO // 총기 부착물[/b][/color]")
		stats.append(" • 부착 부위: [color=#8be9fd]%s[/color]" % slot_name)
		
		var mods = p_data.get("stat_modifiers", {})
		for m_key in mods.keys():
			var val = mods[m_key]
			match m_key:
				"damage":
					stats.append(" • 대미지: %+d" % val)
				"accuracy":
					stats.append(" • 명중률: %+d%%" % val)
				"recoil":
					stats.append(" • 반동: %+d" % val)
				"range":
					stats.append(" • 사거리: %+.1fm" % val)
				"ads_speed":
					stats.append(" • 조준 속도: %+d%%" % val)
				"noise_radius":
					stats.append(" • 사격 소음: %+dpx" % val)
				"weight":
					stats.append(" • 무게: %+.2fkg" % val)
				"magazine_size", "mag_capacity":
					stats.append(" • 탄창 용량: %d발" % val)
				"reload_speed":
					stats.append(" • 장전 시간: %.1f초" % val)
				"zoom":
					stats.append(" • 조준경 배율: %.1fx" % val)
		stats.append("")
		stats.append("[color=#8be9fd][b]USAGE // 장착 방법[/b][/color]")
		stats.append(" • 인벤토리 우측 무기 카드의 [%s] 슬롯으로 드래그하거나 우클릭 [장착], 또는 필드에서 [B] 총기 개조창 이용" % slot_name)
					
	# 탄약 제원
	elif WeaponPartsDatabase.AMMO_TYPES.has(item_id) or (item_id == "탄약" and WeaponPartsDatabase.AMMO_TYPES.has("9mm")):
		var lookup_id = "9mm" if item_id == "탄약" else item_id
		var a_data = WeaponPartsDatabase.AMMO_TYPES[lookup_id]
		stats.append("[color=#f1fa8c][b]AMMUNITION // 탄약 제원[/b][/color]")
		stats.append(" • 피해 배율: [color=#8be9fd]x%.2f[/color]" % a_data.get("damage_mult", 1.0))
		stats.append(" • 관통력: [color=#8be9fd]%d[/color]" % a_data.get("penetration", 10))
		var pellets = a_data.get("pellets", 1)
		if pellets > 1:
			stats.append(" • 펠릿 수: [color=#bd93f9]%d개 (산탄)[/color]" % pellets)
		stats.append("")
		stats.append("[color=#8be9fd][b]USAGE // 장전 방법[/b][/color]")
		stats.append(" • 호환 총기를 손에 들고 [R] 키 재장전 ([Alt+R] 탄종 전환), 또는 인벤토리에서 총기 슬롯 위로 드래그하여 직접 장전")
			
	# 일반 장비 및 소비 아이템
	else:
		if data.has("damage") and float(data["damage"]) > 0:
			stats.append(" • 공격력: %s" % str(data["damage"]))
		if data.has("defense") and float(data["defense"]) > 0:
			stats.append(" • 방어력 (DR): +%d" % int(data["defense"]))
		if data.has("speed_bonus") and float(data["speed_bonus"]) != 0:
			stats.append(" • 이동속도: %+d%%" % int(float(data["speed_bonus"]) * 100))
		if data.has("weight_bonus") and float(data["weight_bonus"]) != 0:
			stats.append(" • 가방 용량: %+0.1fkg" % float(data["weight_bonus"]))
			
		var bg = data.get("backpack_grid")
		if bg is Vector2i and bg != Vector2i.ZERO:
			stats.append(" • 수납 공간: [color=#8be9fd]%d칸 (%dx%d)[/color]" % [bg.x * bg.y, bg.x, bg.y])
			
		var effects = data.get("effects", {})
		if effects.has("hp"): stats.append(" • 체력 회복: [color=#50fa7b]+%d[/color]" % effects["hp"])
		if effects.has("hunger"): stats.append(" • 허기 회복: [color=#50fa7b]+%d[/color]" % effects["hunger"])
		if effects.has("thirst"): stats.append(" • 갈증 해소: [color=#8be9fd]+%d[/color]" % effects["thirst"])
		if effects.has("stamina"): stats.append(" • 스태미나: [color=#f1fa8c]+%d[/color]" % effects["stamina"])
		if effects.get("cures_bleeding", false): stats.append(" • [color=#ff79c6]출혈 지혈 효과[/color]")
		if effects.get("cures_fracture", false): stats.append(" • [color=#ff79c6]골절 치료 효과[/color]")
		if effects.get("cures_infection", false): stats.append(" • [color=#50fa7b]생체 감염(바이오하자드) 완치[/color]")
		if effects.get("poison_resist", false): stats.append(" • [color=#bd93f9]독성/방독 저항[/color]")
		
		var max_s = int(data.get("max_stack", 1))
		if max_s > 1:
			stats.append(" • 최대 중첩: %d개" % max_s)

		var usage_hint := _get_item_usage_hint(item_id, data)
		if usage_hint != "":
			stats.append("")
			stats.append("[color=#8be9fd][b]USAGE // 사용법[/b][/color]")
			stats.append(" • " + usage_hint)
	
	if stats_label:
		if stats.size() > 0:
			stats_label.text = "\n".join(stats)
			stats_label.show()
		else:
			stats_label.text = ""
			stats_label.hide()

static func _get_item_usage_hint(item_id: String, data: Dictionary) -> String:
	var item_type := str(data.get("type", ""))
	var cat := int(data.get("category", -1))
	var eq_slot := ItemDatabase.get_item_equip_slot(item_id) if ItemDatabase else str(data.get("equip_slot", ""))
	if item_type == "melee" or eq_slot == "melee" or item_id in ["나이프", "파이프", "도끼", "야구방망이"]:
		return "[보조무기 슬롯]에 장착 후 [3] 키로 선택 -> [좌클릭] 근접 공격 (탄약 불필요)"
	if item_type == "throwable" or eq_slot == "throwable" or item_id == "수류탄":
		return "[투척무기 슬롯]에 장착 후 [4] 키로 선택 -> [좌클릭] 조준 지점에 투척"
	if item_id == "지도":
		return "가방에 소지 후 [M] 키를 눌러 작전 구역 전체 지도 및 탈출구 확인 (무기 슬롯 장착 불가)"
	if item_id in ["군용 나침반", "나침반"]:
		return "가방에 소지 시 화면 상단 방위각(N/E/S/W) 나침반으로 방향 확인"
	if item_id == "손전등":
		return "[F] 키를 눌러 전술 라이트 점등/소등 전환"
	if item_id in ["장거리 무전기", "군용 무전기", "무전기"]:
		return "가방에 소지한 채 [U] 키를 눌러 드론 탄약 보급·풀턴 회수·정찰 스캔 호출"
	if item_id.contains("망원경"):
		return "[N] 키 전술 야간투시경(NVG) 및 [우클릭] 정조준 원거리 관측에 활용"
	if item_type in ["key", "keycard"] or item_id.contains("열쇠") or item_id.contains("키카드"):
		return "가방 또는 안전 컨테이너(2x2)에 소지한 상태로 잠긴 보안문 앞에서 [E] 키로 개방"
	if cat in [ItemDatabase.ItemCategory.FOOD, ItemDatabase.ItemCategory.WATER, ItemDatabase.ItemCategory.MEDICAL]:
		return "인벤토리에서 더블클릭/우클릭 [사용], 또는 필드 단축키 [5] 붕대 · [6] 구급 · [7] 식수"
	if cat == ItemDatabase.ItemCategory.EQUIPMENT or eq_slot in ["helmet", "vest", "backpack", "bottom"]:
		return "캐릭터 장비 슬롯으로 드래그하거나 더블클릭/우클릭 [장착]"
	return ""

func update_position(target_global_pos: Vector2) -> void:
	reset_size()
	
	var viewport_size = get_viewport_rect().size
	var target_pos = target_global_pos + Vector2(16, 16)
	
	# 우측 화면 이탈 시 마우스 좌측으로 반전
	if target_pos.x + size.x > viewport_size.x - 8.0:
		target_pos.x = target_global_pos.x - size.x - 12.0
		
	# 하단 화면 이탈 시 위쪽으로 밀어올림
	if target_pos.y + size.y > viewport_size.y - 8.0:
		target_pos.y = viewport_size.y - size.y - 8.0
		
	# 좌측 및 상단 화면 이탈 방지
	target_pos.x = maxf(target_pos.x, 8.0)
	target_pos.y = maxf(target_pos.y, 8.0)
		
	global_position = target_pos
