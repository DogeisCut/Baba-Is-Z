@tool
extends Node3D
class_name Level

@export var level_size: Vector3i = Vector3i(5,5,5)
@export var palette: Image

func _ready() -> void:
	%LevelBounds.scale = Vector3(level_size)
	%LevelBounds.global_position = Vector3(level_size.x, -level_size.y, level_size.z)/2
	if not Engine.is_editor_hint():
		Global.current_palette = palette
		Global.level = self
		%Camroot.global_position = Vector3(level_size.x, -level_size.y, level_size.z)/2
		%Enviroment.get_environment().background_color = Global.get_palette_color(Vector2i(1,0))
		%LevelBounds.get_active_material(0).albedo_color = Global.get_palette_color(Vector2i(0,4))

