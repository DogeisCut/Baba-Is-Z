@tool
extends Node3D
class_name Unit

var sprite := unit_name
var color := Color("#000000")
@onready var sprite_node := %Sprite

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
@export_category("Values")
@export var pos: Vector3i
@export var dir: Direction
@export var text_type: TextType
@export var tiling: Tiling = Tiling.NONE
var id := 0
@export var layer := 0

@export_category("Strings")
@export var unit_name := "error"
@export var unit_type := "object"
var read_name := "error"

@export_category("Definition")
@export var base_color: Vector2i = Vector2i(0,3)
@export var active_color: Vector2i = Vector2i(0,3)

var wobble_frame := 1
var wobble_timer := 0.0

var character_frame := 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		sprite = unit_name
		if unit_name.substr(0,5) == "text_":
			read_name = unit_name.substr(5)
		pos = Vector3i(int(global_position.x-0.5), int(-global_position.y-0.5), int(global_position.z-0.5))
		Global.units.append(self)
		id = randi_range(-10000, 10000)
		%Sprite.texture = load("res://Sprites/" + str(sprite) + "_0_1.png")
		%Sprite.sorting_offset = layer/30.0
		color = Global.get_palette_color(base_color)

func _process(delta) -> void:
	if not Engine.is_editor_hint():
		wobble_timer += delta
		if wobble_timer>0.160:
			wobble_timer=0
			wobble_frame+=1
			if wobble_frame>3:
				wobble_frame=1
		var frame := 0
		if tiling == Tiling.CHARACTER or Tiling.DIRECTIONAL:
			frame += dir
		if tiling == Tiling.CHARACTER:
			frame += character_frame
		%Sprite.texture = load("res://Sprites/" + str(sprite) + "_" + str(frame) + "_" + str(wobble_frame) + ".png")
		%Sprite.modulate = color
		if (global_position != Vector3(pos.x+0.5, -(pos.y+0.5), pos.z+0.5)):
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", Vector3(pos.x+0.5, -(pos.y+0.5), pos.z+0.5), 0.15)
		var direction_to_camera = Global.camera.global_transform.origin - global_transform.origin
		var forward_direction := transform.basis.z
		var dot = direction_to_camera.dot(forward_direction)
		%Sprite.flip_h = dot < 0.0
	else:
		%Sprite.texture = load("res://Sprites/" + str(unit_name) + "_0_1.png")

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
	if (at.x>Global.level.level_size.x-1 or at.y>Global.level.level_size.y-1 or at.z>Global.level.level_size.z-1):
		stop = true
	if (at.x<0 or at.y<0 or at.z<0):
		stop = true
	return [Global.units_at(at),stop]
