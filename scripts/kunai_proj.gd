extends RigidBody3D

@onready var enemies: Node3D = $Enemies
@onready var player: CharacterBody3D = $Player

@export var damage: int = 20
@export var lifetime: float = 6.0

var owner_player: Node = null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	$Life.start(lifetime)
	# Optional: spin a bit for flair
	angular_velocity = Vector3(20, 0, 0) * PI/180.0

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	_apply_damage(body)
	queue_free()

func _apply_damage(body: Node) -> void:
	if body.is_in_group("Damagbele"):
		body.health -= damage
		if body.health < 1:
			if body.name == "Player":
				get_tree().reload_current_scene()
			else:
				if body.get_parent() == enemies:
					player.enemies_count -= 1
					player.enemy_count.text = player.enemies_count
				body.queue_free()

func _on_life_timeout() -> void:
	queue_free()
