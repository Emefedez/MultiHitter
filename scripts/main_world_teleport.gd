extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Conectamos la señal 'pressed' del botón a nuestra función
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("Opened main_world...")
	# Cambia la escena actual a la del mundo principal
	get_tree().change_scene_to_file("res://scenes/main_world.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
