# res://autoload/tile_manager.gd
extends Node

## 런타임에 동적으로 타일셋 이미지를 생성하고 TileSet 리소스를 만들어 제공하는 싱글톤
## 텍스처 없이도 게임 개발이 가능하도록 색상 기반의 타일 아틀라스를 생성합니다.

const TILE_SIZE: int = 32
var tileset: TileSet

# 타일 아틀라스 좌표 매핑 (x, y)
# 바닥 타일 (y=0)
const TILE_GRASS = Vector2i(0, 0)
const TILE_DIRT = Vector2i(1, 0)
const TILE_ROAD = Vector2i(2, 0)
const TILE_CONCRETE = Vector2i(3, 0)
const TILE_SIDEWALK = TILE_CONCRETE # 보도블록/인도
const TILE_FLOOR_WOOD = Vector2i(4, 0)
const TILE_FLOOR_TILE = Vector2i(5, 0)
const TILE_ROAD_LINE = Vector2i(6, 0)
const TILE_GRAVEL = Vector2i(7, 0) # 자갈길
const TILE_WATER = Vector2i(7, 2) # 물/물웅덩이 타일
const TILE_CROSSWALK_H = Vector2i(6, 10) # 가로 방향 횡단보도 (동서 도로용)

# 곡선/전환 차선 및 도로-인도 연석/코너 타일 (y=11..13)
const TILE_ROAD_LINE_VB_TR = Vector2i(0, 11)
const TILE_ROAD_LINE_VB_LB = Vector2i(1, 11)
const TILE_ROAD_LINE_VB_TL = Vector2i(2, 11)
const TILE_ROAD_LINE_VB_RB = Vector2i(3, 11)
const TILE_ROAD_LINE_HB_LD = Vector2i(4, 11)
const TILE_ROAD_LINE_HB_TR = Vector2i(5, 11)
const TILE_ROAD_LINE_HB_LU = Vector2i(6, 11)
const TILE_ROAD_LINE_HB_BR = Vector2i(7, 11)

const TILE_SIDEWALK_CURB_N = Vector2i(0, 12)
const TILE_SIDEWALK_CURB_E = Vector2i(1, 12)
const TILE_SIDEWALK_CURB_S = Vector2i(2, 12)
const TILE_SIDEWALK_CURB_W = Vector2i(3, 12)
const TILE_SIDEWALK_CORNER_NW = Vector2i(4, 12)
const TILE_SIDEWALK_CORNER_NE = Vector2i(5, 12)
const TILE_SIDEWALK_CORNER_SE = Vector2i(6, 12)
const TILE_SIDEWALK_CORNER_SW = Vector2i(7, 12)

const TILE_SIDEWALK_DIAG_NW = Vector2i(0, 13)
const TILE_SIDEWALK_DIAG_NE = Vector2i(1, 13)
const TILE_SIDEWALK_DIAG_SE = Vector2i(2, 13)
const TILE_SIDEWALK_DIAG_SW = Vector2i(3, 13)
const TILE_ROAD_EDGE_W = Vector2i(4, 13)
const TILE_ROAD_EDGE_E = Vector2i(5, 13)
const TILE_ROAD_EDGE_N = Vector2i(6, 13)
const TILE_ROAD_EDGE_S = Vector2i(7, 13)

# 오브젝트 타일 (y=1)
const OBJ_TREE = Vector2i(0, 1)
const OBJ_ROCK = Vector2i(1, 1)
const OBJ_WALL = Vector2i(2, 1)
const OBJ_CRATE = Vector2i(3, 1)
const OBJ_BARREL = Vector2i(4, 1)
const OBJ_DEBRIS = Vector2i(5, 1)
const OBJ_DOOR_CLOSED = Vector2i(6, 1) # 닫힌 문 (충돌+차폐)
const OBJ_DOOR_OPEN = Vector2i(7, 1)   # 열린 문 (통과 가능)
const OBJ_DOOR = OBJ_DOOR_CLOSED       # 기존 호환성

# 특수 및 건물 부착물 타일 (y=2)
const OBJ_FRIDGE = Vector2i(0, 2)
const OBJ_WINDOW = Vector2i(1, 2)        # 온전한 창문 (충돌 O, 차폐 X)
const OBJ_WINDOW_BROKEN = Vector2i(2, 2) # 깨진 창문 (충돌 X, 차폐 X, 통과 가능)
const OBJ_FENCE = Vector2i(3, 2)         # 울타리 (충돌 O, 차폐 X)
const OBJ_GATE = Vector2i(4, 2)          # 열린 게이트 (통과 가능)
const OBJ_LIGHT_SWITCH = Vector2i(5, 2)  # 조명 스위치 (벽 부착물)
const TILE_ROOF = Vector2i(6, 2)         # 건물 지붕 (실외에서 덮는 지붕 타일)

# 신규 실내 가구, 보안 잠금문 및 정밀 도로 마킹 타일 (y=3)
const OBJ_BED = Vector2i(0, 3)           # 침대 (의료품/의류 루팅)
const OBJ_DESK = Vector2i(1, 3)          # 책상/테이블 (귀중품/전자부품/열쇠 루팅)
const OBJ_SHELF = Vector2i(2, 3)         # 선반장/진열대 (식량/잡화 루팅)
const OBJ_DOOR_LOCKED = Vector2i(3, 3)   # 잠긴 보안 문 (열쇠/키카드 필요, 충돌+차폐)
const TILE_ROAD_LINE_H = Vector2i(4, 3)  # 가로 방향 차선 아스팔트
const TILE_CROSSWALK = Vector2i(5, 3)    # 교차로 횡단보도 아스팔트

# 호환성 별칭 (건물 내부 씬 등에서 참조)
const WALL_BRICK = OBJ_WALL
const OBJ_FURNITURE = OBJ_DESK

# 비트마스크 방향 & 가구 회전 상수
const DIR_N: int = 1
const DIR_E: int = 2
const DIR_S: int = 4
const DIR_W: int = 8

