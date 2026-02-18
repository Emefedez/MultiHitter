extends Sprite3D

# --- exported configuration (English names) ----------------------------------
@export var character: CharacterBody3D                     # Node to follow (assign in inspector)
@export var max_height: float = 5.0                        # maximum height used for scaling
@export var min_scale: float = 0.1                         # smallest shadow scale
@export var max_scale: float = 0.7                         # largest shadow scale
@export var ground_offset: float = 0.01                    # lift shadow above surface to avoid z-fighting
@export var hide_when_close_to_ground: bool = true         # hide shadow when very close to ground (default: hide)
@export var hide_threshold: float = 0.05                   # threshold (meters) below which shadow may be hidden
@export var ground_lift_factor: float = 0.12               # extra lift proportional to scale to avoid clipping

# alpha / fade settings (smoothly fade shadow by height)
@export var alpha_min: float = 0.0                         # alpha when character is touching the ground
@export var alpha_max: float = 1.0                         # alpha when character is sufficiently above ground
@export var fade_distance: float = 0.70                    # distance (meters) over which alpha interpolates from min->max

@export var debug: bool = false                            # enable debug prints

# --- helper: raycast down from the character and return (distance, hit_position) ---
func get_distance_to_ground():
	if not character:
		return {"distance": max_height, "position": null}

	var from = character.global_position
	var to = from - Vector3.UP * max_height * 2
	var params = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_world_3d().direct_space_state.intersect_ray(params)

	if result:
		var dist = from.y - result.position.y
		return {"distance": dist, "position": result.position}

	return {"distance": max_height, "position": null}

# --- main loop ---------------------------------------------------------------
func _process(_delta: float) -> void:
	if not character:
		return

	# follow character horizontally (X, Z) only
	var char_pos = character.global_position
	global_position.x = char_pos.x
	global_position.z = char_pos.z

	# get vertical distance to the surface under the character
	var ground_info = get_distance_to_ground()
	var distance_to_ground = ground_info.distance
	var ground_pos = ground_info.position

	# SMOOTH ALPHA: compute alpha from distance (no abrupt show/hide)
	var fade_norm = clamp(distance_to_ground / fade_distance, 0.0, 1.0) if fade_distance > 0.0 else 1.0
	var alpha = lerp(alpha_min, alpha_max, fade_norm)

	# apply alpha to sprite modulate (Color is value-type; reassign)
	var c = modulate
	c.a = alpha
	modulate = c

	# keep the node visible while fading; only hide if fully transparent for perf
	visible = alpha > 0.01

	# scale with height: 
	var normalized = clamp(distance_to_ground / max_height, 0.0, 1.5) # 0 (close) ..
	var final_scale = lerp(min_scale, max_scale, normalized)
	scale = Vector3(final_scale, final_scale, final_scale)

	# lift shadow slightly proportional to its size to avoid clipping by geometry
	if ground_pos:
		global_position.y = ground_pos.y + ground_offset + final_scale * ground_lift_factor

	# optional debug output
	if debug:
		print("ShadowFollower | dist=%.3f ground_pos=%s visible=%s scale=%.3f" % [distance_to_ground, str(ground_pos), str(visible), final_scale])
