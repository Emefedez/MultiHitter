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

@export_group("Debug UI")
## Toggle the speed display on/off
@export var show_speed_ui: bool = true
## Optional: Assign an existing Label node from the scene to use instead of generating one
@export var custom_speed_label: Label

# GUI Elements
const SPEED_UI_CANVAS_LAYER: int = 20
var _setup_ui_layer: CanvasLayer
var _speed_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_animation_player()
	if show_speed_ui:
		_setup_speed_ui()

func _setup_animation_player() -> void:
	if not animation_player:
		var players = character_model.find_children("*", "AnimationPlayer", true, false)
		if players.size() > 0:
			animation_player = players[0] as AnimationPlayer

func _setup_speed_ui() -> void:
	# 1. If user assigned a custom label in the Inspector, use it
	if custom_speed_label:
		_speed_label = custom_speed_label
		# Ensure a CanvasLayer ancestor exists and sits above the overlay shader so the label is not sampled
		var node = _speed_label
		var canvas_ancestor: CanvasLayer = null
		while node:
			if node is CanvasLayer:
				canvas_ancestor = node
				break
			node = node.get_parent()
		if canvas_ancestor:
			if canvas_ancestor.layer < SPEED_UI_CANVAS_LAYER:
				canvas_ancestor.layer = SPEED_UI_CANVAS_LAYER
		else:
			# Wrap the custom label in a new CanvasLayer (keeps it on top of the overlay)
			var wrapper := CanvasLayer.new()
			wrapper.name = "SpeedUIWrapper"
			wrapper.layer = SPEED_UI_CANVAS_LAYER
			var old_parent = _speed_label.get_parent()
			if old_parent:
				old_parent.remove_child(_speed_label)
			wrapper.add_child(_speed_label)
			# attach wrapper to the current scene root so it participates in 2D drawing
			if get_tree().current_scene:
				get_tree().current_scene.add_child(wrapper)
		return

	# 2. Otherwise, generate a simple default UI
	# Clean up any existing attempts if necessary
	if _setup_ui_layer: _setup_ui_layer.queue_free()
	
	# Create a CanvasLayer to ensure UI draws above everything (including shaders)
	_setup_ui_layer = CanvasLayer.new()
	_setup_ui_layer.name = "SpeedUI"
	_setup_ui_layer.layer = SPEED_UI_CANVAS_LAYER
	add_child(_setup_ui_layer)
	
	# Create the Label
	_speed_label = Label.new()
	_speed_label.name = "SpeedLabel"
	_speed_label.position = Vector2(20, 20) # Top-left corner
	_speed_label.modulate = Color(1, 1, 0) # Yellow text
	# Add a simple outline for readability
	_speed_label.add_theme_constant_override("outline_size", 6)
	_speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_setup_ui_layer.add_child(_speed_label)

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
	
	# Update GUI with speed
	if _speed_label:
		var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
		_speed_label.text = "Speed: %.2f m/s" % horizontal_speed

func _start_diveroll(direction: Vector3) -> void:
	if not animation_player or not animation_player.has_animation(diveroll_anim_name):
		return

	var anim = animation_player.get_animation(diveroll_anim_name)
	if anim.length <= 0.0: return

	animation_playing = true
	animation_player.play(diveroll_anim_name)
	roll_anim_timer = anim.length
	roll_velocity = _compute_roll_velocity(direction)
	velocity.x = roll_velocity.x
	velocity.z = roll_velocity.z

func _compute_roll_velocity(direction: Vector3) -> Vector3:
	var horizontal = Vector3(direction.x, 0, direction.z)
	var vel_dir = horizontal.normalized() if horizontal.length() > 0.1 else (transform.basis * Vector3.BACK).normalized()
	return Vector3(vel_dir.x, 0, vel_dir.z).normalized() * roll_speed
