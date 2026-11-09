# res://scenes/world/world_generator.gd
class_name WorldGenerator
extends RefCounted

## 도심 격자 + 외곽 연속 곡선(SDF) 하이브리드 도로망, 12종 다중 방 건축 평면도, 실내 마스크 보호를 지원하는 절차적 월드 생성기

const CHUNK_SIZE: int = 16
const LOT_SIZE: int = 32 # 건물 필지 그리드 크기 (주간선 64 간격, 보조도로 32 간격과 정렬)
const MAIN_ROAD_PITCH: int = 64

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var road_warp_noise: FastNoiseLite
var rng_seed: int
var _lot_cache: Dictionary = {}
var lot_calc_count: int = 0

func clear_cache() -> void:
	_lot_cache.clear()
	lot_calc_count = 0

func _init(seed_value: int) -> void:
	rng_seed = seed_value
	_lot_cache.clear()
	lot_calc_count = 0
	
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
	road_warp_noise.frequency = 0.02

# ==========================================================
# 바이옴 판정
# ==========================================================
func get_biome(wx: int, wy: int) -> String:
	var dist = sqrt(float(wx * wx + wy * wy))
	var noise_val = biome_noise.get_noise_2d(wx, wy)
	
	if dist < 35.0:
		return "residential" # 스폰 중심 주거지
	elif dist < 140.0:
		if noise_val > 0.35: return "military"
		elif noise_val > 0.1: return "industrial"
		elif noise_val > -0.15: return "commercial"
		else: return "residential"
	else:
		if noise_val > 0.3: return "military"
		elif noise_val > 0.0: return "industrial"
		else: return "forest"

# ==========================================================
# 하이브리드 도로망 판정 (도심 반듯한 직교 도로 + 외곽 연속 1D 곡선 중심선 도로)
# ==========================================================
func _get_v_highway_x0(kx: int, wy: int) -> int:
	var anchor_dist = sqrt(float((kx * MAIN_ROAD_PITCH) * (kx * MAIN_ROAD_PITCH) + wy * wy))
	var blend = clamp((anchor_dist - 135.0) / 40.0, 0.0, 1.0)
	var curve = 0.0
	if blend > 0.0:
		curve = road_warp_noise.get_noise_2d(float(wy) * 0.55, float(kx) * 37.0) * 10.0 * blend
	var center_x = float(kx * MAIN_ROAD_PITCH) + 1.5 + curve
	return int(floor(center_x)) - 1

func _get_h_highway_y0(ky: int, wx: int) -> int:
	var anchor_dist = sqrt(float(wx * wx + (ky * MAIN_ROAD_PITCH) * (ky * MAIN_ROAD_PITCH)))
	var blend = clamp((anchor_dist - 135.0) / 40.0, 0.0, 1.0)
	var curve = 0.0
	if blend > 0.0:
		curve = road_warp_noise.get_noise_2d(float(wx) * 0.55, float(ky) * 53.0 + 100.0) * 10.0 * blend
	var center_y = float(ky * MAIN_ROAD_PITCH) + 1.5 + curve
	return int(floor(center_y)) - 1

func _get_block_info(block_x: int, block_y: int) -> Dictionary:
	var bc_x = block_x * MAIN_ROAD_PITCH + 32
	var bc_y = block_y * MAIN_ROAD_PITCH + 32
	var bc_dist = sqrt(float(bc_x * bc_x + bc_y * bc_y))
	var bc_biome = get_biome(bc_x, bc_y)
	return {
		"is_urban": bc_dist <= 136.0 and bc_biome != "forest",
		"biome": bc_biome
	}

