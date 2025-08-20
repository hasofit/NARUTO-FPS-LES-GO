extends Panel

@onready var player: CharacterBody3D = $"../.."
@onready var mana___10: Button = $"Mana + 10 Icon/Mana + 10"

func _on_mana__10_pressed() -> void:
	if player.skill_points >= 1:
		player.max_mana *= 1.1
		player.skill_points -= 1
		#mana___10.set_disabled(true)

func _on_speed__10_pressed() -> void:
	if player.skill_points >= 1:
		player.base_speed *= 1.1
		player.skill_points -= 1

func _on_health__10_pressed() -> void:
	if player.skill_points >= 1:
		player.max_health *= 1.1
		player.skill_points -= 1
