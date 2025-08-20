extends RigidBody3D

@onready var player: CharacterBody3D = $"../../Player"
@onready var change: Timer = $Change
@onready var shooting_point: Marker3D = $shooting_point
@onready var lvl_label: Label3D = $Lvl_Label
@onready var health_label: Label3D = $Health_Label

@export var world : Node3D
@export var kunai : PackedScene
@export var health = 10
@export var ai = false
@export var shooting = false
@export var SPEED = 300
@export var turn_time : float = 1
@export var LVL = 1
@export var chasing = false

var left = false

func _ready() -> void:
	change.start(turn_time)
	
	lvl_label.text = "LVL: " + str(LVL)
	health *= LVL / 10 + 1
	health_label.text = str(health)

func _physics_process(delta: float) -> void:
	
	if chasing:
		global_position = global_position.move_toward(player.global_position, 10 * delta)
	
	health_label.text = str(health)
	
	if health < 1:
		player.xp_up(10)
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
	
	new_kunai.linear_velocity = new_kunai.global_transform.basis.z * 30.0