func get_road_tile(wx: int, wy: int) -> Vector2i:
	var kx = int(round((float(wx) - 1.5) / float(MAIN_ROAD_PITCH)))
	var x0 = _get_v_highway_x0(kx, wy)
	var in_v_main = (wx >= x0 and wx <= x0 + 3)
	
	var ky = int(round((float(wy) - 1.5) / float(MAIN_ROAD_PITCH)))
	var y0 = _get_h_highway_y0(ky, wx)
	var in_h_main = (wy >= y0 and wy <= y0 + 3)
	
	var block_x = int(floor(float(wx) / float(MAIN_ROAD_PITCH)))
	var block_y = int(floor(float(wy) / float(MAIN_ROAD_PITCH)))
	var b_info = _get_block_info(block_x, block_y)
	var is_urban_block: bool = b_info["is_urban"]
	var block_biome: String = b_info["biome"]
	
	var mx64 = posmod(wx, MAIN_ROAD_PITCH)
	var my64 = posmod(wy, MAIN_ROAD_PITCH)
	
	# 보조 도로 (폭 2타일): 64x64 도시 블록 단위로 양끝 주간선 도로까지 끊김 없이 관통
	var in_h_sec = false
	var in_v_sec = false
	if is_urban_block:
		if my64 == 32 or my64 == 33:
			var left_x0 = _get_v_highway_x0(block_x, wy)
			var right_x0 = _get_v_highway_x0(block_x + 1, wy)
			in_h_sec = (wx >= left_x0 and wx <= right_x0 + 3)
		if block_biome != "residential" and (mx64 == 32 or mx64 == 33):
			var top_y0 = _get_h_highway_y0(block_y, wx)
			var bot_y0 = _get_h_highway_y0(block_y + 1, wx)
			in_v_sec = (wy >= top_y0 and wy <= bot_y0 + 3)
	
	var in_v = in_v_main or in_v_sec
	var in_h = in_h_main or in_h_sec
	
	if not in_v and not in_h:
		return Vector2i(-1, -1)
		
	# 교차로 내부는 차선 겹침 없이 깔끔한 아스팔트 처리
	if in_v and in_h:
		return TileManager.TILE_ROAD
		
	# 도심 주간선 교차로 직전 횡단보도 마킹
	if is_urban_block and in_v_main and (my64 == 5 or my64 == 62):
		return TileManager.TILE_CROSSWALK
		
	# 연속 중앙선 (주간선 폭 4타일 중 중심 타일 x0+1 / y0+1)
	if in_v_main and wx == x0 + 1:
		return TileManager.TILE_ROAD_LINE
	if in_h_main and wy == y0 + 1:
		return TileManager.TILE_ROAD_LINE_H
		
	return TileManager.TILE_ROAD

func is_road(wx: int, wy: int) -> bool:
	return get_road_tile(wx, wy) != Vector2i(-1, -1)

func is_sidewalk(wx: int, wy: int) -> bool:
	if is_road(wx, wy):
		return false
	var block_x = int(floor(float(wx) / float(MAIN_ROAD_PITCH)))
	var block_y = int(floor(float(wy) / float(MAIN_ROAD_PITCH)))
	if not _get_block_info(block_x, block_y)["is_urban"]:
		var dist = sqrt(float(wx * wx + wy * wy))
		if dist > 142.0 or get_biome(wx, wy) == "forest":
			return false
	# 도심 도로 바로 바깥 1타일 보도블록
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if is_road(wx + dx, wy + dy):
				return true
	return false

# ==========================================================
# 건물 필지(Lot) 및 프리셋 조회
# ==========================================================
static func is_point_in_building(b: Dictionary, wx: int, wy: int) -> bool:
	if b.is_empty():
		return false
	var rel_x = wx - int(b["wx"])
	var rel_y = wy - int(b["wy"])
	var bw = int(b["width"])
	var bh = int(b["height"])
	if rel_x < 0 or rel_x >= bw or rel_y < 0 or rel_y >= bh:
		return false
	var preset: Dictionary = b.get("preset", {})
	if preset.get("shape", "rect") == "l_shape":
		if rel_x >= bw / 2 and rel_y < bh / 2:
			return false
	return true

