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

const OBJ_TREE = Vector2i(0, 1)
const OBJ_ROCK = Vector2i(1, 1)
const OBJ_WALL = Vector2i(2, 1)
const OBJ_CRATE = Vector2i(3, 1)

func _ready() -> void:
	_generate_procedural_tileset()

func _generate_procedural_tileset() -> void:
	# 4x2 타일 아틀라스 이미지 생성 (가로 4칸, 세로 2칸)
	var img = Image.create_empty(4 * TILE_SIZE, 2 * TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	# 색상 정의
	var colors = {
		TILE_GRASS: Color(0.25, 0.5, 0.2),
		TILE_DIRT: Color(0.55, 0.45, 0.3),
		TILE_ROAD: Color(0.3, 0.3, 0.35),
		TILE_CONCRETE: Color(0.6, 0.6, 0.65),
	}
	
	# 바닥 타일 그리기 (y=0)
	for coords in colors.keys():
		_fill_rect(img, coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, colors[coords])
		
	# 오브젝트 타일 그리기 (y=1) - 투명 배경에 도형 그리기
	_draw_tree(img, OBJ_TREE.x * TILE_SIZE, OBJ_TREE.y * TILE_SIZE)
	_draw_rock(img, OBJ_ROCK.x * TILE_SIZE, OBJ_ROCK.y * TILE_SIZE)
	_fill_rect(img, OBJ_WALL.x * TILE_SIZE, OBJ_WALL.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Color(0.4, 0.3, 0.25)) # 벽
	_draw_crate(img, OBJ_CRATE.x * TILE_SIZE, OBJ_CRATE.y * TILE_SIZE) # 상자
	
	var texture = ImageTexture.create_from_image(img)
	
	# TileSet 및 Source 생성
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# 물리 레이어 추가 (충돌체용)
	tileset.add_physics_layer(0)
	
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# 바닥 타일 등록
	for coords in colors.keys():
		source.create_tile(coords)
		
	tileset.add_source(source, 0)
		
	# 오브젝트 타일 등록 및 충돌체 설정
	var objects = [OBJ_TREE, OBJ_ROCK, OBJ_WALL, OBJ_CRATE]
	for coords in objects:
		source.create_tile(coords)
		var tile_data = source.get_tile_data(coords, 0)
		if tile_data:
			# 꽉 차는 사각형 충돌체 생성
			var poly = PackedVector2Array([
				Vector2(-TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, -TILE_SIZE/2.0),
				Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0),
				Vector2(-TILE_SIZE/2.0, TILE_SIZE/2.0)
			])
			
			# 나무나 바위는 충돌 크기를 약간 줄임
			if coords == OBJ_TREE or coords == OBJ_ROCK:
				poly = PackedVector2Array([
					Vector2(-TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, -TILE_SIZE*0.4),
					Vector2(TILE_SIZE*0.4, TILE_SIZE*0.4),
					Vector2(-TILE_SIZE*0.4, TILE_SIZE*0.4)
				])
				
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, poly)

# ==========================================================
# 이미지 드로잉 헬퍼
# ==========================================================
func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for iy in range(h):
		for ix in range(w):
			img.set_pixel(x + ix, y + iy, color)

func _draw_tree(img: Image, x: int, y: int) -> void:
	var cx = x + TILE_SIZE / 2
	var cy = y + TILE_SIZE / 2
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var dx = x + ix - cx
			var dy = y + iy - cy
			var dist = sqrt(dx*dx + dy*dy)
			if dist < TILE_SIZE * 0.45:
				img.set_pixel(x + ix, y + iy, Color(0.15, 0.35, 0.15, 0.9))
			elif dist < TILE_SIZE * 0.2:
				img.set_pixel(x + ix, y + iy, Color(0.35, 0.25, 0.15))

func _draw_rock(img: Image, x: int, y: int) -> void:
	var cx = x + TILE_SIZE / 2
	var cy = y + TILE_SIZE / 2
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			var dx = abs(x + ix - cx)
			var dy = abs(y + iy - cy)
			if dx < TILE_SIZE * 0.4 and dy < TILE_SIZE * 0.35:
				img.set_pixel(x + ix, y + iy, Color(0.4, 0.4, 0.45))

func _draw_crate(img: Image, x: int, y: int) -> void:
	var border = 3
	for iy in range(TILE_SIZE):
		for ix in range(TILE_SIZE):
			if ix < border or ix > TILE_SIZE-1-border or iy < border or iy > TILE_SIZE-1-border:
				img.set_pixel(x + ix, y + iy, Color(0.3, 0.2, 0.1))
			else:
				img.set_pixel(x + ix, y + iy, Color(0.5, 0.35, 0.2))
