# res://scripts/tools/verify_world_generation.gd
extends SceneTree

## 절차적 월드 생성(100개 청크 실내 무결성, 12종 건물 Flood-Fill 도달성, 하이브리드 도로 연속성) 독립 검증 스크립트

func _init() -> void:
	print("=== STARTING WORLD GENERATION INTEGRITY VERIFICATION ===")
	var failures: int = 0
	var gen := WorldGenerator.new(20261108)

	# 1. 100개 청크(-5..4 x -5..4) 생성 후 실내 잔디/나무/바위 침범 = 0 및 도로 고립 픽셀 = 0 검증
	var indoor_grass_count := 0
	var indoor_outdoor_prop_count := 0
	var isolated_road_count := 0
	var total_buildings_sampled := 0
	var seen_seeds := {}

	for cy in range(-5, 5):
		for cx in range(-5, 5):
			var c_data := gen.generate_chunk(Vector2i(cx, cy))
			var tiles: Array = c_data["tiles"]
			var objects: Array = c_data["objects"]
			var inside_mask: PackedByteArray = c_data["inside_mask"]
			var start_wx := cx * WorldGenerator.CHUNK_SIZE
			var start_wy := cy * WorldGenerator.CHUNK_SIZE

			for ly in range(WorldGenerator.CHUNK_SIZE):
				for lx in range(WorldGenerator.CHUNK_SIZE):
					var idx := ly * WorldGenerator.CHUNK_SIZE + lx
					var wx := start_wx + lx
					var wy := start_wy + ly

					if inside_mask[idx] == 1:
						if tiles[idx] == TileManager.TILE_GRASS or tiles[idx] == TileManager.TILE_DIRT:
							indoor_grass_count += 1
						if objects[idx] == TileManager.OBJ_TREE or objects[idx] == TileManager.OBJ_ROCK or objects[idx] == TileManager.OBJ_FENCE:
							indoor_outdoor_prop_count += 1
						var b := gen.get_building_at(wx, wy)
						if not b.is_empty():
							seen_seeds[b["seed"]] = true

					if gen.is_road(wx, wy):
						var ortho_neighbors := 0
						for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if gen.is_road(wx + dir.x, wy + dir.y):
								ortho_neighbors += 1
						if ortho_neighbors < 2:
							isolated_road_count += 1

	total_buildings_sampled = seen_seeds.size()
	if indoor_grass_count == 0 and indoor_outdoor_prop_count == 0 and total_buildings_sampled > 10:
		print("[PASS] 100-Chunk Indoor Mask Check: %d buildings sampled, 0 indoor grass/dirt, 0 indoor trees/rocks" % total_buildings_sampled)
	else:
		printerr("[FAIL] 100-Chunk Indoor Mask Check: buildings=%d, grass=%d, props=%d" % [total_buildings_sampled, indoor_grass_count, indoor_outdoor_prop_count])
		failures += 1

	if isolated_road_count == 0:
		print("[PASS] Hybrid Road Continuity Check (Urban + Outskirts): 0 isolated/crumbled road pixels across 25,600 tiles")
	else:
		printerr("[FAIL] Hybrid Road Continuity Check: %d crumbled road tiles found" % isolated_road_count)
		failures += 1

	# 외곽 숲 곡선 도로 폭(4타일) 샘플 검증 (wy = 220)
	var outskirt_x0 := gen._get_v_highway_x0(0, 220)
	var outskirt_width := 0
	for wx in range(outskirt_x0 - 2, outskirt_x0 + 6):
		if gen.is_road(wx, 220):
			outskirt_width += 1
	if outskirt_width >= 4 and gen.get_road_tile(outskirt_x0 + 1, 220) == TileManager.TILE_ROAD_LINE:
		print("[PASS] Outskirts Curved Highway Check: exact >=4-tile width and continuous centerline at wy=220")
	else:
		printerr("[FAIL] Outskirts Curved Highway Check: width=%d at x0=%d" % [outskirt_width, outskirt_x0])
		failures += 1

	# 2. 12종 모든 BuildingPreset에 대해 출입문 Flood-Fill 도달성 100% 검증
	var preset_failures := 0
	for b_type in BuildingPresets.BuildingType.values():
		var preset := BuildingPresets.get_preset(b_type)
		var bw := int(preset["width"])
		var bh := int(preset["height"])
		var is_l: bool = String(preset.get("shape", "rect")) == "l_shape"
		var ext_doors: Array = preset.get("doors", [])
		var inner_walls: Array = preset.get("inner_walls", [])
		var inner_doors: Array = preset.get("inner_doors", [])
		var locked_doors: Array = preset.get("locked_doors", [])
		var furn_list: Array = preset.get("furniture", [])

		var furn_set := {}
		for f in furn_list:
			furn_set[Vector2i(int(f["x"]), int(f["y"]))] = true

		# 각 내부 셀 분류: walkable(빈 바닥, 문, 잠긴문) vs furniture vs wall
		var walkable := {}
		for ry in range(bh):
			for rx in range(bw):
				if is_l and rx >= bw / 2 and ry < bh / 2:
					continue
				var pt := Vector2i(rx, ry)
				var is_ext_wall := false
				if is_l:
					if rx == 0 or ry == bh - 1: is_ext_wall = true
					elif ry == 0 and rx < bw / 2: is_ext_wall = true
					elif rx == bw - 1 and ry >= bh / 2: is_ext_wall = true
					elif rx == bw / 2 - 1 and ry <= bh / 2: is_ext_wall = true
					elif ry == bh / 2 and rx >= bw / 2 - 1: is_ext_wall = true
				else:
					if rx == 0 or rx == bw - 1 or ry == 0 or ry == bh - 1:
						is_ext_wall = true

				if is_ext_wall:
					if pt in ext_doors:
						walkable[pt] = true
				else:
					if pt in locked_doors or pt in inner_doors:
						walkable[pt] = true
					elif pt in inner_walls or furn_set.has(pt):
						pass
					else:
						walkable[pt] = true

		# 출입문에서 BFS 탐색
		var visited := {}
		var queue: Array[Vector2i] = []
		for d_pt in ext_doors:
			if walkable.has(d_pt):
				visited[d_pt] = true
				queue.append(d_pt)

		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt: Vector2i = cur + dir
				if walkable.has(nxt) and not visited.has(nxt):
					visited[nxt] = true
					queue.append(nxt)

		var unreachable_floors := walkable.size() - visited.size()
		var unreachable_furn := 0
		for f_pt in furn_set.keys():
			var adj_ok := false
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if visited.has(f_pt + dir):
					adj_ok = true
					break
			if not adj_ok:
				unreachable_furn += 1

		if unreachable_floors > 0 or unreachable_furn > 0:
			printerr("[FAIL] Preset '%s' reachability failed: unreachable_floors=%d, unreachable_furniture=%d" % [preset.get("type_name", ""), unreachable_floors, unreachable_furn])
			preset_failures += 1

	if preset_failures == 0:
		print("[PASS] All 12 BuildingPresets Flood-Fill Check: 100% floor tiles & 100% furniture reachable from exterior doors")
	else:
		failures += preset_failures

	print("=== WORLD GENERATION VERIFICATION COMPLETE (Failures: %d) ===" % failures)
	quit(0 if failures == 0 else 1)
