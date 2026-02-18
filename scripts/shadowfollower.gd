extends Sprite3D

# --- exported configuration (English names) ----------------------------------
@export var character: CharacterBody3D
@export var max_height: float = 5.0
@export var ground_offset: float = 0.12                    # Increased lift to avoid "too low" look
@export var shadow_max_scale: float = 0.8                  # Adjusted default scale

func _ready() -> void:
	if not character: character = get_parent() as CharacterBody3D
	axis = Vector3.AXIS_Y
	visible = false

func _process(_delta: float) -> void:
	if not character: return

	# Raycast from character center downwards
	var from = character.global_position + Vector3.UP * 0.5
	var to = character.global_position - Vector3.UP * max_height
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self, character]
	
	var res = get_world_3d().direct_space_state.intersect_ray(query)
	if not res:
		visible = false
		return

	# Calculate distance and scale
	var dist = character.global_position.y - res.position.y
	var alpha = clamp(1.0 - (dist / max_height), 0.0, 1.0)
	
	visible = alpha > 0.01
	modulate.a = alpha * 0.8
	
	var final_scale = lerp(shadow_max_scale, 0.1, dist / max_height)
	scale = Vector3.ONE * final_scale
	
	# Position exactly at hit point with a fixed lift
	global_position = Vector3(character.global_position.x, res.position.y + ground_offset, character.global_position.z)
	global_rotation = Vector3.ZERO
