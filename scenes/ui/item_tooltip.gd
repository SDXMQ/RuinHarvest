# res://scenes/ui/item_tooltip.gd
class_name ItemTooltip
extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var meta_label: Label = $VBox/MetaLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var attachments_label: RichTextLabel = $VBox/AttachmentsLabel
@onready var stats_label: RichTextLabel = $VBox/StatsLabel
@onready var durability_container: VBoxContainer = $VBox/DurabilityContainer
@onready var durability_label: Label = $VBox/DurabilityContainer/DurabilityLabel
@onready var durability_bar: ProgressBar = $VBox/DurabilityContainer/DurabilityBar

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func display_item(item: Dictionary, data: Dictionary) -> void:
	if item.is_empty() or data.is_empty():
		hide()
		return
		
	# 1. 이름 및 희귀도 색상
	var item_name = data.get("name", item.get("name", item.get("id", "아이템")))
	name_label.text = item_name
	
	var rarity = data.get("rarity", 0.5)
	if rarity <= 0.05:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # 레전더리 (황금)
	elif rarity <= 0.15:
		name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0)) # 에픽 (보라)
	elif rarity <= 0.35:
		name_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0)) # 레어 (파랑)
	else:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9)) # 일반 (흰색)
		
	# 2. 카테고리 / 무게 / 가격 메타데이터
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
		
	var weight = data.get("weight", 0.1)
	var value = data.get("value", 100)
	meta_label.text = "[%s]  무게: %.1fkg  |  가치: %d RUB" % [cat_str, weight, value]
	
	# 3. 설명
	var desc = data.get("description", "")
	desc_label.text = desc
	desc_label.visible = desc != ""
	
	# 4. 총기 개조 부착물 및 실시간 버프 스탯 비교
	var raw_id = item.get("receiver", item.get("id", ""))
	var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_id)
	var is_gun = WeaponPartsDatabase.is_modifiable_weapon(item) or WeaponPartsDatabase.RECEIVERS.has(rec_id)
	
	if is_gun:
		_display_gun_details(item, rec_id, data)
	else:
		_display_general_item_details(item, data)
		
	# 5. 내구도 바
	var max_dur = data.get("max_durability", 0)
	if max_dur > 0:
		durability_container.show()
		var cur_dur = item.get("durability", max_dur)
		durability_label.text = "내구도: %d / %d" % [int(cur_dur), int(max_dur)]
		durability_bar.max_value = max_dur
		durability_bar.value = cur_dur
		
		# 내구도 색상 변경
		var ratio = float(cur_dur) / float(max_dur)
		var fill_style = StyleBoxFlat.new()
		if ratio > 0.6:
			fill_style.bg_color = Color(0.2, 0.8, 0.3)
		elif ratio > 0.3:
			fill_style.bg_color = Color(0.9, 0.7, 0.1)
		else:
			fill_style.bg_color = Color(0.9, 0.2, 0.2)
		durability_bar.add_theme_stylebox_override("fill", fill_style)
	else:
		durability_container.hide()
		
	show()

func _display_gun_details(item: Dictionary, rec_id: String, _data: Dictionary) -> void:
	var parts = item.get("parts", item.get("attachments", {}))
	var ammo = item.get("loaded_ammo", "")
	
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
		
	# === 2. 스탯 및 버프 수치만 표시 ===
	var stat_lines: Array[String] = []
	stat_lines.append("[color=#50fa7b][b]SPECIFICATIONS // 무기 제원[/b][/color]")
	
	_append_gun_stat_line(stat_lines, "대미지", base_stats.get("damage", 20.0), cur_stats.get("damage", 20.0), "%.1f", true)
	_append_gun_stat_line(stat_lines, "명중률", base_stats.get("accuracy", 70.0), cur_stats.get("accuracy", 70.0), "%d%%", true)
	_append_gun_stat_line(stat_lines, "연사속도 (RPM)", base_stats.get("rpm", 150), cur_stats.get("rpm", 150), "%d", true)
	_append_gun_stat_line(stat_lines, "반동 제어", base_stats.get("recoil", 30.0), cur_stats.get("recoil", 30.0), "%.1f", false) # 반동 감소가 좋음
	_append_gun_stat_line(stat_lines, "유효 사거리", base_stats.get("range", 10.0), cur_stats.get("range", 10.0), "%.1fm", true)
	
	var cur_zoom = cur_stats.get("zoom", 1.0)
	if cur_zoom > 1.05:
		stat_lines.append(" • 조준경 배율: [color=#bd93f9]%.1fx[/color]" % cur_zoom)
		
	_append_gun_stat_line(stat_lines, "탄창 용량", base_stats.get("magazine_size", 15), cur_stats.get("magazine_size", 15), "%d발", true)
	_append_gun_stat_line(stat_lines, "사격 소음", base_stats.get("noise_radius", 600.0), cur_stats.get("noise_radius", 600.0), "%dpx", false) # 소음 감소가 좋음
	_append_gun_stat_line(stat_lines, "총기 중량", base_stats.get("weight", 2.0), cur_stats.get("weight", 2.0), "%.2fkg", false) # 무게 감소가 좋음
	
	if stats_label:
		stats_label.text = "\n".join(stat_lines)
		stats_label.show()

