@tool
extends Node3D
class_name Unit

@onready var level: Level = $"../.."

var sprite := unit_name
var color := Color("#000000")
@onready var sprite_node := %Sprite

# the game referes to the pallete for unit properies so what i have going here doesnt reeally make sense
# its really gonna cause problems for transformations

enum Direction {
	RIGHT = 0,
	FORAWRD = 32,
	LEFT = 16,
	BACKWARD = 40,
	UP = 8,
	DOWN = 24,
}
enum TextType {
	NOUN = 0,
	VERB = 1,
	PROP = 2,
	PREFIX = 3,
	NOT = 4,
	LETTER = 5,
	AND = 6,
	INFIX = 7,
	CUSTOMOBJECT = 8,
}
enum Tiling {
	NONE = -1,
	DIRECTIONAL = 0,
	ANIMATED = 4,
	ANIMATED_DIRECTIONS = 3,
	CHARACTER = 2,
	TILED = 1,
}

@export_category("Main")
@export var unit_name := "error"
@export var dir: Direction
var pos: Vector3i

#@export_category("Values")
var text_type: TextType
var tiling: Tiling = Tiling.NONE
var layer := 0

#@export_category("Strings")
var unit_type := "object"
var read_name := "error"

#@export_category("Definition")
var base_color: Vector2i = Vector2i(0,3)
var active_color: Vector2i = Vector2i(0,3)

#@export_category("Other")
var arg_type: Array[TextType] = [TextType.NOUN, TextType.PROP]
var arg_extra: Array[String] = []
var custom_objects: Array[String] = []

var id := 0

var wobble_frame := 1
var wobble_timer := 0.0

var character_frame := 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		sprite = unit_name
		if unit_name.substr(0,5) == "text_":
			read_name = unit_name.substr(5)
		else:
			read_name = unit_name
		pos = Vector3i(int(global_position.x-0.5), int(-global_position.y-0.5), int(global_position.z-0.5))
		Global.units.append(self)
		id = randi_range(-10000, 10000)
		var sprite_desired = "res://Sprites/" + str(unit_name) + "_0_1.png"
		if ResourceLoader.exists(sprite_desired):
			%Sprite.texture = load(sprite_desired)
		else:
			%Sprite.texture = load("res://Sprites/error_0_1.png")
		%Sprite.sorting_offset = layer/30.0
		color = Global.get_palette_color(base_color)
		transform_to(unit_name, true)

func _process(delta) -> void:
	if not Engine.is_editor_hint():
		
		var direction_to_camera = Global.camera.global_transform.origin - global_transform.origin
		var forward_direction := transform.basis.z
		var dot = direction_to_camera.dot(forward_direction)
		%Sprite.flip_h = dot < 0.0
		
		wobble_timer += delta
		if wobble_timer>0.160:
			wobble_timer=0
			wobble_frame+=1
			if wobble_frame>3:
				wobble_frame=1
		var frame := 0
		if tiling == Tiling.CHARACTER or Tiling.DIRECTIONAL:
			frame += dir
			if not (dir != Direction.FORAWRD and dir != Direction.BACKWARD):
				%Sprite.flip_h = false
		if tiling == Tiling.CHARACTER:
			frame += character_frame
		
		var sprite_desired = "res://Sprites/" + str(sprite) + "_" + str(invalid_sprite_frame_to_valid(frame)) + "_" + str(wobble_frame) + ".png"
		if ResourceLoader.exists(sprite_desired):
			%Sprite.texture = load(sprite_desired)
		else:
			%Sprite.texture = load("res://Sprites/error_0_1.png")
		%Sprite.modulate = color
		if (global_position != Vector3(pos.x+0.5, -(pos.y+0.5), pos.z+0.5)):
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", Vector3(pos.x+0.5, -(pos.y+0.5), pos.z+0.5), 0.15)
		%Sprite.sorting_offset = layer/30.0
	else:
		var sprite_desired = "res://Sprites/" + str(unit_name) + "_0_1.png"
		if ResourceLoader.exists(sprite_desired):
			%Sprite.texture = load(sprite_desired)
		else:
			%Sprite.texture = load("res://Sprites/error_0_1.png")