const FACE_S: int = 0
const FACE_N: int = 1
const FACE_E: int = 2
const FACE_W: int = 3

# 세로 방향 문/창문/게이트 (y=10) 및 4방향 회전 가구 (y=14..15)
const OBJ_DOOR_CLOSED_V = Vector2i(0, 10)
const OBJ_DOOR_OPEN_V = Vector2i(1, 10)
const OBJ_DOOR_LOCKED_V = Vector2i(2, 10)
const OBJ_WINDOW_V = Vector2i(3, 10)
const OBJ_WINDOW_BROKEN_V = Vector2i(4, 10)
const OBJ_GATE_V = Vector2i(5, 10)

const OBJ_FRIDGE_N = Vector2i(0, 14)
const OBJ_FRIDGE_E = Vector2i(1, 14)
const OBJ_FRIDGE_W = Vector2i(2, 14)
const OBJ_BED_N = Vector2i(3, 14)
const OBJ_BED_E = Vector2i(4, 14)
const OBJ_BED_W = Vector2i(5, 14)
const OBJ_DESK_N = Vector2i(6, 14)
const OBJ_DESK_E = Vector2i(7, 14)
const OBJ_DESK_W = Vector2i(0, 15)
const OBJ_SHELF_N = Vector2i(1, 15)
const OBJ_SHELF_E = Vector2i(2, 15)
const OBJ_SHELF_W = Vector2i(3, 15)

# 드롭 섀도우 & 환경 데코 오버레이 타일 (y=4, y=5)
const SHADOW_SE = Vector2i(0, 4)
const SHADOW_SOUTH = Vector2i(1, 4)
const SHADOW_EAST = Vector2i(2, 4)
const SHADOW_OVAL = Vector2i(3, 4)
const DECO_WEEDS = Vector2i(4, 4)
const DECO_CRACKS = Vector2i(5, 4)
const DECO_MANHOLE = Vector2i(6, 4)
const DECO_PUDDLE = Vector2i(7, 4)
const DECO_LEAVES = Vector2i(0, 5)
const DECO_RUBBLE = Vector2i(1, 5)
const DECO_STAIN = Vector2i(2, 5)
const DECO_DRAIN = Vector2i(3, 5)

func get_tileset() -> TileSet:
	if not tileset:
		_generate_procedural_tileset()
	return tileset

func _ready() -> void:
	_generate_procedural_tileset()

