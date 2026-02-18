extends Node3D

@export var character_scene: PackedScene
var character_instance: Node3D = null
var preview_camera: Camera3D = null

func _ready() -> void:
	# 0) Check if a character is already present as a child (e.g. placed in editor)
	for child in get_children():
		if child is Node3D and not (child is Camera3D) and (child.name.to_lower().contains("dude") or child.name.to_lower().contains("character") or child is CharacterBody3D):
			character_instance = child
			print("[Preview] Usando personaje existente: ", child.name)
			_prepare_for_preview(character_instance)
			
			# Notify all scripts that want the model node (title_rotation, etc.)
			_notify_controllers(character_instance)
			break

	# 1) If no child found, instantiate the configured character
	if character_instance == null:
		if character_scene:
			_show_character(character_scene)
		elif ResourceLoader.exists("res://scenes/main_character.tscn"):
			_show_character(load("res://scenes/main_character.tscn") as PackedScene)

	# 2) Prefer a Camera3D already present in the preview subtree
	preview_camera = _find_camera(self)
	if preview_camera:
		preview_camera.current = true
		print("[Preview] Using existing Camera3D: ", preview_camera.name)
		return

	# 2) If no preview camera but the instantiated character contains a Camera3D, clone its global transform
	if character_instance:
		var char_cam: Camera3D = _find_camera(character_instance)
		if char_cam:
			preview_camera = Camera3D.new()
			preview_camera.name = "PreviewCamera_Cloned"
			add_child(preview_camera)
			# copy global transform so camera sits exactly where the character's camera was
			preview_camera.global_transform = char_cam.global_transform
			preview_camera.current = true
			print("[Preview] Cloned camera transform from character's Camera3D: ", char_cam.name)
			return

	# 3) Fallback: create a default preview camera
	preview_camera = Camera3D.new()
	preview_camera.name = "PreviewCamera"
	add_child(preview_camera)
	preview_camera.transform.origin = Vector3(0.07, 0.03, 0.65)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_camera.current = true
	print("[Preview] Created fallback Camera3D (PreviewCamera)")

# Accept either a PackedScene or a path string
func set_character_scene(res) -> void:
	var scene: PackedScene = null
	if typeof(res) == TYPE_STRING:
		scene = load(res) as PackedScene
	elif res is PackedScene:
		scene = res
	else:
		push_warning("[Preview] set_character_scene: invalid resource")
		return
	_show_character(scene)

func _show_character(scene: PackedScene) -> void:
	if scene == null:
		return
	if character_instance:
		character_instance.queue_free()

	character_instance = scene.instantiate() as Node3D
	add_child(character_instance)
	# No forzamos Vector3.ZERO si ya tiene una posición útil,
	# pero para instancias nuevas suele ser lo correcto.
	character_instance.transform.origin = Vector3.ZERO

	_prepare_for_preview(character_instance)
	
	print("[Preview] Instanced full scene: %s" % character_instance.name)

	# debug: report any AnimationPlayer found under the instanced visual
	var anims_found = character_instance.find_children("*", "AnimationPlayer", true, false)
	if anims_found.size() > 0:
		for a in anims_found:
			print("[Preview] Found AnimationPlayer: ", a.name, " — animations=", a.get_animation_list())
	else:
		print("[Preview] No AnimationPlayer found under instanced model.")

	# Notify all scripts that want the model node (title_rotation, etc.)
	_notify_controllers(character_instance)

func _notify_controllers(model_node: Node3D) -> void:
	# Recursively search children for any script featuring set_character_model_node
	var all_nodes = find_children("*", "", true, false)
	# Also check self just in case
	all_nodes.append(self)
	
	for n in all_nodes:
		if n.has_method("set_character_model_node"):
			print("[Preview] Notifying controller: ", n.name)
			n.call("set_character_model_node", model_node)

func _find_camera(node: Node) -> Camera3D:
	for c in node.get_children():
		if c is Camera3D:
			return c
		var found = _find_camera(c)
		if found:
			return found
	return null

func _prepare_for_preview(node: Node) -> void:
	# recursively disable gameplay/physics on preview nodes
	if node is CharacterBody3D:
		node.set_physics_process(false)
		node.collision_layer = 0
		node.collision_mask = 0
	elif node is RigidBody3D:
		node.freeze = true # Use freeze for RigidBody3D in Godot 4
		node.collision_layer = 0
		node.collision_mask = 0

	if node is CollisionShape3D:
		node.disabled = true

	# Only disable process on nodes that are NOT involved in visuals/animation
	# We want Skeleton3D, MeshInstance3D, and AnimationPlayer to keep working.
	var is_visual = (node is VisualInstance3D or node is AnimationPlayer or node is Skeleton3D or node is BoneAttachment3D)
	
	if not is_visual:
		# If it's a gameplay script (like your movement script), stop it.
		# But keep the node's internal processing if it's a basic Node3D container.
		if node.get_script() != null:
			node.set_process(false)
			node.set_physics_process(false)
		
		node.set_process_input(false)
		node.set_process_unhandled_input(false)

	# recurse
	for child in node.get_children():
		if child is Node:
			_prepare_for_preview(child)

func _debug_materials(node: Node) -> void:
	# print mesh/material info to help debug missing textures
	if node is MeshInstance3D:
		print("[Preview][Material] MeshInstance: ", node.name, " mesh=", node.mesh)
		if node.material_override:
			print("  material_override=", node.material_override)
		else:
			# attempt to show first surface material
			if node.mesh and node.mesh.get_surface_count() > 0:
				var m = node.mesh.surface_get_material(0)
				print("  surface[0] material=", m)
				if m is StandardMaterial3D:
					print("    albedo_texture=", m.albedo_texture)
				elif m is ShaderMaterial:
					# try to read a common shader texture parameter
					if m.has_parameter("albedo_texture"):
						print("    shader albedo_texture=", m.get_shader_parameter("albedo_texture"))

	for child in node.get_children():
		if child is Node:
			_debug_materials(child)
func _apply_material_overrides(_node: Node) -> void:
	# Esta función ya no es necesaria y causaba que todo el modelo 
	# compartiera el mismo material (borrando los colores originales).
	pass