func _get_lot_building(lot_x: int, lot_y: int) -> Dictionary:
	var lot_key := Vector2i(lot_x, lot_y)
	if _lot_cache.has(lot_key):
		return _lot_cache[lot_key]
	lot_calc_count += 1
	var lot_rng = RandomNumberGenerator.new()
	var lot_seed = int(rng_seed ^ (lot_x * 73856093) ^ (lot_y * 19349663))
	lot_rng.seed = lot_seed
	
	var lot_origin_x = lot_x * LOT_SIZE
	var lot_origin_y = lot_y * LOT_SIZE
	var center_wx = lot_origin_x + int(LOT_SIZE * 0.5)
	var center_wy = lot_origin_y + int(LOT_SIZE * 0.5)
	
	var biome = get_biome(center_wx, center_wy)
	if biome == "forest" and lot_rng.randf() > 0.25:
		_lot_cache[lot_key] = {}
		return {} # 숲 외곽은 건물 밀도 낮춤
		
	var preset = BuildingPresets.get_preset_for_biome(biome, lot_rng)
	if preset.is_empty():
		_lot_cache[lot_key] = {}
		return {}
		
	var bw = int(preset["width"])
	var bh = int(preset["height"])
	var has_yard = bool(preset.get("has_yard", false))
	var yard_m = int(preset.get("yard_margin", 0)) if has_yard else 0
	
	# 필지 내 도로/보도블록(좌상단 0..5, 우하단 30..31)을 피한 순수 건축 가능 영역: [6 .. 29] (24x24)
	var usable_min_x = lot_origin_x + 6
	var usable_max_x = lot_origin_x + LOT_SIZE - 2 # 30 (exclusive upper bound)
	var usable_min_y = lot_origin_y + 6
	var usable_max_y = lot_origin_y + LOT_SIZE - 2
	
	var tot_w = bw + yard_m * 2
	var tot_h = bh + yard_m * 2
	if tot_w > (usable_max_x - usable_min_x) or tot_h > (usable_max_y - usable_min_y):
		_lot_cache[lot_key] = {}
		return {}
		
	var slack_x = (usable_max_x - usable_min_x) - tot_w
	var slack_y = (usable_max_y - usable_min_y) - tot_h
	var b_x = usable_min_x + yard_m + lot_rng.randi_range(0, max(0, slack_x))
	# 남쪽 가로 도로를 마주하도록 필지 남측 전면부에 정렬 배치
	var south_setback = lot_rng.randi_range(0, min(2, max(0, slack_y)))
	var b_y = usable_max_y - yard_m - bh - south_setback
	
	# 월드 스폰 지점 (0,0) 광장 보호
	var full_rect = Rect2i(b_x - yard_m - 1, b_y - yard_m - 1, tot_w + 2, tot_h + 2)
	if full_rect.intersects(Rect2i(-7, -7, 14, 14)):
		_lot_cache[lot_key] = {}
		return {}
		
	# 도로(특히 숲 외곽 곡선 도로)와의 겹침 완전 배제
	for cy in range(b_y - yard_m - 1, b_y + bh + yard_m + 1):
		for cx in range(b_x - yard_m - 1, b_x + bw + yard_m + 1):
			if is_road(cx, cy):
				_lot_cache[lot_key] = {}
				return {}
				
	var result := {
		"preset": preset,
		"wx": b_x,
		"wy": b_y,
		"width": bw,
		"height": bh,
		"biome": biome,
		"seed": lot_seed
	}
	_lot_cache[lot_key] = result
	return result

func get_building_at(wx: int, wy: int) -> Dictionary:
	var lot_x = int(floor(float(wx) / float(LOT_SIZE)))
	var lot_y = int(floor(float(wy) / float(LOT_SIZE)))
	
	for ly in range(lot_y - 1, lot_y + 2):
		for lx in range(lot_x - 1, lot_x + 2):
			var b = _get_lot_building(lx, ly)
			if not b.is_empty() and is_point_in_building(b, wx, wy):
				return b
	return {}

