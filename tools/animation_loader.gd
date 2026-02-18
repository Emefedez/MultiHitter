@tool
extends Node

## Ruta a la carpeta que contiene las animaciones (.tres o .res)
@export_dir var animations_folder: String = "res://import/animations"
## El AnimationPlayer donde cargar las animaciones
@export var target_animation_player: AnimationPlayer

## Haz clic en esta casilla en el Inspector para cargar las animaciones
@export var load_animations_now: bool = false:
	set(value):
		if value:
			_load_all_animations()
		load_animations_now = false

func _load_all_animations() -> void:
	if not target_animation_player:
		printerr("[AnimLoader] ¡Error! Debes asignar un AnimationPlayer.")
		return
	
	var dir = DirAccess.open(animations_folder)
	if not dir:
		printerr("[AnimLoader] ¡Error! No se puede abrir la carpeta: ", animations_folder)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var library = target_animation_player.get_animation_library("")
	
	# Si no existe librería por defecto, crea una nueva
	if not library:
		library = AnimationLibrary.new()
		target_animation_player.add_animation_library("", library)
		print("[AnimLoader] Creada nueva librería de animación.")
	
	var count = 0
	
	while file_name != "":
		if not dir.current_is_dir():
			# Buscar archivos .tres o .res (ignorando .import y otros)
			if (file_name.ends_with(".tres") or file_name.ends_with(".res")) and not file_name.ends_with(".import"):
				var full_path = animations_folder + "/" + file_name
				var anim_name = file_name.get_basename() # "jump.res" -> "jump"
				
				var anim_resource = load(full_path)
				if anim_resource is Animation:
					library.add_animation(anim_name, anim_resource)
					print("[AnimLoader] Añadida animación: ", anim_name)
					count += 1
				else:
					printerr("[AnimLoader] El archivo no es una animación válida: ", file_name)
					
		file_name = dir.get_next()
		
	print("[AnimLoader] ¡Proceso terminado! Se cargaron ", count, " animaciones.")
