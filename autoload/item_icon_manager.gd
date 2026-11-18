# res://autoload/item_icon_manager.gd
extends Node

## 런타임 및 디스크 PNG 기반 32x32 택티컬 픽셀 아이콘 생성·셰이딩·캐싱 매니저

const ICON_SIZE: int = 32
const ICON_DIR: String = "res://assets/pixel/icons/"

var icon_cache: Dictionary = {}

func get_icon_disk_path(item_id: String) -> String:
	var safe_id := item_id.strip_edges()
	safe_id = safe_id.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	if safe_id == "":
		safe_id = "unknown_item"
	return ICON_DIR + safe_id + ".png"

func get_icon(item_id: String) -> Texture2D:
	if icon_cache.has(item_id):
		return icon_cache[item_id]

	var disk_path := get_icon_disk_path(item_id)
	var abs_path := ProjectSettings.globalize_path(disk_path)
	if FileAccess.file_exists(abs_path):
		var loaded_img := Image.new()
		if loaded_img.load(abs_path) == OK and not loaded_img.is_empty():
			if loaded_img.get_format() != Image.FORMAT_RGBA8:
				loaded_img.convert(Image.FORMAT_RGBA8)
			var disk_tex := ImageTexture.create_from_image(loaded_img)
			icon_cache[item_id] = disk_tex
			return disk_tex

	if ResourceLoader.exists(disk_path):
		var res_tex = load(disk_path)
		if res_tex is Texture2D:
			icon_cache[item_id] = res_tex
			return res_tex

	var tex := _generate_icon(item_id)
	icon_cache[item_id] = tex
	return tex

func generate_icon_image(item_id: String) -> Image:
	var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	_paint_icon_by_id(img, item_id, ICON_SIZE)
	_apply_pixel_icon_polish(img)
	return img

