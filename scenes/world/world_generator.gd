# res://scenes/world/world_generator.gd
class_name WorldGenerator
extends RefCounted

const CHUNK_SIZE: int = 16

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var rng: RandomNumberGenerator

func _init(seed_value: int) -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = seed_value + 1
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.frequency = 0.02
	
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

func get_biome(wx: int, wy: int) -> String:
	var dist = sqrt(wx * wx + wy * wy)
	var noise_val = biome_noise.get_noise_2d(wx, wy)
	
	if dist < 30:
		return "residential"
	elif dist < 120:
		if noise_val > 0.4: return "military"
		elif noise_val > 0.1: return "industrial"
		elif noise_val > -0.2: return "commercial"
		else: return "residential"
	else:
		if noise_val > 0.2: return "military"
		else: return "forest"

func is_road(wx: int, wy: int) -> bool:
	var biome = get_biome(wx, wy)
	if biome == "forest": return false
	
	# 격자형 도로망
	# 40칸마다 메인 도로, 20칸마다 보조 도로
	if abs(wx) % 40 < 4 or abs(wy) % 40 < 4:
		return true
	if (abs(wx) % 20 < 2 or abs(wy) % 20 < 2) and biome != "residential":
		return true
		
	return false

func is_building_area(wx: int, wy: int) -> bool:
	var biome = get_biome(wx, wy)
	if biome == "forest": return false
	
	# 도로에서 조금 떨어진 곳에 건물 배치
	var dx = abs(wx) % 20
	var dy = abs(wy) % 20
	
	if dx > 4 and dx < 16 and dy > 4 and dy < 16:
		return true
		
	return false

func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var objects: Array[Vector2i] = []
	var entities: Array[Dictionary] = [] # 엔티티(프리팹) 스폰 리스트
	
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	objects.resize(CHUNK_SIZE * CHUNK_SIZE)
	
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			
			var biome = get_biome(wx, wy)
			var road = is_road(wx, wy)
			var building = is_building_area(wx, wy)
			
			var tile_coords = TileManager.TILE_GRASS
			var obj_coords = Vector2i(-1, -1)
			
			# 바닥 결정
			if road:
				tile_coords = TileManager.TILE_ROAD
			elif building:
				tile_coords = TileManager.TILE_CONCRETE
			else:
				var n_val = noise.get_noise_2d(wx, wy)
				if n_val > 0.2:
					tile_coords = TileManager.TILE_DIRT
				elif biome == "military" or biome == "industrial":
					tile_coords = TileManager.TILE_CONCRETE
					
			# 도로 중앙선 포인트
			if road and (abs(wx) % 20 == 0 or abs(wy) % 20 == 0):
				tile_coords = TileManager.TILE_ROAD_LINE
				
			# 오브젝트 결정
			if building:
				var dx = abs(wx) % 20
				var dy = abs(wy) % 20
				# 출입문은 남쪽(dy == 15, dx == 10) 외벽에 1개 배치
				if dy == 15 and dx == 10:
					obj_coords = TileManager.OBJ_DOOR
				else:
					obj_coords = TileManager.OBJ_WALL
			elif road:
				# 도로 위 버려진 차 엔티티 스폰 (확률 낮춤, 차량 크기가 커졌으므로)
				if rng.randf() < 0.005 and tile_coords != TileManager.TILE_ROAD_LINE:
					# 도로의 방향 파악 (세로 도로인지 가로 도로인지)
					var rot = 0.0
					if abs(wx) % 40 < 4 or (abs(wx) % 20 < 2 and biome != "residential"):
						# 세로 도로
						rot = 0.0 if rng.randf() > 0.5 else PI
					else:
						# 가로 도로
						rot = PI / 2.0 if rng.randf() > 0.5 else -PI / 2.0
						
					# 살짝 삐뚤어지게
					rot += rng.randf_range(-0.15, 0.15)
					
					entities.append({
						"type": "car",
						"wx": wx,
						"wy": wy,
						"rotation": rot
					})
			else:
				# 자연 프랍
				if rng.randf() < 0.1:
					if rng.randf() > 0.3:
						obj_coords = TileManager.OBJ_TREE
					else:
						obj_coords = TileManager.OBJ_ROCK
						
			# 은신처 (0,0 근처 안전지대)
			if abs(wx) < 10 and abs(wy) < 10:
				if not building and not road:
					obj_coords = Vector2i(-1, -1) # 안전지대는 장애물/프랍 최소화
					tile_coords = TileManager.TILE_GRASS
			
			tiles[idx] = tile_coords
			objects[idx] = obj_coords
			
	return {
		"tiles": tiles,
		"objects": objects,
		"entities": entities
	}