func _generate_procedural_tileset() -> void:
	var texture: Texture2D = null
	var pam = get_node_or_null("/root/PixelAssetManager")
	if pam and pam.has_method("get_canvas_texture"):
		texture = pam.get_canvas_texture("tiles/world_tileset")

	if texture == null:
		# 폴백: 8x16 절차적 픽셀 타일 아틀라스 이미지 + 자동 노멀맵 생성
		var img = Image.create_empty(8 * TILE_SIZE, 16 * TILE_SIZE, false, Image.FORMAT_RGBA8)
		var colors = {
			TILE_GRASS: Color(0.25, 0.5, 0.2),
			TILE_DIRT: Color(0.55, 0.45, 0.3),
			TILE_ROAD: Color(0.24, 0.25, 0.29),
			TILE_CONCRETE: Color(0.6, 0.6, 0.65),
			TILE_FLOOR_WOOD: Color(0.6, 0.45, 0.3),
			TILE_FLOOR_TILE: Color(0.7, 0.7, 0.7)
		}
		for coords in colors.keys():
			_fill_rect_noisy(img, coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, colors[coords])
		_draw_road_line(img, TILE_ROAD_LINE.x * TILE_SIZE, TILE_ROAD_LINE.y * TILE_SIZE, true)
		_draw_road_line(img, TILE_ROAD_LINE_H.x * TILE_SIZE, TILE_ROAD_LINE_H.y * TILE_SIZE, false)
		_draw_crosswalk(img, TILE_CROSSWALK.x * TILE_SIZE, TILE_CROSSWALK.y * TILE_SIZE)
		_draw_gravel(img, TILE_GRAVEL.x * TILE_SIZE, TILE_GRAVEL.y * TILE_SIZE)
		_fill_rect_noisy(img, TILE_WATER.x * TILE_SIZE, TILE_WATER.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Color(0.15, 0.35, 0.55))
		_draw_tree(img, OBJ_TREE.x * TILE_SIZE, OBJ_TREE.y * TILE_SIZE)
		_draw_rock(img, OBJ_ROCK.x * TILE_SIZE, OBJ_ROCK.y * TILE_SIZE)
		_fill_rect_noisy(img, OBJ_WALL.x * TILE_SIZE, OBJ_WALL.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Color(0.4, 0.3, 0.25))
		_draw_crate(img, OBJ_CRATE.x * TILE_SIZE, OBJ_CRATE.y * TILE_SIZE)
		_draw_barrel(img, OBJ_BARREL.x * TILE_SIZE, OBJ_BARREL.y * TILE_SIZE)
		_draw_debris(img, OBJ_DEBRIS.x * TILE_SIZE, OBJ_DEBRIS.y * TILE_SIZE)
		_draw_door_closed(img, OBJ_DOOR_CLOSED.x * TILE_SIZE, OBJ_DOOR_CLOSED.y * TILE_SIZE)
		_draw_door_open(img, OBJ_DOOR_OPEN.x * TILE_SIZE, OBJ_DOOR_OPEN.y * TILE_SIZE)
		_draw_fridge(img, OBJ_FRIDGE.x * TILE_SIZE, OBJ_FRIDGE.y * TILE_SIZE)
		_draw_window(img, OBJ_WINDOW.x * TILE_SIZE, OBJ_WINDOW.y * TILE_SIZE)
		_draw_broken_window(img, OBJ_WINDOW_BROKEN.x * TILE_SIZE, OBJ_WINDOW_BROKEN.y * TILE_SIZE)
		_draw_fence(img, OBJ_FENCE.x * TILE_SIZE, OBJ_FENCE.y * TILE_SIZE)
		_draw_gate(img, OBJ_GATE.x * TILE_SIZE, OBJ_GATE.y * TILE_SIZE)
		_draw_light_switch(img, OBJ_LIGHT_SWITCH.x * TILE_SIZE, OBJ_LIGHT_SWITCH.y * TILE_SIZE)
		_draw_roof(img, TILE_ROOF.x * TILE_SIZE, TILE_ROOF.y * TILE_SIZE)
		_draw_bed(img, OBJ_BED.x * TILE_SIZE, OBJ_BED.y * TILE_SIZE)
		_draw_desk(img, OBJ_DESK.x * TILE_SIZE, OBJ_DESK.y * TILE_SIZE)
		_draw_shelf(img, OBJ_SHELF.x * TILE_SIZE, OBJ_SHELF.y * TILE_SIZE)
		_draw_door_locked(img, OBJ_DOOR_LOCKED.x * TILE_SIZE, OBJ_DOOR_LOCKED.y * TILE_SIZE)
		_draw_fallback_shadows_decos(img)
		_draw_fallback_extended_tiles(img)
		if pam and pam.has_method("generate_normal_map_from_image") and pam.has_method("create_canvas_texture_from_images"):
			var norm_img: Image = pam.generate_normal_map_from_image(img, 2.4)
			texture = pam.create_canvas_texture_from_images(img, norm_img)
		else:
			texture = ImageTexture.create_from_image(img)

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

	# 바닥 타일 등록 (기본 + 확장 가로 횡단보도 / 곡선 차선 / 연석·코너 / 도로 갓길)
	var ground_coords: Array[Vector2i] = [
		TILE_GRASS, TILE_DIRT, TILE_ROAD, TILE_CONCRETE, TILE_FLOOR_WOOD, TILE_FLOOR_TILE,
		TILE_ROAD_LINE, TILE_ROAD_LINE_H, TILE_CROSSWALK, TILE_GRAVEL, TILE_WATER, TILE_CROSSWALK_H,
		TILE_ROAD_LINE_VB_TR, TILE_ROAD_LINE_VB_LB, TILE_ROAD_LINE_VB_TL, TILE_ROAD_LINE_VB_RB,
		TILE_ROAD_LINE_HB_LD, TILE_ROAD_LINE_HB_TR, TILE_ROAD_LINE_HB_LU, TILE_ROAD_LINE_HB_BR,
		TILE_SIDEWALK_CURB_N, TILE_SIDEWALK_CURB_E, TILE_SIDEWALK_CURB_S, TILE_SIDEWALK_CURB_W,
		TILE_SIDEWALK_CORNER_NW, TILE_SIDEWALK_CORNER_NE, TILE_SIDEWALK_CORNER_SE, TILE_SIDEWALK_CORNER_SW,
		TILE_SIDEWALK_DIAG_NW, TILE_SIDEWALK_DIAG_NE, TILE_SIDEWALK_DIAG_SE, TILE_SIDEWALK_DIAG_SW,
		TILE_ROAD_EDGE_W, TILE_ROAD_EDGE_E, TILE_ROAD_EDGE_N, TILE_ROAD_EDGE_S,
	]
	for coords in ground_coords:
		source.create_tile(coords)

	# 드롭 섀도우 & 환경 데코 타일 등록 (충돌/차폐 없음)
	for coords in [SHADOW_SE, SHADOW_SOUTH, SHADOW_EAST, SHADOW_OVAL, DECO_WEEDS, DECO_CRACKS, DECO_MANHOLE, DECO_PUDDLE, DECO_LEAVES, DECO_RUBBLE, DECO_STAIN, DECO_DRAIN]:
		source.create_tile(coords)

	tileset.add_source(source, 0)

	# 오브젝트 타일 등록 및 충돌체/차폐체 설정
	var all_objects: Array[Vector2i] = [
		OBJ_TREE, OBJ_ROCK, OBJ_WALL, OBJ_CRATE, OBJ_BARREL, OBJ_DEBRIS,
		OBJ_DOOR_CLOSED, OBJ_DOOR_OPEN, OBJ_FRIDGE,
		OBJ_WINDOW, OBJ_WINDOW_BROKEN, OBJ_FENCE, OBJ_GATE, OBJ_LIGHT_SWITCH, TILE_ROOF,
		OBJ_BED, OBJ_DESK, OBJ_SHELF, OBJ_DOOR_LOCKED,
		OBJ_DOOR_CLOSED_V, OBJ_DOOR_OPEN_V, OBJ_DOOR_LOCKED_V,
		OBJ_WINDOW_V, OBJ_WINDOW_BROKEN_V, OBJ_GATE_V,
		OBJ_FRIDGE_N, OBJ_FRIDGE_E, OBJ_FRIDGE_W,
		OBJ_BED_N, OBJ_BED_E, OBJ_BED_W,
		OBJ_DESK_N, OBJ_DESK_E, OBJ_DESK_W,
		OBJ_SHELF_N, OBJ_SHELF_E, OBJ_SHELF_W,
	]
	for m in range(16):
		var wm: Vector2i = get_wall_tile_for_mask(m)
		if wm != OBJ_WALL and not all_objects.has(wm):
			all_objects.append(wm)
		var fm: Vector2i = get_fence_tile_for_mask(m)
		if fm != OBJ_FENCE and not all_objects.has(fm):
			all_objects.append(fm)

	for coords in all_objects:
		source.create_tile(coords)
		var tile_data = source.get_tile_data(coords, 0)
		if tile_data:
			# 기본 꽉 찬 사각형 폴리곤
			var full_poly = PackedVector2Array([
				Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0),
				Vector2(-TILE_SIZE/2.0, TILE_SIZE/2.0)
			])

			# 충돌체 설정
			var has_collision = false
			var col_poly = full_poly

			if is_wall(coords) or is_door_closed(coords) or is_door_locked(coords) or coords == OBJ_CRATE or is_fridge(coords):
				has_collision = true
				col_poly = full_poly
			elif is_bed(coords) or is_desk(coords) or is_shelf(coords):
				has_collision = true
				col_poly = PackedVector2Array([
					Vector2(-TILE_SIZE*0.42, -TILE_SIZE*0.42),
					Vector2(TILE_SIZE*0.42, -TILE_SIZE*0.42),
					Vector2(TILE_SIZE*0.42, TILE_SIZE*0.42),
					Vector2(-TILE_SIZE*0.42, TILE_SIZE*0.42)
				])
			elif coords in [OBJ_TREE, OBJ_ROCK, OBJ_BARREL, OBJ_DEBRIS]:
				has_collision = true
				col_poly = PackedVector2Array([
					Vector2(-TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, TILE_SIZE*0.4),
					Vector2(-TILE_SIZE*0.4, TILE_SIZE*0.4)
				])
			elif is_window(coords) or is_fence(coords):
				# 창문과 울타리는 이동을 막음
				has_collision = true
				col_poly = full_poly
			# OBJ_DOOR_OPEN*, OBJ_WINDOW_BROKEN*, OBJ_GATE*, OBJ_LIGHT_SWITCH는 충돌 없음 (통과 가능)

			if has_collision:
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, col_poly)

			# 빛 차폐(Occluder) 등록 (빛을 막는 벽, 닫힌/잠긴 문, 상자, 바위, 냉장고, 높은 선반장 등)
			# 창문, 깨진 창문, 울타리, 게이트, 열린 문, 낮은 가구(침대/책상)는 빛을 통과시킴!
			if is_wall(coords) or is_door_closed(coords) or is_door_locked(coords) or coords in [OBJ_CRATE, OBJ_ROCK] or is_fridge(coords) or is_shelf(coords):
				var occluder = OccluderPolygon2D.new()
				occluder.polygon = full_poly
				tile_data.set_occluder(0, occluder)

			# OBJ_TREE 대체 타일(alt=1): ObjectLayer에서는 투명 처리하되 충돌체는 100% 보존하여 FoliageFxLayer 바람 셰이더와 이중 렌더링 방지
			if coords == OBJ_TREE:
				var alt_id: int = source.create_alternative_tile(OBJ_TREE, 1)
				var alt_data: TileData = source.get_tile_data(OBJ_TREE, alt_id)
				if alt_data:
					alt_data.modulate = Color(1.0, 1.0, 1.0, 0.0)
					if has_collision:
						alt_data.add_collision_polygon(0)
						alt_data.set_collision_polygon_points(0, 0, col_poly)

