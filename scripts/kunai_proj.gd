extends RigidBody3D

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
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	elif "health" in body:
		body.health -= damage
		if body.health < 1:
			body.queue_free()

func _on_life_timeout() -> void:
	queue_free()
