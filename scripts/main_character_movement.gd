extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

## Set Camera on Model
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var character_model: Node3D = $CharacterModel

# Animation helpers
var animation_playing: bool = false
var roll_anim_timer: float = 0.0
var roll_velocity: Vector3 = Vector3.ZERO

# roll movement (scripted root motion replacement)
@export var roll_speed: float = 8.0    # horizontal speed applied while rolling (tweak in Inspector)


# --- JUMP ANIMATION LOCKOUT ---
var jump_anim_timer: float = 0.0
const JUMP_ANIM_DURATION = 1.75 # seconds, adjust as needed

# EXPORT VARIABLES - Set these in the Inspector!
@export_group("Animation Setup")
## Assign the AnimationPlayer from your character model here
@export var animation_player: AnimationPlayer
## Name of the walking animation in the AnimationPlayer
@export var walk_anim_name: String = "walking"
## Name of the idle animation in the AnimationPlayer
@export var idle_anim_name: String = "idle"
## Name for jump animation
@export var jump_anim_name: String = "jump"
## Name for diveroll animation
@export var diveroll_anim_name: String = "diveroll"

# DEBUG FUNCTION - Prints all available animations in the assigned AnimationPlayer

func _debug_print_animations() -> void:
	if animation_player:
		var anims = animation_player.get_animation_list()
		print("[Character] Available animations: ", anims)
		# Try to help the user if defaults are wrong
		if anims.has("mixamo_com"):
			print("[Character] TIP: Found 'mixamo_com'. You might want to rename it or change the Walk Anim Name setting.")
		# Check diveroll presence and give quick guidance
		if not diveroll_anim_name.is_empty() and not anims.has(diveroll_anim_name):
			print("[Character] NOTE: diveroll_anim_name ('%s') not present in AnimationPlayer." % diveroll_anim_name)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Auto-find AnimationPlayer if not assigned manually
	if animation_player == null:
		var players = character_model.find_children("*", "AnimationPlayer", true, false)
		if players.size() > 0:
			animation_player = players[0] as AnimationPlayer
			print("[Character] Auto-found AnimationPlayer: ", animation_player.name)
			_debug_print_animations()
		else:
			push_warning("[Character] No AnimationPlayer found! Assign it in the Inspector or check your model.")
	else:
		# If animation_player was manually assigned, print its animations for debugging
		_debug_print_animations()

## Handle mouse look and cursor toggle
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-40), deg_to_rad(50))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		animation_player.play(jump_anim_name)
		velocity.y = JUMP_VELOCITY
		jump_anim_timer = JUMP_ANIM_DURATION

	if not is_on_floor() and (roll_anim_timer==0.0):
		velocity += get_gravity() * delta
		if not is_on_floor() and (JUMP_ANIM_DURATION > 0.0):
			animation_player.play(jump_anim_name)
    
	# Update jump animation timer
	if jump_anim_timer > 0.0:
		jump_anim_timer -= delta

	if is_on_floor() and (jump_anim_timer < (JUMP_ANIM_DURATION - 1)):
		jump_anim_timer = 0.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := SPEED
	if Input.is_action_pressed("move_sprint"):
		current_speed = SPRINT_SPEED

	if Input.is_action_just_pressed("move_crouch") and not animation_playing and roll_anim_timer <= 0.0:
		_start_diveroll(direction)

	if roll_anim_timer > 0.0:
		roll_anim_timer -= delta
		if roll_anim_timer <= 0.0:
			roll_anim_timer = 0.0
			animation_playing = false
			roll_velocity = Vector3.ZERO
		velocity.x = roll_velocity.x
		velocity.z = roll_velocity.z
	else:
		# Only play walk/idle if not in jump animation lockout
		if jump_anim_timer <= 0.0:
			if direction and (!animation_playing):
				velocity.x = direction.x * current_speed 
				velocity.z = direction.z * current_speed
				animation_player.play(walk_anim_name)
			else:
				velocity.x = move_toward(velocity.x, 0, current_speed) 
				velocity.z = move_toward(velocity.z, 0, current_speed)
				if not idle_anim_name.is_empty(): 
					animation_player.play(idle_anim_name)
				elif animation_player and animation_player.is_playing():
					animation_player.stop()
		else:
			# Still update velocity, but don't override jump animation
			if direction:
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed
			else:
				velocity.x = move_toward(velocity.x, 0, current_speed)
				velocity.z = move_toward(velocity.z, 0, current_speed)

	# finally, apply physics movement
	move_and_slide()

func _start_diveroll(direction: Vector3) -> void:
	if animation_player == null:
		push_warning("[Character] Cannot play diveroll: no AnimationPlayer assigned.")
		return

	if diveroll_anim_name.is_empty():
		push_warning("[Character] Diveroll animation name is empty; assign one in Inspector.")
		return

	if not animation_player.has_animation(diveroll_anim_name):
		push_warning("[Character] Diveroll '%s' not found on AnimationPlayer." % diveroll_anim_name)
		return

	var anim = animation_player.get_animation(diveroll_anim_name)
	var anim_len = anim.length if anim else 0.0
	var track_count = anim.get_track_count() if anim else 0

	if anim_len <= 0.0 or track_count == 0:
		push_warning("[Character] Diveroll '%s' has length=%.3f tracks=%d — skipping." % [diveroll_anim_name, anim_len, track_count])
		return

	animation_playing = true
	animation_player.play(diveroll_anim_name)
	roll_anim_timer = anim_len
	roll_velocity = _compute_roll_velocity(direction)
	velocity.x = roll_velocity.x
	velocity.z = roll_velocity.z
	print("[Character] Playing diveroll '%s' (len=%.3f, tracks=%d) roll_vel=%s" % [diveroll_anim_name, anim_len, track_count, str(roll_velocity)])

func _compute_roll_velocity(direction: Vector3) -> Vector3:
	var horizontal = Vector3(direction.x, 0, direction.z)
	if horizontal.length() > 0.1:
		return horizontal.normalized() * roll_speed
	var forward = (transform.basis * Vector3(0, 0, 1)).normalized()
	return Vector3(forward.x, 0, forward.z).normalized() * roll_speed