# res://autoload/tile_manager.gd
extends Node

## 런타임에 동적으로 타일셋 이미지를 생성하고 TileSet 리소스를 만들어 제공하는 싱글톤
## 텍스처 없이도 게임 개발이 가능하도록 색상 기반의 타일 아틀라스를 생성합니다.

const TILE_SIZE: int = 32
var tileset: TileSet

# 타일 아틀라스 좌표 매핑 (x, y)
const TILE_GRASS = Vector2i(0, 0)
const TILE_DIRT = Vector2i(1, 0)
const TILE_ROAD = Vector2i(2, 0)
const TILE_CONCRETE = Vector2i(3, 0)
const TILE_FLOOR_WOOD = Vector2i(4, 0)
const TILE_FLOOR_TILE = Vector2i(5, 0)
const TILE_ROAD_LINE = Vector2i(6, 0)

const OBJ_TREE = Vector2i(0, 1)
const OBJ_ROCK = Vector2i(1, 1)
const OBJ_WALL = Vector2i(2, 1)
const OBJ_CRATE = Vector2i(3, 1)
const OBJ_BARREL = Vector2i(4, 1)
const OBJ_CAR = Vector2i(5, 1)
const OBJ_DOOR = Vector2i(6, 1)
const OBJ_FRIDGE = Vector2i(0, 2)

func _ready() -> void:
	_generate_procedural_tileset()

func _generate_procedural_tileset() -> void:
	# 8x3 타일 아틀라스 이미지 생성
	var img = Image.create_empty(8 * TILE_SIZE, 3 * TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	# 색상 정의
	var colors = {
		TILE_GRASS: Color(0.25, 0.5, 0.2),
		TILE_DIRT: Color(0.55, 0.45, 0.3),
		TILE_ROAD: Color(0.3, 0.3, 0.35),
		TILE_CONCRETE: Color(0.6, 0.6, 0.65),
		TILE_FLOOR_WOOD: Color(0.6, 0.45, 0.3),
		TILE_FLOOR_TILE: Color(0.7, 0.7, 0.7),
		TILE_ROAD_LINE: Color(0.8, 0.8, 0.2)
	}
	
	# 바닥 타일 그리기 (y=0)
	for coords in colors.keys():
		_fill_rect_noisy(img, coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, colors[coords])
		
	# 오브젝트 타일 그리기 (y=1, y=2)
	_draw_tree(img, OBJ_TREE.x * TILE_SIZE, OBJ_TREE.y * TILE_SIZE)
	_draw_rock(img, OBJ_ROCK.x * TILE_SIZE, OBJ_ROCK.y * TILE_SIZE)
	_fill_rect_noisy(img, OBJ_WALL.x * TILE_SIZE, OBJ_WALL.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Color(0.4, 0.3, 0.25)) # 벽
	_draw_crate(img, OBJ_CRATE.x * TILE_SIZE, OBJ_CRATE.y * TILE_SIZE)
	_draw_barrel(img, OBJ_BARREL.x * TILE_SIZE, OBJ_BARREL.y * TILE_SIZE)
	_draw_car(img, OBJ_CAR.x * TILE_SIZE, OBJ_CAR.y * TILE_SIZE)
	_fill_rect_noisy(img, OBJ_DOOR.x * TILE_SIZE, OBJ_DOOR.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Color(0.5, 0.25, 0.1)) # 문
	_draw_fridge(img, OBJ_FRIDGE.x * TILE_SIZE, OBJ_FRIDGE.y * TILE_SIZE)
	
	var texture = ImageTexture.create_from_image(img)
	
	# TileSet 및 Source 생성
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# 물리 레이어 추가 (충돌체용)
	tileset.add_physics_layer(0)
	
	# 빛 차폐(Occlusion) 레이어 추가
	tileset.add_occlusion_layer(0)
	
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# 바닥 타일 등록
	for coords in colors.keys():
		source.create_tile(coords)
		
	tileset.add_source(source, 0)
		
	# 오브젝트 타일 등록 및 충돌체 설정
	var objects = [OBJ_TREE, OBJ_ROCK, OBJ_WALL, OBJ_CRATE, OBJ_BARREL, OBJ_CAR, OBJ_DOOR, OBJ_FRIDGE]
	for coords in objects:
		source.create_tile(coords)
		var tile_data = source.get_tile_data(coords, 0)
		if tile_data:
			# 꽉 차는 사각형 충돌체/차폐체 생성
			var poly = PackedVector2Array([
				Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0),
				Vector2(-TILE_SIZE/2.0, TILE_SIZE/2.0)
			])
			
			# 나무나 바위는 충돌 크기를 약간 줄임
			if coords == OBJ_TREE or coords == OBJ_ROCK or coords == OBJ_BARREL:
				poly = PackedVector2Array([
					Vector2(-TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, TILE_SIZE*0.4),
					Vector2(-TILE_SIZE*0.4, TILE_SIZE*0.4)
				])
			
			# 문은 충돌체를 갖지 않게 하거나, 닫혔을 때만 적용 가능. 일단 통과 가능하게 처리(충돌 없음).
			if coords != OBJ_DOOR:
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, poly)
				
				# 빛 차폐(Occluder) 등록 (투명도 없는 물체 위주)
				if coords in [OBJ_WALL, OBJ_CRATE, OBJ_CAR, OBJ_ROCK, OBJ_FRIDGE]:
					var occluder = OccluderPolygon2D.new()
					occluder.polygon = poly
					tile_data.add_occluder_polygon(0)
					tile_data.set_occluder_polygon(0, 0, occluder)

