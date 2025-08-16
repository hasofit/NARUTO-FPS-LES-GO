extends CharacterBody3D

# --- Projectile throwing config ---
@export var throw_projectile_scene: PackedScene
@export var wall_projectile_scene: PackedScene
@export var throw_speed: float = 38.0
@export var throw_cooldown: float = 0.55
@export var wall_cooldown: float = 1.0

@onready var cam: Camera3D = %Camera3D
@onready var right_hand_kunai: Node3D = $"Camera3D/Right Hand/Kunai"
@onready var throw_cd: Timer = Timer.new()
@onready var wall_cd: Timer = Timer.new()
@onready var kunai_wall: Node3D = $Kunai_Wall
@onready var enemies: Node3D = $"../Enemies"
@onready var enemy_count: Label = $"../CanvasLayer/Enemy count"
@onready var timer: Timer = $"../CanvasLayer/Timer/Timer"
@onready var timer_label: Label = $"../CanvasLayer/Timer"

# --- Nodes ---
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var damage_cooldown: Timer = $DamageCooldown

# Melee hit Area3D (assign in Inspector)
@export var kunai_area_path: NodePath
@onready var kunai_area: Area3D = get_node_or_null(kunai_area_path)
@onready var collision_shape_3d: CollisionShape3D = $"Camera3D/Right Hand/Kunai/CollisionShape3D"
@onready var shadow_clone: Node3D = $ShadowClone
@onready var shadow_clone_1_marker: Marker3D = $ShadowClone/ShadowClone1Marker
@onready var shadow_clone_2_marker: Marker3D = $ShadowClone/ShadowClone2Marker

# --- Movement config ---
@export var base_speed: float = 7.0
@export var jump_speed: float = 10.0
@export var gravity: float = 30.0
@export var world: Node3D
@export var sens = 0.2
var is_sprinting := false
var enemies_count = 0
var New_Clone

# >>> double-jump
@export var max_jumps: int = 2
var jumps_left: int = 0
# <<<

# --- Contact DPS config ---
@export var damage_per_tick: int = 1
@export var tick_interval: float = 0.2
var overlapping: Dictionary = {}  # Dictionary<Node3D, float>

# --- Scenes ---
const PLAYER_SCENE := preload("res://scenes/player.tscn")

