# res://scenes/ui/item_tooltip.gd
class_name ItemTooltip
extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var meta_label: Label = $VBox/MetaLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var stats_label: Label = $VBox/StatsLabel
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
	var item_name = data.get("name", item.get("id", "아이템"))
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
	
	# 4. 스탯 / 효과 목록
	var stats: Array[String] = []
	if data.has("damage"):
		stats.append("⚔️ 공격력: %d" % data["damage"])
	if data.has("defense"):
		stats.append("🛡️ 방어력: +%d" % data["defense"])
	if data.has("speed_bonus"):
		stats.append("⚡ 이동속도: +%d%%" % int(data["speed_bonus"] * 100))
	if data.has("weight_bonus"):
		stats.append("🎒 배낭 용량: +%.1fkg" % data["weight_bonus"])
		
	var effects = data.get("effects", {})
	if effects.has("hp"): stats.append("❤️ 체력 회복: +%d" % effects["hp"])
	if effects.has("hunger"): stats.append("🍖 허기 회복: +%d" % effects["hunger"])
	if effects.has("thirst"): stats.append("💧 갈증 해소: +%d" % effects["thirst"])
	if effects.has("stamina"): stats.append("🏃 스태미나: +%d" % effects["stamina"])
	if effects.get("cures_bleeding", false): stats.append("🩹 출혈 치료")
	if effects.get("cures_fracture", false): stats.append("🦴 골절 치료")
	if effects.get("poison_resist", false): stats.append("☣️ 방독/독 저항")
	
	if stats.size() > 0:
		stats_label.text = "\n".join(stats)
		stats_label.show()
	else:
		stats_label.hide()
		
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

func update_position(target_global_pos: Vector2) -> void:
	# 마우스 오른쪽에 뜨도록 배치 (화면 경계 클램핑)
	var viewport_size = get_viewport_rect().size
	var target_pos = target_global_pos + Vector2(16, 16)
	
	if target_pos.x + size.x > viewport_size.x:
		target_pos.x = target_global_pos.x - size.x - 12
	if target_pos.y + size.y > viewport_size.y:
		target_pos.y = viewport_size.y - size.y - 12
		
	global_position = target_pos
