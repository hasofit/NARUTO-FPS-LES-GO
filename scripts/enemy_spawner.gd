extends MeshInstance3D

@onready var cooldown: Timer = $Cooldown

@export var LVL = 1

var new_enemy = null
var should_spawn = true

func _physics_process(delta: float) -> void:
	if !new_enemy and should_spawn:
		cooldown.stop()
		const TEST_DUMMY = preload("res://scenes/test_dummy.tscn")
		new_enemy = TEST_DUMMY.instantiate()
		add_child(new_enemy)
		new_enemy.global_position = global_position
		new_enemy.chasing = true
		new_enemy.LVL = LVL
		should_spawn = false
		cooldown.start()

func _on_cooldown_timeout() -> void:
	should_spawn = true
