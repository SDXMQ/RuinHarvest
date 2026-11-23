extends Node2D
class_name PlayerVisuals

var hit_flash_tween: Tween
var floating_texts: Array = []
@onready var player = get_parent()

var _sprites_ready: bool = false
var _player_parts_tex: CanvasTexture = null
var _weapon_parts_tex: CanvasTexture = null

var _contact_shadow: Sprite2D
var _boot_left: Sprite2D
var _boot_right: Sprite2D
var _backpack_spr: Sprite2D
var _torso_spr: Sprite2D
var _arms_spr: Sprite2D
var _head_spr: Sprite2D
var _gasmask_spr: Sprite2D
var _nvg_spr: Sprite2D

var _wep_stock: Sprite2D
var _wep_mag: Sprite2D
var _wep_grip: Sprite2D
var _wep_receiver: Sprite2D
var _wep_barrel: Sprite2D
var _wep_muzzle: Sprite2D
var _wep_rail: Sprite2D
var _wep_optic: Sprite2D
var _wep_muzzle_flash: Sprite2D
var _glow_overlay: Node2D
var _hud_overlay: Node2D

var _laser_active: bool = false
var _laser_start: Vector2 = Vector2.ZERO
var _laser_end: Vector2 = Vector2.ZERO
var _nvg_glow_active: bool = false
var _is_dead_visual: bool = false

static func _cell_rect(col: int, row: int, sz: int = 32) -> Rect2:
	return Rect2(float(col * sz), float(row * sz), float(sz), float(sz))

func _make_layer_sprite(sname: String, z_ord: int, use_parent_mat: bool = true) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.name = sname
	spr.centered = true
	spr.region_enabled = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.use_parent_material = use_parent_mat
	spr.z_index = z_ord
	add_child(spr)
	return spr

func _ensure_pixel_layers() -> void:
	if _sprites_ready:
		return
	_sprites_ready = true
	if PixelAssetManager:
		_player_parts_tex = PixelAssetManager.get_canvas_texture("entities/player_parts")
		_weapon_parts_tex = PixelAssetManager.get_canvas_texture("weapons/weapon_parts")

	_contact_shadow = _make_layer_sprite("ContactShadow", -2, false)
	if _player_parts_tex:
		_contact_shadow.texture = _player_parts_tex
	_contact_shadow.region_rect = _cell_rect(0, 0)
	_contact_shadow.modulate = Color(1.0, 1.0, 1.0, 0.72)

	_boot_left = _make_layer_sprite("BootLeft", 0, true)
	_boot_right = _make_layer_sprite("BootRight", 0, true)
	for b in [_boot_left, _boot_right]:
		if _player_parts_tex:
			b.texture = _player_parts_tex
		b.region_rect = _cell_rect(1, 0)

	_backpack_spr = _make_layer_sprite("BackpackSprite", 1, true)
	_torso_spr = _make_layer_sprite("TorsoSprite", 2, true)
	_arms_spr = _make_layer_sprite("ArmsSprite", 3, true)

	# Weapon modular layers (above arms, below head)
	_wep_stock = _make_layer_sprite("WepStock", 3, true)
	_wep_mag = _make_layer_sprite("WepMag", 3, true)
	_wep_grip = _make_layer_sprite("WepGrip", 3, true)
	_wep_barrel = _make_layer_sprite("WepBarrel", 4, true)
	_wep_muzzle = _make_layer_sprite("WepMuzzle", 4, true)
	_wep_receiver = _make_layer_sprite("WepReceiver", 4, true)
	_wep_rail = _make_layer_sprite("WepRail", 5, true)
	_wep_optic = _make_layer_sprite("WepOptic", 5, true)

	_wep_muzzle_flash = _make_layer_sprite("WepMuzzleFlash", 6, false)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_wep_muzzle_flash.material = unshaded
	_wep_muzzle_flash.modulate = Color(2.4, 1.9, 1.05, 0.96)
	_wep_muzzle_flash.region_rect = _cell_rect(7, 2)
	_wep_muzzle_flash.visible = false

	_head_spr = _make_layer_sprite("HeadSprite", 6, true)
	_gasmask_spr = _make_layer_sprite("GasmaskSprite", 7, true)
	_nvg_spr = _make_layer_sprite("NvgSprite", 7, true)

	for p_spr in [_backpack_spr, _torso_spr, _arms_spr, _head_spr, _gasmask_spr, _nvg_spr]:
		if _player_parts_tex:
			p_spr.texture = _player_parts_tex
	for w_spr in [_wep_stock, _wep_mag, _wep_grip, _wep_barrel, _wep_muzzle, _wep_receiver, _wep_rail, _wep_optic, _wep_muzzle_flash]:
		if _weapon_parts_tex:
			w_spr.texture = _weapon_parts_tex

	_glow_overlay = Node2D.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.z_index = 8
	_glow_overlay.material = unshaded
	_glow_overlay.draw.connect(_on_glow_overlay_draw)
	add_child(_glow_overlay)

	_hud_overlay = Node2D.new()
	_hud_overlay.name = "HudOverlay"
	_hud_overlay.z_index = 12
	_hud_overlay.material = unshaded
	_hud_overlay.draw.connect(_on_hud_overlay_draw)
	add_child(_hud_overlay)