func _draw_fallback_shadows_decos(img: Image) -> void:
	for y in range(14):
		var a := int(130.0 * (1.0 - float(y) / 14.0))
		for x in range(TILE_SIZE):
			img.set_pixel(SHADOW_SOUTH.x * TILE_SIZE + x, SHADOW_SOUTH.y * TILE_SIZE + y, Color8(8, 10, 14, a))
	for x in range(14):
		var a := int(120.0 * (1.0 - float(x) / 14.0))
		for y in range(TILE_SIZE):
			img.set_pixel(SHADOW_EAST.x * TILE_SIZE + x, SHADOW_EAST.y * TILE_SIZE + y, Color8(8, 10, 14, a))
	for y in range(16):
		for x in range(16 - y):
			img.set_pixel(SHADOW_SE.x * TILE_SIZE + x, SHADOW_SE.y * TILE_SIZE + y, Color8(8, 10, 14, 105))
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var dx := (float(x) - 15.5) / 13.0
			var dy := (float(y) - 16.5) / 11.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(SHADOW_OVAL.x * TILE_SIZE + x, SHADOW_OVAL.y * TILE_SIZE + y, Color8(8, 10, 14, int(115.0 * (1.0 - d))))

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
	var cx = x + int(TILE_SIZE * 0.5)
	var cy = y + int(TILE_SIZE * 0.5)
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
	var cx = x + int(TILE_SIZE * 0.5)
	var cy = y + int(TILE_SIZE * 0.5)
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
	var cx = x + int(TILE_SIZE * 0.5)
	var cy = y + int(TILE_SIZE * 0.5)
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

func _draw_debris(img: Image, x: int, y: int) -> void:
	# 부서진 철조각이나 쓰레기 더미 잔해로 렌더링
	for i in range(8):
		var dx = randi_range(4, TILE_SIZE-4)
		var dy = randi_range(4, TILE_SIZE-4)
		var size = randi_range(2, 6)
		var col = Color(randf_range(0.3, 0.5), randf_range(0.3, 0.4), randf_range(0.3, 0.4))
		img.fill_rect(Rect2i(x + dx, y + dy, size, size), col)

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
					if ix >= 7 and ix <= TILE_SIZE - 7 and iy == int(TILE_SIZE * 0.5):
						c = Color(0.4, 0.4, 0.4)
				
				img.set_pixel(px, py, c)

func _draw_gravel(img: Image, x: int, y: int) -> void:
	# 흙 베이스
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.45, 0.4, 0.35))
	# 자갈 돌멩이들
	for i in range(12):
		var gx = randi_range(2, TILE_SIZE - 5)
		var gy = randi_range(2, TILE_SIZE - 5)
		var gw = randi_range(2, 4)
		var gh = randi_range(2, 4)
		var gc = Color(randf_range(0.5, 0.7), randf_range(0.5, 0.65), randf_range(0.5, 0.6))
		img.fill_rect(Rect2i(x + gx, y + gy, gw, gh), gc)

func _draw_door_closed(img: Image, x: int, y: int) -> void:
	# 문틀 및 닫힌 나무 문
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0.45, 0.25, 0.12)
			# 테두리 문틀
			if ix < 3 or ix > TILE_SIZE - 4 or iy < 3 or iy > TILE_SIZE - 4:
				c = Color(0.25, 0.15, 0.08)
			# 나무 판자 세로 홈
			elif ix % 7 == 0:
				c = Color(0.35, 0.2, 0.1)
			# 손잡이 (황동)
			if ix >= TILE_SIZE - 8 and ix <= TILE_SIZE - 6 and iy >= int(TILE_SIZE * 0.5) - 2 and iy <= int(TILE_SIZE * 0.5) + 2:
				c = Color(0.85, 0.7, 0.2)
			img.set_pixel(x + ix, y + iy, c)

