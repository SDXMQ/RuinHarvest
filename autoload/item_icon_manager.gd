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
	var lower_id = item_id.to_lower()
	
	# === 1. 방탄복 / 조끼 ===
	if item_id.contains("3레벨_방탄") or item_id.contains("3레벨_조끼") or lower_id.contains("armor_3") or lower_id.contains("heavy_armor"):
		_draw_armor_tier(img, 3, size)
	elif item_id.contains("2레벨_방탄") or item_id.contains("2레벨_조끼") or lower_id.contains("armor_2") or lower_id.contains("tactical_vest"):
		_draw_armor_tier(img, 2, size)
	elif item_id.contains("1레벨_방탄") or item_id.contains("1레벨_조끼") or item_id.contains("방탄") or item_id.contains("조끼") or lower_id.contains("armor"):
		_draw_armor_tier(img, 1, size)
		
	# === 2. 헬멧 / 방독면 ===
	elif item_id.contains("3레벨_헬멧") or lower_id.contains("helmet_3") or item_id.contains("스페츠나츠"):
		_draw_helmet_tier(img, 3, size)
	elif item_id.contains("2레벨_헬멧") or lower_id.contains("helmet_2") or item_id.contains("군용_헬멧"):
		_draw_helmet_tier(img, 2, size)
	elif item_id.contains("1레벨_헬멧") or item_id.contains("헬멧") or lower_id.contains("helmet"):
		_draw_helmet_tier(img, 1, size)
	elif item_id.contains("방독면") or lower_id.contains("gasmask"):
		_draw_gasmask(img, size)
		
	# === 3. 배낭 / 가방 ===
	elif item_id.contains("3레벨_가방") or item_id.contains("3레벨_배낭") or lower_id.contains("backpack_3"):
		_draw_backpack_tier(img, 3, size)
	elif item_id.contains("2레벨_가방") or item_id.contains("2레벨_배낭") or lower_id.contains("backpack_2"):
		_draw_backpack_tier(img, 2, size)
	elif item_id.contains("1레벨_가방") or item_id.contains("가방") or item_id.contains("배낭") or lower_id.contains("backpack"):
		_draw_backpack_tier(img, 1, size)
		
	# === 4. 신발 ===
	elif item_id.contains("운동화") or item_id.contains("신발") or lower_id.contains("sneaker") or lower_id.contains("boot"):
		_draw_shoes(img, size)
		
	# === 5. 총기 리시버 및 완제품 ===
	elif item_id.contains("레버액션") or lower_id.contains("lever"):
		_draw_receiver(img, "lever", size)
	elif item_id.contains("M4") or item_id.contains("m4"):
		_draw_receiver(img, "m4", size)
	elif item_id.contains("AK") or item_id.contains("ak"):
		_draw_receiver(img, "ak", size)
	elif item_id.contains("M9") or item_id.contains("m9") or item_id.contains("베레타"):
		_draw_receiver(img, "m9", size)
	elif item_id.contains("레밍턴") or item_id.contains("870") or item_id.contains("샷건") or lower_id.contains("shotgun"):
		_draw_receiver(img, "shotgun", size)
	elif item_id.contains("SV98") or item_id.contains("sv98") or item_id.contains("저격") or lower_id.contains("sniper"):
		_draw_receiver(img, "sv98", size)
	elif item_id.contains("권총") or lower_id.contains("pistol"):
		_draw_gun(img, Color(0.25, 0.25, 0.3), size)
	elif item_id.contains("소총") or lower_id.contains("rifle"):
		_draw_gun(img, Color(0.45, 0.3, 0.2), size, true)
		
	# === 6. 탄약류 ===
	elif item_id.contains("5.56"):
		_draw_ammo_type(img, "5.56mm", size)
	elif item_id.contains("7.62"):
		_draw_ammo_type(img, "7.62mm", size)
	elif item_id.contains("12게이지") or item_id.contains("벅샷") or item_id.contains("슬러그"):
		_draw_ammo_type(img, "12gauge", size)
	elif item_id.contains("9mm") or item_id.contains(".45") or item_id.contains("탄약") or lower_id.contains("ammo"):
		_draw_ammo_type(img, "9mm", size)
	elif item_id.contains("수류탄") or lower_id.contains("grenade"):
		_draw_grenade(img, size)
		
	# === 7. 총기 부착물 (파츠) ===
	elif item_id.contains("조준경") or item_id.contains("사이트") or item_id.contains("ACOG") or item_id.contains("스코프") or lower_id.contains("optic") or lower_id.contains("scope"):
		_draw_attachment(img, "optic", item_id, size)
	elif item_id.contains("소음기") or item_id.contains("소염기") or item_id.contains("컴펜세이터") or lower_id.contains("muzzle"):
		_draw_attachment(img, "muzzle", item_id, size)
	elif item_id.contains("손잡이") or item_id.contains("그립") or lower_id.contains("grip"):
		_draw_attachment(img, "grip", item_id, size)
	elif item_id.contains("탄창") or lower_id.contains("mag"):
		_draw_attachment(img, "magazine", item_id, size)
	elif item_id.contains("개머리판") or item_id.contains("스톡") or lower_id.contains("stock"):
		_draw_attachment(img, "stock", item_id, size)
	elif item_id.contains("총열") or lower_id.contains("barrel"):
		_draw_attachment(img, "barrel", item_id, size)
		
	# === 8. 근접 무기 ===
	elif item_id.contains("도끼") or lower_id.contains("axe"):
		_draw_axe(img, size)
	elif item_id.contains("나이프") or item_id.contains("칼") or lower_id.contains("knife"):
		_draw_melee(img, Color(0.8, 0.8, 0.85), "knife", size)
	elif item_id.contains("야구방망이") or lower_id.contains("bat"):
		_draw_melee(img, Color(0.7, 0.7, 0.75), "bat", size)
	elif item_id.contains("파이프") or lower_id.contains("pipe"):
		_draw_melee(img, Color(0.55, 0.55, 0.6), "pipe", size)
		
	# === 9. 의료품 ===
	elif item_id.contains("고급") and item_id.contains("치료"):
		_draw_advanced_medkit(img, size)
	elif item_id.contains("구급상자") or item_id.contains("키트") or lower_id.contains("medkit"):
		_draw_medkit(img, size)
	elif item_id.contains("붕대") or lower_id.contains("bandage"):
		_draw_bandage(img, size)
	elif item_id.contains("진통제") or item_id.contains("약") or lower_id.contains("pills"):
		_draw_pills(img, size)
	elif item_id.contains("약초") or lower_id.contains("herb"):
		_draw_herb(img, size)
		
	# === 10. 식량 및 음료 ===
	elif item_id.contains("생수") or item_id.contains("물") or lower_id.contains("water"):
		_draw_bottle(img, Color(0.2, 0.65, 0.95), size)
	elif item_id.contains("탄산음료") or lower_id.contains("soda"):
		_draw_can(img, Color(0.85, 0.2, 0.2), size)
	elif item_id.contains("에너지 드링크") or lower_id.contains("energy"):
		_draw_can(img, Color(0.2, 0.85, 0.35), size)
	elif item_id.contains("커피") or lower_id.contains("coffee"):
		_draw_can(img, Color(0.45, 0.28, 0.18), size)
	elif item_id.contains("통조림") or item_id.contains("식량") or lower_id.contains("canned"):
		_draw_can(img, Color(0.85, 0.5, 0.15), size)
	elif item_id.contains("빵") or lower_id.contains("bread"):
		_draw_bread(img, size)
	elif item_id.contains("에너지바") or lower_id.contains("bar"):
		_draw_energy_bar(img, size)
	elif item_id.contains("고기") or lower_id.contains("meat"):
		_draw_meat(img, size)
	elif item_id.contains("전투 식량") or lower_id.contains("mre"):
		_draw_mre(img, size)
		
	# === 11. 도구 및 잡품 ===
	elif item_id.contains("손전등") or lower_id.contains("flashlight"):
		_draw_flashlight(img, size)
	elif item_id.contains("배터리") or lower_id.contains("battery"):
		_draw_battery(img, size)
	elif item_id.contains("지도") or lower_id.contains("map"):
		_draw_map(img, size)
	elif item_id.contains("나침반") or lower_id.contains("compass"):
		_draw_compass(img, size)
	elif item_id.contains("고철") or lower_id.contains("scrap"):
		_draw_scrap(img, size)
	elif item_id.contains("나무") or lower_id.contains("wood"):
		_draw_wood(img, size)
	elif item_id.contains("못") or lower_id.contains("nail"):
		_draw_nails(img, size)
	elif item_id.contains("천") or lower_id.contains("cloth"):
		_draw_cloth(img, size)
	elif item_id.contains("기계") or lower_id.contains("gear"):
		_draw_gears(img, size)
	elif item_id.contains("전선") or lower_id.contains("wire"):
		_draw_wire(img, size)
	elif item_id.contains("화약") or lower_id.contains("gunpowder"):
		_draw_gunpowder(img, size)
	elif item_id.contains("CPU") or lower_id.contains("cpu"):
		_draw_cpu(img, size)
	elif item_id.contains("그래픽") or lower_id.contains("gpu"):
		_draw_gpu(img, size)
	elif item_id.contains("금시계") or lower_id.contains("watch"):
		_draw_watch(img, Color(0.95, 0.8, 0.2), size)
	elif item_id.contains("은반지") or lower_id.contains("ring"):
		_draw_ring(img, Color(0.85, 0.9, 0.95), size)
	elif item_id.contains("골동품") or lower_id.contains("vase"):
		_draw_vase(img, size)
	elif item_id.contains("무전기") or item_id.contains("라디오"):
		_draw_radio(img, size)
	elif item_id.contains("열쇠") or lower_id.contains("key_"):
		_draw_key(img, size)
	elif item_id.contains("키카드") or lower_id.contains("keycard"):
		_draw_keycard(img, size)
	elif item_id.contains("SSD") or lower_id.contains("ssd"):
		_draw_ssd(img, size)
	else:
		_draw_generic_box(img, size)
		
	return ImageTexture.create_from_image(img)