func _ready() -> void:
	_ensure_pixel_layers()
	if material is ShaderMaterial:
		material = material.duplicate()
	reset_visual_state()
	if EventBus.has_signal("player_damaged") and not (player and player.has_method("_on_player_damaged")):
		EventBus.player_damaged.connect(_on_player_damaged)
	_sync_pixel_layers()

func reset_visual_state() -> void:
	if hit_flash_tween and is_instance_valid(hit_flash_tween):
		hit_flash_tween.kill()
	hit_flash_tween = null
	_is_dead_visual = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	if material:
		material.set_shader_parameter("flash_color", Color.WHITE)
		material.set_shader_parameter("flash_modifier", 0.0)

func trigger_hit_flash() -> void:
	if _is_dead_visual or not player or player.hp <= 0 or bool(player.get("_is_dying")):
		return
	if hit_flash_tween and is_instance_valid(hit_flash_tween):
		hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	if material:
		material.set_shader_parameter("flash_color", Color(1.0, 0.15, 0.15, 1.0))
		material.set_shader_parameter("flash_modifier", 0.9)
		hit_flash_tween.tween_property(material, "shader_parameter/flash_modifier", 0.0, 0.18)
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").request_shake(8.0, 0.3)

func show_death_visual() -> void:
	if hit_flash_tween and is_instance_valid(hit_flash_tween):
		hit_flash_tween.kill()
	hit_flash_tween = null
	_is_dead_visual = true
	if material:
		material.set_shader_parameter("flash_color", Color.WHITE)
		material.set_shader_parameter("flash_modifier", 0.0)
	position = Vector2.ZERO
	rotation = PI * 0.48
	modulate = Color(0.62, 0.55, 0.55, 0.92)

func show_floating_text(text: String, color: Color = Color(1.0, 0.9, 0.4), duration: float = 0.8) -> void:
	# 동일 텍스트가 최근에 떠있다면 타이머 갱신
	for ft in floating_texts:
		if ft["text"] == text:
			ft["elapsed"] = 0.0
			ft["duration"] = duration
			ft["color"] = color
			return
	floating_texts.append({
		"text": text,
		"color": color,
		"elapsed": 0.0,
		"duration": max(0.2, duration)
	})
	queue_redraw()

func _process(delta: float) -> void:
	if floating_texts.size() > 0:
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["elapsed"] += delta
			if floating_texts[i]["elapsed"] >= floating_texts[i]["duration"]:
				floating_texts.remove_at(i)
	_sync_pixel_layers()
	if _glow_overlay:
		_glow_overlay.queue_redraw()
	if _hud_overlay:
		_hud_overlay.queue_redraw()
	queue_redraw()

func _on_player_damaged(_amount: float, source: String) -> void:
	if source == "status_effect":
		return
	trigger_hit_flash()

