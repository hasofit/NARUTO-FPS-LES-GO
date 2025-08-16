extends Node3D

@onready var timer: Timer = $CanvasLayer/Timer/Timer
@onready var timer_label: Label = $CanvasLayer/Timer
@onready var player: CharacterBody3D = $Player

func _physics_process(delta: float) -> void:
	timer_label.text = str(floor(timer.time_left))
	if player:
		if player.enemies_count < 1:
			timer.paused = true