func _draw_door_open(img: Image, x: int, y: int) -> void:
	# 열린 문 (문틀은 열려있고 바닥이 보이며 문짝이 한쪽에 젖혀짐)
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.6, 0.45, 0.3)) # 통로 바닥
	# 문틀 가장자리
	for iy in range(TILE_SIZE):
		img.set_pixel(x, y + iy, Color(0.25, 0.15, 0.08))
		img.set_pixel(x + TILE_SIZE - 1, y + iy, Color(0.25, 0.15, 0.08))
	# 젖혀진 문짝 (좌측에 수직으로 붙어있음)
	for iy in range(4, TILE_SIZE - 4):
		for ix in range(1, 5):
			img.set_pixel(x + ix, y + iy, Color(0.45, 0.25, 0.12))

func _draw_window(img: Image, x: int, y: int) -> void:
	# 창틀 및 반투명 푸른 유리
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0.3, 0.5, 0.7, 0.6) # 유리
			# 창틀 (벽체와 일치하는 나무/콘크리트 틀)
			if ix < 3 or ix > TILE_SIZE - 4 or iy < 3 or iy > TILE_SIZE - 4:
				c = Color(0.35, 0.25, 0.2)
			# 십자 창살
			elif ix == int(TILE_SIZE * 0.5) or ix == int(TILE_SIZE * 0.5) - 1 or iy == int(TILE_SIZE * 0.5) or iy == int(TILE_SIZE * 0.5) - 1:
				c = Color(0.35, 0.25, 0.2)
			# 유리 하이라이트
			elif (ix + iy) % 8 == 0 and ix > 4 and ix < TILE_SIZE - 5:
				c = Color(0.6, 0.8, 1.0, 0.85)
			img.set_pixel(x + ix, y + iy, c)

func _draw_broken_window(img: Image, x: int, y: int) -> void:
	# 깨진 창문 (창틀 일부만 남고 유리 파편과 구멍)
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.2, 0.2, 0.2, 0.3)) # 빈 공간
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			# 부서진 창틀
			if ix < 3 or ix > TILE_SIZE - 4 or iy < 3 or iy > TILE_SIZE - 4:
				img.set_pixel(x + ix, y + iy, Color(0.35, 0.25, 0.2))
			# 가장자리에 뾰족하게 남은 유리 조각들
			elif (ix < 7 and (iy < 8 or iy > TILE_SIZE - 9)) or (ix > TILE_SIZE - 8 and iy < 10):
				img.set_pixel(x + ix, y + iy, Color(0.4, 0.65, 0.85, 0.8))

func _draw_fence(img: Image, x: int, y: int) -> void:
	# 나무 울타리 (투명 배경에 말뚝과 가로목)
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0, 0, 0, 0)
			# 가로 연결목 2줄
			if (iy >= 8 and iy <= 11) or (iy >= 20 and iy <= 23):
				c = Color(0.5, 0.35, 0.2)
			# 세로 말뚝 3개
			if (ix >= 4 and ix <= 8) or (ix >= 14 and ix <= 18) or (ix >= 24 and ix <= 28):
				if iy >= 4:
					c = Color(0.58, 0.4, 0.22)
					# 뾰족한 상단
					if iy < 8 and (ix == 4 or ix == 8 or ix == 14 or ix == 18 or ix == 24 or ix == 28):
						c = Color(0, 0, 0, 0)
			if c.a > 0:
				img.set_pixel(x + ix, y + iy, c)

func _draw_gate(img: Image, x: int, y: int) -> void:
	# 열린 게이트 (양쪽 기둥만 있고 중앙은 개방)
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0, 0, 0, 0)
			# 좌측 기둥, 우측 기둥
			if (ix <= 6 or ix >= TILE_SIZE - 7) and iy >= 2:
				c = Color(0.45, 0.3, 0.15)
				if ix == 0 or ix == 6 or ix == TILE_SIZE - 7 or ix == TILE_SIZE - 1:
					c = Color(0.3, 0.2, 0.1)
			if c.a > 0:
				img.set_pixel(x + ix, y + iy, c)

func _draw_light_switch(img: Image, x: int, y: int) -> void:
	# 벽면의 조명 스위치 박스
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0, 0, 0, 0)
			if ix >= 10 and ix <= 22 and iy >= 8 and iy <= 24:
				c = Color(0.85, 0.85, 0.8) # 회색 플레이트
				if ix == 10 or ix == 22 or iy == 8 or iy == 24:
					c = Color(0.3, 0.3, 0.3)
				# 스위치 레버 (중앙)
				elif ix >= 14 and ix <= 18 and iy >= 13 and iy <= 19:
					c = Color(0.2, 0.6, 0.2) # ON 느낌 녹색 핀
			if c.a > 0:
				img.set_pixel(x + ix, y + iy, c)

func _draw_roof(img: Image, x: int, y: int) -> void:
	# 짙은 다크 네이비/차콜 아스팔트 기와 지붕 텍스처
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.18, 0.2, 0.24))
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			# 가로 슁글 라인 (8픽셀마다)
			if iy % 8 == 0:
				img.set_pixel(x + ix, y + iy, Color(0.12, 0.13, 0.16))
			# 세로 기와 틈새 (지그재그)
			var row = int(float(iy) / 8.0)
			var offset = (row % 2) * 8
			if (ix + offset) % 16 == 0:
				img.set_pixel(x + ix, y + iy, Color(0.1, 0.11, 0.14))
			# 약간의 밝은 하이라이트 라인
			if iy % 8 == 1:
				img.set_pixel(x + ix, y + iy, Color(0.24, 0.26, 0.3))

