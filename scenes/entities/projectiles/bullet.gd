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
	elif body is TileMapLayer or body is StaticBody2D:
		queue_free()

func _draw() -> void:
	# 노란색 발광 예광탄
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color(1.0, 0.9, 0.3), 2.5)
	draw_circle(Vector2(6, 0), 2.0, Color.WHITE)