func _furniture_type_to_atlas(f_type: String) -> Vector2i:
	match f_type:
		"bed": return TileManager.OBJ_BED
		"desk": return TileManager.OBJ_DESK
		"shelf": return TileManager.OBJ_SHELF
		"fridge": return TileManager.OBJ_FRIDGE
		"barrel": return TileManager.OBJ_BARREL
		_: return TileManager.OBJ_CRATE

# ==========================================================
# 다단계 청크 생성 파이프라인 (실내 잔디/나무 침범 및 통로 막힘 원천 차단)
# ==========================================================
func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	var total_cells = CHUNK_SIZE * CHUNK_SIZE
	var tiles: Array[Vector2i] = []
	var objects: Array[Vector2i] = []
	var roofs: Array[Vector2i] = []
	var entities: Array[Dictionary] = []
	
	tiles.resize(total_cells)
	objects.resize(total_cells)
	roofs.resize(total_cells)
	
	var inside_building := PackedByteArray()
	inside_building.resize(total_cells)
	var protected_zone := PackedByteArray()
	protected_zone.resize(total_cells)
	var road_mask := PackedByteArray()
	road_mask.resize(total_cells)
	var sidewalk_mask := PackedByteArray()
	sidewalk_mask.resize(total_cells)
	
	for i in range(total_cells):
		objects[i] = Vector2i(-1, -1)
		roofs[i] = Vector2i(-1, -1)
		inside_building[i] = 0
		protected_zone[i] = 0
		road_mask[i] = 0
		sidewalk_mask[i] = 0
		
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	# 주변 필지의 활성 건물 수집
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
				
	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = int(rng_seed ^ (chunk_pos.x * 374761393) ^ (chunk_pos.y * 668265263))
	
	# [Pass 1] 기본 지형, 도로망, 인도 생성
	for cy in range(CHUNK_SIZE):
		for cx in range(CHUNK_SIZE):
			var idx = cy * CHUNK_SIZE + cx
			var wx = start_wx + cx
			var wy = start_wy + cy
			var biome = get_biome(wx, wy)
			var r_tile = get_road_tile(wx, wy)
			if r_tile != Vector2i(-1, -1):
				tiles[idx] = r_tile
				road_mask[idx] = 1
			elif is_sidewalk(wx, wy):
				tiles[idx] = TileManager.TILE_CONCRETE
				sidewalk_mask[idx] = 1
			else:
				var n_val = noise.get_noise_2d(wx, wy)
				if n_val > 0.22:
					tiles[idx] = TileManager.TILE_DIRT
				elif biome == "military" or biome == "industrial":
					tiles[idx] = TileManager.TILE_CONCRETE
				else:
					tiles[idx] = TileManager.TILE_GRASS
					
	# [Pass 2] 건물 본체(바닥, 지붕, 외벽/문/창문, 내벽/방문/잠긴문, 벽면 정렬 가구) 배치 및 실내 마스크 고정
	for b in active_buildings:
		var b_x = int(b["wx"])
		var b_y = int(b["wy"])
		var bw = int(b["width"])
		var bh = int(b["height"])
		var preset: Dictionary = b["preset"]
		var is_l_shape = preset.get("shape", "rect") == "l_shape"
		var floor_tile: Vector2i = preset.get("floor_tile", TileManager.TILE_FLOOR_WOOD)
		var ext_doors: Array = preset.get("doors", [])
		var ext_windows: Array = preset.get("windows", [])
		var inner_walls: Array = preset.get("inner_walls", [])
		var inner_doors: Array = preset.get("inner_doors", [])
		var locked_doors: Array = preset.get("locked_doors", [])
		var furn_list: Array = preset.get("furniture", [])
		
		var ix0 = max(start_wx, b_x)
		var ix1 = min(start_wx + CHUNK_SIZE, b_x + bw)
		var iy0 = max(start_wy, b_y)
		var iy1 = min(start_wy + CHUNK_SIZE, b_y + bh)
		
		for wy in range(iy0, iy1):
			for wx in range(ix0, ix1):
				if not is_point_in_building(b, wx, wy):
					continue
				var idx = (wy - start_wy) * CHUNK_SIZE + (wx - start_wx)
				var rel_x = wx - b_x
				var rel_y = wy - b_y
				var pt = Vector2i(rel_x, rel_y)
				
				inside_building[idx] = 1
				protected_zone[idx] = 1
				tiles[idx] = floor_tile
				roofs[idx] = TileManager.TILE_ROOF
				objects[idx] = Vector2i(-1, -1)
				
				var is_ext_wall = false
				if is_l_shape:
					if rel_x == 0 or rel_y == bh - 1:
						is_ext_wall = true
					elif rel_y == 0 and rel_x < bw / 2:
						is_ext_wall = true
					elif rel_x == bw - 1 and rel_y >= bh / 2:
						is_ext_wall = true
					elif rel_x == bw / 2 - 1 and rel_y <= bh / 2:
						is_ext_wall = true
					elif rel_y == bh / 2 and rel_x >= bw / 2 - 1:
						is_ext_wall = true
				else:
					if rel_x == 0 or rel_x == bw - 1 or rel_y == 0 or rel_y == bh - 1:
						is_ext_wall = true
						
				if is_ext_wall:
					if pt in ext_doors:
						objects[idx] = TileManager.OBJ_DOOR_CLOSED
					elif pt in ext_windows:
						objects[idx] = TileManager.OBJ_WINDOW
					else:
						objects[idx] = TileManager.OBJ_WALL
				else:
					if pt in locked_doors:
						objects[idx] = TileManager.OBJ_DOOR_LOCKED
					elif pt in inner_doors:
						objects[idx] = TileManager.OBJ_DOOR_OPEN
					elif pt in inner_walls:
						objects[idx] = TileManager.OBJ_WALL
					else:
						for f in furn_list:
							if int(f.get("x", -1)) == rel_x and int(f.get("y", -1)) == rel_y:
								objects[idx] = _furniture_type_to_atlas(String(f.get("type", "crate")))
								break
								
	# [Pass 3] 마당, 울타리, 게이트 및 출입문 진입로 생성 (실내 마스크 및 도로 침범 절대 금지)
	for b in active_buildings:
		var b_x = int(b["wx"])
		var b_y = int(b["wy"])
		var bw = int(b["width"])
		var bh = int(b["height"])
		var preset: Dictionary = b["preset"]
		var has_yard = bool(preset.get("has_yard", false))
		var yard_m = int(preset.get("yard_margin", 0)) if has_yard else 0
		var ext_doors: Array = preset.get("doors", [])
		var path_tile = TileManager.TILE_GRAVEL if has_yard else TileManager.TILE_CONCRETE
		
		# 3-A. 마당 잔디 및 울타리
		if has_yard and yard_m > 0:
			var y_left = b_x - yard_m
			var y_right = b_x + bw + yard_m - 1
			var y_top = b_y - yard_m
			var y_bottom = b_y + bh + yard_m - 1
			
			var yx0 = max(start_wx, y_left)
			var yx1 = min(start_wx + CHUNK_SIZE, y_right + 1)
			var yy0 = max(start_wy, y_top)
			var yy1 = min(start_wy + CHUNK_SIZE, y_bottom + 1)
			
			for wy in range(yy0, yy1):
				for wx in range(yx0, yx1):
					var idx = (wy - start_wy) * CHUNK_SIZE + (wx - start_wx)
					if inside_building[idx] == 1 or road_mask[idx] == 1:
						continue
					var on_fence = (wx == y_left or wx == y_right or wy == y_top or wy == y_bottom)
					if on_fence:
						var is_gate = false
						for door_pos in ext_doors:
							if wx == b_x + int(door_pos.x) and wy == y_bottom:
								is_gate = true
								break
						if is_gate:
							objects[idx] = TileManager.OBJ_GATE
							tiles[idx] = path_tile
							protected_zone[idx] = 1
						elif protected_zone[idx] == 0 and objects[idx] == Vector2i(-1, -1) and sidewalk_mask[idx] == 0:
							objects[idx] = TileManager.OBJ_FENCE
					else:
						if sidewalk_mask[idx] == 0 and protected_zone[idx] == 0:
							tiles[idx] = TileManager.TILE_GRASS
							
		# 3-B. 출입문 앞 보호구역 및 도로/인도까지 이어지는 직선 진입로
		for door_pos in ext_doors:
			var door_wx = b_x + int(door_pos.x)
			var door_wy = b_y + int(door_pos.y)
			
			for pwy in range(door_wy + 1, door_wy + yard_m + 8):
				if is_road(door_wx, pwy):
					break
				for pwx in range(door_wx - 1, door_wx + 2):
					if pwx >= start_wx and pwx < start_wx + CHUNK_SIZE and pwy >= start_wy and pwy < start_wy + CHUNK_SIZE:
						var pidx = (pwy - start_wy) * CHUNK_SIZE + (pwx - start_wx)
						if inside_building[pidx] == 1 or road_mask[pidx] == 1:
							continue
						protected_zone[pidx] = 1
						if pwx == door_wx:
							if sidewalk_mask[pidx] == 0:
								tiles[pidx] = path_tile
							if objects[pidx] != TileManager.OBJ_GATE:
								objects[pidx] = Vector2i(-1, -1)
						elif objects[pidx] != TileManager.OBJ_FENCE and objects[pidx] != TileManager.OBJ_GATE:
							objects[pidx] = Vector2i(-1, -1)
				if is_sidewalk(door_wx, pwy):
					break
					
	# [Pass 4] 야외 자연물(나무/바위) 및 폐차 스폰 (건물 내부·보호구역·인도 완전 제외)
	for cy in range(CHUNK_SIZE):
		for cx in range(CHUNK_SIZE):
			var idx = cy * CHUNK_SIZE + cx
			if inside_building[idx] == 1 or protected_zone[idx] == 1 or objects[idx] != Vector2i(-1, -1):
				continue
			var wx = start_wx + cx
			var wy = start_wy + cy
			
			if road_mask[idx] == 1:
				var rt = tiles[idx]
				if rt == TileManager.TILE_ROAD and abs(wx) > 8 and abs(wy) > 8 and chunk_rng.randf() < 0.0035:
					entities.append({
						"type": "car",
						"wx": wx,
						"wy": wy,
						"rotation": chunk_rng.randf_range(-0.18, 0.18)
					})
			elif sidewalk_mask[idx] == 0:
				var biome = get_biome(wx, wy)
				var spawn_roll = chunk_rng.randf()
				var density = 0.09 if biome == "forest" else 0.035
				if spawn_roll < density:
					if spawn_roll < density * 0.60:
						objects[idx] = TileManager.OBJ_TREE
					elif spawn_roll < density * 0.82:
						objects[idx] = TileManager.OBJ_ROCK
					elif spawn_roll < density * 0.92:
						objects[idx] = TileManager.OBJ_BARREL
					else:
						objects[idx] = TileManager.OBJ_CRATE
						
	# [Pass 5] 스폰 중심지 (0,0) 장애물 안전 클리어 (도로/인도 및 건물 내부 보존)
	for cy in range(CHUNK_SIZE):
		for cx in range(CHUNK_SIZE):
			var wx = start_wx + cx
			var wy = start_wy + cy
			if abs(wx) < 6 and abs(wy) < 6:
				var idx = cy * CHUNK_SIZE + cx
				if inside_building[idx] == 0:
					objects[idx] = Vector2i(-1, -1)
					
	return {
		"tiles": tiles,
		"objects": objects,
		"roofs": roofs,
		"inside_mask": inside_building,
		"entities": entities
	}
