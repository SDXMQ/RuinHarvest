# res://autoload/item_icon_manager.gd
extends Node

## 런타임에 게임 내 아이템들의 고해상도 픽셀 아트 아이콘을 절차적으로 생성하고 캐싱하는 매니저

var icon_cache: Dictionary = {}

func get_icon(item_id: String) -> Texture2D:
	if icon_cache.has(item_id):
		return icon_cache[item_id]
		
	var tex = _generate_icon(item_id)
	icon_cache[item_id] = tex
	return tex

func _generate_icon(item_id: String) -> Texture2D:
	var size = 32
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	
	# 기본 테두리나 그림자 설정 가능
	
	match item_id:
		"pistol":
			_draw_gun(img, Color(0.2, 0.2, 0.25), size)
		"shotgun":
			_draw_gun(img, Color(0.5, 0.3, 0.2), size, true)
		"bandage":
			_draw_bandage(img, size)
		"medkit":
			_draw_medkit(img, size)
		"water_bottle":
			_draw_bottle(img, Color(0.2, 0.6, 0.9), size)
		"canned_food":
			_draw_can(img, Color(0.8, 0.4, 0.2), size)
		"scrap":
			_draw_scrap(img, size)
		"9mm_ammo":
			_draw_ammo(img, Color(0.8, 0.7, 0.3), size)
		_:
			# 기본 더미 아이콘 (물음표 또는 사각형)
			for y in range(8, 24):
				for x in range(8, 24):
					img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 0.5))
					
	return ImageTexture.create_from_image(img)

# --- 개별 아이콘 그리기 함수들 ---

func _draw_gun(img: Image, color: Color, size: int, is_long: bool = false) -> void:
	# 단순화된 총기 픽셀 드로잉
	var length = 20 if is_long else 12
	# 총열
	for x in range(6, 6 + length):
		for y in range(12, 16):
			img.set_pixel(x, y, color)
	# 손잡이
	for x in range(6, 10):
		for y in range(16, 22):
			img.set_pixel(x, y, Color(0.3, 0.2, 0.15))

func _draw_bandage(img: Image, size: int) -> void:
	for x in range(10, 22):
		for y in range(12, 20):
			var c = Color(0.9, 0.9, 0.85)
			if x % 4 == 0 or y % 3 == 0: c = Color(0.8, 0.8, 0.75) # 주름
			img.set_pixel(x, y, c)

func _draw_medkit(img: Image, size: int) -> void:
	# 가방
	for x in range(6, 26):
		for y in range(10, 24):
			img.set_pixel(x, y, Color(0.8, 0.2, 0.2))
	# 적십자
	for x in range(14, 18):
		for y in range(12, 22):
			img.set_pixel(x, y, Color(1, 1, 1))
	for x in range(10, 22):
		for y in range(15, 19):
			img.set_pixel(x, y, Color(1, 1, 1))

func _draw_bottle(img: Image, liquid_color: Color, size: int) -> void:
	for x in range(12, 20):
		for y in range(8, 26):
			if y < 12:
				img.set_pixel(x, y, Color(0.8, 0.8, 0.8)) # 뚜껑
			else:
				var c = liquid_color if y > 16 else Color(0.9, 0.9, 0.9, 0.6)
				img.set_pixel(x, y, c)

func _draw_can(img: Image, color: Color, size: int) -> void:
	for x in range(10, 22):
		for y in range(12, 24):
			var c = color if y > 14 and y < 22 else Color(0.7, 0.7, 0.75)
			img.set_pixel(x, y, c)

func _draw_scrap(img: Image, size: int) -> void:
	for i in range(15):
		var px = randi_range(8, 24)
		var py = randi_range(8, 24)
		var c = Color(0.4, 0.4, 0.45)
		img.set_pixel(px, py, c)
		img.set_pixel(px+1, py, c)

func _draw_ammo(img: Image, color: Color, size: int) -> void:
	for x in range(12, 20):
		for y in range(10, 22):
			var c = color
			if y < 14: c = Color(0.4, 0.4, 0.4) # 탄두
			img.set_pixel(x, y, c)
