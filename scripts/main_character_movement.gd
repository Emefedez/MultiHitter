extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

## Set Camera on Model
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var character_model: Node3D = $CharacterModel

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

# DEBUG FUNCTION - Prints all available animations in the assigned AnimationPlayer

func _debug_print_animations() -> void:
	if animation_player:
		var anims = animation_player.get_animation_list()
		print("[Character] Available animations: ", anims)
		# Try to help the user if defaults are wrong
		if not anims.has(walk_anim_name):
			print("[Character] WARNING: Configured walk animation '" + walk_anim_name + "' not found in list.")
			if anims.has("mixamo_com"):
				print("[Character] TIP: Found 'mixamo_com'. You might want to rename it or change the Walk Anim Name setting.")
		if not anims.has(jump_anim_name):
			print("[Character] WARNING: Configured jump animation '" + jump_anim_name + "' not found in list.")

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

	if not is_on_floor():
		velocity += get_gravity() * delta
		if not is_on_floor() and (JUMP_ANIM_DURATION> 0.0):
			animation_player.play(jump_anim_name)
	

	# Update jump animation timer
	if jump_anim_timer > 0.0:
		jump_anim_timer -= delta

	if is_on_floor() and (jump_anim_timer<(JUMP_ANIM_DURATION-1)):
		jump_anim_timer = 0.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := SPEED
	if Input.is_action_pressed("move_sprint"):
		current_speed = SPRINT_SPEED

	# Only play walk/idle if not in jump animation lockout
	if jump_anim_timer <= 0.0: #if not in jump animation lockout
		if direction: #choose direction
			velocity.x = direction.x * current_speed 
			velocity.z = direction.z * current_speed
			_play_animation(walk_anim_name)
		else: #smoothly decelerate to stop when no input
			velocity.x = move_toward(velocity.x, 0, current_speed) 
			velocity.z = move_toward(velocity.z, 0, current_speed)
			if not idle_anim_name.is_empty(): 
				_play_animation(idle_anim_name)
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

	move_and_slide()

func _play_animation(anim_name: String) -> void: 
		if animation_player.has_animation(anim_name):
			if animation_player.current_animation != anim_name:
				animation_player.play(anim_name)
		else:
			# Prevent spamming errors every frame
			if Engine.get_process_frames() % 60 == 0: 
				printerr("[Character] Missing animation: ", anim_name)

