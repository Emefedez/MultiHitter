extends Node3D

@export var animation_player: AnimationPlayer
@export var character_model_path: NodePath  # assign the instantiated model node in the SubViewport (NodePath)

@export var idle_anim_name: String = "idle"
@export var char_chosen: bool = false

func _ready() -> void:
	# try resolving editor-assigned NodePath first
	if character_model_path != NodePath("") and has_node(character_model_path):
		var resolved := get_node_or_null(character_model_path) as Node3D
		if resolved:
			_set_animation_player_from_node(resolved)

	# fallback: try to auto-find AnimationPlayer under this node
	if animation_player == null:
		var players = find_children("*", "AnimationPlayer", true, false)
		if players.size() > 0:
			animation_player = players[0] as AnimationPlayer
			print("[Character] Auto-found AnimationPlayer: ", animation_player.name)

	if animation_player == null:
		push_warning("[Character] No AnimationPlayer found on preview (assign NodePath or call set_character_model_node at runtime).")

func _process(_delta: float) -> void:
	if not char_chosen and animation_player:
		if not animation_player.is_playing() and idle_anim_name != "":
			animation_player.play(idle_anim_name)
			print("[Character] Playing: ", idle_anim_name)
		
		# Forzamos el avance de la animación si por alguna razón el árbol está pausado
		if animation_player.active == false:
			animation_player.active = true

func _set_animation_player_from_node(node: Node3D) -> void:
	if node == null: return
	var players = node.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		animation_player = players[0] as AnimationPlayer
		animation_player.active = true
		
		var libs = animation_player.get_animation_library_list()
		var anim_list = animation_player.get_animation_list()
		print("[Character] Bound AnimationPlayer: ", animation_player.name, " 
  Libraries: ", libs, " 
  Animations: ", anim_list)
		
		# Auto-assign if list is empty but character has a separate loader? 
		# No, just report it.
		
		if not anim_list.has(idle_anim_name) and anim_list.size() > 0:
			print("[Character] '%s' not found. Falling back to: %s" % [idle_anim_name, anim_list[0]])
			idle_anim_name = anim_list[0]
		
		if idle_anim_name != "":
			animation_player.play(idle_anim_name)
		else:
			print("[Character] Warning: AnimationPlayer found but animation list is EMPTY.")
	else:
		print("[Character] No AnimationPlayer found under node: ", node.name)
