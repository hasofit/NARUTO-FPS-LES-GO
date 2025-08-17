extends RigidBody3D

@onready var player: CharacterBody3D = $"../../Player"
@onready var change: Timer = $Change

@export var health = 10
@export var ai = false
@export var SPEED = 300
@export var turn_time = 1

var left = false

func _ready() -> void:
	change.start(turn_time)

func _physics_process(delta: float) -> void:
	if health < 1:
		player.enemies_count -= 1
		player.enemy_count.text = str(player.enemies_count)
		queue_free()
	if ai:
		if left:
			global_position += -transform.basis.x * SPEED * delta
		elif !left:
			global_position += transform.basis.x * SPEED * delta
		lock_rotation = true
	else:
		lock_rotation = false

func _on_change_timeout() -> void:
	if left:
		left = false
	else:
		left = true
