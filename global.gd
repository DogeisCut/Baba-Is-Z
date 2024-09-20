extends Node
@export var current_palette: Image = preload("res://Palettes/default.png")

func get_palette_color(color: Vector2i) -> Color:
	return current_palette.get_pixelv(color)

var units: Array[Unit]
var feature_index: Dictionary
var baserules = [["text", "is", "push"],["level", "is", "stop"],["cursor","is","select"]]
var level: Level
var camera: Camera3D
var movement: Array

func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("parse_text")

enum TurnActions {
	IDLE,
	RIGHT,
	FORAWRD,
	LEFT,
	BACKWARD,
	UP,
	DOWN
}
var directions = {
	TurnActions.RIGHT: [Vector3i(1,0,0), Unit.Direction.RIGHT],
	TurnActions.FORAWRD: [Vector3i(0,0,1), Unit.Direction.FORAWRD],
	TurnActions.LEFT: [Vector3i(-1,0,0), Unit.Direction.LEFT],
	TurnActions.BACKWARD: [Vector3i(0,0,-1), Unit.Direction.BACKWARD],
	TurnActions.UP: [Vector3i(0,-1,0), Unit.Direction.UP],
	TurnActions.DOWN: [Vector3i(0,1,0), Unit.Direction.DOWN],
	TurnActions.IDLE: [Vector3i(0,0,0), null]
}

var infix_conditions: Dictionary = {
	"on": func(obj1, obj2_name):
		for stacker in units_at(obj1.pos):
			if stacker == obj1:
				continue
			if stacker.unit_name == obj2_name:
				return true
		return false,
	
	"under": func(obj1, obj2_name):
		var below_pos = obj1.pos + Vector3i(0, -1, 0)
		for unit in units_at(below_pos):
			if unit.unit_name == obj2_name:
				return true
		return false,

	"above": func(obj1, obj2_name):
		var above_pos = obj1.pos + Vector3i(0, 1, 0)
		for unit in units_at(above_pos):
			if unit.unit_name == obj2_name:
				return true
		return false,

	"near": func(obj1, obj2_name):
		var adjacent_offsets = [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0),
			Vector3i(0, -1, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1)
		]
		for offset in adjacent_offsets:
			var adjacent_pos = obj1.pos + offset
			for unit in units_at(adjacent_pos):
				if unit.unit_name == obj2_name:
					return true
		return false,

	"beside": func(obj1, obj2_name):
		var beside_offsets = [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1)
		]
		for offset in beside_offsets:
			var beside_pos = obj1.pos + offset
			for unit in units_at(beside_pos):
				if unit.unit_name == obj2_name:
					return true
		return false,
}

var prefix_conditions: Dictionary = {
	"lonely": func(obj: Unit):
		var is_lonely = true
		for stacker in units_at(obj.pos):
			if stacker == obj:
				continue
			is_lonely = false
		return is_lonely,
	"idle": func(obj: Unit): #poopoo
		return false,
	"often": func(obj: Unit):
		return randf() <= 3.0 / 4.0,
	"powered": func(obj: Unit): #poopoo
		return false,
	"seldom": func(obj: Unit):
		return randf() <= 1.0 / 6.0,
	"never": func(obj: Unit):
		return false,
}

func handle_prefix_conditions(prefix):
	return prefix_conditions[prefix]

func get_units_with_effect(verb: String, prop: String):
	var effected = []
	for unit in units:
		for property in unit.properties:
			if property[0] == verb and property[1] == prop:
				effected.append(unit)
	return effected

func has_feature(unit: Unit, verb: String, prop: String, at: Vector3i):
	for unit_at in units_at(at):
		if unit_at != unit:
			continue;
		if unit_equals_noun(unit_at, unit.read_name):
			for property in unit_at.properties:
				if property[0] == verb and property[1] == prop:
					return true
	return false

func block(action: TurnActions) -> void:
	for unit in get_units_with_effect("is", "you"):
		unit.move(directions[action][0], directions[action][1], false)

func _process(_delta) -> void:
	var camera_direction = Global.camera.global_transform.basis.z
	var action: TurnActions
	if !get_units_with_effect("is", "you").is_empty():
		if Input.is_action_just_pressed("game_right"):
			action = TurnActions.RIGHT
		if Input.is_action_just_pressed("game_forward"):
			action = TurnActions.FORAWRD
		if Input.is_action_just_pressed("game_left"):
			action = TurnActions.LEFT
		if Input.is_action_just_pressed("game_backward"):
			action = TurnActions.BACKWARD
		if Input.is_action_just_pressed("game_up"):
			action = TurnActions.UP
		if Input.is_action_just_pressed("game_down"):
			action = TurnActions.DOWN
		if Input.is_action_just_pressed("game_idle"):
			action = TurnActions.IDLE
		if action:
			%SoundMove.play()
			turn(action)

func turn(action: TurnActions) -> void:
	block(action)
	for move in movement:
		var unit: Unit = move[0]
		var to: Vector3i = move[1]
		unit.pos = to
	movement = []
	parse_text()

func parse_text() -> void:
		var parsing_directions = [Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)]
		for unit in units:
			unit.properties = []
		for rule in baserules:
			for unit in units:
				if unit_equals_noun(unit, rule[0]):
					unit.properties.append([rule[1], rule[2]])
		var color_text = []
		for direction in parsing_directions:
			for unit in units:
				var is_text_unit: = (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")
				if is_text_unit:
					unit.color = Global.get_palette_color(unit.base_color)
					
					if unit.text_type == unit.TextType.VERB:
						
						for potential_noun in units_at(Vector3i(unit.pos)-direction):
							if (potential_noun.unit_name.substr(0,5) == "text_") and (potential_noun.unit_type == "text") and potential_noun.text_type == potential_noun.TextType.NOUN:
								for potential_prop in units_at(Vector3i(unit.pos)+direction):
									if (potential_prop.unit_name.substr(0,5) == "text_") and (potential_prop.unit_type == "text") and ((potential_prop.text_type == potential_prop.TextType.PROP) or (potential_prop.text_type == potential_prop.TextType.NOUN)):
										color_text.append(potential_noun)
										color_text.append(unit)
										color_text.append(potential_prop)
										for obj_unit in units:
											if obj_unit.unit_name == potential_noun.read_name:
												obj_unit.properties.append([unit.read_name, potential_prop.read_name])
		for unit in color_text:
			unit.color = Global.get_palette_color(unit.active_color)

func unit_equals_noun(unit: Unit, noun: String):
	if noun == "text":
		if (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text"):
			return true
	return unit.read_name == noun

func check_condition(rule, unit):
	if !rule["rule_dict"][3].is_empty():
		var res = true
		for condition in rule["rule_dict"][3]:
			if condition[1].is_empty():
				res = res and prefix_conditions[condition[0]].call(unit)
			else:
				res = res and infix_conditions[condition[0]].call(unit, condition[1][0])
		return res
	return true

func units_at(pos: Vector3i) -> Array[Unit]:
	var returns: Array[Unit] = []
	for i in units.size():
		var unit: Unit = units[i]
		if unit.pos == pos:
			returns.append(unit)
	return returns
