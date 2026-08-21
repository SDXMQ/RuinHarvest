# res://scenes/entities/projectiles/bullet.gd
extends Area2D

@export var speed: float = 650.0
@export var damage: float = 25.0
@export var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var traveled_time: float = 0.0

func setup(pos: Vector2, dir: Vector2, dmg: float) -> void:
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()
	damage = dmg

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	traveled_time += delta
	if traveled_time >= max_lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return # 플레이어가 쏜 총알이 플레이어에게 닿는 것 무시
		
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
		queue_free()
	elif body is TileMapLayer:
		var layer = body as TileMapLayer
		var hit_tile_pos = layer.local_to_map(global_position + direction * 4.0)
		var coords = layer.get_cell_atlas_coords(hit_tile_pos)
		if coords == TileManager.OBJ_WINDOW:
			layer.set_cell(hit_tile_pos, 0, TileManager.OBJ_WINDOW_BROKEN)
			EventBus.noise_created.emit(global_position, 400.0, "break")
			EventBus.window_broken.emit(hit_tile_pos)
			EventBus.event_logged.emit("💥 총격으로 창문이 깨졌습니다!")
			if SoundManager: SoundManager.play("hit_melee")
		queue_free()
	elif body is StaticBody2D:
		queue_free()

func _draw() -> void:
	# 노란색 발광 예광탄
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color(1.0, 0.9, 0.3), 2.5)
	draw_circle(Vector2(6, 0), 2.0, Color.WHITE)
