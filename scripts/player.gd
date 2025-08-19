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
@onready var enemies: Node3D = %Enemies
@onready var enemy_count: Label = $"../CanvasLayer/Enemy count"

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
@onready var HP_BAR: ProgressBar = $"CanvasLayer/Health Bar"
@onready var slow: Timer = $Slow
@onready var mana_bar: ProgressBar = $"CanvasLayer/Mana Bar"

# --- Movement config ---
@export var base_speed: float = 7.0
@export var jump_speed: float = 10.0
@export var gravity: float = 30.0
@export var world: Node3D
@export var sens = 0.2
@export var health = 10
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

@export var mana = 100
@export var max_mana = 100
@export var mana_regen = 5

var overlapping: Dictionary = {}  # Dictionary<Node3D, float>

# --- Scenes ---
const PLAYER_SCENE := preload("res://scenes/player.tscn")

func _ready() -> void:
	
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	
	HP_BAR.max_value = health

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
	mana_bar.value = mana
	mana_bar.max_value = max_mana
	
	if mana != max_mana:
		mana += mana_regen * delta
	
	if Input.is_action_just_pressed("slow time") and mana > 30:
		mana -= 30
		if Engine.time_scale == 1:
			Engine.time_scale = 0.1
			slow.start()
		else:
			mana += 30
			Engine.time_scale = 1
			slow.stop()
	
	HP_BAR.value = health

	if Input.is_action_just_pressed("ShadowClone") and mana > 20:
		for i in shadow_clone.get_children():
			# Remove any previous clone(s) under this marker
			if i.get_child_count() > 0:
				for child in i.get_children():
					child.queue_free()
				print("cleared?")
			# Spawn a fresh clone under the marker
			New_Clone = PLAYER_SCENE.instantiate()
			i.add_child(New_Clone)
			mana -= 20

	if Input.is_action_pressed("restart"):
		Engine.time_scale = 1
		get_tree().reload_current_scene()

	# --- Throw inputs ---
	if Input.is_action_just_pressed("Kunai Wall") and mana > 10:
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
	for body in overlapping.keys().duplicate():
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
	# Keep visibility tied to throw cooldown if desired
	if throw_cd.one_shot and throw_cd.time_left == 0 and right_hand_kunai.visible == false:
		right_hand_kunai.visible = true
	# Do NOT re-tie monitoring to cooldown; it's re-enabled immediately after throw.

# --- Overlap handlers from Area3D ---
func _on_kunai_body_entered(body: Node3D) -> void:
	if body == self:
		return
	# Start at 0 so the first tick can happen ASAP
	overlapping[body] = 0.0

func _on_kunai_body_exited(body: Node3D) -> void:
	if overlapping.has(body):
		overlapping.erase(body)

# --- Damage application ---
func _apply_contact_damage(body: Node) -> void:
	if body == null or !is_instance_valid(body):
		return

	# Preferred: enemies implement apply_damage(damage: int)
	if body.has_method("apply_damage"):
		body.apply_damage(damage_per_tick)
		return

	# Fallback: manipulate a "health" property if present
	# All Objects have get()/set(); get("health") returns null if missing.
	var current_hp = body.get("health")
	if current_hp != null:
		var hp := int(current_hp) - damage_per_tick
		body.set("health", hp)
		if hp < 1 and overlapping.has(body):
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

	# ✅ Re-enable the hand hitbox immediately on the next frame (avoids same-frame self-hits)
	if kunai_area:
		call_deferred("_reenable_kunai_area")

func _reenable_kunai_area() -> void:
	if is_instance_valid(kunai_area):
		kunai_area.monitoring = true

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
			mana -= 10
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


func _on_slow_timeout() -> void:
	Engine.time_scale = 1