func _sync_pixel_layers() -> void:
	_ensure_pixel_layers()
	if not player:
		return

	var walk_bob := 0.0
	var bob_y := 0.0
	var bob_rot := 0.0
	var is_moving := false
	if not _is_dead_visual and "velocity" in player and player.velocity.length() > 10.0:
		is_moving = true

	var recoil_offset := 0.0
	var muzzle_flash_timer := 0.0
	var equipped_weapon_data: Dictionary = {}
	var active_slot: String = "primary1"
	var equip_dict: Dictionary = {}
	var nvg_on: bool = false

	if player.has_node("PlayerCamera"):
		walk_bob = float(player.get_node("PlayerCamera").walk_bob)
		bob_y = sin(walk_bob * 2.0) * 1.4
		bob_rot = sin(walk_bob) * 0.06
	if player.has_node("WeaponHandler"):
		var wh = player.get_node("WeaponHandler")
		recoil_offset = float(wh.recoil_offset)
		equipped_weapon_data = wh.equipped_weapon_data
		active_slot = wh.active_weapon_slot
		equip_dict = wh.equipment
	if player.has_node("PlayerLighting"):
		var pl = player.get_node("PlayerLighting")
		muzzle_flash_timer = float(pl.muzzle_flash_timer)
		nvg_on = bool(pl.nvg_enabled)

	if _is_dead_visual:
		position = Vector2.ZERO
		rotation = PI * 0.48
		_contact_shadow.position = Vector2(1.0, 2.0)
	else:
		position = Vector2(0.0, bob_y)
		rotation = bob_rot
		_contact_shadow.position = Vector2(1.0, 2.0 - bob_y)

	# 1. 양발 교차 보행 애니메이션
	var stride := sin(walk_bob) * 4.5 if is_moving else 0.0
	_boot_left.position = Vector2(stride, -5.0)
	_boot_right.position = Vector2(-stride, 5.0)

	# 2. 배낭 레이어 (1~3티어)
	var bp_id := String(equip_dict.get("backpack", {}).get("id", ""))
	if bp_id == "":
		_backpack_spr.visible = false
	else:
		_backpack_spr.visible = true
		if bp_id.contains("3") or bp_id.contains("대형"):
			_backpack_spr.region_rect = _cell_rect(4, 0)
		elif bp_id.contains("2") or bp_id.contains("전술") or bp_id.contains("중형"):
			_backpack_spr.region_rect = _cell_rect(3, 0)
		else:
			_backpack_spr.region_rect = _cell_rect(2, 0)

	# 3. 방탄조끼 및 상의 레이어
	var vest_id := String(equip_dict.get("vest", {}).get("id", ""))
	if vest_id.contains("3") or vest_id.contains("6B43") or vest_id.contains("중방탄") or vest_id.contains("중갑"):
		_torso_spr.region_rect = _cell_rect(3, 1)
	elif vest_id.contains("2") or vest_id.contains("전술") or vest_id.contains("군용"):
		_torso_spr.region_rect = _cell_rect(2, 1)
	elif vest_id != "":
		_torso_spr.region_rect = _cell_rect(1, 1)
	else:
		_torso_spr.region_rect = _cell_rect(0, 1)

	# 4. 팔 & 모듈형 무기/부착물 레이어
	for ws in [_wep_stock, _wep_mag, _wep_grip, _wep_barrel, _wep_muzzle, _wep_receiver, _wep_rail, _wep_optic, _wep_muzzle_flash]:
		ws.visible = false
		ws.rotation = 0.0
		ws.scale = Vector2.ONE

	_laser_active = false
	var w_id := String(equipped_weapon_data.get("id", ""))
	var w_type := String(equipped_weapon_data.get("type", ""))
	var attachments: Dictionary = equipped_weapon_data.get("parts", equipped_weapon_data.get("attachments", {}))

	if equipped_weapon_data.is_empty():
		_arms_spr.region_rect = _cell_rect(5, 0)
		_arms_spr.position = Vector2(clampf(recoil_offset * 0.4, 0.0, 5.0), 0.0)
	elif active_slot == "throwable" or w_type == "throwable" or w_id.contains("수류탄"):
		_arms_spr.region_rect = _cell_rect(5, 0)
		_arms_spr.position = Vector2.ZERO
		_wep_receiver.visible = true
		_wep_receiver.region_rect = _cell_rect(6, 2)
		_wep_receiver.position = Vector2(8.0 - recoil_offset * 0.5, 7.0)
	elif w_type == "melee" or w_id.contains("검") or w_id.contains("도끼") or w_id.contains("나이프") or w_id.contains("파이프") or w_id.contains("방망이"):
		_arms_spr.region_rect = _cell_rect(5, 0)
		var swing_ratio := clampf(recoil_offset / 7.0, 0.0, 1.0)
		_arms_spr.position = Vector2(swing_ratio * 4.0, 0.0)
		_wep_receiver.visible = true
		if w_id.contains("도끼"):
			_wep_receiver.region_rect = _cell_rect(6, 0)
		elif w_id.contains("나이프") or w_id.contains("검"):
			_wep_receiver.region_rect = _cell_rect(7, 0)
		else:
			_wep_receiver.region_rect = _cell_rect(5, 2)
		_wep_receiver.position = Vector2(11.0 + swing_ratio * 5.0, 6.0 - swing_ratio * 5.0)
		_wep_receiver.rotation = -0.35 + swing_ratio * 0.95
	else:
		var res_rec := WeaponPartsDatabase.resolve_receiver_id(w_id)
		var is_pistol := (res_rec == "M9_리시버") or w_id.contains("M9") or w_id.contains("권총") or active_slot == "sidearm"
		var is_sniper := (res_rec == "SV98_리시버") or w_id.contains("AWM") or w_id.contains("SV") or w_id.contains("저격")

		var kick := clampf(recoil_offset * 0.45, 0.0, 5.5)
		var mount_x := (10.0 if is_pistol else 12.0) - kick
		var mount_y := 0.0 if is_pistol else 1.0

		_arms_spr.region_rect = _cell_rect(7, 0) if is_pistol else _cell_rect(6, 0)
		_arms_spr.position = Vector2(-kick * 0.6, 0.0)

		# Receiver sprite
		_wep_receiver.visible = true
		_wep_receiver.position = Vector2(mount_x, mount_y)
		match res_rec:
			"M9_리시버":
				_wep_receiver.region_rect = _cell_rect(0, 0)
			"AK_리시버":
				_wep_receiver.region_rect = _cell_rect(1, 0)
			"M4_리시버":
				_wep_receiver.region_rect = _cell_rect(2, 0)
			"레밍턴_리시버":
				_wep_receiver.region_rect = _cell_rect(3, 0)
			"SV98_리시버":
				_wep_receiver.region_rect = _cell_rect(4, 0)
			"레버액션_리시버", "레버액션 소총":
				_wep_receiver.region_rect = _cell_rect(5, 0)
			"MP5_리시버":
				_wep_receiver.region_rect = _cell_rect(0, 3)
			_:
				_wep_receiver.region_rect = _cell_rect(0, 0) if is_pistol else _cell_rect(2, 0)

		var rec_front_local := 6.0 if is_pistol else 9.0
		var rec_back_local := -6.0 if is_pistol else -9.0

		# Barrel
		var barrel_id := String(attachments.get("barrel", ""))
		var is_long_barrel := barrel_id.contains("롱") or barrel_id.contains("장총열") or barrel_id.contains("정밀")
		var tip_x := mount_x + rec_front_local
		if is_long_barrel or is_sniper:
			_wep_barrel.visible = true
			_wep_barrel.region_rect = _cell_rect(1, 1)
			_wep_barrel.position = Vector2(tip_x + 6.0, mount_y)
			tip_x += 15.0
		elif (not is_pistol) or barrel_id != "":
			_wep_barrel.visible = true
			_wep_barrel.region_rect = _cell_rect(0, 1)
			_wep_barrel.position = Vector2(tip_x + 4.0, mount_y)
			tip_x += 9.0

		# Muzzle
		var muzzle_id := String(attachments.get("muzzle", ""))
		if muzzle_id != "":
			_wep_muzzle.visible = true
			if muzzle_id.contains("소음기"):
				_wep_muzzle.region_rect = _cell_rect(2, 1)
				_wep_muzzle.position = Vector2(tip_x + 4.0, mount_y)
				tip_x += 11.0
			else:
				_wep_muzzle.region_rect = _cell_rect(3, 1)
				_wep_muzzle.position = Vector2(tip_x + 2.0, mount_y)
				tip_x += 5.0

		# Stock
		var stock_id := String(attachments.get("stock", ""))
		if (not is_pistol) or stock_id != "":
			_wep_stock.visible = true
			if stock_id.contains("PRS") or stock_id.contains("정밀") or stock_id.contains("저격"):
				_wep_stock.region_rect = _cell_rect(5, 1)
			else:
				_wep_stock.region_rect = _cell_rect(4, 1)
			_wep_stock.position = Vector2(mount_x + rec_back_local, mount_y)

		# Magazine
		var mag_id := String(attachments.get("magazine", ""))
		if not is_pistol and mag_id != "":
			_wep_mag.visible = true
			if mag_id.contains("드럼") or mag_id.contains("50"):
				_wep_mag.region_rect = _cell_rect(7, 1)
				_wep_mag.position = Vector2(mount_x - 1.0, mount_y + 4.0)
			else:
				_wep_mag.region_rect = _cell_rect(6, 1)
				_wep_mag.position = Vector2(mount_x + 1.0, mount_y + 3.0)

		# Underbarrel / Side Foregrip
		var grip_id := String(attachments.get("grip", ""))
		if not is_pistol and grip_id != "":
			_wep_grip.visible = true
			_wep_grip.region_rect = _cell_rect(3, 2)
			_wep_grip.position = Vector2(mount_x + 7.0, mount_y + 2.0)

		# Rail Pod (Flashlight / Laser Sight)
		var stats: Dictionary = equipped_weapon_data.get("computed_stats", {})
		var rail_val = attachments.get("rail", [])
		var has_rail := false
		if rail_val is Array:
			has_rail = not rail_val.is_empty()
		elif rail_val is String:
			has_rail = rail_val != ""
		if has_rail or bool(stats.get("laser_sight", false)) or bool(stats.get("flashlight_boost", false)):
			_wep_rail.visible = true
			_wep_rail.region_rect = _cell_rect(4, 2)
			_wep_rail.position = Vector2(mount_x + (3.0 if is_pistol else 6.0), mount_y - 3.0)

		# Optic
		var optic_id := String(attachments.get("optic", ""))
		if optic_id != "" or is_sniper:
			if optic_id.contains("8배율") or optic_id.contains("스나이퍼") or (optic_id == "" and is_sniper):
				_wep_optic.visible = true
				_wep_optic.region_rect = _cell_rect(2, 2)
				_wep_optic.position = Vector2(mount_x + 1.0, mount_y - 1.0)
			elif optic_id.contains("4배율") or optic_id.contains("ACOG") or optic_id.contains("2배율") or optic_id.contains("배율"):
				_wep_optic.visible = true
				_wep_optic.region_rect = _cell_rect(1, 2)
				_wep_optic.position = Vector2(mount_x + 1.0, mount_y - 1.0)
			elif not optic_id.contains("기본"):
				_wep_optic.visible = true
				_wep_optic.region_rect = _cell_rect(0, 2)
				_wep_optic.position = Vector2(mount_x, mount_y - 1.0)

		# HDR Pixel Muzzle Flash
		if muzzle_flash_timer > 0.0:
			_wep_muzzle_flash.visible = true
			_wep_muzzle_flash.position = Vector2(tip_x + 7.0, mount_y)
			_wep_muzzle_flash.scale = Vector2(1.15, 1.05)

		# HDR Laser Sight beam anchor
		if bool(stats.get("laser_sight", false)):
			_laser_active = true
			_laser_start = Vector2(tip_x, mount_y)
			_laser_end = _compute_laser_end(_laser_start)

	# 5. 머리 & 헬멧 / 방독면 / 야간투시경
	var helmet_id := String(equip_dict.get("helmet", {}).get("id", ""))
	_gasmask_spr.visible = false
	if helmet_id.contains("방독"):
		_head_spr.region_rect = _cell_rect(0, 2)
		_gasmask_spr.visible = true
		_gasmask_spr.region_rect = _cell_rect(5, 2)
	elif helmet_id.contains("3") or helmet_id.contains("알틴") or helmet_id.contains("스페츠나츠"):
		_head_spr.region_rect = _cell_rect(3, 2)
	elif helmet_id.contains("2") or helmet_id.contains("군용"):
		_head_spr.region_rect = _cell_rect(2, 2)
	elif helmet_id != "":
		_head_spr.region_rect = _cell_rect(1, 2)
	else:
		_head_spr.region_rect = _cell_rect(0, 2)

	_nvg_glow_active = nvg_on
	_nvg_spr.visible = nvg_on
	if nvg_on:
		_nvg_spr.region_rect = _cell_rect(4, 2)