func _draw_road_line(img: Image, x: int, y: int, is_vertical: bool) -> void:
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.24, 0.25, 0.29))
	var line_col = Color(0.88, 0.78, 0.18)
	var edge_col = Color(0.72, 0.62, 0.14)
	if is_vertical:
		for iy in range(3, TILE_SIZE - 3):
			img.set_pixel(x + TILE_SIZE - 4, y + iy, edge_col)
			img.set_pixel(x + TILE_SIZE - 3, y + iy, line_col)
			img.set_pixel(x + TILE_SIZE - 2, y + iy, line_col)
	else:
		for ix in range(3, TILE_SIZE - 3):
			img.set_pixel(x + ix, y + TILE_SIZE - 4, edge_col)
			img.set_pixel(x + ix, y + TILE_SIZE - 3, line_col)
			img.set_pixel(x + ix, y + TILE_SIZE - 2, line_col)

func _draw_crosswalk(img: Image, x: int, y: int) -> void:
	_fill_rect_noisy(img, x, y, TILE_SIZE, TILE_SIZE, Color(0.24, 0.25, 0.29))
	var stripe_col = Color(0.82, 0.84, 0.86, 0.92)
	for s in [4, 12, 20, 27]:
		for iy in range(4, TILE_SIZE - 4):
			for dx in range(3):
				if s + dx < TILE_SIZE - 2:
					img.set_pixel(x + s + dx, y + iy, stripe_col)

func _draw_bed(img: Image, x: int, y: int) -> void:
	for iy in range(3, TILE_SIZE - 3):
		for ix in range(5, TILE_SIZE - 5):
			var c = Color(0.32, 0.45, 0.62) # 침구 담요 (차분한 네이비 블루)
			if ix == 5 or ix == TILE_SIZE - 6 or iy == 3 or iy == TILE_SIZE - 4:
				c = Color(0.38, 0.24, 0.14) # 원목 프레임
			elif iy <= 10 and ix >= 7 and ix <= TILE_SIZE - 8:
				c = Color(0.90, 0.90, 0.88) # 흰색 베개
			elif iy == 11:
				c = Color(0.75, 0.78, 0.82) # 시트 접힌 부분
			img.set_pixel(x + ix, y + iy, c)

func _draw_desk(img: Image, x: int, y: int) -> void:
	for iy in range(5, TILE_SIZE - 5):
		for ix in range(3, TILE_SIZE - 3):
			var c = Color(0.52, 0.36, 0.22) # 원목 책상 상판
			if ix == 3 or ix == TILE_SIZE - 4 or iy == 5 or iy == TILE_SIZE - 6:
				c = Color(0.28, 0.18, 0.10) # 테두리
			elif ix == int(TILE_SIZE * 0.62):
				c = Color(0.34, 0.22, 0.12) # 서랍 구분선
			elif ix >= 7 and ix <= 14 and iy >= 9 and iy <= 16:
				c = Color(0.86, 0.85, 0.78) # 놓여있는 서류 용지
			elif ix >= TILE_SIZE - 9 and ix <= TILE_SIZE - 7 and iy == TILE_SIZE - 7:
				c = Color(0.85, 0.72, 0.25) # 황동 서랍 손잡이
			img.set_pixel(x + ix, y + iy, c)

func _draw_shelf(img: Image, x: int, y: int) -> void:
	for iy in range(4, TILE_SIZE - 4):
		for ix in range(3, TILE_SIZE - 3):
			var c = Color(0.36, 0.38, 0.42) # 철제/목재 선반 프레임
			if ix == 3 or ix == TILE_SIZE - 4 or iy == 4 or iy == TILE_SIZE - 5 or iy == 12 or iy == 20:
				c = Color(0.22, 0.24, 0.28) # 선반 칸막이
			else:
				if (ix >= 6 and ix <= 11) and (iy >= 6 and iy <= 10):
					c = Color(0.75, 0.32, 0.22) # 붉은 상자/통조림
				elif (ix >= 14 and ix <= 21) and (iy >= 6 and iy <= 10):
					c = Color(0.28, 0.58, 0.36) # 녹색 탄약/구급팩
				elif (ix >= 7 and ix <= 16) and (iy >= 14 and iy <= 18):
					c = Color(0.68, 0.56, 0.32) # 종이 박스
				elif (ix >= 19 and ix <= 25) and (iy >= 14 and iy <= 18):
					c = Color(0.32, 0.52, 0.78) # 생수/물품
			img.set_pixel(x + ix, y + iy, c)

func _draw_door_locked(img: Image, x: int, y: int) -> void:
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var c = Color(0.22, 0.25, 0.30) # 중장갑 강철 보안문
			if ix < 3 or ix > TILE_SIZE - 4 or iy < 3 or iy > TILE_SIZE - 4:
				c = Color(0.12, 0.14, 0.18) # 강철 문틀
			elif iy >= 6 and iy <= 9:
				# 적색/황색 보안 경고 스트라이프
				c = Color(0.85, 0.18, 0.18) if floori(float(ix + iy) / 3.0) % 2 == 0 else Color(0.88, 0.72, 0.15)
			elif ix >= TILE_SIZE - 10 and ix <= TILE_SIZE - 5 and iy >= 13 and iy <= 20:
				# 전자식 키패드 / 황금 자물쇠 인디케이터
				c = Color(0.95, 0.78, 0.20)
				if ix >= TILE_SIZE - 8 and ix <= TILE_SIZE - 7 and iy >= 15 and iy <= 16:
					c = Color(1.0, 0.15, 0.15) # 적색 LOCKED LED
			img.set_pixel(x + ix, y + iy, c)

