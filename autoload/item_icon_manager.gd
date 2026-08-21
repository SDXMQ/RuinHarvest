# res://autoload/item_icon_manager.gd
extends Node

## 런타임에 게임 내 모든 아이템의 픽셀 아트 아이콘을 절차적으로 생성하고 캐싱하는 매니저

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
	
	match item_id:
		# === 무기 및 탄약 ===
		"권총", "pistol":
			_draw_gun(img, Color(0.2, 0.2, 0.25), size)
		"레버액션 소총", "shotgun", "rifle":
			_draw_gun(img, Color(0.45, 0.3, 0.2), size, true)
		"탄약", "9mm_ammo", "ammo":
			_draw_ammo(img, Color(0.85, 0.75, 0.25), size)
		"수류탄", "grenade":
			_draw_grenade(img, size)
		"파이프", "pipe":
			_draw_melee(img, Color(0.55, 0.55, 0.6), "pipe", size)
		"나이프", "knife":
			_draw_melee(img, Color(0.8, 0.8, 0.85), "knife", size)
		"야구방망이", "bat":
			_draw_melee(img, Color(0.7, 0.7, 0.75), "bat", size)
		"도끼", "axe":
			_draw_axe(img, size)

		# === 의료 ===
		"붕대", "bandage":
			_draw_bandage(img, size)
		"진통제", "painkillers":
			_draw_pills(img, size)
		"구급상자", "medkit":
			_draw_medkit(img, size)
		"고급 치료킷", "advanced_medkit":
			_draw_advanced_medkit(img, size)
		"약초", "herb":
			_draw_herb(img, size)

		# === 식량 및 음료 ===
		"생수", "water_bottle", "water":
			_draw_bottle(img, Color(0.2, 0.6, 0.9), size)
		"탄산음료", "soda":
			_draw_can(img, Color(0.8, 0.2, 0.2), size)
		"에너지 드링크", "energy_drink":
			_draw_can(img, Color(0.2, 0.8, 0.3), size)
		"커피", "coffee":
			_draw_can(img, Color(0.4, 0.25, 0.15), size)
		"식량통조림", "canned_food", "food":
			_draw_can(img, Color(0.8, 0.45, 0.15), size)
		"마른 빵", "bread":
			_draw_bread(img, size)
		"에너지바", "energy_bar":
			_draw_energy_bar(img, size)
		"고기 구이", "cooked_meat":
			_draw_meat(img, size)
		"전투 식량", "mre":
			_draw_mre(img, size)
		"농작물", "crop":
			_draw_crop(img, size)

		# === 장비 및 도구 ===
		"손전등", "flashlight":
			_draw_flashlight(img, size)
		"비상용 배터리", "battery":
			_draw_battery(img, size)
		"가방", "backpack":
			_draw_backpack(img, size)
		"방독면", "gasmask":
			_draw_gasmask(img, size)
		"방탄조끼", "body_armor":
			_draw_armor(img, size)
		"운동화", "sneakers":
			_draw_shoes(img, size)
		"지도", "map":
			_draw_map(img, size)
		"군용 나침반", "compass":
			_draw_compass(img, size)

		# === 재료 및 부품 ===
		"고철", "scrap":
			_draw_scrap(img, size)
		"나무", "wood":
			_draw_wood(img, size)
		"못", "nail":
			_draw_nails(img, size)
		"천", "cloth":
			_draw_cloth(img, size)
		"기계 부품", "mechanical_parts":
			_draw_gears(img, size)
		"폐전선", "wire":
			_draw_wire(img, size)
		"화약", "gunpowder":
			_draw_gunpowder(img, size)
		"CPU", "cpu":
			_draw_cpu(img, size)
		"그래픽카드", "gpu":
			_draw_gpu(img, size)

		# === 전리품 및 퀘스트 ===
		"금시계", "gold_watch":
			_draw_watch(img, Color(0.9, 0.75, 0.2), size)
		"은반지", "silver_ring":
			_draw_ring(img, Color(0.8, 0.85, 0.9), size)
		"골동품", "antique":
			_draw_vase(img, size)
		"라디오 부품", "radio_parts":
			_draw_radio_parts(img, size)
		"장거리 무전기", "radio":
			_draw_radio(img, size)
		"암호화된 SSD", "encrypted_ssd", "ssd":
			_draw_ssd(img, size)

		_:
			# 기본 더미 아이콘 (기하학적 상자)
			_draw_generic_box(img, size)
					
	return ImageTexture.create_from_image(img)

# ============================================================
# 개별 아이콘 픽셀 드로잉 함수들
# ============================================================

