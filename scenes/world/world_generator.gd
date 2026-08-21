# res://scenes/world/world_generator.gd
class_name WorldGenerator
extends RefCounted

## 비선형 도로망, 12종 건물 프리셋, 울타리/마당, 자갈길 연결을 지원하는 절차적 월드 생성기

const CHUNK_SIZE: int = 16
const LOT_SIZE: int = 32 # 건물 필지 그리드 크기

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var road_warp_noise: FastNoiseLite
var rng_seed: int

func _init(seed_value: int) -> void:
	rng_seed = seed_value
	
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = seed_value + 1
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.frequency = 0.015
	
	road_warp_noise = FastNoiseLite.new()
	road_warp_noise.seed = seed_value + 2
	road_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	road_warp_noise.frequency = 0.03

# ==========================================================
# 바이옴 판정
# ==========================================================
func get_biome(wx: int, wy: int) -> String:
	var dist = sqrt(wx * wx + wy * wy)
	var noise_val = biome_noise.get_noise_2d(wx, wy)
	
	if dist < 35:
		return "residential" # 스폰 중심 주거지
	elif dist < 140:
		if noise_val > 0.35: return "military"
		elif noise_val > 0.1: return "industrial"
		elif noise_val > -0.15: return "commercial"
		else: return "residential"
	else:
		if noise_val > 0.3: return "military"
		elif noise_val > 0.0: return "industrial"
		else: return "forest"

# ==========================================================
# 도로 판정 (도메인 워핑 기반 유기적 비선형 도로)
# ==========================================================
func _get_warped_coords(wx: int, wy: int) -> Vector2:
	# 노이즈를 통한 좌표 워핑으로 직선 도로를 부드러운 곡선으로 변형
	var warp_x = road_warp_noise.get_noise_2d(wx * 0.5, wy * 0.5) * 6.0
	var warp_y = road_warp_noise.get_noise_2d(wx * 0.5 + 50.0, wy * 0.5 + 50.0) * 6.0
	return Vector2(wx + warp_x, wy + warp_y)

func is_road(wx: int, wy: int) -> bool:
	var biome = get_biome(wx, wy)
	var warped = _get_warped_coords(wx, wy)
	
	if biome == "forest":
		# 숲에서는 주요 간선 도로만 통과 (60 간격, 두께 3)
		var rx = fposmod(warped.x, 60.0)
		if rx > 30.0: rx = 60.0 - rx
		var ry = fposmod(warped.y, 60.0)
		if ry > 30.0: ry = 60.0 - ry
		return rx <= 1.5 or ry <= 1.5
		
	# 주간선도로 (40간격, 두께 4)
	var rx = fposmod(warped.x, 40.0)
	if rx > 20.0: rx = 40.0 - rx
	var ry = fposmod(warped.y, 40.0)
	if ry > 20.0: ry = 40.0 - ry
	
	if rx <= 2.0 or ry <= 2.0:
		return true
		
	# 보조도로 (20간격, 두께 2 - 상업/공업/군사 지역)
	if biome != "residential":
		var sx = fposmod(warped.x, 20.0)
		if sx > 10.0: sx = 20.0 - sx
		var sy = fposmod(warped.y, 20.0)
		if sy > 10.0: sy = 20.0 - sy
		if sx <= 1.0 or sy <= 1.0:
			return true
			
	return false

func is_sidewalk(wx: int, wy: int) -> bool:
	if is_road(wx, wy): return false
	# 도로에 바로 인접한 1타일은 보도블록/인도
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			if is_road(wx + dx, wy + dy):
				return true
	return false