# ============================================================
# 1. 방탄복 / 헬멧 / 배낭 티어별 정밀 드로잉
# ============================================================
func _draw_armor_tier(img: Image, tier: int, _size: int) -> void:
	var base_col = Color(0.2, 0.25, 0.35) # 1티어: 네이비 경찰 조끼
	var accent_col = Color(0.3, 0.4, 0.55)
	if tier == 2:
		base_col = Color(0.28, 0.38, 0.22) # 2티어: 올리브 전술 방탄복
		accent_col = Color(0.18, 0.26, 0.14)
	elif tier == 3:
		base_col = Color(0.12, 0.13, 0.15) # 3티어: 블랙 중장갑 플레이트 캐리어
		accent_col = Color(0.25, 0.28, 0.3)
		
	# 몸통 조끼 실루엣
	for x in range(7, 25):
		for y in range(7, 26):
			if y < 12 and (x < 11 or x > 20): continue # 어깨 파임
			if y > 22 and (x < 9 or x > 22): continue
			img.set_pixel(x, y, base_col)
			
	# 어깨 스트랩 및 벨크로
	for x in range(11, 14):
		for y in range(7, 12): img.set_pixel(x, y, accent_col)
	for x in range(18, 21):
		for y in range(7, 12): img.set_pixel(x, y, accent_col)
		
	# 티어별 특징 디테일
	if tier == 1:
		# 경찰 패치 / 지퍼 라인
		for y in range(12, 24): img.set_pixel(15, y, Color(0.15, 0.15, 0.2))
		for x in range(12, 19): img.set_pixel(x, 14, Color(0.8, 0.8, 0.3, 0.9)) # 패치
	elif tier == 2:
		# MOLLE 웨빙 3줄 및 매거진 파우치 2개
		for y in [14, 18, 22]:
			for x in range(9, 23):
				if x % 2 == 0: img.set_pixel(x, y, accent_col)
		# 탄창 파우치 2개
		for x in range(10, 14):
			for y in range(16, 22): img.set_pixel(x, y, Color(0.2, 0.3, 0.18))
		for x in range(17, 21):
			for y in range(16, 22): img.set_pixel(x, y, Color(0.2, 0.3, 0.18))
	elif tier == 3:
		# 대형 세라믹 플레이트 각인 및 목 보호대
		for x in range(9, 23):
			for y in range(13, 23):
				if x == 9 or x == 22 or y == 13 or y == 22:
					img.set_pixel(x, y, Color(0.35, 0.4, 0.45)) # 금속/세라믹 테두리
		# 강화 패드
		for x in range(12, 19):
			for y in range(16, 20): img.set_pixel(x, y, Color(0.08, 0.08, 0.1))

