extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var character_model: Node3D = $CharacterModel

var animation_player: AnimationPlayer = null
var walk_anim_name: String = ""
var idle_anim_name: String = ""

# Mixamo exports all takes as "mixamo.com" -> Godot sanitizes to "mixamo_com".
# Map those ugly names to real ones here. Add more entries as you import more animations.
var anim_rename := {
	"mixamo_com": "walking",
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_animations()

## Find the AnimationPlayer already in the scene and set up animation names
func _setup_animations() -> void:
	var players = character_model.find_children("*", "AnimationPlayer", true, false)
	if players.size() == 0:
		push_warning("No AnimationPlayer found in CharacterModel subtree.")
		return
	animation_player = players[0] as AnimationPlayer
	# Rename Mixamo junk names, then override with .tres if available
	_rename_animations()
	_load_custom_animations()
	var anims = animation_player.get_animation_list()
	print("[Character] Available animations: ", anims)
	for anim_name in anims:
		var lower = anim_name.to_lower()
		if "walk" in lower or "run" in lower:
			walk_anim_name = anim_name
		elif "idle" in lower or "rest" in lower or "stand" in lower:
			idle_anim_name = anim_name
	# Fallback: use the first non-RESET animation for walking
	if walk_anim_name.is_empty():
		for anim_name in anims:
			if anim_name != "RESET":
				walk_anim_name = anim_name
				break
	print("[Character] Walk animation: '", walk_anim_name, "'")
	print("[Character] Idle animation: '", idle_anim_name, "'")

## Renames animations from Mixamo junk names (e.g. "mixamo_com") to proper names
func _rename_animations() -> void:
	if animation_player == null:
		return
	var lib = animation_player.get_animation_library("")
	if lib == null:
		return
	for old_name in anim_rename:
		if lib.has_animation(old_name):
			var new_name: String = anim_rename[old_name]
			var anim = lib.get_animation(old_name)
			lib.remove_animation(old_name)
			lib.add_animation(new_name, anim)
			print("[Character] Renamed animation: '", old_name, "' -> '", new_name, "'")

## Replaces animations with edited .tres files from res://animations/
func _load_custom_animations() -> void:
	if animation_player == null:
		return
	var anims = animation_player.get_animation_list()
	for anim_name in anims:
		if anim_name == "RESET":
			continue
		var tres_path = "res://animations/" + anim_name + ".tres"
		if ResourceLoader.exists(tres_path):
			var custom_anim = load(tres_path) as Animation
			if custom_anim:
				var lib = animation_player.get_animation_library("")
				if lib:
					lib.remove_animation(anim_name)
					lib.add_animation(anim_name, custom_anim)
					print("[Character] Using custom animation: ", anim_name, " from ", tres_path)

## Press F9 during gameplay to extract all FBX animations to editable .tres files
func _extract_animations_to_files() -> void:
	if animation_player == null:
		print("[ExtractAnims] No AnimationPlayer loaded.")
		return
	DirAccess.make_dir_recursive_absolute("res://animations")
	var anims = animation_player.get_animation_list()
	var saved := 0
	for anim_name in anims:
		if anim_name == "RESET":
			continue
		var anim = animation_player.get_animation(anim_name)
		if anim == null:
			continue
		var anim_copy = anim.duplicate(true) as Animation
		var save_path = "res://animations/" + anim_name + ".tres"
		var err = ResourceSaver.save(anim_copy, save_path)
		if err == OK:
			print("[ExtractAnims] Saved: ", save_path)
			saved += 1
		else:
			printerr("[ExtractAnims] FAILED: ", save_path, " error: ", err)
	print("[ExtractAnims] Done! Extracted ", saved, " animations to res://animations/")
	print("[ExtractAnims] Edit the .tres files freely, they'll be used automatically on next run.")

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

	# F9 = extract animations to .tres files
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_extract_animations_to_files()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := SPEED
	if Input.is_action_pressed("move_sprint"):
		current_speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		_play_animation(walk_anim_name)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		if not idle_anim_name.is_empty():
			_play_animation(idle_anim_name)
		elif animation_player and animation_player.is_playing():
			animation_player.stop()

	move_and_slide()

func _play_animation(anim_name: String) -> void:
	if animation_player and not anim_name.is_empty():
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