# ==========================================================
# 건물 필지(Lot) 및 프리셋 조회
# ==========================================================
func _get_lot_building(lot_x: int, lot_y: int) -> Dictionary:
	var lot_rng = RandomNumberGenerator.new()
	var lot_seed = rng_seed ^ (lot_x * 73856093) ^ (lot_y * 19349663)
	lot_rng.seed = lot_seed
	
	var lot_origin_x = lot_x * LOT_SIZE
	var lot_origin_y = lot_y * LOT_SIZE
	var center_wx = lot_origin_x + LOT_SIZE / 2
	var center_wy = lot_origin_y + LOT_SIZE / 2
	
	var biome = get_biome(center_wx, center_wy)
	if biome == "forest" and lot_rng.randf() > 0.3:
		return {} # 숲에는 건물 빈도 낮춤
		
	# 중심부가 도로인지 확인
	if is_road(center_wx, center_wy):
		return {}
		
	var preset = BuildingPresets.get_preset_for_biome(biome, lot_rng)
	if preset.is_empty():
		return {}
		
	# 건물 크기 및 배치 오프셋 (필지 내에서 여백 다양성)
	var bw = preset["width"]
	var bh = preset["height"]
	var max_off_x = LOT_SIZE - bw - 8
	var max_off_y = LOT_SIZE - bh - 8
	if max_off_x < 0 or max_off_y < 0:
		return {}
		
	var b_x = lot_origin_x + 4 + lot_rng.randi_range(0, max(0, max_off_x))
	var b_y = lot_origin_y + 4 + lot_rng.randi_range(0, max(0, max_off_y))
	
	# 건물이 도로와 겹치지 않는지 확인
	for cy in range(b_y - 1, b_y + bh + 1):
		for cx in range(b_x - 1, b_x + bw + 1):
			if is_road(cx, cy):
				return {} # 도로와 겹치면 취소
				
	return {
		"preset": preset,
		"wx": b_x,
		"wy": b_y,
		"width": bw,
		"height": bh,
		"biome": biome,
		"seed": lot_seed
	}

func get_building_at(wx: int, wy: int) -> Dictionary:
	var lot_x = int(floor(float(wx) / float(LOT_SIZE)))
	var lot_y = int(floor(float(wy) / float(LOT_SIZE)))
	
	for ly in range(lot_y - 1, lot_y + 2):
		for lx in range(lot_x - 1, lot_x + 2):
			var b = _get_lot_building(lx, ly)
			if not b.is_empty():
				var bx = b["wx"]
				var by = b["wy"]
				var bw = b["width"]
				var bh = b["height"]
				if wx >= bx and wx < bx + bw and wy >= by and wy < by + bh:
					return b
	return {}