func _compute_laser_end(start_pos: Vector2) -> Vector2:
	var end_pos := start_pos + Vector2(350.0, 0.0)
	if is_inside_tree() and player:
		var world_2d: World2D = player.get_world_2d()
		if world_2d != null and world_2d.direct_space_state:
			var q := PhysicsRayQueryParameters2D.create(to_global(start_pos), to_global(end_pos), 1, [player])
			var hit: Dictionary = world_2d.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				end_pos = to_local(hit["position"])
	return end_pos

func _on_glow_overlay_draw() -> void:
	if not _glow_overlay:
		return
	if _nvg_glow_active:
		_glow_overlay.draw_rect(Rect2(9.0, -4.0, 3.0, 2.0), Color(0.35, 2.2, 0.55, 0.98))
		_glow_overlay.draw_rect(Rect2(9.0, 2.0, 3.0, 2.0), Color(0.35, 2.2, 0.55, 0.98))
	if _laser_active:
		var laser_end := _laser_end if _laser_end != Vector2.ZERO else (_laser_start + Vector2(350.0, 0.0))
		_glow_overlay.draw_line(_laser_start, laser_end, Color(2.1, 0.22, 0.22, 0.62), 1.0)
		_glow_overlay.draw_rect(Rect2(laser_end - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(2.6, 0.35, 0.35, 0.95))

func _draw() -> void:
	if _hud_overlay:
		_hud_overlay.queue_redraw()

func _on_hud_overlay_draw() -> void:
	if not _hud_overlay:
		return
	var vault_timer := 0.0
	if player and player.has_node("InteractionDetector"):
		vault_timer = float(player.get_node("InteractionDetector").vault_timer)

	var p_rot: float = float(player.rotation) if player else 0.0
	var counter_rot: float = -p_rot - rotation
	if vault_timer > 0.0:
		var ratio := clampf(vault_timer / 1.0, 0.0, 1.0)
		var bar_w := 36.0
		var bar_h := 5.0
		var bar_pos := Vector2(-bar_w / 2.0, -26.0)
		_hud_overlay.draw_set_transform(Vector2(0.0, -position.y), counter_rot, Vector2.ONE)
		_hud_overlay.draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0, 0, 0, 0.85))
		var fill_color := Color(1.0, 0.8, 0.2).lerp(Color(0.2, 0.9, 0.3), ratio)
		_hud_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color)
		_hud_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. 월드 플로팅 텍스트 및 전술 상태 팝업 (플레이어 회전에 무관하게 정방향 표시)
	if floating_texts.size() > 0:
		_hud_overlay.draw_set_transform(Vector2(0.0, -position.y), counter_rot, Vector2.ONE)
		var font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else ThemeDB.fallback_font
		for idx in range(floating_texts.size()):
			var ft = floating_texts[idx]
			var t := clampf(float(ft["elapsed"]) / float(ft["duration"]), 0.0, 1.0)
			var alpha := clampf(1.0 - pow(t, 1.6), 0.0, 1.0)
			var y_off := -30.0 - t * 18.0 - idx * 14.0
			var txt: String = String(ft["text"])
			var col: Color = ft["color"]
			col.a = alpha
			var shadow_col := Color(0.0, 0.0, 0.0, 0.85 * alpha)
			_hud_overlay.draw_string(font, Vector2(-60.0 + 1.0, y_off + 1.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, shadow_col)
			_hud_overlay.draw_string(font, Vector2(-60.0, y_off), txt, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, col)
		_hud_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
