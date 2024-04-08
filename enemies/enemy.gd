class_name Enemy
extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

signal died

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = -direction
@export var max_speed: float = 50
@export var acceleration: float = 2000

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: Node = $StateMachine
@onready var stats: Node = $Stats
#@onready var hitbox: EnemyHitbox = $Graphics/Hitbox
#@onready var hurtbox: Hurtbox = $Graphics/Hurtbox
#@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D


func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta)
	velocity.y += default_gravity * delta
	
	move_and_slide()


func die() -> void:
	died.emit()
	set_process_mode(PROCESS_MODE_DISABLED)
	#queue_free()


func spawn() -> void:
	set_process_mode(PROCESS_MODE_ALWAYS)
	animation_player.play("idle")
	stats.health = stats.max_health
