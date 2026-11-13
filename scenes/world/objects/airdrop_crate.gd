# res://scenes/world/objects/airdrop_crate.gd
extends StaticBody2D

signal crate_landed(drop_pos: Vector2)

enum DropState { FLARE_PHASE, CHUTE_FALL, LANDED_IMPACT, LOOTABLE }

var current_state: DropState = DropState.FLARE_PHASE
var state_timer: float = 0.0
var flare_timer: float = 0.0
var is_looted: bool = false
var interactable_type: Vector2i = Vector2i(-1, -1)

var col: CollisionShape2D = null

const FLARE_DURATION: float = 2.5
const FALL_DURATION: float = 3.0
const IMPACT_DURATION: float = 0.25

var fall_altitude: float = -450.0
var chute_sway: float = 0.0

var _chute_spr: Sprite2D = null
var _crate_spr: Sprite2D = null
var _flare_light: PointLight2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	col.shape = rect
	col.disabled = true
	add_child(col)

	_setup_pixel_visuals()

	current_state = DropState.FLARE_PHASE
	state_timer = 0.0
	interactable_type = Vector2i(-1, -1)

	# 1단계(FLARE_PHASE): 지면 적색 신호탄 연막 파티클/사운드
	if SoundManager:
		SoundManager.play("explosion_distant")
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("smoke", global_position.x, global_position.y, 10)

func _setup_pixel_visuals() -> void:
	var props_tex: CanvasTexture = PixelAssetManager.get_canvas_texture("props/world_props") if PixelAssetManager else null
	var mat_chute: ShaderMaterial = PixelAssetManager.create_pixel_entity_material(0.20) if PixelAssetManager else null
	var mat_crate: ShaderMaterial = PixelAssetManager.create_pixel_entity_material(0.26) if PixelAssetManager else null

	_chute_spr = Sprite2D.new()
	_chute_spr.name = "ChutePixelSprite"
	_chute_spr.centered = true
	_chute_spr.region_enabled = true
	_chute_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chute_spr.z_index = 1
	_chute_spr.visible = false
	if props_tex:
		_chute_spr.texture = props_tex
	if mat_chute:
		_chute_spr.material = mat_chute
	add_child(_chute_spr)

	_crate_spr = Sprite2D.new()
	_crate_spr.name = "CratePixelSprite"
	_crate_spr.centered = true
	_crate_spr.region_enabled = true
	_crate_spr.region_rect = Rect2(0, 96, 48, 48)
	_crate_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crate_spr.z_index = 2
	_crate_spr.visible = false
	if props_tex:
		_crate_spr.texture = props_tex
	if mat_crate:
		_crate_spr.material = mat_crate
	add_child(_crate_spr)

	_flare_light = PointLight2D.new()
	_flare_light.name = "FlareLight"
	_flare_light.position = Vector2(22, 14)
	_flare_light.color = Color(1.0, 0.24, 0.14)
	_flare_light.energy = 1.4
	_flare_light.height = 28.0
	_flare_light.texture_scale = 2.6
	if PixelAssetManager:
		_flare_light.texture = PixelAssetManager.get_radial_light_texture()
	add_child(_flare_light)

func _process(delta: float) -> void:
	flare_timer += delta
	state_timer += delta

	match current_state:
		DropState.FLARE_PHASE:
			if state_timer >= FLARE_DURATION:
				current_state = DropState.CHUTE_FALL
				state_timer = 0.0
				fall_altitude = -450.0
		DropState.CHUTE_FALL:
			var t = clamp(state_timer / FALL_DURATION, 0.0, 1.0)
			fall_altitude = lerp(-450.0, 0.0, t)
			chute_sway = sin(state_timer * 3.5) * 12.0 * (1.0 - t * 0.4)
			if state_timer >= FALL_DURATION:
				current_state = DropState.LANDED_IMPACT
				state_timer = 0.0
				fall_altitude = 0.0
				chute_sway = 0.0
				crate_landed.emit(global_position)

				# 3단계(LANDED_IMPACT): 지면 충돌 사운드, 착지 먼지 파티클, 카메라 쉐이크
				if SoundManager:
					SoundManager.play("hit_melee")
				var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
				if ps:
					ps.emit("dust", global_position.x, global_position.y, 14)
				if EventBus.has_signal("camera_shake_requested"):
					EventBus.camera_shake_requested.emit(6.0, 0.4)
		DropState.LANDED_IMPACT:
			if state_timer >= IMPACT_DURATION:
				# 4단계(LOOTABLE): 낙하산 쓰러짐, 충돌체/상호작용 프롬프트 활성화
				current_state = DropState.LOOTABLE
				state_timer = 0.0
				if col:
					col.disabled = false
				collision_layer = 1
				interactable_type = Vector2i(7, 2)
		DropState.LOOTABLE:
			pass

	_sync_pixel_sprites()
	queue_redraw()