func _draw_helmet_tier(img: Image, tier: int, _size: int) -> void:
	var dome_col = Color(0.7, 0.2, 0.2) # 1티어: 붉은색 오토바이 헬멧
	if tier == 2: dome_col = Color(0.3, 0.4, 0.25) # 2티어: 올리브 군용 방탄모
	elif tier == 3: dome_col = Color(0.2, 0.22, 0.25) # 3티어: 스페츠나츠 알틴 헬멧
	
	# 헬멧 둥근 돔
	for x in range(8, 24):
		for y in range(7, 22):
			var dx = (x - 15.5) / 7.5
			var dy = (y - 14.0) / 7.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, dome_col)
				
	# 바이저 / 특징 디테일
	if tier == 1:
		# 오토바이 풀페이스 블랙 틴트 바이저
		for x in range(12, 23):
			for y in range(13, 18):
				img.set_pixel(x, y, Color(0.1, 0.12, 0.15))
		# 하이라이트
		img.set_pixel(13, 14, Color(0.8, 0.8, 0.9, 0.8))
	elif tier == 2:
		# 방탄모 챙 & 야투경 마운트
		for x in range(7, 25): img.set_pixel(x, 19, Color(0.22, 0.3, 0.18))
		for x in range(14, 18):
			for y in range(12, 16): img.set_pixel(x, y, Color(0.15, 0.15, 0.15))
	elif tier == 3:
		# 티타늄 안면 방탄 쉴드 & 슬릿
		for x in range(11, 24):
			for y in range(12, 21):
				img.set_pixel(x, y, Color(0.35, 0.38, 0.4))
		# 방탄 유리 슬릿
		for x in range(13, 22):
			img.set_pixel(x, 15, Color(0.2, 0.7, 0.9))
			img.set_pixel(x, 16, Color(0.2, 0.7, 0.9))