# ==========================================================
# 청크 생성 (타일, 오브젝트, 지붕, 엔티티)
# ==========================================================
func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var objects: Array[Vector2i] = []
	var roofs: Array[Vector2i] = []
	var entities: Array[Dictionary] = []
	
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	objects.resize(CHUNK_SIZE * CHUNK_SIZE)
	roofs.resize(CHUNK_SIZE * CHUNK_SIZE)
	
	for i in range(CHUNK_SIZE * CHUNK_SIZE):
		roofs[i] = Vector2i(-1, -1)
	
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	# 1. 주변 Lot에서 생성된 건물 리스트 수집
	var min_lot_x = int(floor(float(start_wx - LOT_SIZE) / float(LOT_SIZE)))
	var max_lot_x = int(floor(float(start_wx + CHUNK_SIZE + LOT_SIZE) / float(LOT_SIZE)))
	var min_lot_y = int(floor(float(start_wy - LOT_SIZE) / float(LOT_SIZE)))
	var max_lot_y = int(floor(float(start_wy + CHUNK_SIZE + LOT_SIZE) / float(LOT_SIZE)))
	
	var active_buildings: Array[Dictionary] = []
	for ly in range(min_lot_y, max_lot_y + 1):
		for lx in range(min_lot_x, max_lot_x + 1):
			var b = _get_lot_building(lx, ly)
			if not b.is_empty():
				active_buildings.append(b)
				
	# 2. 청크 내 각 타일 순회 생성
	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = rng_seed ^ (chunk_pos.x * 374761393) ^ (chunk_pos.y * 668265263)
	
	for cy in range(CHUNK_SIZE):
		for cx in range(CHUNK_SIZE):
			var idx = cy * CHUNK_SIZE + cx
			var wx = start_wx + cx
			var wy = start_wy + cy
			
			var biome = get_biome(wx, wy)
			var road = is_road(wx, wy)
			var sidewalk = is_sidewalk(wx, wy)
			
			var tile_coords = TileManager.TILE_GRASS
			var obj_coords = Vector2i(-1, -1)
			var is_protected_zone = false # 문 앞 등 장애물 금지 구역
			
			# A. 기본 바닥 타일 결정
			if road:
				tile_coords = TileManager.TILE_ROAD
				var warped = _get_warped_coords(wx, wy)
				
				# 중앙선 처리 (도로 중심에서 0.5 타일 이내일 때)
				var is_center_x = false
				var is_center_y = false
				
				if biome == "forest":
					var rx = fposmod(warped.x, 60.0)
					if rx > 30.0: rx = 60.0 - rx
					var ry = fposmod(warped.y, 60.0)
					if ry > 30.0: ry = 60.0 - ry
					if rx <= 0.5 or ry <= 0.5: tile_coords = TileManager.TILE_ROAD_LINE
				else:
					var rx = fposmod(warped.x, 40.0)
					if rx > 20.0: rx = 40.0 - rx
					var ry = fposmod(warped.y, 40.0)
					if ry > 20.0: ry = 40.0 - ry
					if rx <= 0.5 or ry <= 0.5: tile_coords = TileManager.TILE_ROAD_LINE
					
					if biome != "residential" and tile_coords != TileManager.TILE_ROAD_LINE:
						var sx = fposmod(warped.x, 20.0)
						if sx > 10.0: sx = 20.0 - sx
						var sy = fposmod(warped.y, 20.0)
						if sy > 10.0: sy = 20.0 - sy
						if sx <= 0.5 or sy <= 0.5: tile_coords = TileManager.TILE_ROAD_LINE
			elif sidewalk:
				tile_coords = TileManager.TILE_CONCRETE
			else:
				var n_val = noise.get_noise_2d(wx, wy)
				if n_val > 0.2:
					tile_coords = TileManager.TILE_DIRT
				elif biome == "military" or biome == "industrial":
					tile_coords = TileManager.TILE_CONCRETE
			
			# B. 건물 및 마당/울타리/자갈길 체크
			for b in active_buildings:
				var b_x = b["wx"]
				var b_y = b["wy"]
				var bw = b["width"]
				var bh = b["height"]
				var preset = b["preset"]
				var has_yard = preset.get("has_yard", false)
				var yard_m = preset.get("yard_margin", 2)
				var is_l_shape = preset.get("shape", "") == "l_shape"
				
				# 1) 건물 내부 영역 검사
				var in_building = false
				var rel_x = wx - b_x
				var rel_y = wy - b_y
				
				if rel_x >= 0 and rel_x < bw and rel_y >= 0 and rel_y < bh:
					if is_l_shape:
						# L자형: 우상단 빈 공간
						if not (rel_x >= bw/2 and rel_y < bh/2):
							in_building = true
					else:
						in_building = true
						
				if in_building:
					tile_coords = preset.get("floor_tile", TileManager.TILE_FLOOR_WOOD)
					roofs[idx] = TileManager.TILE_ROOF # 지붕 레이어에 지붕 타일 할당
					
					# 외벽 판정
					var is_wall = false
					if rel_x == 0 or rel_x == bw - 1 or rel_y == 0 or rel_y == bh - 1:
						is_wall = true
					elif is_l_shape:
						if (rel_x == bw/2 - 1 and rel_y < bh/2) or (rel_y == bh/2 and rel_x >= bw/2):
							is_wall = true
							
					if is_wall:
						var pt = Vector2i(rel_x, rel_y)
						if pt in preset.get("doors", []):
							obj_coords = TileManager.OBJ_DOOR_CLOSED # 닫힌 문
						elif pt in preset.get("windows", []):
							obj_coords = TileManager.OBJ_WINDOW # 창문
						else:
							obj_coords = TileManager.OBJ_WALL # 벽
					else:
						# 실내 내부 가구 / 전리품 상자 배치
						var furn_list = preset.get("furniture", [])
						for f in furn_list:
							if f.get("x") == rel_x and f.get("y") == rel_y:
								var f_type = f.get("type", "crate")
								if f_type == "fridge": obj_coords = TileManager.OBJ_FRIDGE
								elif f_type == "barrel": obj_coords = TileManager.OBJ_BARREL
								else: obj_coords = TileManager.OBJ_CRATE
								break
								
						# 무작위 추가 가구/상자 스폰 (5% 확률)
						if obj_coords == Vector2i(-1, -1) and chunk_rng.randf() < 0.05:
							var r_roll = chunk_rng.randf()
							if r_roll < 0.4: obj_coords = TileManager.OBJ_CRATE
							elif r_roll < 0.7: obj_coords = TileManager.OBJ_BARREL
							else: obj_coords = TileManager.OBJ_FRIDGE
					continue
					
				# 2) 건물 출입구 앞 진입로 및 자갈길
				for door_pos in preset.get("doors", []):
					var door_wx = b_x + door_pos.x
					var door_wy = b_y + door_pos.y
					
					# 문 앞 3x3 영역 보호
					if abs(wx - door_wx) <= 1 and wy >= door_wy and wy <= door_wy + 2:
						is_protected_zone = true
						tile_coords = TileManager.TILE_GRAVEL
						
					# 문에서 남쪽/가장 가까운 도로까지 자갈길 연장
					if wx == door_wx and wy > door_wy and wy <= door_wy + yard_m + 4:
						tile_coords = TileManager.TILE_GRAVEL
						is_protected_zone = true
				
				# 3) 마당 및 울타리/게이트 검사
				if has_yard:
					var y_left = b_x - yard_m
					var y_right = b_x + bw + yard_m - 1
					var y_top = b_y - yard_m
					var y_bottom = b_y + bh + yard_m - 1
					
					if wx >= y_left and wx <= y_right and wy >= y_top and wy <= y_bottom:
						# 울타리 테두리
						if wx == y_left or wx == y_right or wy == y_top or wy == y_bottom:
							# 문 앞 게이트 위치 판정
							var is_gate = false
							for door_pos in preset.get("doors", []):
								var door_wx = b_x + door_pos.x
								if wx == door_wx and wy == y_bottom:
									is_gate = true
									break
									
							if is_gate:
								obj_coords = TileManager.OBJ_GATE
								tile_coords = TileManager.TILE_GRAVEL
								is_protected_zone = true
							elif obj_coords == Vector2i(-1, -1):
								obj_coords = TileManager.OBJ_FENCE
						else:
							# 마당 내부 잔디
							if tile_coords != TileManager.TILE_GRAVEL:
								tile_coords = TileManager.TILE_GRASS
			
			# C. 야외 프랍 및 폐차 스폰 (오브젝트가 비어있을 때)
			if obj_coords == Vector2i(-1, -1) and not is_protected_zone:
				if road:
					# 도로 위 버려진 차량
					if chunk_rng.randf() < 0.004 and tile_coords != TileManager.TILE_ROAD_LINE:
						var rot = chunk_rng.randf_range(-PI, PI)
						entities.append({
							"type": "car",
							"wx": wx,
							"wy": wy,
							"rotation": rot
						})
				elif not sidewalk:
					# 자연물 및 파밍 상자 스폰
					var spawn_roll = chunk_rng.randf()
					if spawn_roll < 0.07:
						if spawn_roll < 0.04:
							obj_coords = TileManager.OBJ_TREE
						elif spawn_roll < 0.055:
							obj_coords = TileManager.OBJ_ROCK
						elif spawn_roll < 0.065:
							obj_coords = TileManager.OBJ_BARREL
						else:
							obj_coords = TileManager.OBJ_CRATE
			
			# D. 중심부 스폰 안전지대 (0,0 근처)
			if abs(wx) < 8 and abs(wy) < 8:
				if not road and obj_coords != TileManager.OBJ_DOOR_CLOSED and obj_coords != TileManager.OBJ_WALL:
					obj_coords = Vector2i(-1, -1)
					tile_coords = TileManager.TILE_GRASS
					
			tiles[idx] = tile_coords
			objects[idx] = obj_coords
			
	return {
		"tiles": tiles,
		"objects": objects,
		"roofs": roofs,
		"entities": entities
	}
