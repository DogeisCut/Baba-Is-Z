extends Node
@export var current_palette: Image = preload("res://Palettes/default.png")

func get_palette_color(color: Vector2i):
	return current_palette.get_pixelv(color)

var units: Array[Unit]
var feature_index: Dictionary
var baserules = [["text", "is", "push"],["level", "is", "stop"],["cursor","is","select"]]
var level: Level
var camera: Camera3D
var movement: Array

func _ready():
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

func block(action: TurnActions):
	for unit in get_units_with_effect("you"):
		unit.move(directions[action][0], directions[action][1], false)

func _process(_delta):
	var camera_direction = Global.camera.global_transform.basis.z
	var action: TurnActions
	if feature_index.has("you"):
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

func turn(action: TurnActions):
	block(action)
	for move in movement:
		var unit: Unit = move[0]
		var to: Vector3i = move[1]
		unit.pos = to
	movement = []
	parse_text()

func parse_text():
		var parsing_directions = [Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)]
		feature_index = {}
		for rule in baserules:
			if !feature_index.has(rule[0]): feature_index[rule[0]] = []
			if !feature_index.has(rule[1]): feature_index[rule[1]] = []
			if !feature_index.has(rule[2]): feature_index[rule[2]] = []
			feature_index[rule[0]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
			feature_index[rule[1]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
			feature_index[rule[2]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
		for unit in units:
			var is_text_unit: = (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")
			if is_text_unit:
				unit.color = Global.get_palette_color(unit.base_color)
				if unit.text_type == unit.TextType.VERB:
					var found_nouns: Array[Unit] = []
					var found_props: Array[Unit] = []
					for direction in parsing_directions:
						for potential_noun in units_at(Vector3i(unit.pos)-direction):
							if (potential_noun.unit_name.substr(0,5) == "text_") and (potential_noun.unit_type == "text") and potential_noun.text_type == potential_noun.TextType.NOUN:
								found_nouns.append(potential_noun)
						for potential_prop in units_at(Vector3i(unit.pos)+direction):
							if (potential_prop.unit_name.substr(0,5) == "text_") and (potential_prop.unit_type == "text") and ((potential_prop.text_type == potential_prop.TextType.PROP) or (potential_prop.text_type == potential_prop.TextType.NOUN)):
								found_props.append(potential_prop)
					for found_noun in found_nouns:
						for found_prop in found_props:
							if !feature_index.has(found_noun.read_name): feature_index[found_noun.read_name] = []
							if !feature_index.has(unit.read_name): feature_index[unit.read_name] = []
							if !feature_index.has(found_prop.read_name): feature_index[found_prop.read_name] = []
							feature_index[found_noun.read_name].append({rule_units = [found_noun, unit, found_prop], rule_dict = [found_noun.read_name, unit.read_name, found_prop.read_name], tags = []})
							feature_index[unit.read_name].append({rule_units = [found_noun, unit, found_prop], rule_dict = [found_noun.read_name, unit.read_name, found_prop.read_name], tags = []})
							feature_index[found_prop.read_name].append({rule_units = [found_noun, unit, found_prop], rule_dict = [found_noun.read_name, unit.read_name, found_prop.read_name], tags = []})
		for feature_name in feature_index:
			var feature = feature_index[feature_name]
			for rule in feature:
				for unit in rule["rule_units"]:
					unit.color = Global.get_palette_color(unit.active_color)

func get_units_with_effect(prop: String):
	var returns: Array[Unit] = []
	var names: Array[String] = []
	if feature_index.has(prop):
		for rule in feature_index[prop]:
			if (rule["rule_dict"][1] == "is") and (rule["rule_dict"][2] == prop):
				names.append(rule["rule_dict"][0])
				if rule["rule_dict"][0] == "text":
					for unit in units:
						if unit.unit_type == "text":
							names.append(unit.unit_name)
		for unit in units:
			if names.has(unit.unit_name):
				returns.append(unit)
	return returns

func hasfeature(target_unit: Unit, ruleVerb: String, ruleProp: String, at: Vector3i):
	if target_unit.unit_type == "text":
		if feature_index.has("text"):
			for unit in units:
				if unit != target_unit: continue
				if unit.unit_type == "text":
					for rule in feature_index["text"]:
						if (rule["rule_dict"][1] == ruleVerb) and (rule["rule_dict"][2] == ruleProp):
							if (unit.pos == at):
								return true
	else:
		var hasrule = false
		if feature_index.has(target_unit.unit_name):
			for rule in feature_index[target_unit.unit_name]:
				if (rule["rule_dict"][1] == ruleVerb) and (rule["rule_dict"][2] == ruleProp):
					hasrule = true
			for i in units.size():
				var unit: Unit = units[i]
				if unit != target_unit: continue
				if (unit.unit_name == target_unit.unit_name) and (unit.pos == at) and hasrule:
					return true
	return false

func units_at(pos: Vector3i):
	var returns: Array[Unit] = []
	for i in units.size():
		var unit: Unit = units[i]
		if unit.pos == pos:
			returns.append(unit)
	return returns