func transform_to(pallete_obj_name, instant = false):
	if instant:
		unit_name = pallete_obj_name
		if unit_name.substr(0,5) == "text_":
			read_name = unit_name.substr(5)
		else:
			read_name = unit_name
		
		if level.object_palette[pallete_obj_name].has("text_type"):
			text_type = level.object_palette[pallete_obj_name]["text_type"]
		
		if level.object_palette[pallete_obj_name].has("unit_type"):
			unit_type = level.object_palette[pallete_obj_name]["unit_type"]
		
		if level.object_palette[pallete_obj_name].has("sprite"):
			sprite = level.object_palette[pallete_obj_name]["sprite"]
		
		if level.object_palette[pallete_obj_name].has("tiling"):
			tiling = level.object_palette[pallete_obj_name]["tiling"]
		
		if level.object_palette[pallete_obj_name].has("base_color"):
			color = Global.get_palette_color(level.object_palette[pallete_obj_name]["base_color"])
			base_color = level.object_palette[pallete_obj_name]["base_color"]
		
		if level.object_palette[pallete_obj_name].has("active_color"):
			active_color = level.object_palette[pallete_obj_name]["active_color"]
		
		if level.object_palette[pallete_obj_name].has("layer"):
			layer = level.object_palette[pallete_obj_name]["layer"]
	else:
		unit_name = pallete_obj_name
		if unit_name.substr(0,5) == "text_":
			read_name = unit_name.substr(5)
		else:
			read_name = unit_name
		
		if level.object_palette[pallete_obj_name].has("text_type"):
			text_type = level.object_palette[pallete_obj_name]["text_type"]
		
		if level.object_palette[pallete_obj_name].has("unit_type"):
			unit_type = level.object_palette[pallete_obj_name]["unit_type"]
		
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.15/2.0)
		tween.tween_callback(
			func():
				if level.object_palette[pallete_obj_name].has("sprite"):
					sprite = level.object_palette[pallete_obj_name]["sprite"]
				
				if level.object_palette[pallete_obj_name].has("tiling"):
					tiling = level.object_palette[pallete_obj_name]["tiling"]
				
				if level.object_palette[pallete_obj_name].has("base_color"):
					color = Global.get_palette_color(level.object_palette[pallete_obj_name]["base_color"])
					base_color = level.object_palette[pallete_obj_name]["base_color"]
				
				if level.object_palette[pallete_obj_name].has("active_color"):
					active_color = level.object_palette[pallete_obj_name]["active_color"]
				
				if level.object_palette[pallete_obj_name].has("layer"):
					layer = level.object_palette[pallete_obj_name]["layer"]
				
				var tween2 = create_tween()
				tween2.tween_property(self, "scale", Vector3(1, 1, 1), 0.15/2.0)
		)

func move(by: Vector3i, _direction: Direction, instant: bool) -> bool:
	if _direction!=null: 
		dir = _direction
	for unit in Global.units:
		if Global.hasfeature(unit,"is","push",(pos+by)):
			if unit.move(by, _direction, instant)==false:
				return false
	if check(pos+by)[1]==false:
		if instant:
			pos += by
		else:
			Global.movement.append([self, pos+by])
		if tiling == Tiling.CHARACTER: character_frame=(character_frame+1)%4
		return true
	else:
		return false

func check(at: Vector3i) -> Array:
	var stop = false
	for unit in Global.units:
		var isstop = Global.hasfeature(unit,"is","stop",at)
		if isstop:
			stop = true
	if (at.x>level.level_size.x-1 or at.y>level.level_size.y-1 or at.z>level.level_size.z-1):
		stop = true
	if (at.x<0 or at.y<0 or at.z<0):
		stop = true
	return [Global.units_at(at),stop]

func get_direction_relative_to_cam() -> Direction:
	# Vector pointing from the object to the camera
	var direction_to_camera = (Global.camera.global_transform.origin - global_transform.origin).normalized()

	# Object's forward, right, and up axes (in world space)
	var forward_direction = transform.basis.z.normalized()
	var right_direction = transform.basis.x.normalized()
	var up_direction = transform.basis.y.normalized()

	# Calculate dot products to determine how aligned the camera is with the object's directions
	var forward_dot = direction_to_camera.dot(forward_direction)
	var right_dot = direction_to_camera.dot(right_direction)
	var up_dot = direction_to_camera.dot(up_direction)

	# Determine the dominant direction based on the dot products
	if abs(up_dot) > abs(forward_dot) and abs(up_dot) > abs(right_dot):
		# Camera is above or below the object
		if up_dot > 0:
			return Direction.DOWN  # Camera is below the object (since +Y is usually "up" in Godot)
		else:
			return Direction.UP    # Camera is above the object
	elif abs(forward_dot) > abs(right_dot):
		# Camera is in front or behind the object
		if forward_dot > 0:
			return Direction.BACKWARD  # Camera is behind the object (relative to its forward direction)
		else:
			return Direction.FORAWRD  # Camera is in front of the object
	else:
		# Camera is to the left or right of the object
		if right_dot > 0:
			return Direction.LEFT  # Camera is to the left of the object
		else:
			return Direction.RIGHT  # Camera is to the right of the object

#probably should do this for side sprites too but not yet
func invalid_sprite_frame_to_valid(frame: int) -> int:
	# Calculate direction vectors
	var direction_to_camera = (Global.camera.global_transform.origin - global_transform.origin).normalized()
	var forward_direction = transform.basis.z.normalized()
	var left_direction = transform.basis.x.normalized()
	
	# Calculate dot products
	var f_dot = direction_to_camera.dot(forward_direction)
	var l_dot = direction_to_camera.dot(left_direction)
	
	var forward_frame = 24
	var backward_frame = 8
	
	
	if abs(f_dot) > abs(l_dot):
		# The camera is closer to being in front or behind
		if f_dot > 0:
			# Camera is in front of the object
			forward_frame = 24
			backward_frame = 8
		else:
			# Camera is behind the object
			forward_frame = 8
			backward_frame = 24
	else:
		# The camera is closer to being to the left or right
		if l_dot > 0:
			# Camera is to the left of the object
			forward_frame = 16
			backward_frame = 0
		else:
			# Camera is to the right of the object
			forward_frame = 0
			backward_frame = 16
	
	match(frame):
		32:
			return forward_frame
		33:
			return forward_frame + 1
		34:
			return forward_frame + 2
		35:
			return forward_frame + 3
		40:
			return backward_frame
		41:
			return backward_frame + 1
		42:
			return backward_frame + 2
		43:
			return backward_frame + 3
	return frame
