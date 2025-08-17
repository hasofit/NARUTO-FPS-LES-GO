extends RigidBody3D

@onready var player: CharacterBody3D = $"../../Player"
@onready var change: Timer = $Change
@onready var shooting_point: Marker3D = $Shooting

@export var world : Node3D
@export var kunai : PackedScene
@export var health = 10
@export var ai = false
@export var shooting = false
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
	if shooting:
		shoot()
	
	if left:
		left = false
	else:
		left = true

func shoot():
	var new_kunai = kunai.instantiate()
	world.add_child(new_kunai)
	new_kunai.global_transform = shooting_point.global_transform
	
	# Apply forward velocity (along the local -Z axis in 3D)
	new_kunai.linear_velocity = new_kunai.global_transform.basis.z * 30.0
