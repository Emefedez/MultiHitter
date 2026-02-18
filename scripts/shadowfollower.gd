extends Sprite3D

@export var character: CharacterBody3D
@export var altura_maxima: float = 5.0 # A esta altura la sombra será diminuta

func _process(delta: float) -> void:
	if not character:
		return

	# 1. SEGUIMIENTO: Solo copiamos X y Z. 
	# Dejamos la Y quieta (asumiendo que colocaste la sombra en el suelo en el editor)
	global_position.x = character.global_position.x
	global_position.z = character.global_position.z

	# 2. VISIBILIDAD: ¿Está el personaje en el aire?
	if not character.is_on_floor():
		visible = true
		
		# 3. ESCALADO DINÁMICO
		# Calculamos la distancia vertical entre el personaje y la sombra
		var distancia_y = character.global_position.y - global_position.y
		
		# Fórmula matemática: (1.0 - porcentaje de altura). 
		# clamp asegura que la escala no baje de 0.2 ni suba de 1.0
		var escala_final = clamp(0.5 - (distancia_y / altura_maxima), 0.2, 1.0)
		
		scale = Vector3(escala_final, escala_final, escala_final)
		
	else:
		# Si está en el suelo, ocultamos la sombra (según tu petición)
		visible = false
