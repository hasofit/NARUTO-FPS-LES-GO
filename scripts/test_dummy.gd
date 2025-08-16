extends RigidBody3D

@onready var player: CharacterBody3D = $"../../Player"

var health = 10

func _physics_process(delta: float) -> void:
	if health < 1:
		player.enemies_count -= 1
		player.enemy_count.text = str(player.enemies_count)
		queue_free()