func _draw_backpack_tier(img: Image, tier: int, _size: int) -> void:
	var col = Color(0.45, 0.4, 0.3) # 1티어: 소형 카키 럭색
	var min_x = 9
	var max_x = 23
	var min_y = 9
	var max_y = 24
	
	if tier == 2:
		col = Color(0.3, 0.4, 0.28) # 2티어: 중형 올리브 백팩
		min_x = 7
		max_x = 25
		min_y = 8
		max_y = 25
	elif tier == 3:
		col = Color(0.18, 0.18, 0.2) # 3티어: 대형 블랙 전술 백팩
		min_x = 6
		max_x = 26
		min_y = 7
		max_y = 26
		
	# 가방 본체
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			img.set_pixel(x, y, col)
			
	# 포켓 및 스트랩
	for y in range(min_y + 4, max_y - 2):
		img.set_pixel(min_x + 3, y, col.darkened(0.25))
		img.set_pixel(max_x - 4, y, col.darkened(0.25))
	for x in range(min_x + 2, max_x - 2):
		img.set_pixel(x, min_y + 7, Color(0.15, 0.15, 0.15)) # 지퍼
		
	if tier >= 2:
		# 사이드 포켓
		for y in range(min_y + 6, max_y - 2):
			img.set_pixel(min_x - 1, y, col.darkened(0.15))
			img.set_pixel(max_x, y, col.darkened(0.15))
	if tier == 3:
		# 침낭 롤 / 압축 버클
		for x in range(min_x, max_x):
			img.set_pixel(x, min_y - 1, Color(0.35, 0.3, 0.25))
			img.set_pixel(x, max_y, Color(0.35, 0.3, 0.25))

# ============================================================
# 2. 총기 리시버 및 완제품 드로잉
# ============================================================
func _draw_receiver(img: Image, rec_type: String, _size: int) -> void:
	if rec_type == "m4":
		# M4A1 리시버 (상부 피카티니 레일, 탄창구, 버퍼튜브)
		for x in range(5, 27):
			for y in range(12, 17): img.set_pixel(x, y, Color(0.2, 0.22, 0.25))
		# 피카티니 레일 요철
		for x in range(6, 26):
			if x % 2 == 0: img.set_pixel(x, 11, Color(0.35, 0.38, 0.4))
		# 손잡이
		for x in range(7, 12):
			for y in range(17, 24): img.set_pixel(x, y, Color(0.15, 0.15, 0.18))
		# 탄창 삽입구
		for x in range(14, 19):
			for y in range(17, 21): img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
	elif rec_type == "ak":
		# AK-47 리시버 (목재 손잡이/핸드가드 + 스틸 리시버)
		for x in range(5, 27):
			for y in range(12, 17): img.set_pixel(x, y, Color(0.28, 0.3, 0.32))
		# 가스 튜브 & 목재 핸드가드
		for x in range(18, 27):
			for y in range(11, 16): img.set_pixel(x, y, Color(0.55, 0.3, 0.15))
		# 목재 손잡이
		for x in range(6, 11):
			for y in range(17, 24): img.set_pixel(x, y, Color(0.5, 0.28, 0.12))
		# 곡선 탄창 삽입구
		for x in range(13, 18):
			for y in range(17, 21): img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
	elif rec_type == "m9":
		# M9 베레타 권총
		for x in range(8, 24):
			for y in range(13, 17): img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
		for x in range(7, 13):
			for y in range(17, 25): img.set_pixel(x, y, Color(0.18, 0.18, 0.2))
		img.set_pixel(23, 14, Color(0.1, 0.1, 0.1)) # 총구
	elif rec_type == "shotgun":
		# 레밍턴 870 펌프액션 샷건
		for x in range(4, 28):
			for y in range(13, 17): img.set_pixel(x, y, Color(0.3, 0.32, 0.35))
		# 펌프 포어엔드
		for x in range(17, 24):
			for y in range(16, 19): img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
		# 개머리판/손잡이
		for x in range(4, 10):
			for y in range(15, 23): img.set_pixel(x, y, Color(0.45, 0.28, 0.15))
	elif rec_type == "sv98":
		# SV-98 저격총 (올리브 스나이퍼 바디 + 롱 배럴)
		for x in range(3, 29):
			for y in range(13, 16): img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
		for x in range(6, 18):
			for y in range(15, 20): img.set_pixel(x, y, Color(0.25, 0.38, 0.22)) # 올리브 스톡
		# 볼트 핸들
		img.set_pixel(13, 12, Color(0.7, 0.7, 0.75))
	elif rec_type == "lever":
		# 윈체스터 레버액션 소총 (스틸 배럴/리시버 + 목재 개머리판/포어엔드 + 레버 루프)
		for x in range(3, 29):
			for y in range(13, 16): img.set_pixel(x, y, Color(0.25, 0.28, 0.3))
		# 목재 포어엔드
		for x in range(16, 25):
			for y in range(15, 18): img.set_pixel(x, y, Color(0.5, 0.28, 0.12))
		# 목재 개머리판
		for x in range(3, 11):
			for y in range(14, 22): img.set_pixel(x, y, Color(0.5, 0.28, 0.12))
		# 레버 루프
		for x in range(11, 15):
			img.set_pixel(x, 19, Color(0.2, 0.2, 0.25))
		img.set_pixel(11, 18, Color(0.2, 0.2, 0.25))
		img.set_pixel(14, 18, Color(0.2, 0.2, 0.25))