func save_all_icons_to_disk(force_overwrite: bool = true) -> int:
	var abs_dir := ProjectSettings.globalize_path(ICON_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var all_ids: Dictionary = {}
	if is_instance_valid(ItemDatabase):
		for k in ItemDatabase.items.keys():
			all_ids[str(k)] = true
	for r_id in WeaponPartsDatabase.RECEIVERS.keys():
		all_ids[str(r_id)] = true
	for p_id in WeaponPartsDatabase.PARTS.keys():
		all_ids[str(p_id)] = true
	for a_id in WeaponPartsDatabase.AMMO_TYPES.keys():
		all_ids[str(a_id)] = true
	for extra_id in ["무기고 열쇠", "보안 키카드", "항생제", "Scav 인식표", "초콜릿", "MP5_리시버", "함정", "탄약 케이스", "의약품 케이스", "무기 부품 상자", "인식표 지갑"]:
		all_ids[extra_id] = true

	var saved_count: int = 0
	for item_id in all_ids.keys():
		var abs_path := ProjectSettings.globalize_path(get_icon_disk_path(str(item_id)))
		if not force_overwrite and FileAccess.file_exists(abs_path):
			continue
		var img := generate_icon_image(str(item_id))
		if img.save_png(abs_path) == OK:
			icon_cache[str(item_id)] = ImageTexture.create_from_image(img)
			saved_count += 1
	return saved_count

func _generate_icon(item_id: String) -> Texture2D:
	var img := generate_icon_image(item_id)
	return ImageTexture.create_from_image(img)

func _paint_icon_by_id(img: Image, item_id: String, size: int) -> void:
	var norm_id := item_id.replace("_", " ").strip_edges()
	var lower_id := norm_id.to_lower()

	# === 0. 특수 압축 보관 케이스 (다른 키워드 매칭보다 최우선 판별) ===
	if norm_id.contains("탄약 케이스") or lower_id.contains("ammo case"):
		_draw_storage_case(img, "ammo", size)
		return
	elif norm_id.contains("의약품 케이스") or lower_id.contains("med case"):
		_draw_storage_case(img, "medical", size)
		return
	elif norm_id.contains("무기 부품 상자") or lower_id.contains("parts box"):
		_draw_storage_case(img, "weapon_part", size)
		return
	elif norm_id.contains("인식표 지갑") or lower_id.contains("dogtag"):
		if norm_id.contains("지갑") or lower_id.contains("wallet") or lower_id.contains("case"):
			_draw_storage_case(img, "dogtag_key", size)
			return

	# === 1. 방탄복 / 조끼 ===
	if norm_id.contains("3레벨") and (norm_id.contains("방탄") or norm_id.contains("조끼")) or lower_id.contains("armor 3") or lower_id.contains("heavy armor"):
		_draw_armor_tier(img, 3, size)
	elif norm_id.contains("2레벨") and (norm_id.contains("방탄") or norm_id.contains("조끼")) or lower_id.contains("armor 2") or lower_id.contains("tactical vest"):
		_draw_armor_tier(img, 2, size)
	elif norm_id.contains("방탄") or norm_id.contains("조끼") or lower_id.contains("armor"):
		_draw_armor_tier(img, 1, size)

	# === 2. 헬멧 / 방독면 ===
	elif norm_id.contains("3레벨 헬멧") or lower_id.contains("helmet 3") or norm_id.contains("스페츠나츠"):
		_draw_helmet_tier(img, 3, size)
	elif norm_id.contains("2레벨 헬멧") or lower_id.contains("helmet 2") or norm_id.contains("군용 헬멧"):
		_draw_helmet_tier(img, 2, size)
	elif norm_id.contains("헬멧") or lower_id.contains("helmet"):
		_draw_helmet_tier(img, 1, size)
	elif norm_id.contains("방독면") or lower_id.contains("gasmask"):
		_draw_gasmask(img, size)

	# === 3. 배낭 / 가방 ===
	elif norm_id.contains("3레벨") and (norm_id.contains("가방") or norm_id.contains("배낭")) or lower_id.contains("backpack 3"):
		_draw_backpack_tier(img, 3, size)
	elif norm_id.contains("2레벨") and (norm_id.contains("가방") or norm_id.contains("배낭")) or lower_id.contains("backpack 2"):
		_draw_backpack_tier(img, 2, size)
	elif norm_id.contains("가방") or norm_id.contains("배낭") or lower_id.contains("backpack"):
		_draw_backpack_tier(img, 1, size)

	# === 4. 신발 ===
	elif norm_id.contains("운동화") or norm_id.contains("신발") or lower_id.contains("sneaker") or lower_id.contains("boot"):
		_draw_shoes(img, size)

	# === 5. 총기 부착물 (도구/리시버보다 먼저 판별해 전술 손전등·레일 파츠 구분) ===
	elif norm_id.contains("레이저") or norm_id.contains("표적지시기") or lower_id.contains("laser"):
		_draw_attachment(img, "rail_laser", norm_id, size)
	elif norm_id.contains("전술 손전등") or lower_id.contains("rail light"):
		_draw_attachment(img, "rail_light", norm_id, size)
	elif norm_id.contains("아이언사이트") or norm_id.contains("기계식"):
		_draw_attachment(img, "iron_sight", norm_id, size)
	elif norm_id.contains("조준경") or norm_id.contains("사이트") or norm_id.contains("ACOG") or norm_id.contains("스코프") or lower_id.contains("optic") or lower_id.contains("scope"):
		_draw_attachment(img, "optic", norm_id, size)
	elif norm_id.contains("소음기") or norm_id.contains("소염기") or norm_id.contains("컴펜세이터") or lower_id.contains("muzzle"):
		_draw_attachment(img, "muzzle", norm_id, size)
	elif norm_id.contains("포어그립") or norm_id.contains("손잡이") or norm_id.contains("그립") or lower_id.contains("grip"):
		_draw_attachment(img, "grip", norm_id, size)
	elif norm_id.contains("탄창") or lower_id.contains("mag"):
		_draw_attachment(img, "magazine", norm_id, size)
	elif norm_id.contains("개머리판") or norm_id.contains("스톡") or lower_id.contains("stock"):
		_draw_attachment(img, "stock", norm_id, size)
	elif norm_id.contains("총열") or lower_id.contains("barrel"):
		_draw_attachment(img, "barrel", norm_id, size)

	# === 6. 총기 리시버 및 완제품 ===
	elif norm_id.contains("레버액션") or lower_id.contains("lever"):
		_draw_receiver(img, "lever", size)
	elif lower_id.contains("mp5") or norm_id.contains("기관단총"):
		_draw_receiver(img, "mp5", size)
	elif lower_id.contains("m4"):
		_draw_receiver(img, "m4", size)
	elif lower_id.contains("ak"):
		_draw_receiver(img, "ak", size)
	elif lower_id.contains("m9") or norm_id.contains("베레타"):
		_draw_receiver(img, "m9", size)
	elif norm_id.contains("레밍턴") or norm_id.contains("870") or norm_id.contains("샷건") or norm_id.contains("산탄총") or lower_id.contains("shotgun"):
		_draw_receiver(img, "shotgun", size)
	elif lower_id.contains("sv98") or norm_id.contains("저격") or lower_id.contains("sniper"):
		_draw_receiver(img, "sv98", size)
	elif norm_id.contains("권총") or lower_id.contains("pistol"):
		_draw_gun(img, Color(0.28, 0.30, 0.34), size, false)
	elif norm_id.contains("소총") or lower_id.contains("rifle"):
		_draw_gun(img, Color(0.45, 0.30, 0.20), size, true)

	# === 7. 탄약 / 투척류 ===
	elif norm_id.contains("5.56"):
		_draw_ammo_type(img, "5.56mm", size)
	elif norm_id.contains("7.62"):
		_draw_ammo_type(img, "7.62mm", size)
	elif norm_id.contains("12게이지") or norm_id.contains("벅샷") or norm_id.contains("슬러그"):
		if norm_id.contains("슬러그") or lower_id.contains("slug"):
			_draw_ammo_type(img, "12slug", size)
		else:
			_draw_ammo_type(img, "12gauge", size)
	elif norm_id.contains(".45"):
		_draw_ammo_type(img, "45acp", size)
	elif norm_id.contains("9mm") or norm_id.contains("탄약") or lower_id.contains("ammo"):
		_draw_ammo_type(img, "9mm", size)
	elif norm_id.contains("수류탄") or lower_id.contains("grenade"):
		_draw_grenade(img, size)

	# === 8. 근접 무기 ===
	elif norm_id.contains("도끼") or lower_id.contains("axe"):
		_draw_axe(img, size)
	elif norm_id.contains("나이프") or norm_id.contains("칼") or lower_id.contains("knife"):
		_draw_melee(img, Color(0.78, 0.82, 0.88), "knife", size)
	elif norm_id.contains("야구방망이") or lower_id.contains("bat"):
		_draw_melee(img, Color(0.64, 0.43, 0.22), "bat", size)
	elif norm_id.contains("파이프") or lower_id.contains("pipe"):
		_draw_melee(img, Color(0.55, 0.58, 0.62), "pipe", size)

	# === 9. 의료품 ===
	elif norm_id.contains("고급") and norm_id.contains("치료"):
		_draw_advanced_medkit(img, size)
	elif norm_id.contains("구급상자") or norm_id.contains("키트") or lower_id.contains("medkit"):
		_draw_medkit(img, size)
	elif norm_id.contains("항생제") or lower_id.contains("antibiotic"):
		_draw_antibiotic(img, size)
	elif norm_id.contains("붕대") or lower_id.contains("bandage"):
		_draw_bandage(img, size)
	elif norm_id.contains("약초") or lower_id.contains("herb"):
		_draw_herb(img, size)
	elif norm_id.contains("진통제") or norm_id.contains("알약") or lower_id.contains("pills"):
		_draw_pills(img, size)

	# === 10. 식량 / 작물 / 음료 ===
	elif norm_id.contains("생수") or norm_id.contains("물") or lower_id.contains("water"):
		_draw_bottle(img, Color(0.22, 0.65, 0.95), size)
	elif norm_id.contains("탄산음료") or lower_id.contains("soda"):
		_draw_can(img, Color(0.85, 0.22, 0.22), size)
	elif norm_id.contains("에너지바") or lower_id.contains("energy bar") or lower_id.contains("bar"):
		_draw_energy_bar(img, size)
	elif norm_id.contains("에너지 드링크") or norm_id.contains("드링크") or lower_id.contains("energy"):
		_draw_can(img, Color(0.22, 0.85, 0.35), size)
	elif norm_id.contains("커피") or lower_id.contains("coffee"):
		_draw_can(img, Color(0.45, 0.28, 0.18), size)
	elif norm_id.contains("전투 식량") or lower_id.contains("mre"):
		_draw_mre(img, size)
	elif norm_id.contains("통조림") or norm_id.contains("식량") or lower_id.contains("canned"):
		_draw_can(img, Color(0.85, 0.5, 0.16), size)
	elif norm_id.contains("빵") or lower_id.contains("bread"):
		_draw_bread(img, size)
	elif norm_id.contains("초콜릿") or lower_id.contains("chocolate"):
		_draw_chocolate(img, size)
	elif norm_id.contains("고기") or lower_id.contains("meat"):
		_draw_meat(img, size)
	elif norm_id.contains("농작물") or lower_id.contains("crop"):
		_draw_crop(img, size)

	# === 11. 도구 / 광학 / 재료 / 고가품 / 특수 퀘스트 ===
	elif norm_id.contains("망원경") or lower_id.contains("binocular") or lower_id.contains("telescope"):
		_draw_binoculars(img, norm_id.contains("고배율"), size)
	elif norm_id.contains("손전등") or lower_id.contains("flashlight"):
		_draw_flashlight(img, size)
	elif norm_id.contains("배터리") or lower_id.contains("battery"):
		_draw_battery(img, size)
	elif norm_id.contains("지도") or lower_id.contains("map"):
		_draw_map(img, size)
	elif norm_id.contains("나침반") or lower_id.contains("compass"):
		_draw_compass(img, size)
	elif norm_id.contains("고철") or lower_id.contains("scrap"):
		_draw_scrap(img, size)
	elif norm_id.contains("나무") or lower_id.contains("wood"):
		_draw_wood(img, size)
	elif norm_id.contains("못") or lower_id.contains("nail"):
		_draw_nails(img, size)
	elif norm_id.contains("천") or lower_id.contains("cloth"):
		_draw_cloth(img, size)
	elif norm_id.contains("라디오") and norm_id.contains("부품"):
		_draw_radio_parts(img, size)
	elif norm_id.contains("기계") or norm_id.contains("부품") or lower_id.contains("gear"):
		_draw_gears(img, size)
	elif norm_id.contains("전선") or lower_id.contains("wire"):
		_draw_wire(img, size)
	elif norm_id.contains("화약") or lower_id.contains("gunpowder"):
		_draw_gunpowder(img, size)
	elif lower_id.contains("cpu"):
		_draw_cpu(img, size)
	elif norm_id.contains("그래픽") or lower_id.contains("gpu"):
		_draw_gpu(img, size)
	elif norm_id.contains("금시계") or lower_id.contains("watch"):
		_draw_watch(img, Color(0.95, 0.80, 0.22), size)
	elif norm_id.contains("은반지") or lower_id.contains("ring"):
		_draw_ring(img, Color(0.85, 0.90, 0.96), size)
	elif norm_id.contains("골동품") or lower_id.contains("vase"):
		_draw_vase(img, size)
	elif norm_id.contains("무전기") or norm_id.contains("라디오") or lower_id.contains("radio"):
		_draw_radio(img, size)
	elif norm_id.contains("인식표") or norm_id.contains("식별줄") or lower_id.contains("dogtag"):
		_draw_dogtag(img, size)
	elif norm_id.contains("열쇠") or lower_id.contains("key ") or lower_id.contains("key_"):
		_draw_key(img, size)
	elif norm_id.contains("키카드") or lower_id.contains("keycard"):
		_draw_keycard(img, size)
	elif lower_id.contains("ssd"):
		_draw_ssd(img, size)
	elif norm_id.contains("함정") or norm_id.contains("덫") or lower_id.contains("trap"):
		_draw_bear_trap(img, size)
	else:
		_draw_generic_box(img, size)

func _apply_pixel_icon_polish(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return
	var src := Image.new()
	src.copy_from(img)

	var outline_col := Color(0.05, 0.06, 0.08, 0.96)
	var hi_tint := Color(0.96, 0.94, 0.88, 1.0)
	var sh_tint := Color(0.07, 0.09, 0.13, 1.0)

	# 1. 좌상단 입사광 기준 1px 하이라이트 베벨 + 우하단 섀도우 베벨 + 내부 체커보드 디더링
	for y in range(h):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.15:
				continue
			var top_empty: bool = (y == 0) or src.get_pixel(x, y - 1).a <= 0.15
			var left_empty: bool = (x == 0) or src.get_pixel(x - 1, y).a <= 0.15
			var bot_empty: bool = (y == h - 1) or src.get_pixel(x, y + 1).a <= 0.15
			var right_empty: bool = (x == w - 1) or src.get_pixel(x + 1, y).a <= 0.15

			var is_accent: bool = (
				(c.r > 0.88 and c.g < 0.35 and c.b < 0.35)
				or (c.b > 0.82 and c.r < 0.42)
				or (c.r > 0.88 and c.g > 0.78 and c.b < 0.40)
			)
			if not is_accent:
				if (top_empty or left_empty) and not (bot_empty and right_empty):
					c = c.lerp(Color(hi_tint.r, hi_tint.g, hi_tint.b, c.a), 0.18)
				elif bot_empty or right_empty:
					c = c.lerp(Color(sh_tint.r, sh_tint.g, sh_tint.b, c.a), 0.24)
				elif ((x + y) & 1) == 1:
					c = c.darkened(0.055)
			img.set_pixel(x, y, c)

	# 2. 투명 배경과 맞닿은 4방향 경계 1px 전술 다크 외곽선
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.15:
				continue
			var adj: bool = (
				(x > 0 and src.get_pixel(x - 1, y).a > 0.15)
				or (x < w - 1 and src.get_pixel(x + 1, y).a > 0.15)
				or (y > 0 and src.get_pixel(x, y - 1).a > 0.15)
				or (y < h - 1 and src.get_pixel(x, y + 1).a > 0.15)
			)
			if adj:
				img.set_pixel(x, y, outline_col)

# ============================================================
# 1. 방탄복 / 헬멧 / 배낭 티어별 정밀 드로잉
# ============================================================
func _draw_armor_tier(img: Image, tier: int, _size: int) -> void:
	var base_col := Color(0.20, 0.25, 0.35) # 1티어: 네이비 경찰 조끼
	var accent_col := Color(0.30, 0.40, 0.55)
	if tier == 2:
		base_col = Color(0.28, 0.38, 0.22) # 2티어: 올리브 전술 방탄복
		accent_col = Color(0.18, 0.26, 0.14)
	elif tier == 3:
		base_col = Color(0.14, 0.15, 0.18) # 3티어: 블랙 중장갑 플레이트 캐리어
		accent_col = Color(0.28, 0.32, 0.36)

	for x in range(7, 25):
		for y in range(7, 26):
			if y < 12 and (x < 11 or x > 20): continue
			if y > 22 and (x < 9 or x > 22): continue
			img.set_pixel(x, y, base_col)

	for x in range(11, 14):
		for y in range(7, 12): img.set_pixel(x, y, accent_col)
	for x in range(18, 21):
		for y in range(7, 12): img.set_pixel(x, y, accent_col)

	if tier == 1:
		for y in range(12, 24): img.set_pixel(15, y, Color(0.14, 0.15, 0.20))
		for x in range(12, 19): img.set_pixel(x, 14, Color(0.85, 0.80, 0.28))
	elif tier == 2:
		for y in [14, 18, 22]:
			for x in range(9, 23):
				if x % 2 == 0: img.set_pixel(x, y, accent_col)
		for x in range(10, 14):
			for y in range(16, 22): img.set_pixel(x, y, Color(0.20, 0.30, 0.18))
		for x in range(17, 21):
			for y in range(16, 22): img.set_pixel(x, y, Color(0.20, 0.30, 0.18))
	elif tier == 3:
		for x in range(9, 23):
			for y in range(13, 23):
				if x == 9 or x == 22 or y == 13 or y == 22:
					img.set_pixel(x, y, Color(0.40, 0.45, 0.50))
		for x in range(12, 19):
			for y in range(16, 20): img.set_pixel(x, y, Color(0.09, 0.10, 0.12))

func _draw_helmet_tier(img: Image, tier: int, _size: int) -> void:
	var dome_col := Color(0.68, 0.20, 0.20) # 1티어
	if tier == 2: dome_col = Color(0.30, 0.40, 0.25) # 2티어
	elif tier == 3: dome_col = Color(0.22, 0.24, 0.28) # 3티어

	for x in range(8, 24):
		for y in range(7, 22):
			var dx := (x - 15.5) / 7.5
			var dy := (y - 14.0) / 7.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, dome_col)

	if tier == 1:
		for x in range(12, 23):
			for y in range(13, 18):
				img.set_pixel(x, y, Color(0.10, 0.12, 0.16))
		img.set_pixel(13, 14, Color(0.82, 0.86, 0.96))
	elif tier == 2:
		for x in range(7, 25): img.set_pixel(x, 19, Color(0.22, 0.30, 0.18))
		for x in range(14, 18):
			for y in range(12, 16): img.set_pixel(x, y, Color(0.15, 0.15, 0.16))
	elif tier == 3:
		for x in range(11, 24):
			for y in range(12, 21):
				img.set_pixel(x, y, Color(0.36, 0.40, 0.43))
		for x in range(13, 22):
			img.set_pixel(x, 15, Color(0.22, 0.72, 0.92))
			img.set_pixel(x, 16, Color(0.22, 0.72, 0.92))

func _draw_backpack_tier(img: Image, tier: int, _size: int) -> void:
	var col := Color(0.45, 0.40, 0.30)
	var min_x: int = 9
	var max_x: int = 23
	var min_y: int = 9
	var max_y: int = 24

	if tier == 2:
		col = Color(0.30, 0.40, 0.28)
		min_x = 7; max_x = 25; min_y = 8; max_y = 25
	elif tier == 3:
		col = Color(0.19, 0.20, 0.22)
		min_x = 6; max_x = 26; min_y = 7; max_y = 26

	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			img.set_pixel(x, y, col)

	for y in range(min_y + 4, max_y - 2):
		img.set_pixel(min_x + 3, y, col.darkened(0.25))
		img.set_pixel(max_x - 4, y, col.darkened(0.25))
	for x in range(min_x + 2, max_x - 2):
		img.set_pixel(x, min_y + 7, Color(0.14, 0.14, 0.16))

	if tier >= 2:
		for y in range(min_y + 6, max_y - 2):
			img.set_pixel(min_x - 1, y, col.darkened(0.15))
			img.set_pixel(max_x, y, col.darkened(0.15))
	if tier == 3:
		for x in range(min_x, max_x):
			img.set_pixel(x, min_y - 1, Color(0.36, 0.31, 0.25))
			img.set_pixel(x, max_y, Color(0.36, 0.31, 0.25))

# ============================================================
# 2. 총기 리시버 및 완제품 드로잉
# ============================================================
func _draw_receiver(img: Image, rec_type: String, _size: int) -> void:
	if rec_type == "m4":
		for x in range(5, 27):
			for y in range(12, 17): img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
		for x in range(6, 26):
			if x % 2 == 0: img.set_pixel(x, 11, Color(0.38, 0.42, 0.46))
		for x in range(7, 12):
			for y in range(17, 24): img.set_pixel(x, y, Color(0.16, 0.16, 0.20))
		for x in range(14, 19):
			for y in range(17, 21): img.set_pixel(x, y, Color(0.25, 0.27, 0.31))
	elif rec_type == "ak":
		for x in range(5, 27):
			for y in range(12, 17): img.set_pixel(x, y, Color(0.29, 0.31, 0.34))
		for x in range(18, 27):
			for y in range(11, 16): img.set_pixel(x, y, Color(0.56, 0.31, 0.15))
		for x in range(6, 11):
			for y in range(17, 24): img.set_pixel(x, y, Color(0.50, 0.28, 0.12))
		for x in range(13, 18):
			for y in range(17, 21): img.set_pixel(x, y, Color(0.20, 0.21, 0.22))
	elif rec_type == "m9":
		for x in range(8, 24):
			for y in range(13, 17): img.set_pixel(x, y, Color(0.28, 0.30, 0.35))
		for x in range(7, 13):
			for y in range(17, 25): img.set_pixel(x, y, Color(0.18, 0.19, 0.22))
		img.set_pixel(23, 14, Color(0.10, 0.10, 0.12))
	elif rec_type == "shotgun":
		for x in range(4, 28):
			for y in range(13, 17): img.set_pixel(x, y, Color(0.32, 0.34, 0.38))
		for x in range(17, 24):
			for y in range(16, 19): img.set_pixel(x, y, Color(0.20, 0.20, 0.22))
		for x in range(4, 10):
			for y in range(15, 23): img.set_pixel(x, y, Color(0.48, 0.28, 0.15))
	elif rec_type == "sv98":
		for x in range(3, 29):
			for y in range(13, 16): img.set_pixel(x, y, Color(0.22, 0.23, 0.25))
		for x in range(6, 18):
			for y in range(15, 20): img.set_pixel(x, y, Color(0.26, 0.39, 0.22))
		img.set_pixel(13, 12, Color(0.75, 0.78, 0.82))
	elif rec_type == "lever":
		for x in range(3, 29):
			for y in range(13, 16): img.set_pixel(x, y, Color(0.28, 0.31, 0.34))
		for x in range(16, 25):
			for y in range(15, 18): img.set_pixel(x, y, Color(0.52, 0.29, 0.13))
		for x in range(3, 11):
			for y in range(14, 22): img.set_pixel(x, y, Color(0.52, 0.29, 0.13))
		for x in range(11, 15):
			img.set_pixel(x, 19, Color(0.22, 0.22, 0.26))
		img.set_pixel(11, 18, Color(0.22, 0.22, 0.26))
		img.set_pixel(14, 18, Color(0.22, 0.22, 0.26))
	elif rec_type == "mp5":
		# MP5A5 기관단총: 슬림 상부 리시버 + 골진 핸드가드 + 곡선형 9mm 탄창 + 인입식 스톡
		for x in range(8, 25):
			for y in range(12, 16):
				img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
		for x in range(18, 25):
			for y in range(13, 16):
				img.set_pixel(x, y, Color(0.14, 0.16, 0.19) if x % 2 == 0 else Color(0.26, 0.29, 0.34))
		for x in range(25, 28):
			img.set_pixel(x, 14, Color(0.38, 0.42, 0.48))
		img.set_pixel(24, 11, Color(0.32, 0.36, 0.42)) # 원형 가늠쇠 후드
		for x in range(4, 8):
			img.set_pixel(x, 13, Color(0.35, 0.38, 0.44)) # 인입식 스톡 바
		for y in range(11, 17):
			img.set_pixel(4, y, Color(0.16, 0.17, 0.20)) # 스톡 패드
		for y in range(16, 22):
			for x in range(11, 14):
				img.set_pixel(x, y, Color(0.16, 0.17, 0.20)) # 권총손잡이
		for step in range(8):
			var mx := 17 + int(step / 2)
			var my := 16 + step
			for dx in range(3):
				if mx + dx < 28 and my < 26:
					img.set_pixel(mx + dx, my, Color(0.28, 0.32, 0.38)) # 곡선형 9mm 탄창

func _draw_bear_trap(img: Image, _size: int) -> void:
	# 강철 덫 (원형 톱니 턱 + 중앙 압력판 + 체인)
	for y in range(11, 23):
		for x in range(6, 26):
			var dx := float(x) - 15.5
			var dy := (float(y) - 16.5) * 1.35
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= 7.0 and dist <= 9.5:
				img.set_pixel(x, y, Color(0.38, 0.42, 0.48))
			elif dist < 4.2:
				img.set_pixel(x, y, Color(0.55, 0.38, 0.22))
	for tx in [9, 12, 15, 18, 21]:
		img.set_pixel(tx, 12, Color(0.82, 0.86, 0.92))
		img.set_pixel(tx, 20, Color(0.82, 0.86, 0.92))

# ============================================================
# 3. 구경별 탄약 드로잉
# ============================================================
func _draw_ammo_type(img: Image, cal: String, _size: int) -> void:
	if cal == "12gauge":
		# 12G 벅샷 (붉은색 플라스틱 쉘 + 황동 림)
		for i in range(2):
			var ox := 9 + i * 8
			for x in range(ox, ox + 6):
				for y in range(10, 23):
					var c := Color(0.84, 0.20, 0.20) if y < 19 else Color(0.86, 0.74, 0.22)
					img.set_pixel(x, y, c)
	elif cal == "12slug":
		# 12G 슬러그 (짙은 청록 쉘 + 은빛 대형 슬러그 탄두)
		for i in range(2):
			var ox := 9 + i * 8
			for x in range(ox, ox + 6):
				for y in range(9, 23):
					var c := Color(0.18, 0.45, 0.75)
					if y < 12: c = Color(0.76, 0.80, 0.86)
					elif y >= 19: c = Color(0.86, 0.74, 0.22)
					img.set_pixel(x, y, c)
	elif cal == "5.56mm":
		for i in range(3):
			var ox := 7 + i * 7
			for x in range(ox, ox + 5):
				for y in range(10, 23):
					var c := Color(0.85, 0.75, 0.25)
					if y < 13: c = Color(0.28, 0.68, 0.30)
					elif y == 22: c = Color(0.32, 0.32, 0.34)
					img.set_pixel(x, y, c)
	elif cal == "7.62mm":
		for i in range(3):
			var ox := 7 + i * 7
			for x in range(ox, ox + 5):
				for y in range(9, 24):
					var c := Color(0.80, 0.65, 0.20)
					if y < 14: c = Color(0.76, 0.44, 0.22)
					elif y == 23: c = Color(0.25, 0.25, 0.27)
					img.set_pixel(x, y, c)
	elif cal == "45acp":
		for i in range(3):
			var ox := 6 + i * 7
			for x in range(ox, ox + 6):
				for y in range(13, 23):
					var c := Color(0.86, 0.72, 0.24)
					if y < 16: c = Color(0.74, 0.46, 0.28)
					elif y == 22: c = Color(0.28, 0.28, 0.30)
					img.set_pixel(x, y, c)
	else:
		_draw_ammo(img, Color(0.85, 0.75, 0.25), _size)

# ============================================================
# 4. 총기 부착물(파츠) 드로잉
# ============================================================
func _draw_attachment(img: Image, part_category: String, full_id: String, _size: int) -> void:
	match part_category:
		"rail_laser":
			# PEQ 적색 레이저 모듈 + 에미터 + 발광 붉은 렌즈
			for x in range(8, 22):
				for y in range(12, 19):
					img.set_pixel(x, y, Color(0.18, 0.20, 0.22))
			for x in range(10, 18):
				img.set_pixel(x, 19, Color(0.28, 0.30, 0.34)) # 레일 클램프
			img.set_pixel(13, 13, Color(0.55, 0.58, 0.62)) # 다이얼
			for y in range(13, 17):
				img.set_pixel(22, y, Color(0.95, 0.18, 0.18))
				img.set_pixel(23, y, Color(1.0, 0.32, 0.24))
			img.set_pixel(26, 14, Color(1.0, 0.22, 0.22))
			img.set_pixel(28, 14, Color(0.98, 0.32, 0.25))
		"rail_light":
			# 무기 장착형 전술 라이트
			for x in range(8, 20):
				for y in range(13, 18):
					img.set_pixel(x, y, Color(0.20, 0.22, 0.26))
			for x in range(11, 17):
				img.set_pixel(x, 18, Color(0.30, 0.32, 0.36))
			for x in range(20, 25):
				for y in range(11, 20):
					img.set_pixel(x, y, Color(0.40, 0.44, 0.48))
			for y in range(12, 19):
				img.set_pixel(25, y, Color(0.95, 0.92, 0.55))
		"iron_sight":
			# 기계식 가늠자 & 가늠쇠 세트
			for x in range(8, 24):
				for y in range(18, 21):
					img.set_pixel(x, y, Color(0.25, 0.28, 0.32))
			for x in range(9, 13):
				for y in range(12, 18): img.set_pixel(x, y, Color(0.28, 0.31, 0.35))
			for x in range(19, 23):
				for y in range(12, 18): img.set_pixel(x, y, Color(0.28, 0.31, 0.35))
			img.set_pixel(21, 13, Color(0.25, 0.92, 0.45)) # 트리튬 야광 도트
		"optic":
			if full_id.contains("8배율") or full_id.contains("스나이퍼"):
				for x in range(6, 26):
					for y in range(13, 19): img.set_pixel(x, y, Color(0.22, 0.24, 0.27))
				for y in range(11, 21):
					img.set_pixel(7, y, Color(0.22, 0.72, 0.94))
					img.set_pixel(25, y, Color(0.22, 0.72, 0.94))
			elif full_id.contains("4배율") or full_id.contains("ACOG") or full_id.contains("2배율"):
				for x in range(9, 23):
					for y in range(12, 20): img.set_pixel(x, y, Color(0.26, 0.27, 0.31))
				img.set_pixel(10, 15, Color(0.30, 0.80, 1.0))
				img.set_pixel(10, 16, Color(0.30, 0.80, 1.0))
			else:
				for x in range(10, 22):
					for y in range(14, 21): img.set_pixel(x, y, Color(0.22, 0.22, 0.24))
				img.set_pixel(16, 16, Color(0.98, 0.18, 0.18))
				img.set_pixel(16, 17, Color(0.98, 0.18, 0.18))
		"muzzle":
			if full_id.contains("소음기"):
				for x in range(7, 25):
					for y in range(13, 19):
						var c := Color(0.22, 0.23, 0.25)
						if x % 3 == 0: c = Color(0.14, 0.15, 0.17)
						img.set_pixel(x, y, c)
			elif full_id.contains("소염기"):
				for x in range(9, 23):
					for y in range(13, 19): img.set_pixel(x, y, Color(0.30, 0.33, 0.36))
				for y in [14, 17]:
					img.set_pixel(20, y, Color(0.10, 0.11, 0.13))
					img.set_pixel(22, y, Color(0.10, 0.11, 0.13))
			else:
				for x in range(10, 22):
					for y in range(12, 20): img.set_pixel(x, y, Color(0.36, 0.39, 0.42))
				for x in range(12, 19, 2):
					img.set_pixel(x, 12, Color(0.10, 0.11, 0.13))
					img.set_pixel(x, 19, Color(0.10, 0.11, 0.13))
		"grip":
			for x in range(11, 21):
				for y in range(10, 14): img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
			if full_id.contains("RK-1") or full_id.contains("인체공학") or full_id.contains("앵글"):
				for i in range(9):
					var gy := 14 + i
					var gx := 12 + int(i * 0.6)
					for dx in range(5):
						img.set_pixel(gx + dx, gy, Color(0.26, 0.22, 0.18))
			else:
				for x in range(13, 19):
					for y in range(14, 24): img.set_pixel(x, y, Color(0.16, 0.17, 0.20))
		"magazine":
			if full_id.contains("드럼"):
				for x in range(9, 23):
					for y in range(11, 25):
						var dx := (x - 15.5) / 6.5
						var dy := (y - 17.5) / 6.5
						if dx * dx + dy * dy <= 1.0: img.set_pixel(x, y, Color(0.22, 0.24, 0.27))
				for x in range(14, 18):
					for y in range(8, 12): img.set_pixel(x, y, Color(0.26, 0.28, 0.32))
			elif full_id.contains("확장") or full_id.contains("30"):
				for y in range(8, 25):
					var curve := int(maxf(0.0, float(y - 15) * 0.35))
					for x in range(11 + curve, 19 + curve):
						img.set_pixel(x, y, Color(0.24, 0.26, 0.30))
				for x in range(12, 18): img.set_pixel(x, 8, Color(0.88, 0.76, 0.24))
			else:
				for x in range(11, 20):
					for y in range(11, 24): img.set_pixel(x, y, Color(0.22, 0.24, 0.28))
				for x in range(12, 19): img.set_pixel(x, 11, Color(0.88, 0.76, 0.24))
		"stock":
			if full_id.contains("PRS") or full_id.contains("저격"):
				for x in range(6, 25):
					for y in range(11, 21): img.set_pixel(x, y, Color(0.26, 0.30, 0.24))
				for x in range(5, 8):
					for y in range(10, 23): img.set_pixel(x, y, Color(0.14, 0.14, 0.16))
			else:
				for x in range(8, 24):
					img.set_pixel(x, 12, Color(0.28, 0.30, 0.34))
					img.set_pixel(x, 13, Color(0.28, 0.30, 0.34))
					img.set_pixel(x, 19, Color(0.24, 0.26, 0.30))
				for x in range(6, 10):
					for y in range(11, 23): img.set_pixel(x, y, Color(0.14, 0.15, 0.18))
		_:
			if full_id.contains("짧은"):
				for x in range(9, 23):
					for y in range(14, 18): img.set_pixel(x, y, Color(0.32, 0.34, 0.38))
			else:
				for x in range(4, 28):
					for y in range(14, 18):
						var bc := Color(0.32, 0.35, 0.39)
						if y == 15 and x % 4 == 0: bc = Color(0.45, 0.48, 0.52)
						img.set_pixel(x, y, bc)

# ============================================================
# 5. 기본 무기 및 도구 드로잉
# ============================================================
func _draw_gun(img: Image, color: Color, _size: int, is_long: bool = false) -> void:
	var length: int = 20 if is_long else 13
	for x in range(6, 6 + length):
		for y in range(12, 16):
			img.set_pixel(x, y, color)
	img.set_pixel(6 + length, 13, Color(0.12, 0.12, 0.14))
	img.set_pixel(6 + length, 14, Color(0.12, 0.12, 0.14))
	for x in range(6, 11):
		for y in range(16, 23):
			img.set_pixel(x, y, Color(0.36, 0.23, 0.15))
	img.set_pixel(12, 17, Color(0.12, 0.12, 0.14))
	img.set_pixel(12, 18, Color(0.12, 0.12, 0.14))

func _draw_ammo(img: Image, color: Color, _size: int) -> void:
	for i in range(3):
		var ox := 7 + i * 7
		for x in range(ox, ox + 5):
			for y in range(12, 23):
				var c := color
				if y < 15: c = Color(0.65, 0.46, 0.32)
				elif y == 22: c = Color(0.24, 0.24, 0.26)
				img.set_pixel(x, y, c)

func _draw_grenade(img: Image, _size: int) -> void:
	for x in range(11, 21):
		for y in range(12, 24):
			var c := Color(0.25, 0.42, 0.25)
			if (x + y) % 3 == 0: c = Color(0.16, 0.28, 0.16)
			img.set_pixel(x, y, c)
	for x in range(14, 18):
		for y in range(7, 12):
			img.set_pixel(x, y, Color(0.72, 0.74, 0.78))

func _draw_melee(img: Image, color: Color, m_type: String, _size: int) -> void:
	for i in range(16):
		var x := 8 + i
		var y := 23 - i
		img.set_pixel(x, y, color)
		img.set_pixel(x + 1, y, color)
		if m_type == "knife" and i > 8:
			img.set_pixel(x + 2, y, color.lightened(0.2))
		elif m_type == "pipe":
			img.set_pixel(x, y + 1, Color(0.32, 0.34, 0.38))
		elif m_type == "bat" and i > 6:
			img.set_pixel(x + 1, y + 1, color)
			img.set_pixel(x + 2, y, color)

func _draw_axe(img: Image, _size: int) -> void:
	for i in range(18):
		var x := 7 + i
		var y := 24 - i
		img.set_pixel(x, y, Color(0.46, 0.30, 0.15))
		img.set_pixel(x + 1, y, Color(0.36, 0.21, 0.10))
	for x in range(19, 27):
		for y in range(5, 13):
			if x >= y + 13:
				img.set_pixel(x, y, Color(0.80, 0.82, 0.86))

func _draw_bandage(img: Image, _size: int) -> void:
	for x in range(9, 23):
		for y in range(11, 21):
			var c := Color(0.90, 0.90, 0.85)
			if (x + y) % 4 == 0: c = Color(0.74, 0.74, 0.70)
			img.set_pixel(x, y, c)

func _draw_pills(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(11, 23):
			var c := Color(0.85, 0.50, 0.16) if y < 14 else Color(0.88, 0.90, 0.94)
			img.set_pixel(x, y, c)
	for x in range(6, 12):
		for y in range(20, 24):
			img.set_pixel(x, y, Color(0.88, 0.22, 0.22) if x < 9 else Color(0.90, 0.90, 0.90))

func _draw_antibiotic(img: Image, _size: int) -> void:
	# 항생제 바이알 & 오토인젝터 실린지
	for x in range(11, 21):
		for y in range(11, 25):
			var c := Color(0.75, 0.86, 0.92)
			if y >= 16: c = Color(0.18, 0.78, 0.62)
			img.set_pixel(x, y, c)
	# 금속 캡 + 고무 마개
	for x in range(12, 20):
		for y in range(7, 11):
			img.set_pixel(x, y, Color(0.82, 0.84, 0.88) if y < 9 else Color(0.24, 0.26, 0.30))
	# 라벨 십자 마크
	img.set_pixel(15, 14, Color(0.95, 0.25, 0.25))
	img.set_pixel(16, 14, Color(0.95, 0.25, 0.25))

func _draw_medkit(img: Image, _size: int) -> void:
	for x in range(6, 26):
		for y in range(10, 23):
			img.set_pixel(x, y, Color(0.82, 0.20, 0.20))
	for x in range(14, 18):
		for y in range(12, 21): img.set_pixel(x, y, Color.WHITE)
	for x in range(10, 22):
		for y in range(14, 18): img.set_pixel(x, y, Color.WHITE)

func _draw_advanced_medkit(img: Image, _size: int) -> void:
	for x in range(5, 27):
		for y in range(8, 24):
			img.set_pixel(x, y, Color(0.22, 0.38, 0.26))
	for x in range(14, 18):
		for y in range(11, 21): img.set_pixel(x, y, Color(0.92, 0.82, 0.22))
	for x in range(10, 22):
		for y in range(14, 18): img.set_pixel(x, y, Color(0.92, 0.82, 0.22))

func _draw_herb(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x - 16) * (x - 16) + (y - 16) * (y - 16) < 36:
				img.set_pixel(x, y, Color(0.25, 0.72, 0.32))
	for y in range(18, 26):
		img.set_pixel(16, y, Color(0.16, 0.48, 0.22))

func _draw_bottle(img: Image, liquid_color: Color, _size: int) -> void:
	for x in range(12, 20):
		for y in range(7, 26):
			if y < 11:
				img.set_pixel(x, y, Color(0.76, 0.78, 0.84))
			else:
				var c := liquid_color if y > 15 else Color(0.86, 0.90, 0.96, 0.85)
				img.set_pixel(x, y, c)

func _draw_can(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(9, 24):
			var c := color if (y > 11 and y < 22) else Color(0.75, 0.76, 0.80)
			img.set_pixel(x, y, c)

func _draw_bread(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(12, 22):
			var c := Color(0.80, 0.56, 0.26)
			if y == 12 or y == 21: c = Color(0.58, 0.38, 0.18)
			img.set_pixel(x, y, c)

func _draw_energy_bar(img: Image, _size: int) -> void:
	for x in range(6, 26):
		for y in range(12, 20):
			var c := Color(0.90, 0.32, 0.12) if (x % 6 < 3) else Color(0.22, 0.22, 0.24)
			img.set_pixel(x, y, c)

func _draw_chocolate(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(11, 21):
			var c := Color(0.38, 0.22, 0.14)
			if x == 12 or x == 17 or y == 16: c = Color(0.24, 0.12, 0.07)
			if x > 18: c = Color(0.82, 0.22, 0.20) # 포장지
			img.set_pixel(x, y, c)

func _draw_meat(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c := Color(0.58, 0.25, 0.16)
			if (x + y) % 5 == 0: c = Color(0.24, 0.10, 0.06)
			img.set_pixel(x, y, c)

func _draw_mre(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c := Color(0.62, 0.54, 0.34)
			if y > 12 and y < 16: c = Color(0.42, 0.34, 0.20)
			img.set_pixel(x, y, c)

func _draw_crop(img: Image, _size: int) -> void:
	for x in range(11, 21):
		for y in range(10, 24):
			img.set_pixel(x, y, Color(0.88, 0.50, 0.12))
	for x in range(13, 19):
		for y in range(6, 10):
			img.set_pixel(x, y, Color(0.22, 0.72, 0.24))

func _draw_binoculars(img: Image, high_mag: bool, _size: int) -> void:
	var body_col := Color(0.22, 0.30, 0.22) if not high_mag else Color(0.24, 0.26, 0.30)
	var trim_col := Color(0.14, 0.18, 0.14) if not high_mag else Color(0.82, 0.66, 0.24)
	# 좌/우 경통 (고배율은 더 길고 황금 링 포커서)
	var y_top: int = 7 if high_mag else 9
	var y_bot: int = 25 if high_mag else 23
	for x in range(8, 14):
		for y in range(y_top, y_bot):
			img.set_pixel(x, y, body_col)
	for x in range(18, 24):
		for y in range(y_top, y_bot):
			img.set_pixel(x, y, body_col)
	# 중앙 브릿지
	for x in range(13, 19):
		for y in range(14, 18):
			img.set_pixel(x, y, trim_col)
	# 대물 렌즈 글레어
	for x in range(9, 13):
		img.set_pixel(x, y_bot - 2, Color(0.28, 0.78, 0.95))
	for x in range(19, 23):
		img.set_pixel(x, y_bot - 2, Color(0.28, 0.78, 0.95))

func _draw_flashlight(img: Image, _size: int) -> void:
	for x in range(8, 20):
		for y in range(13, 19):
			img.set_pixel(x, y, Color(0.25, 0.26, 0.31))
	for x in range(20, 25):
		for y in range(11, 21):
			img.set_pixel(x, y, Color(0.92, 0.82, 0.25))

func _draw_battery(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 24):
			var c := Color(0.16, 0.52, 0.22) if y > 14 else Color(0.90, 0.80, 0.14)
			img.set_pixel(x, y, c)
	for x in range(14, 18):
		for y in range(7, 10):
			img.set_pixel(x, y, Color(0.72, 0.74, 0.78))

func _draw_backpack(img: Image, _size: int) -> void:
	_draw_backpack_tier(img, 1, _size)

func _draw_gasmask(img: Image, _size: int) -> void:
	for x in range(9, 23):
		for y in range(8, 24):
			img.set_pixel(x, y, Color(0.25, 0.25, 0.29))
	for x in range(11, 15):
		for y in range(11, 15): img.set_pixel(x, y, Color(0.28, 0.72, 0.85))
	for x in range(17, 21):
		for y in range(11, 15): img.set_pixel(x, y, Color(0.28, 0.72, 0.85))
	for x in range(13, 19):
		for y in range(18, 23): img.set_pixel(x, y, Color(0.15, 0.16, 0.17))

func _draw_armor(img: Image, _size: int) -> void:
	_draw_armor_tier(img, 1, _size)

func _draw_shoes(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(14, 22):
			var c := Color(0.22, 0.50, 0.80) if y < 19 else Color(0.86, 0.86, 0.86)
			img.set_pixel(x, y, c)

func _draw_map(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(8, 24):
			var c := Color(0.88, 0.83, 0.68)
			if (x == 12 or x == 19) and y % 2 == 0: c = Color(0.68, 0.62, 0.48)
			img.set_pixel(x, y, c)
	img.set_pixel(15, 14, Color(0.95, 0.18, 0.18))
	img.set_pixel(16, 14, Color(0.95, 0.18, 0.18))
	img.set_pixel(15, 15, Color(0.95, 0.18, 0.18))

func _draw_compass(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var dist := (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 49:
				var c := Color(0.20, 0.30, 0.22)
				if dist > 36: c = Color(0.75, 0.66, 0.22)
				img.set_pixel(x, y, c)
	for y in range(10, 16): img.set_pixel(16, y, Color(0.96, 0.20, 0.20))
	for y in range(16, 22): img.set_pixel(16, y, Color(0.25, 0.82, 0.98))

func _draw_scrap(img: Image, _size: int) -> void:
	# 결정론적 고철 판재 & 녹슨 볼트 형태
	for x in range(7, 24):
		for y in range(11, 22):
			if (x + y * 2) % 5 != 0:
				var rust := ((x * 7 + y * 13) % 9) < 3
				var c := Color(0.54, 0.36, 0.26) if rust else Color(0.45, 0.48, 0.52)
				img.set_pixel(x, y, c)
	for x in range(11, 21):
		img.set_pixel(x, 9, Color(0.58, 0.62, 0.66))
	img.set_pixel(14, 15, Color(0.78, 0.80, 0.85))
	img.set_pixel(19, 17, Color(0.78, 0.80, 0.85))

func _draw_wood(img: Image, _size: int) -> void:
	for x in range(6, 26):
		for y in range(10, 22):
			var c := Color(0.56, 0.36, 0.20)
			if y == 13 or y == 18: c = Color(0.40, 0.25, 0.12)
			img.set_pixel(x, y, c)

func _draw_nails(img: Image, _size: int) -> void:
	for i in range(3):
		var ox := 9 + i * 5
		for y in range(9, 23): img.set_pixel(ox, y, Color(0.72, 0.74, 0.78))
		img.set_pixel(ox - 1, 9, Color(0.42, 0.44, 0.48))
		img.set_pixel(ox + 1, 9, Color(0.42, 0.44, 0.48))

func _draw_cloth(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c := Color(0.70, 0.65, 0.60)
			if (x + y) % 3 == 0: c = Color(0.58, 0.53, 0.48)
			img.set_pixel(x, y, c)

func _draw_gears(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var dist := (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 45 and dist > 9:
				img.set_pixel(x, y, Color(0.60, 0.62, 0.68))
			elif dist <= 9:
				img.set_pixel(x, y, Color(0.20, 0.21, 0.24))

func _draw_wire(img: Image, _size: int) -> void:
	for i in range(20):
		var x := int(16.0 + cos(float(i) * 0.4) * 8.0)
		var y := int(16.0 + sin(float(i) * 0.4) * 8.0)
		img.set_pixel(x, y, Color(0.86, 0.45, 0.20))
		img.set_pixel(x + 1, y, Color(0.24, 0.34, 0.85))

func _draw_gunpowder(img: Image, _size: int) -> void:
	# 결정론적 화약 주머니 & 흑색 입자 더미
	for x in range(9, 23):
		for y in range(11, 24):
			var dist_x := absi(x - 16)
			if y < 14 and dist_x > 3:
				continue
			var c := Color(0.68, 0.24, 0.18) if y < 15 else Color(0.20, 0.21, 0.24)
			if y >= 15 and ((x * 11 + y * 7) % 5 == 0):
				c = Color(0.36, 0.38, 0.42)
			img.set_pixel(x, y, c)
	for x in range(11, 21):
		img.set_pixel(x, 14, Color(0.88, 0.72, 0.22))

func _draw_cpu(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c := Color(0.20, 0.56, 0.30)
			if x > 10 and x < 21 and y > 10 and y < 21:
				c = Color(0.76, 0.78, 0.84)
			img.set_pixel(x, y, c)

func _draw_gpu(img: Image, _size: int) -> void:
	for x in range(5, 27):
		for y in range(10, 22):
			var c := Color(0.20, 0.22, 0.26)
			if x % 6 == 0 and y > 12 and y < 19: c = Color(0.14, 0.64, 0.76)
			img.set_pixel(x, y, c)

func _draw_watch(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist := (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 30:
				img.set_pixel(x, y, Color.WHITE if dist < 16 else color)

func _draw_ring(img: Image, color: Color, _size: int) -> void:
	for x in range(10, 22):
		for y in range(10, 22):
			var dist := (x - 16) * (x - 16) + (y - 16) * (y - 16)
			if dist < 32 and dist > 14:
				img.set_pixel(x, y, color)
	img.set_pixel(16, 10, Color(0.22, 0.82, 0.98))
	img.set_pixel(16, 11, Color(0.22, 0.82, 0.98))

func _draw_vase(img: Image, _size: int) -> void:
	for x in range(10, 22):
		for y in range(8, 24):
			if (x >= 14 and x <= 17 and y < 12) or (y >= 12 and (x - 16) * (x - 16) + (y - 18) * (y - 18) < 25):
				img.set_pixel(x, y, Color(0.20, 0.52, 0.72))

func _draw_radio_parts(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(10, 22):
			var c := Color(0.24, 0.48, 0.30)
			if (x == 12 or x == 18) and y > 12 and y < 18: c = Color(0.88, 0.80, 0.22)
			elif x > 13 and x < 17 and y > 13 and y < 18: c = Color(0.18, 0.20, 0.24)
			img.set_pixel(x, y, c)

func _draw_radio(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(11, 23): img.set_pixel(x, y, Color(0.30, 0.36, 0.30))
	for y in range(5, 11): img.set_pixel(10, y, Color(0.72, 0.74, 0.78))
	for x in range(16, 21):
		for y in range(14, 20):
			if (x + y) % 2 == 0: img.set_pixel(x, y, Color(0.12, 0.12, 0.14))

func _draw_dogtag(img: Image, _size: int) -> void:
	# 인식표 체인 고리
	for x in range(11, 21):
		if x % 2 == 0:
			img.set_pixel(x, 7, Color(0.72, 0.75, 0.80))
			img.set_pixel(x + 1, 8, Color(0.55, 0.58, 0.64))
	# 하부 인식표 플레이트 (어두운 스틸)
	for x in range(12, 23):
		for y in range(12, 24):
			img.set_pixel(x, y, Color(0.48, 0.52, 0.58))
	# 상부 인식표 플레이트 (밝은 스틸 + 붉은 각인/노치)
	for x in range(9, 19):
		for y in range(10, 21):
			var c := Color(0.74, 0.78, 0.84)
			if y == 14 or y == 16: c = Color(0.36, 0.40, 0.46)
			img.set_pixel(x, y, c)
	img.set_pixel(13, 11, Color(0.86, 0.22, 0.22))

func _draw_ssd(img: Image, _size: int) -> void:
	for x in range(7, 25):
		for y in range(9, 23):
			var c := Color(0.16, 0.17, 0.20)
			if x > 16 and y > 18: c = Color(0.88, 0.76, 0.24)
			img.set_pixel(x, y, c)

func _draw_generic_box(img: Image, _size: int) -> void:
	for x in range(8, 24):
		for y in range(8, 24):
			var c := Color(0.50, 0.50, 0.55)
			if x == 8 or x == 23 or y == 8 or y == 23: c = Color(0.22, 0.22, 0.26)
			img.set_pixel(x, y, c)

func _draw_key(img: Image, _size: int) -> void:
	var brass := Color(0.92, 0.76, 0.24)
	var dark_brass := Color(0.62, 0.48, 0.12)
	for x in range(6, 16):
		for y in range(9, 19):
			var d2 := (x - 10.5) * (x - 10.5) + (y - 13.5) * (y - 13.5)
			if d2 <= 20.0 and d2 >= 5.0:
				img.set_pixel(x, y, brass if y < 14 else dark_brass)
	for x in range(15, 27):
		img.set_pixel(x, 13, brass)
		img.set_pixel(x, 14, dark_brass)
	for x in [21, 22, 25, 26]:
		for y in range(15, 19):
			img.set_pixel(x, y, brass)

func _draw_keycard(img: Image, _size: int) -> void:
	for x in range(5, 27):
		for y in range(8, 24):
			var c := Color(0.16, 0.40, 0.76)
			if x == 5 or x == 26 or y == 8 or y == 23:
				c = Color(0.86, 0.91, 0.98)
			elif y >= 10 and y <= 12:
				c = Color(0.10, 0.12, 0.16)
			elif x >= 8 and x <= 12 and y >= 15 and y <= 19:
				c = Color(0.95, 0.80, 0.25)
			elif x >= 15 and x <= 23 and (y == 16 or y == 19):
				c = Color(0.65, 0.82, 0.98)
			img.set_pixel(x, y, c)

func _draw_storage_case(img: Image, case_kind: String, _size: int) -> void:
	var body_col := Color(0.24, 0.30, 0.22)
	var trim_col := Color(0.42, 0.50, 0.34)
	var accent_col := Color(0.92, 0.76, 0.24)
	if case_kind == "medical":
		body_col = Color(0.76, 0.80, 0.86)
		trim_col = Color(0.55, 0.62, 0.70)
		accent_col = Color(0.88, 0.22, 0.24)
	elif case_kind == "weapon_part":
		body_col = Color(0.18, 0.21, 0.26)
		trim_col = Color(0.34, 0.40, 0.48)
		accent_col = Color(0.32, 0.78, 0.96)
	elif case_kind == "dogtag_key":
		body_col = Color(0.32, 0.24, 0.18)
		trim_col = Color(0.48, 0.36, 0.26)
		accent_col = Color(0.94, 0.80, 0.28)

	# 케이스 본체
	for x in range(5, 27):
		for y in range(8, 25):
			var c := body_col
			if y < 11:
				c = trim_col
			elif y == 12:
				c = Color(0.10, 0.12, 0.15)
			img.set_pixel(x, y, c)
	# 상단 손잡이
	for x in range(12, 20):
		img.set_pixel(x, 6, trim_col)
		img.set_pixel(x, 7, trim_col)
	img.set_pixel(12, 7, Color(0.12, 0.13, 0.16))
	img.set_pixel(19, 7, Color(0.12, 0.13, 0.16))
	# 잠금 래치 2개
	for lx in [8, 22]:
		for y in range(11, 15):
			img.set_pixel(lx, y, accent_col)
			img.set_pixel(lx + 1, y, accent_col)
	# 중앙 심볼
	if case_kind == "medical":
		for x in range(14, 18):
			for y in range(15, 22):
				img.set_pixel(x, y, accent_col)
		for x in range(12, 20):
			for y in range(17, 20):
				img.set_pixel(x, y, accent_col)
	elif case_kind == "ammo":
		for bx in [12, 15, 18]:
			for y in range(15, 22):
				img.set_pixel(bx, y, accent_col)
				img.set_pixel(bx + 1, y, accent_col)
	elif case_kind == "weapon_part":
		for x in range(11, 21):
			for y in range(17, 20):
				img.set_pixel(x, y, accent_col)
		for y in range(15, 22):
			img.set_pixel(14, y, accent_col)
			img.set_pixel(15, y, accent_col)
	else:
		for x in range(13, 19):
			for y in range(15, 21):
				img.set_pixel(x, y, accent_col)
		img.set_pixel(15, 17, body_col)
		img.set_pixel(16, 17, body_col)