func _draw_gun(img: Image, color: Color, size: int, is_long: bool = false) -> void:
	var length = 20 if is_long else 13
	# 총열
	for x in range(6, 6 + length):
		for y in range(12, 16):
			img.set_pixel(x, y, color)
	# 총구 팁
	img.set_pixel(6 + length, 13, Color(0.1, 0.1, 0.1))
	img.set_pixel(6 + length, 14, Color(0.1, 0.1, 0.1))
	# 손잡이
	for x in range(6, 11):
		for y in range(16, 23):
			img.set_pixel(x, y, Color(0.35, 0.22, 0.15))
	# 방아쇠 울
	img.set_pixel(12, 17, Color(0.1, 0.1, 0.1))
	img.set_pixel(12, 18, Color(0.1, 0.1, 0.1))

func _draw_ammo(img: Image, color: Color, size: int) -> void:
	# 탄약 3발 나란히
	for i in range(3):
		var ox = 7 + i * 7
		for x in range(ox, ox + 5):
			for y in range(12, 23):
				var c = color
				if y < 15: c = Color(0.45, 0.45, 0.5) # 탄두 (구리/은색)
				elif y == 22: c = Color(0.2, 0.2, 0.2) # 바닥 림
				img.set_pixel(x, y, c)

func _draw_grenade(img: Image, size: int) -> void:
	for x in range(11, 21):
		for y in range(12, 24):
			var c = Color(0.25, 0.4, 0.25)
			if (x + y) % 3 == 0: c = Color(0.15, 0.25, 0.15) # 표면 요철
			img.set_pixel(x, y, c)
	# 안전핀 / 신관
	for x in range(14, 18):
		for y in range(7, 12):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.75))

func _draw_melee(img: Image, color: Color, m_type: String, size: int) -> void:
	# 대각선 방향 근접 무기
	for i in range(16):
		var x = 8 + i
		var y = 23 - i
		img.set_pixel(x, y, color)
		img.set_pixel(x + 1, y, color)
		if m_type == "knife" and i > 8:
			img.set_pixel(x + 2, y, color.lightened(0.2)) # 칼날
		elif m_type == "pipe":
			img.set_pixel(x, y + 1, Color(0.3, 0.3, 0.3))
		elif m_type == "bat" and i > 6:
			img.set_pixel(x + 1, y + 1, color)
			img.set_pixel(x + 2, y, color)

func _draw_axe(img: Image, size: int) -> void:
	# 자루 (나무)
	for i in range(18):
		var x = 7 + i
		var y = 24 - i
		img.set_pixel(x, y, Color(0.45, 0.3, 0.15))
		img.set_pixel(x + 1, y, Color(0.35, 0.2, 0.1))
	# 도끼날
	for x in range(19, 27):
		for y in range(5, 13):
			if x >= y + 13:
				img.set_pixel(x, y, Color(0.8, 0.8, 0.85))

func _draw_bandage(img: Image, size: int) -> void:
	for x in range(9, 23):
		for y in range(11, 21):
			var c = Color(0.92, 0.92, 0.88)
			if (x + y) % 4 == 0: c = Color(0.78, 0.78, 0.74)
			img.set_pixel(x, y, c)

func _draw_pills(img: Image, size: int) -> void:
	# 약통
	for x in range(10, 22):
		for y in range(11, 23):
			var c = Color(0.85, 0.5, 0.15) if y < 14 else Color(0.9, 0.9, 0.95)
			img.set_pixel(x, y, c)
	# 캡슐 1개 옆에
	for x in range(6, 12):
		for y in range(20, 24):
			img.set_pixel(x, y, Color(0.9, 0.2, 0.2) if x < 9 else Color(0.9, 0.9, 0.9))

func _draw_medkit(img: Image, size: int) -> void:
	for x in range(6, 26):
		for y in range(10, 23):
			img.set_pixel(x, y, Color(0.85, 0.2, 0.2))
	# 흰 십자가
	for x in range(14, 18):
		for y in range(12, 21):
			img.set_pixel(x, y, Color.WHITE)
	for x in range(10, 22):
		for y in range(14, 18):
			img.set_pixel(x, y, Color.WHITE)

func _draw_advanced_medkit(img: Image, size: int) -> void:
	# 고급 군용 카키색 메디킷
	for x in range(5, 27):
		for y in range(8, 24):
			img.set_pixel(x, y, Color(0.2, 0.35, 0.25))
	for x in range(14, 18):
		for y in range(11, 21):
			img.set_pixel(x, y, Color(0.9, 0.8, 0.2))
	for x in range(10, 22):
		for y in range(14, 18):
			img.set_pixel(x, y, Color(0.9, 0.8, 0.2))

func _draw_herb(img: Image, size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x - 16) * (x - 16) + (y - 16) * (y - 16) < 36:
				img.set_pixel(x, y, Color(0.25, 0.7, 0.3))
	# 줄기
	for y in range(18, 26):
		img.set_pixel(16, y, Color(0.15, 0.45, 0.2))