func _draw_fallback_extended_tiles(img: Image) -> void:
	var copy_pairs := {
		TILE_CROSSWALK_H: TILE_CROSSWALK,
		OBJ_DOOR_CLOSED_V: OBJ_DOOR_CLOSED,
		OBJ_DOOR_OPEN_V: OBJ_DOOR_OPEN,
		OBJ_DOOR_LOCKED_V: OBJ_DOOR_LOCKED,
		OBJ_WINDOW_V: OBJ_WINDOW,
		OBJ_WINDOW_BROKEN_V: OBJ_WINDOW_BROKEN,
		OBJ_GATE_V: OBJ_GATE,
		OBJ_FRIDGE_N: OBJ_FRIDGE,
		OBJ_FRIDGE_E: OBJ_FRIDGE,
		OBJ_FRIDGE_W: OBJ_FRIDGE,
		OBJ_BED_N: OBJ_BED,
		OBJ_BED_E: OBJ_BED,
		OBJ_BED_W: OBJ_BED,
		OBJ_DESK_N: OBJ_DESK,
		OBJ_DESK_E: OBJ_DESK,
		OBJ_DESK_W: OBJ_DESK,
		OBJ_SHELF_N: OBJ_SHELF,
		OBJ_SHELF_E: OBJ_SHELF,
		OBJ_SHELF_W: OBJ_SHELF,
	}
	for dst in [TILE_ROAD_LINE_VB_TR, TILE_ROAD_LINE_VB_LB, TILE_ROAD_LINE_VB_TL, TILE_ROAD_LINE_VB_RB,
				TILE_ROAD_LINE_HB_LD, TILE_ROAD_LINE_HB_TR, TILE_ROAD_LINE_HB_LU, TILE_ROAD_LINE_HB_BR,
				TILE_ROAD_EDGE_W, TILE_ROAD_EDGE_E, TILE_ROAD_EDGE_N, TILE_ROAD_EDGE_S]:
		copy_pairs[dst] = TILE_ROAD
	for dst in [TILE_SIDEWALK_CURB_N, TILE_SIDEWALK_CURB_E, TILE_SIDEWALK_CURB_S, TILE_SIDEWALK_CURB_W,
				TILE_SIDEWALK_CORNER_NW, TILE_SIDEWALK_CORNER_NE, TILE_SIDEWALK_CORNER_SE, TILE_SIDEWALK_CORNER_SW,
				TILE_SIDEWALK_DIAG_NW, TILE_SIDEWALK_DIAG_NE, TILE_SIDEWALK_DIAG_SE, TILE_SIDEWALK_DIAG_SW]:
		copy_pairs[dst] = TILE_CONCRETE
	for m in range(16):
		var wm := get_wall_tile_for_mask(m)
		if wm != OBJ_WALL:
			copy_pairs[wm] = OBJ_WALL
		var fm := get_fence_tile_for_mask(m)
		if fm != OBJ_FENCE:
			copy_pairs[fm] = OBJ_FENCE
	var src_img: Image = img.duplicate()
	for dst in copy_pairs.keys():
		var src: Vector2i = copy_pairs[dst]
		img.blit_rect(src_img, Rect2i(src * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE)), dst * TILE_SIZE)

# ==========================================================
# 방향/코너/비트마스크 판별 및 상태 전이 유틸리티 API
# ==========================================================
func get_wall_tile_for_mask(mask: int) -> Vector2i:
	var m := clampi(mask, 0, 15)
	if m == (DIR_E | DIR_W):
		return OBJ_WALL
	return Vector2i(m % 8, 6 + floori(float(m) / 8.0))

func get_fence_tile_for_mask(mask: int) -> Vector2i:
	var m := clampi(mask, 0, 15)
	if m == (DIR_E | DIR_W):
		return OBJ_FENCE
	return Vector2i(m % 8, 8 + floori(float(m) / 8.0))

func is_wall(coords: Vector2i) -> bool:
	return coords == OBJ_WALL or (coords.y in [6, 7] and coords.x >= 0 and coords.x < 8 and coords != Vector2i(2, 7))

func is_fence(coords: Vector2i) -> bool:
	return coords == OBJ_FENCE or (coords.y in [8, 9] and coords.x >= 0 and coords.x < 8 and coords != Vector2i(2, 9))

func is_gate(coords: Vector2i) -> bool:
	return coords == OBJ_GATE or coords == OBJ_GATE_V

func is_door_closed(coords: Vector2i) -> bool:
	return coords == OBJ_DOOR_CLOSED or coords == OBJ_DOOR_CLOSED_V

func is_door_open(coords: Vector2i) -> bool:
	return coords == OBJ_DOOR_OPEN or coords == OBJ_DOOR_OPEN_V

func is_door_locked(coords: Vector2i) -> bool:
	return coords == OBJ_DOOR_LOCKED or coords == OBJ_DOOR_LOCKED_V

func is_window(coords: Vector2i) -> bool:
	return coords == OBJ_WINDOW or coords == OBJ_WINDOW_V

func is_window_broken(coords: Vector2i) -> bool:
	return coords == OBJ_WINDOW_BROKEN or coords == OBJ_WINDOW_BROKEN_V

func is_fridge(coords: Vector2i) -> bool:
	return coords == OBJ_FRIDGE or coords == OBJ_FRIDGE_N or coords == OBJ_FRIDGE_E or coords == OBJ_FRIDGE_W

func is_bed(coords: Vector2i) -> bool:
	return coords == OBJ_BED or coords == OBJ_BED_N or coords == OBJ_BED_E or coords == OBJ_BED_W

func is_desk(coords: Vector2i) -> bool:
	return coords == OBJ_DESK or coords == OBJ_DESK_N or coords == OBJ_DESK_E or coords == OBJ_DESK_W

func is_shelf(coords: Vector2i) -> bool:
	return coords == OBJ_SHELF or coords == OBJ_SHELF_N or coords == OBJ_SHELF_E or coords == OBJ_SHELF_W

func is_structure_wall_line(coords: Vector2i) -> bool:
	return is_wall(coords) or is_door_closed(coords) or is_door_open(coords) or is_door_locked(coords) or is_window(coords) or is_window_broken(coords)

func is_structure_shadow_caster(coords: Vector2i) -> bool:
	return is_structure_wall_line(coords) or is_fence(coords) or is_gate(coords)

func casts_oval_shadow(coords: Vector2i) -> bool:
	return coords in [OBJ_CRATE, OBJ_BARREL, OBJ_DEBRIS, OBJ_ROCK] or is_fridge(coords) or is_bed(coords) or is_desk(coords) or is_shelf(coords)