func _ready() -> void:
	if !Input.is_action_pressed("ShadowClone"):
		for i in enemies.get_children():
			enemies_count += 1
			enemy_count.text = str(enemies_count)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Validate & configure the Area3D
	if kunai_area == null:
		push_error("kunai_area_path is not set or not an Area3D. Assign it in the Inspector.")
	else:
		kunai_area.monitoring = true
		kunai_area.monitorable = true
		if not kunai_area.body_entered.is_connected(_on_kunai_body_entered):
			kunai_area.body_entered.connect(_on_kunai_body_entered)
		if not kunai_area.body_exited.is_connected(_on_kunai_body_exited):
			kunai_area.body_exited.connect(_on_kunai_body_exited)

	# Cooldown timers
	add_child(throw_cd)
	throw_cd.one_shot = true
	add_child(wall_cd)
	wall_cd.one_shot = true

	# >>> double-jump
	jumps_left = max_jumps
	# <<<

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * sens
		%Camera3D.rotation_degrees.x -= event.relative.y * (sens / 2)
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -60.0, 60.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Start"):
		timer.start()
	
	if Input.is_action_just_pressed("ShadowClone"):
		for i in shadow_clone.get_children():
			# Remove any previous clone(s) under this marker
			if i.get_child_count() > 0:
				for child in i.get_children():
					child.queue_free()  # <-- FIX: free the child, not self
				print("cleared?")
			# Spawn a fresh clone under the marker
			New_Clone = PLAYER_SCENE.instantiate()
			i.add_child(New_Clone)
	
	if Input.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	# --- Throw inputs ---
	if Input.is_action_just_pressed("Kunai Wall"):
		_fire_kunai_wall()                # uses wall_cd

	if Input.is_action_just_pressed("throw"):
		_throw_from_hand()                # uses throw_cd

	# --- Movement ---
	var input_2d := Input.get_vector("move_right", "move_left", "move_forward", "move_backwards")
	var input_3d := Vector3(input_2d.x, 0, input_2d.y)
	var direction := transform.basis * input_3d

	var speed := base_speed * (2.0 if is_sprinting else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	velocity.y -= gravity * delta

	# >>> double-jump: reset jumps on floor, consume on press
	if is_on_floor() and velocity.y <= 0.0:
		jumps_left = max_jumps

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_speed
			jumps_left = max_jumps - 1
		elif jumps_left > 0:
			velocity.y = jump_speed
			jumps_left -= 1
	# <<<

	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()

	if Input.is_action_just_pressed("sprint"):
		is_sprinting = true
	if Input.is_action_just_released("sprint"):
		is_sprinting = false

	if Input.is_action_pressed("hit"):
		animation_player.play("Kunai")

	# --- Continuous contact damage ticking ---
	for body in overlapping.keys():
		if not is_instance_valid(body):
			overlapping.erase(body)
			continue

		overlapping[body] += delta
		if overlapping[body] >= tick_interval:
			overlapping[body] -= tick_interval
			_apply_contact_damage(body)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	animation_player.play("RESET")

func _process(_delta: float) -> void:
	# Only hand throw toggles the visible/Area3D, so restore based on throw_cd
	if throw_cd.one_shot and throw_cd.time_left == 0 and right_hand_kunai.visible == false:
		right_hand_kunai.visible = true
		if kunai_area:
			kunai_area.monitoring = true

# --- Overlap handlers from Area3D ---
func _on_kunai_body_entered(body: Node3D) -> void:
	if body == self:
		return
	overlapping[body] = tick_interval

func _on_kunai_body_exited(body: Node3D) -> void:
	overlapping.erase(body)

# --- Damage application ---
func _apply_contact_damage(body: Node) -> void:
	if body == null:
		return
	if body.has_method("apply_damage"):
		body.apply_damage(damage_per_tick)
	elif "health" in body:
		body.health -= damage_per_tick
		if body.health < 1:
			overlapping.erase(body)

# =========================
# Throwing helpers
# =========================

func _throw_from_hand() -> void:
	if throw_projectile_scene == null:
		push_error("Assign 'throw_projectile_scene' in the Inspector.")
		return
	if throw_cd.time_left > 0.0:
		return

	# Disable hand hitbox/mesh before spawning (same-frame safety)
	if kunai_area:
		kunai_area.monitoring = false
	right_hand_kunai.visible = false

	var proj := throw_projectile_scene.instantiate() as RigidBody3D
	var spawn_origin: Vector3 = right_hand_kunai.global_transform.origin
	var dir: Vector3 = _aim_dir_from_camera(spawn_origin)

	# Safe spawn a bit forward; clamp to just before any obstruction
	var desired_offset: float = 0.35
	var space := get_world_3d().direct_space_state
	var check_from: Vector3 = spawn_origin
	var check_to: Vector3 = spawn_origin + dir * desired_offset
	var params := PhysicsRayQueryParameters3D.create(check_from, check_to)
	params.exclude = [self]
	var hit := space.intersect_ray(params)
	if hit:
		spawn_origin = hit.position - dir * 0.02
	else:
		spawn_origin += dir * desired_offset

	# Transform & velocity (carry some player speed)
	var spawn_xform := Transform3D(right_hand_kunai.global_transform.basis, spawn_origin)
	proj.global_transform = spawn_xform
	proj.linear_velocity = dir * throw_speed + velocity * 0.35

	# Collision exceptions
	proj.add_collision_exception_with(self)
	for n in right_hand_kunai.get_children():
		if n is CollisionObject3D:
			proj.add_collision_exception_with(n)

	get_tree().current_scene.add_child(proj)
	throw_cd.start(throw_cooldown)

# Raycast from camera to crosshair; return direction from a given origin.
func _aim_dir_from_camera(spawn_origin: Vector3, max_dist: float = 2000.0) -> Vector3:
	var cam_from: Vector3 = cam.global_transform.origin
	var cam_to: Vector3 = cam_from + (-cam.global_transform.basis.z) * max_dist
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(cam_from, cam_to)
	params.exclude = [self]
	var hit := space.intersect_ray(params)
	if hit:
		var hit_pos: Vector3 = hit.position
		return (hit_pos - spawn_origin).normalized()
	return (-cam.global_transform.basis.z).normalized()

func _fire_kunai_wall() -> void:
	if wall_projectile_scene == null:
		push_error("Assign 'wall_projectile_scene' in the Inspector.")
		return
	if wall_cd.time_left > 0.0:
		return
	for m in kunai_wall.get_children():
		if m is Marker3D:
			_spawn_from_marker(m as Marker3D)
	wall_cd.start(wall_cooldown)

func _spawn_from_marker(m: Marker3D) -> void:
	var proj := wall_projectile_scene.instantiate() as RigidBody3D
	var origin: Vector3 = m.global_transform.origin
	var dir: Vector3 = -m.global_transform.basis.z.normalized()
	var spawn_transform := Transform3D(m.global_transform.basis, origin + dir * 0.35)
	proj.global_transform = spawn_transform
	proj.linear_velocity = dir * throw_speed
	proj.add_collision_exception_with(self)
	get_tree().current_scene.add_child(proj)

func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