# ============================================================
# 3. 구경별 탄약 드로잉
# ============================================================
func _draw_ammo_type(img: Image, cal: String, _size: int) -> void:
	if cal == "12gauge":
		# 샷건 쉘 2개 (빨간색 플라스틱 + 황동 바닥 림)
		for i in range(2):
			var ox = 9 + i * 8
			for x in range(ox, ox + 6):
				for y in range(10, 23):
					var c = Color(0.85, 0.2, 0.2) if y < 19 else Color(0.85, 0.75, 0.2)
					img.set_pixel(x, y, c)
	elif cal == "5.56mm":
		# 5.56 NATO 소총탄 (날렵한 녹색 팁 + 황동 탄피)
		for i in range(3):
			var ox = 7 + i * 7
			for x in range(ox, ox + 5):
				for y in range(10, 23):
					var c = Color(0.85, 0.75, 0.25)
					if y < 13: c = Color(0.3, 0.6, 0.3) # 그린 팁
					elif y == 22: c = Color(0.3, 0.3, 0.3)
					img.set_pixel(x, y, c)
	elif cal == "7.62mm":
		# 7.62mm 대구경 탄약 (구리 탄두 + 묵직한 황동 탄피)
		for i in range(3):
			var ox = 7 + i * 7
			for x in range(ox, ox + 5):
				for y in range(9, 24):
					var c = Color(0.8, 0.65, 0.2)
					if y < 14: c = Color(0.75, 0.45, 0.25) # 구리 탄두
					elif y == 23: c = Color(0.25, 0.25, 0.25)
					img.set_pixel(x, y, c)
	else:
		# 9mm / .45ACP 권총탄
		_draw_ammo(img, Color(0.85, 0.75, 0.25), _size)