# ==========================================================
# 이미지 드로잉 헬퍼
# ==========================================================
func _fill_rect_noisy(img: Image, x: int, y: int, w: int, h: int, base_color: Color) -> void:
	for iy in range(h):
		for ix in range(w):
			# 기본 노이즈 추가 (텍스처 질감)
			var noise = (randf() - 0.5) * 0.1
			var color = base_color
			color.r = clamp(color.r + noise, 0.0, 1.0)
			color.g = clamp(color.g + noise, 0.0, 1.0)
			color.b = clamp(color.b + noise, 0.0, 1.0)
			img.set_pixel(x + ix, y + iy, color)
			
			# 풀밭인 경우 풀잎 스포이드
			if base_color == Color(0.25, 0.5, 0.2) and randf() < 0.05:
				img.set_pixel(x + ix, y + iy, Color(0.15, 0.4, 0.15))
			# 콘크리트인 경우 균열/돌조각
			elif base_color == Color(0.6, 0.6, 0.65) and randf() < 0.02:
				img.set_pixel(x + ix, y + iy, Color(0.4, 0.4, 0.45))
			# 나무 바닥인 경우 나무결 무늬
			elif base_color == Color(0.6, 0.45, 0.3) and iy % 4 == 0:
				img.set_pixel(x + ix, y + iy, Color(0.45, 0.3, 0.2))

func _draw_tree(img: Image, x: int, y: int) -> void:
	var cx = x + TILE_SIZE / 2
	var cy = y + TILE_SIZE / 2
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var dx = x + ix - cx
			var dy = y + iy - cy
			var dist = sqrt(dx*dx + dy*dy)
			# 흔들리는 잎사귀 느낌을 위해 노이즈 경계
			var noise = randf() * 3.0
			if dist + noise < TILE_SIZE * 0.5:
				img.set_pixel(x + ix, y + iy, Color(0.15, 0.35 + randf()*0.1, 0.15, 0.9))
			elif dist < TILE_SIZE * 0.2:
				img.set_pixel(x + ix, y + iy, Color(0.35, 0.25, 0.15)) # 기둥

func _draw_rock(img: Image, x: int, y: int) -> void:
	var cx = x + TILE_SIZE / 2
	var cy = y + TILE_SIZE / 2
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var dx = abs(x + ix - cx)
			var dy = abs(y + iy - cy)
			var noise = randf() * 2.0
			if dx + noise < TILE_SIZE * 0.45 and dy + noise < TILE_SIZE * 0.4:
				# 음영 표현
				var c = 0.5 if (x+ix) < cx else 0.3
				img.set_pixel(x + ix, y + iy, Color(c, c, c+0.05))

func _draw_crate(img: Image, x: int, y: int) -> void:
	var border = 3
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			if ix < border or ix > TILE_SIZE-1-border or iy < border or iy > TILE_SIZE-1-border:
				img.set_pixel(x + ix, y + iy, Color(0.2, 0.15, 0.1)) # 짙은 테두리
			else:
				var c = Color(0.5, 0.35, 0.2)
				if ix == iy or ix == (TILE_SIZE - 1 - iy): # X자 나무 덧댐 무늬
					c = Color(0.4, 0.25, 0.1)
				img.set_pixel(x + ix, y + iy, c)