func _sync_pixel_sprites() -> void:
	if _flare_light:
		_flare_light.energy = 1.15 + 0.55 * sin(flare_timer * 7.5)
	if not _crate_spr or not _chute_spr:
		return

	match current_state:
		DropState.FLARE_PHASE:
			_crate_spr.visible = false
			_chute_spr.visible = false
		DropState.CHUTE_FALL:
			var crate_center := Vector2(chute_sway, fall_altitude)
			_crate_spr.visible = true
			_crate_spr.position = crate_center
			_chute_spr.visible = true
			_chute_spr.region_rect = Rect2(48, 96, 96, 48)
			_chute_spr.position = crate_center + Vector2(0, -64)
			_chute_spr.z_index = 3
			_chute_spr.modulate.a = 0.96
		DropState.LANDED_IMPACT, DropState.LOOTABLE:
			_crate_spr.visible = true
			_crate_spr.position = Vector2.ZERO
			_chute_spr.visible = true
			_chute_spr.region_rect = Rect2(144, 96, 64, 48)
			_chute_spr.position = Vector2(-10, -28)
			_chute_spr.z_index = 1
			_chute_spr.modulate.a = 0.90

func _draw() -> void:
	var flare_pos = Vector2(22, 14)
	_draw_flare_and_smoke(flare_pos)

	match current_state:
		DropState.FLARE_PHASE:
			# 1단계: 지면 착지 지점 적색 신호탄 표식 및 HDR 경고 링
			draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.6, 0.3, 0.2, 0.78), 1.5)
			draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.6, 0.3, 0.2, 0.78), 1.5)
			draw_arc(Vector2.ZERO, 18.0, 0, TAU, 20, Color(1.8, 0.35, 0.2, 0.55), 1.2)

		DropState.CHUTE_FALL:
			# 2단계: 지면 원형 그림자 확대 및 낙하산 현수줄
			var t = clamp(state_timer / FALL_DURATION, 0.0, 1.0)
			var shadow_radius = lerp(4.0, 24.0, t)
			var shadow_alpha = lerp(0.22, 0.58, t)
			draw_circle(Vector2.ZERO, shadow_radius, Color(0.02, 0.03, 0.04, shadow_alpha))

			var crate_center := Vector2(chute_sway, fall_altitude)
			var chute_apex := crate_center + Vector2(0, -64)
			draw_line(crate_center + Vector2(-15, -16), chute_apex + Vector2(-36, 12), Color(0.78, 0.80, 0.72, 0.78), 1.0)
			draw_line(crate_center + Vector2(15, -16), chute_apex + Vector2(36, 12), Color(0.78, 0.80, 0.72, 0.78), 1.0)
			draw_line(crate_center + Vector2(-7, -16), chute_apex + Vector2(-12, 12), Color(0.78, 0.80, 0.72, 0.72), 1.0)
			draw_line(crate_center + Vector2(7, -16), chute_apex + Vector2(12, 12), Color(0.78, 0.80, 0.72, 0.72), 1.0)

		DropState.LANDED_IMPACT, DropState.LOOTABLE:
			# 3~4단계: 지면 박스 드롭 섀도우 & 낙하산 끈
			draw_rect(Rect2(-15, -15, 42, 42), Color(0.02, 0.03, 0.05, 0.48))
			draw_line(Vector2(-12, -14), Vector2(-24, -28), Color(0.7, 0.72, 0.64, 0.6), 1.0)
			draw_line(Vector2(10, -14), Vector2(-2, -26), Color(0.7, 0.72, 0.64, 0.6), 1.0)

func _draw_flare_and_smoke(flare_pos: Vector2) -> void:
	# 붉은색 신호탄 HDR 플레어 코어 및 도트 연막
	var pulse = 0.65 + 0.35 * sin(flare_timer * 6.5)
	draw_circle(flare_pos, 16.0 * pulse, Color(1.4, 0.22, 0.12, 0.20 * pulse))
	draw_circle(flare_pos, 8.0 * pulse, Color(1.8, 0.32, 0.16, 0.45 * pulse))
	draw_rect(Rect2(flare_pos - Vector2(2, 2), Vector2(4, 4)), Color(2.4, 0.45, 0.22, 0.98))

	for i in range(4):
		var t: float = fmod(flare_timer * 0.75 + float(i) * 0.25, 1.0)
		var sp: Vector2 = flare_pos + Vector2(sin(flare_timer * 2.2 + float(i) * 1.4) * 7.0 * t, -t * 30.0)
		var smoke_sz: float = floorf(4.0 + t * 8.0)
		var smoke_alpha: float = (1.0 - t) * 0.48
		draw_rect(Rect2(Vector2(floorf(sp.x - smoke_sz * 0.5), floorf(sp.y - smoke_sz * 0.5)), Vector2(smoke_sz, smoke_sz)), Color(0.95, 0.28, 0.22, smoke_alpha))