# ============================================================
# 4. 총기 부착물(파츠) 드로잉
# ============================================================
func _draw_attachment(img: Image, part_category: String, full_id: String, _size: int) -> void:
	match part_category:
		"optic":
			# 조준경 / 스코프
			if full_id.contains("8배율") or full_id.contains("스나이퍼"):
				for x in range(6, 26):
					for y in range(13, 19): img.set_pixel(x, y, Color(0.2, 0.22, 0.25))
				for y in range(11, 21):
					img.set_pixel(7, y, Color(0.2, 0.7, 0.9)) # 대물렌즈
					img.set_pixel(25, y, Color(0.2, 0.7, 0.9))
			elif full_id.contains("4배율") or full_id.contains("ACOG") or full_id.contains("2배율"):
				for x in range(9, 23):
					for y in range(12, 20): img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
				img.set_pixel(10, 15, Color(0.3, 0.8, 1.0))
				img.set_pixel(10, 16, Color(0.3, 0.8, 1.0))
			else:
				# 레드닷 사이트
				for x in range(10, 22):
					for y in range(14, 21): img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
				img.set_pixel(16, 16, Color.RED) # 빨간 조준점
				img.set_pixel(16, 17, Color.RED)
		"muzzle":
			# 소음기 / 컴펜세이터
			if full_id.contains("소음기"):
				for x in range(8, 24):
					for y in range(13, 19):
						var c = Color(0.2, 0.2, 0.22)
						if x % 3 == 0: c = Color(0.12, 0.12, 0.14)
						img.set_pixel(x, y, c)
			else:
				for x in range(10, 22):
					for y in range(12, 20): img.set_pixel(x, y, Color(0.35, 0.38, 0.4))
				for x in range(12, 19, 2):
					img.set_pixel(x, 12, Color(0.1, 0.1, 0.1)) # 포트 구멍
					img.set_pixel(x, 19, Color(0.1, 0.1, 0.1))
		"grip":
			# 수직 / 앵글 손잡이
			for x in range(11, 21):
				for y in range(10, 14): img.set_pixel(x, y, Color(0.2, 0.2, 0.25)) # 레일 마운트
			for x in range(13, 19):
				for y in range(14, 24): img.set_pixel(x, y, Color(0.15, 0.15, 0.18))
		"magazine":
			# 대용량 / 드럼 탄창
			if full_id.contains("드럼"):
				for x in range(9, 23):
					for y in range(11, 25):
						var dx = (x - 15.5) / 6.5
						var dy = (y - 17.5) / 6.5
						if dx * dx + dy * dy <= 1.0: img.set_pixel(x, y, Color(0.2, 0.22, 0.25))
			else:
				for x in range(10, 20):
					for y in range(9, 25): img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
				for x in range(11, 19): img.set_pixel(x, 9, Color(0.85, 0.75, 0.2)) # 상단 탄약 노출
		"stock":
			# 전술 / 저격 개머리판
			for x in range(8, 24):
				for y in range(12, 20): img.set_pixel(x, y, Color(0.2, 0.22, 0.25))
			for x in range(6, 10):
				for y in range(10, 24): img.set_pixel(x, y, Color(0.12, 0.12, 0.15)) # 숄더 패드
		_:
			# 총열 등 기타
			for x in range(6, 26):
				for y in range(14, 18): img.set_pixel(x, y, Color(0.3, 0.32, 0.35))

# ============================================================
# 5. 기본 무기 및 도구 드로잉
# ============================================================
func _draw_gun(img: Image, color: Color, _size: int, is_long: bool = false) -> void:
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

func _draw_ammo(img: Image, color: Color, _size: int) -> void:
	# 탄약 3발 나란히
	for i in range(3):
		var ox = 7 + i * 7
		for x in range(ox, ox + 5):
			for y in range(12, 23):
				var c = color
				if y < 15: c = Color(0.45, 0.45, 0.5) # 탄두 (구리/은색)
				elif y == 22: c = Color(0.2, 0.2, 0.2) # 바닥 림
				img.set_pixel(x, y, c)

func _draw_grenade(img: Image, _size: int) -> void:
	for x in range(11, 21):
		for y in range(12, 24):
			var c = Color(0.25, 0.4, 0.25)
			if (x + y) % 3 == 0: c = Color(0.15, 0.25, 0.15) # 표면 요철
			img.set_pixel(x, y, c)
	# 안전핀 / 신관
	for x in range(14, 18):
		for y in range(7, 12):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.75))

func _draw_melee(img: Image, color: Color, m_type: String, _size: int) -> void:
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

func _draw_axe(img: Image, _size: int) -> void:
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

func _draw_bandage(img: Image, _size: int) -> void:
	for x in range(9, 23):
		for y in range(11, 21):
			var c = Color(0.92, 0.92, 0.88)
			if (x + y) % 4 == 0: c = Color(0.78, 0.78, 0.74)
			img.set_pixel(x, y, c)

func _draw_pills(img: Image, _size: int) -> void:
	# 약통
	for x in range(10, 22):
		for y in range(11, 23):
			var c = Color(0.85, 0.5, 0.15) if y < 14 else Color(0.9, 0.9, 0.95)
			img.set_pixel(x, y, c)
	# 캡슐 1개 옆에
	for x in range(6, 12):
		for y in range(20, 24):
			img.set_pixel(x, y, Color(0.9, 0.2, 0.2) if x < 9 else Color(0.9, 0.9, 0.9))

func _draw_medkit(img: Image, _size: int) -> void:
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

func _draw_advanced_medkit(img: Image, _size: int) -> void:
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

func _draw_herb(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x - 16) * (x - 16) + (y - 16) * (y - 16) < 36:
				img.set_pixel(x, y, Color(0.25, 0.7, 0.3))
	# 줄기
	for y in range(18, 26):
		img.set_pixel(16, y, Color(0.15, 0.45, 0.2))

func _draw_bottle(img: Image, liquid_color: Color, _size: int) -> void:
	for x in range(12, 20):
		for y in range(7, 26):
			if y < 11:
				img.set_pixel(x, y, Color(0.75, 0.75, 0.8)) # 뚜껑/주둥이
			else:
				var c = liquid_color if y > 15 else Color(0.9, 0.9, 0.95, 0.7)
				img.set_pixel(x, y, c)