func _draw_bottle(img: Image, liquid_color: Color, size: int) -> void:
	for x in range(12, 20):
		for y in range(7, 26):
			if y < 11:
				img.set_pixel(x, y, Color(0.75, 0.75, 0.8)) # 뚜껑/주둥이
			else:
				var c = liquid_color if y > 15 else Color(0.9, 0.9, 0.95, 0.7)
				img.set_pixel(x, y, c)

func _draw_can(img: Image, color: Color, size: int) -> void:
	for x in range(10, 22):
		for y in range(9, 24):
			var c = color if (y > 11 and y < 22) else Color(0.75, 0.75, 0.8)
			img.set_pixel(x, y, c)

func _draw_bread(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(12, 22):
			var c = Color(0.8, 0.55, 0.25)
			if y == 12 or y == 21: c = Color(0.6, 0.4, 0.2)
			img.set_pixel(x, y, c)

func _draw_energy_bar(img: Image, size: int) -> void:
	for x in range(6, 26):
		for y in range(12, 20):
			var c = Color(0.9, 0.3, 0.1) if (x % 6 < 3) else Color(0.2, 0.2, 0.2)
			img.set_pixel(x, y, c)

func _draw_meat(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c = Color(0.55, 0.25, 0.15)
			if (x + y) % 5 == 0: c = Color(0.2, 0.1, 0.05) # 그릴 자국
			img.set_pixel(x, y, c)

func _draw_mre(img: Image, size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c = Color(0.65, 0.55, 0.35)
			if y > 12 and y < 16: c = Color(0.45, 0.35, 0.2) # 라벨
			img.set_pixel(x, y, c)

func _draw_crop(img: Image, size: int) -> void:
	for x in range(11, 21):
		for y in range(10, 24):
			img.set_pixel(x, y, Color(0.9, 0.5, 0.1)) # 당근/작물
	for x in range(13, 19):
		for y in range(6, 10):
			img.set_pixel(x, y, Color(0.2, 0.7, 0.2)) # 잎사귀

func _draw_flashlight(img: Image, size: int) -> void:
	# 손전등 몸통
	for x in range(8, 20):
		for y in range(13, 19):
			img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
	# 헤드
	for x in range(20, 25):
		for y in range(11, 21):
			img.set_pixel(x, y, Color(0.9, 0.8, 0.2))

func _draw_battery(img: Image, size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 24):
			var c = Color(0.15, 0.5, 0.2) if y > 14 else Color(0.9, 0.8, 0.1)
			img.set_pixel(x, y, c)
	# 단자
	for x in range(14, 18):
		for y in range(7, 10):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.75))

func _draw_backpack(img: Image, size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 25):
			var c = Color(0.35, 0.45, 0.3)
			if (y > 14 and y < 17) or (x > 14 and x < 17): c = Color(0.2, 0.25, 0.18) # 스트랩
			img.set_pixel(x, y, c)

func _draw_gasmask(img: Image, size: int) -> void:
	for x in range(9, 23):
		for y in range(8, 24):
			img.set_pixel(x, y, Color(0.25, 0.25, 0.28))
	# 유리 렌즈
	for x in range(11, 15):
		for y in range(11, 15):
			img.set_pixel(x, y, Color(0.3, 0.7, 0.8))
	for x in range(17, 21):
		for y in range(11, 15):
			img.set_pixel(x, y, Color(0.3, 0.7, 0.8))
	# 정화통
	for x in range(13, 19):
		for y in range(18, 23):
			img.set_pixel(x, y, Color(0.15, 0.15, 0.15))

func _draw_armor(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.2, 0.3, 0.25)
			if y < 12 and (x < 11 or x > 20): continue # 목둘레 파임
			img.set_pixel(x, y, c)

func _draw_shoes(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(14, 22):
			var c = Color(0.2, 0.5, 0.8) if y < 19 else Color(0.85, 0.85, 0.85) # 밑창
			img.set_pixel(x, y, c)

func _draw_map(img: Image, size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c = Color(0.9, 0.85, 0.7)
			if (x == 12 or x == 19) and y % 2 == 0: c = Color(0.7, 0.65, 0.5) # 접힌 선
			img.set_pixel(x, y, c)
	# 나침반 표시나 도로 선
	img.set_pixel(15, 14, Color.RED)
	img.set_pixel(16, 14, Color.RED)
	img.set_pixel(15, 15, Color.RED)

func _draw_compass(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 49:
				var c = Color(0.2, 0.3, 0.2)
				if dist > 36: c = Color(0.7, 0.65, 0.2) # 황동 테두리
				img.set_pixel(x, y, c)
	# 바늘 (북: 빨강, 남: 파랑)
	for y in range(10, 16):
		img.set_pixel(16, y, Color.RED)
	for y in range(16, 22):
		img.set_pixel(16, y, Color.CYAN)

func _draw_scrap(img: Image, size: int) -> void:
	for i in range(18):
		var px = randi_range(7, 23)
		var py = randi_range(7, 23)
		var c = Color(randf_range(0.4, 0.6), randf_range(0.35, 0.5), randf_range(0.3, 0.45))
		img.set_pixel(px, py, c)
		img.set_pixel(px + 1, py, c)

func _draw_wood(img: Image, size: int) -> void:
	for x in range(6, 26):
		for y in range(10, 22):
			var c = Color(0.55, 0.35, 0.2)
			if (y == 13 or y == 18): c = Color(0.4, 0.25, 0.12) # 나뭇결
			img.set_pixel(x, y, c)

func _draw_nails(img: Image, size: int) -> void:
	for i in range(3):
		var ox = 9 + i * 5
		for y in range(9, 23):
			img.set_pixel(ox, y, Color(0.7, 0.7, 0.75))
		img.set_pixel(ox - 1, 9, Color(0.4, 0.4, 0.4))
		img.set_pixel(ox + 1, 9, Color(0.4, 0.4, 0.4))

func _draw_cloth(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.7, 0.65, 0.6)
			if (x + y) % 3 == 0: c = Color(0.6, 0.55, 0.5)
			img.set_pixel(x, y, c)

func _draw_gears(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 45 and dist > 9:
				img.set_pixel(x, y, Color(0.6, 0.6, 0.65))
			elif dist <= 9:
				img.set_pixel(x, y, Color(0.2, 0.2, 0.2))

func _draw_wire(img: Image, size: int) -> void:
	for i in range(20):
		var x = int(16 + cos(i * 0.4) * 8)
		var y = int(16 + sin(i * 0.4) * 8)
		img.set_pixel(x, y, Color(0.85, 0.45, 0.2)) # 구리빛 전선
		img.set_pixel(x + 1, y, Color(0.2, 0.2, 0.8)) # 피복

func _draw_gunpowder(img: Image, size: int) -> void:
	for x in range(9, 23):
		for y in range(12, 24):
			var c = Color(0.2, 0.2, 0.22)
			if randf() < 0.3: c = Color(0.35, 0.35, 0.38)
			img.set_pixel(x, y, c)

func _draw_cpu(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.2, 0.55, 0.3)
			if x > 10 and x < 21 and y > 10 and y < 21:
				c = Color(0.75, 0.75, 0.8) # 금속 히트스프레더
			img.set_pixel(x, y, c)

func _draw_gpu(img: Image, size: int) -> void:
	for x in range(5, 27):
		for y in range(10, 22):
			var c = Color(0.2, 0.2, 0.25)
			if x % 6 == 0 and y > 12 and y < 19: c = Color(0.1, 0.6, 0.7) # 팬
			img.set_pixel(x, y, c)

func _draw_watch(img: Image, color: Color, size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 30:
				img.set_pixel(x, y, Color.WHITE if dist < 16 else color)

func _draw_ring(img: Image, color: Color, size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 32 and dist > 14:
				img.set_pixel(x, y, color)
	# 보석
	img.set_pixel(16, 10, Color(0.2, 0.8, 1.0))
	img.set_pixel(16, 11, Color(0.2, 0.8, 1.0))

func _draw_vase(img: Image, size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x >= 14 and x <= 17 and y < 12) or (y >= 12 and (x - 16) * (x - 16) + (y - 18) * (y - 18) < 25):
				img.set_pixel(x, y, Color(0.2, 0.5, 0.7)) # 청자

func _draw_radio_parts(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c = Color(0.25, 0.45, 0.3)
			if (x == 12 or x == 18) and y > 12 and y < 18: c = Color(0.8, 0.8, 0.2)
			img.set_pixel(x, y, c)

func _draw_radio(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(11, 23):
			img.set_pixel(x, y, Color(0.3, 0.35, 0.3))
	# 안테나
	for y in range(5, 11):
		img.set_pixel(10, y, Color(0.7, 0.7, 0.75))
	# 스피커 그릴
	for x in range(16, 21):
		for y in range(14, 20):
			if (x + y) % 2 == 0: img.set_pixel(x, y, Color(0.1, 0.1, 0.1))

func _draw_ssd(img: Image, size: int) -> void:
	for x in range(7, 25):
		for y in range(9, 23):
			var c = Color(0.15, 0.15, 0.18)
			if x > 16 and y > 18: c = Color(0.85, 0.75, 0.2) # 골드 핑거 커넥터
			img.set_pixel(x, y, c)

func _draw_generic_box(img: Image, size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.5, 0.5, 0.55)
			if x == 8 or x == 23 or y == 8 or y == 23: c = Color(0.2, 0.2, 0.25)
			img.set_pixel(x, y, c)