func _append_gun_stat_line(lines: Array[String], title: String, base_val: float, cur_val: float, fmt: String, higher_is_better: bool) -> void:
	var diff = cur_val - base_val
	var cur_str = fmt % cur_val
	
	if abs(diff) < 0.05:
		# 버프/너프가 없는 기본 수치
		lines.append(" • %s: %s" % [title, cur_str])
	else:
		# 버프/너프 수치 하이라이트
		var is_good = (diff > 0) if higher_is_better else (diff < 0)
		var sign_str = "+" if diff > 0 else ""
		var arrow = "▲" if diff > 0 else "▼"
		var delta_str = "%s%s %s" % [sign_str, fmt % diff, arrow]
		var color_tag = "#50fa7b" if is_good else "#ff5555"
		lines.append(" • %s: %s [color=%s][b](%s)[/b][/color]" % [title, cur_str, color_tag, delta_str])

func _display_general_item_details(_item: Dictionary, data: Dictionary) -> void:
	if attachments_label: attachments_label.hide()
	
	var stats: Array[String] = []
	if data.has("damage"): stats.append("• 공격력: %d" % data["damage"])
	if data.has("defense"): stats.append("• 방어력: +%d" % data["defense"])
	if data.has("speed_bonus"): stats.append("• 이동속도: +%d%%" % int(data["speed_bonus"] * 100))
	if data.has("weight_bonus"): stats.append("• 배낭 용량: +%.1fkg" % data["weight_bonus"])
		
	var effects = data.get("effects", {})
	if effects.has("hp"): stats.append("• 체력 회복: +%d" % effects["hp"])
	if effects.has("hunger"): stats.append("• 허기 회복: +%d" % effects["hunger"])
	if effects.has("thirst"): stats.append("• 갈증 해소: +%d" % effects["thirst"])
	if effects.has("stamina"): stats.append("• 스태미나: +%d" % effects["stamina"])
	if effects.get("cures_bleeding", false): stats.append("• 출혈 지혈")
	if effects.get("cures_fracture", false): stats.append("• 골절 부목 치료")
	if effects.get("poison_resist", false): stats.append("• 방독/독성 저항")
	
	if stats_label:
		if stats.size() > 0:
			stats_label.text = "\n".join(stats)
			stats_label.show()
		else:
			stats_label.hide()

func update_position(target_global_pos: Vector2) -> void:
	# 마우스 주변에 뜨도록 배치 (상하좌우 화면 경계 완벽 클램핑)
	var viewport_size = get_viewport_rect().size
	var target_pos = target_global_pos + Vector2(16, 16)
	
	if target_pos.x + size.x > viewport_size.x:
		target_pos.x = target_global_pos.x - size.x - 12
	if target_pos.y + size.y > viewport_size.y:
		target_pos.y = viewport_size.y - size.y - 12
		
	# 좌측 및 상단 화면 밖 이탈 방지
	target_pos.x = maxf(target_pos.x, 8.0)
	target_pos.y = maxf(target_pos.y, 8.0)
		
	global_position = target_pos