func _draw_can(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(9, 24):
			var c = color if (y > 11 and y < 22) else Color(0.75, 0.75, 0.8)
			img.set_pixel(x, y, c)

func _draw_bread(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(12, 22):
			var c = Color(0.8, 0.55, 0.25)
			if y == 12 or y == 21: c = Color(0.6, 0.4, 0.2)
			img.set_pixel(x, y, c)

func _draw_energy_bar(img: Image, _size: int) -> void:
	for x in range(6, 26):
		for y in range(12, 20):
			var c = Color(0.9, 0.3, 0.1) if (x % 6 < 3) else Color(0.2, 0.2, 0.2)
			img.set_pixel(x, y, c)

func _draw_meat(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c = Color(0.55, 0.25, 0.15)
			if (x + y) % 5 == 0: c = Color(0.2, 0.1, 0.05) # 그릴 자국
			img.set_pixel(x, y, c)

func _draw_mre(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c = Color(0.65, 0.55, 0.35)
			if y > 12 and y < 16: c = Color(0.45, 0.35, 0.2) # 라벨
			img.set_pixel(x, y, c)

func _draw_crop(img: Image, _size: int) -> void:
	for x in range(11, 21):
		for y in range(10, 24):
			img.set_pixel(x, y, Color(0.9, 0.5, 0.1)) # 당근/작물
	for x in range(13, 19):
		for y in range(6, 10):
			img.set_pixel(x, y, Color(0.2, 0.7, 0.2)) # 잎사귀

func _draw_flashlight(img: Image, _size: int) -> void:
	# 손전등 몸통
	for x in range(8, 20):
		for y in range(13, 19):
			img.set_pixel(x, y, Color(0.25, 0.25, 0.3))
	# 헤드
	for x in range(20, 25):
		for y in range(11, 21):
			img.set_pixel(x, y, Color(0.9, 0.8, 0.2))

func _draw_battery(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 24):
			var c = Color(0.15, 0.5, 0.2) if y > 14 else Color(0.9, 0.8, 0.1)
			img.set_pixel(x, y, c)
	# 단자
	for x in range(14, 18):
		for y in range(7, 10):
			img.set_pixel(x, y, Color(0.7, 0.7, 0.75))

func _draw_backpack(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 25):
			var c = Color(0.35, 0.45, 0.3)
			if (y > 14 and y < 17) or (x > 14 and x < 17): c = Color(0.2, 0.25, 0.18) # 스트랩
			img.set_pixel(x, y, c)

func _draw_gasmask(img: Image, _size: int) -> void:
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

func _draw_armor(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.2, 0.3, 0.25)
			if y < 12 and (x < 11 or x > 20): continue # 목둘레 파임
			img.set_pixel(x, y, c)

func _draw_shoes(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(14, 22):
			var c = Color(0.2, 0.5, 0.8) if y < 19 else Color(0.85, 0.85, 0.85) # 밑창
			img.set_pixel(x, y, c)

func _draw_map(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c = Color(0.9, 0.85, 0.7)
			if (x == 12 or x == 19) and y % 2 == 0: c = Color(0.7, 0.65, 0.5) # 접힌 선
			img.set_pixel(x, y, c)
	# 나침반 표시나 도로 선
	img.set_pixel(15, 14, Color.RED)
	img.set_pixel(16, 14, Color.RED)
	img.set_pixel(15, 15, Color.RED)

func _draw_compass(img: Image, _size: int) -> void:
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

func _draw_scrap(img: Image, _size: int) -> void:
	for i in range(18):
		var px = randi_range(7, 23)
		var py = randi_range(7, 23)
		var c = Color(randf_range(0.4, 0.6), randf_range(0.35, 0.5), randf_range(0.3, 0.45))
		img.set_pixel(px, py, c)
		img.set_pixel(px + 1, py, c)

func _draw_wood(img: Image, _size: int) -> void:
	for x in range(6, 26):
		for y in range(10, 22):
			var c = Color(0.55, 0.35, 0.2)
			if (y == 13 or y == 18): c = Color(0.4, 0.25, 0.12) # 나뭇결
			img.set_pixel(x, y, c)

func _draw_nails(img: Image, _size: int) -> void:
	for i in range(3):
		var ox = 9 + i * 5
		for y in range(9, 23):
			img.set_pixel(ox, y, Color(0.7, 0.7, 0.75))
		img.set_pixel(ox - 1, 9, Color(0.4, 0.4, 0.4))
		img.set_pixel(ox + 1, 9, Color(0.4, 0.4, 0.4))

func _draw_cloth(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.7, 0.65, 0.6)
			if (x + y) % 3 == 0: c = Color(0.6, 0.55, 0.5)
			img.set_pixel(x, y, c)

func _draw_gears(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 45 and dist > 9:
				img.set_pixel(x, y, Color(0.6, 0.6, 0.65))
			elif dist <= 9:
				img.set_pixel(x, y, Color(0.2, 0.2, 0.2))

func _draw_wire(img: Image, _size: int) -> void:
	for i in range(20):
		var x = int(16 + cos(i * 0.4) * 8)
		var y = int(16 + sin(i * 0.4) * 8)
		img.set_pixel(x, y, Color(0.85, 0.45, 0.2)) # 구리빛 전선
		img.set_pixel(x + 1, y, Color(0.2, 0.2, 0.8)) # 피복

func _draw_gunpowder(img: Image, _size: int) -> void:
	for x in range(9, 23):
		for y in range(12, 24):
			var c = Color(0.2, 0.2, 0.22)
			if randf() < 0.3: c = Color(0.35, 0.35, 0.38)
			img.set_pixel(x, y, c)

func _draw_cpu(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.2, 0.55, 0.3)
			if x > 10 and x < 21 and y > 10 and y < 21:
				c = Color(0.75, 0.75, 0.8) # 금속 히트스프레더
			img.set_pixel(x, y, c)

func _draw_gpu(img: Image, _size: int) -> void:
	for x in range(5, 27):
		for y in range(10, 22):
			var c = Color(0.2, 0.2, 0.25)
			if x % 6 == 0 and y > 12 and y < 19: c = Color(0.1, 0.6, 0.7) # 팬
			img.set_pixel(x, y, c)

func _draw_watch(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 30:
				img.set_pixel(x, y, Color.WHITE if dist < 16 else color)

func _draw_ring(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist = (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 32 and dist > 14:
				img.set_pixel(x, y, color)
	# 보석
	img.set_pixel(16, 10, Color(0.2, 0.8, 1.0))
	img.set_pixel(16, 11, Color(0.2, 0.8, 1.0))

func _draw_vase(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x >= 14 and x <= 17 and y < 12) or (y >= 12 and (x - 16) * (x - 16) + (y - 18) * (y - 18) < 25):
				img.set_pixel(x, y, Color(0.2, 0.5, 0.7)) # 청자

func _draw_radio_parts(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c = Color(0.25, 0.45, 0.3)
			if (x == 12 or x == 18) and y > 12 and y < 18: c = Color(0.8, 0.8, 0.2)
			img.set_pixel(x, y, c)

func _draw_radio(img: Image, _size: int) -> void:
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

func _draw_ssd(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(9, 23):
			var c = Color(0.15, 0.15, 0.18)
			if x > 16 and y > 18: c = Color(0.85, 0.75, 0.2) # 골드 핑거 커넥터
			img.set_pixel(x, y, c)

func _draw_generic_box(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c = Color(0.5, 0.5, 0.55)
			if x == 8 or x == 23 or y == 8 or y == 23: c = Color(0.2, 0.2, 0.25)
			img.set_pixel(x, y, c)

func _draw_key(img: Image, _size: int) -> void:
	var brass = Color(0.92, 0.76, 0.24)
	var dark_brass = Color(0.62, 0.48, 0.12)
	# 열쇠 손잡이 고리 (좌상단 원형)
	for x in range(6, 16):
		for y in range(9, 19):
			var d2 = (x - 10.5) * (x - 10.5) + (y - 13.5) * (y - 13.5)
			if d2 <= 20.0 and d2 >= 5.0:
				img.set_pixel(x, y, brass if y < 14 else dark_brass)
	# 열쇠 몸통 축
	for x in range(15, 27):
		img.set_pixel(x, 13, brass)
		img.set_pixel(x, 14, dark_brass)
	# 열쇠 이빨 (우하단)
	for x in [21, 22, 25, 26]:
		for y in range(15, 19):
			img.set_pixel(x, y, brass)

func _draw_keycard(img: Image, _size: int) -> void:
	for x in range(5, 27):
		for y in range(8, 24):
			var c = Color(0.15, 0.38, 0.72) # 블루 보안 카드 본체
			if x == 5 or x == 26 or y == 8 or y == 23:
				c = Color(0.85, 0.90, 0.98) # 흰색 테두리
			elif y >= 10 and y <= 12:
				c = Color(0.10, 0.12, 0.16) # 마그네틱 띠
			elif x >= 8 and x <= 12 and y >= 15 and y <= 19:
				c = Color(0.95, 0.80, 0.25) # IC 골드 칩
			elif x >= 15 and x <= 23 and (y == 16 or y == 19):
				c = Color(0.65, 0.82, 0.98) # 바코드/텍스트 라인
			img.set_pixel(x, y, c)