func is_road_asphalt(coords: Vector2i) -> bool:
	return coords in [
		TILE_ROAD, TILE_ROAD_LINE, TILE_ROAD_LINE_H, TILE_CROSSWALK, TILE_CROSSWALK_H,
		TILE_ROAD_LINE_VB_TR, TILE_ROAD_LINE_VB_LB, TILE_ROAD_LINE_VB_TL, TILE_ROAD_LINE_VB_RB,
		TILE_ROAD_LINE_HB_LD, TILE_ROAD_LINE_HB_TR, TILE_ROAD_LINE_HB_LU, TILE_ROAD_LINE_HB_BR,
		TILE_ROAD_EDGE_W, TILE_ROAD_EDGE_E, TILE_ROAD_EDGE_N, TILE_ROAD_EDGE_S,
	]

func is_sidewalk_tile(coords: Vector2i) -> bool:
	return coords in [
		TILE_CONCRETE,
		TILE_SIDEWALK_CURB_N, TILE_SIDEWALK_CURB_E, TILE_SIDEWALK_CURB_S, TILE_SIDEWALK_CURB_W,
		TILE_SIDEWALK_CORNER_NW, TILE_SIDEWALK_CORNER_NE, TILE_SIDEWALK_CORNER_SE, TILE_SIDEWALK_CORNER_SW,
		TILE_SIDEWALK_DIAG_NW, TILE_SIDEWALK_DIAG_NE, TILE_SIDEWALK_DIAG_SE, TILE_SIDEWALK_DIAG_SW,
	]

func is_vertical_variant(coords: Vector2i) -> bool:
	return coords in [OBJ_DOOR_CLOSED_V, OBJ_DOOR_OPEN_V, OBJ_DOOR_LOCKED_V, OBJ_WINDOW_V, OBJ_WINDOW_BROKEN_V, OBJ_GATE_V]

func get_door_closed_tile(is_vertical: bool) -> Vector2i:
	return OBJ_DOOR_CLOSED_V if is_vertical else OBJ_DOOR_CLOSED

func get_door_open_tile(is_vertical: bool) -> Vector2i:
	return OBJ_DOOR_OPEN_V if is_vertical else OBJ_DOOR_OPEN

func get_door_locked_tile(is_vertical: bool) -> Vector2i:
	return OBJ_DOOR_LOCKED_V if is_vertical else OBJ_DOOR_LOCKED

func get_window_tile(is_vertical: bool) -> Vector2i:
	return OBJ_WINDOW_V if is_vertical else OBJ_WINDOW

func get_gate_tile(is_vertical: bool) -> Vector2i:
	return OBJ_GATE_V if is_vertical else OBJ_GATE

func get_window_broken_tile(coords: Vector2i) -> Vector2i:
	return OBJ_WINDOW_BROKEN_V if coords == OBJ_WINDOW_V or coords == OBJ_WINDOW_BROKEN_V else OBJ_WINDOW_BROKEN

func get_toggled_door_tile(coords: Vector2i) -> Vector2i:
	if coords == OBJ_DOOR_CLOSED:
		return OBJ_DOOR_OPEN
	if coords == OBJ_DOOR_CLOSED_V:
		return OBJ_DOOR_OPEN_V
	if coords == OBJ_DOOR_OPEN:
		return OBJ_DOOR_CLOSED
	if coords == OBJ_DOOR_OPEN_V:
		return OBJ_DOOR_CLOSED_V
	if coords == OBJ_DOOR_LOCKED:
		return OBJ_DOOR_OPEN
	if coords == OBJ_DOOR_LOCKED_V:
		return OBJ_DOOR_OPEN_V
	return coords

func get_unlocked_door_tile(coords: Vector2i) -> Vector2i:
	return OBJ_DOOR_OPEN_V if coords == OBJ_DOOR_LOCKED_V else OBJ_DOOR_OPEN

func get_furniture_variant(base_coords: Vector2i, facing: int) -> Vector2i:
	if facing == FACE_S:
		return base_coords
	if base_coords == OBJ_FRIDGE:
		match facing:
			FACE_N: return OBJ_FRIDGE_N
			FACE_E: return OBJ_FRIDGE_E
			FACE_W: return OBJ_FRIDGE_W
	elif base_coords == OBJ_BED:
		match facing:
			FACE_N: return OBJ_BED_N
			FACE_E: return OBJ_BED_E
			FACE_W: return OBJ_BED_W
	elif base_coords == OBJ_DESK:
		match facing:
			FACE_N: return OBJ_DESK_N
			FACE_E: return OBJ_DESK_E
			FACE_W: return OBJ_DESK_W
	elif base_coords == OBJ_SHELF:
		match facing:
			FACE_N: return OBJ_SHELF_N
			FACE_E: return OBJ_SHELF_E
			FACE_W: return OBJ_SHELF_W
	return base_coords

func choose_door_is_vertical(n_wall: bool, e_wall: bool, s_wall: bool, w_wall: bool) -> bool:
	var v_score: int = int(n_wall) + int(s_wall)
	var h_score: int = int(e_wall) + int(w_wall)
	return v_score > h_score

func choose_furniture_facing(n_wall: int, e_wall: int, s_wall: int, w_wall: int, n_open: bool, e_open: bool, s_open: bool, w_open: bool) -> int:
	# 각 방향 후보 [facing, back_wall_strength(0/1/2), front_open, front_wall_strength]
	var candidates := [
		[FACE_S, n_wall, s_open, s_wall],
		[FACE_N, s_wall, n_open, n_wall],
		[FACE_E, w_wall, e_open, e_wall],
		[FACE_W, e_wall, w_open, w_wall],
	]
	var best_facing: int = FACE_S
	var best_score: int = -99999
	for cand in candidates:
		var back_str: int = cand[1]
		var f_open: bool = cand[2]
		var f_wall: int = cand[3]
		var score: int = back_str * 10
		if f_open:
			score += 6
		elif f_wall > 0:
			score -= 10
		else:
			score -= 4
		if score > best_score:
			best_score = score
			best_facing = cand[0]
	return best_facing