func _draw_barrel(img: Image, x: int, y: int) -> void:
	var cx = x + TILE_SIZE / 2
	var cy = y + TILE_SIZE / 2
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var dx = x + ix - cx
			var dy = y + iy - cy
			var dist = sqrt(dx*dx + dy*dy)
			if dist < TILE_SIZE * 0.35:
				var highlight = 0.1 if dx < -2 else 0.0
				img.set_pixel(x + ix, y + iy, Color(0.2 + highlight, 0.25 + highlight, 0.7)) # 드럼통 몸체
			elif dist < TILE_SIZE * 0.4:
				img.set_pixel(x + ix, y + iy, Color(0.1, 0.1, 0.1)) # 테두리

func _draw_car(img: Image, x: int, y: int) -> void:
	# 녹슨 폐차를 픽셀아트로 정교하게 표현
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var px = x + ix
			var py = y + iy
			
			# 차량 기본 뼈대
			if ix >= 4 and ix <= TILE_SIZE - 4 and iy >= 2 and iy <= TILE_SIZE - 2:
				var is_window = false
				# 앞유리 / 뒷유리 영역
				if (iy >= 8 and iy <= 12) or (iy >= 20 and iy <= 24):
					if ix >= 6 and ix <= TILE_SIZE - 6:
						is_window = true
				
				if is_window:
					# 깨진 유리 (어둡고 가끔 노이즈)
					var c = Color(0.1, 0.15, 0.2)
					if randf() < 0.1: c = Color(0.3, 0.35, 0.4) # 깨진 반사광
					img.set_pixel(px, py, c)
				else:
					# 녹슨 철판 (기본은 바랜 빨간/파란/노란색 중 하나인데 전체적으로 녹슬게 표현)
					var base_car_color = Color(0.4, 0.2, 0.2) # 녹슨 붉은 차
					# 노이즈를 섞어 심하게 부식된 느낌
					var noise = (randf() - 0.5) * 0.2
					var rust = Color(0.6, 0.35, 0.15) # 주황빛 녹
					if randf() < 0.3:
						base_car_color = rust
						
					base_car_color.r = clamp(base_car_color.r + noise, 0.0, 1.0)
					base_car_color.g = clamp(base_car_color.g + noise, 0.0, 1.0)
					base_car_color.b = clamp(base_car_color.b + noise, 0.0, 1.0)
					
					# 외곽선(범퍼 등)은 더 어둡게
					if ix == 4 or ix == TILE_SIZE - 4 or iy == 2 or iy == TILE_SIZE - 2:
						base_car_color = Color(0.1, 0.1, 0.1)
						
					img.set_pixel(px, py, base_car_color)

func _draw_fridge(img: Image, x: int, y: int) -> void:
	# 버려지고 더러운 흰색 냉장고 (위에서 본 모습, 약간 정사각형에 가까운 직사각형)
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var px = x + ix
			var py = y + iy
			
			if ix >= 6 and ix <= TILE_SIZE - 6 and iy >= 6 and iy <= TILE_SIZE - 6:
				var c = Color(0.85, 0.85, 0.85) # 기본 흰색
				# 테두리
				if ix == 6 or ix == TILE_SIZE - 6 or iy == 6 or iy == TILE_SIZE - 6:
					c = Color(0.2, 0.2, 0.2)
				else:
					# 더러운 때, 녹슨 자국
					if randf() < 0.15:
						c = Color(0.5, 0.45, 0.4)
					# 손잡이 (우측 하단부근)
					if ix >= TILE_SIZE - 10 and ix <= TILE_SIZE - 8 and iy >= TILE_SIZE - 18 and iy <= TILE_SIZE - 12:
						c = Color(0.3, 0.3, 0.3)
					# 냉장실/냉동실 구분선 (가운데 선)
					if ix >= 7 and ix <= TILE_SIZE - 7 and iy == TILE_SIZE / 2:
						c = Color(0.4, 0.4, 0.4)
				
				img.set_pixel(px, py, c)
