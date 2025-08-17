extends RigidBody3D

@onready var player: CharacterBody3D = $"../../Player"
@onready var change: Timer = $Change
@onready var shooting_point: Marker3D = $shooting_point

@export var world : Node3D
@export var kunai : PackedScene
@export var health = 10
@export var ai = false
@export var shooting = false
@export var SPEED = 300
@export var turn_time : float = 1

var left = false

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
	
	new_kunai.linear_velocity = new_kunai.global_transform.basis.z * 30.0
