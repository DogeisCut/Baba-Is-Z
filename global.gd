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

var colors = {
	"red": Vector2i(2, 2),
	"orange": Vector2i(2, 3),
	"yellow": Vector2i(2, 4),
	"lime": Vector2i(5, 3),
	"green": Vector2i(5, 2),
	"cyan": Vector2i(1, 4),
	"blue": Vector2i(3, 2),
	"purple": Vector2i(3, 1),
	"pink": Vector2i(4, 1),
	"rosy": Vector2i(4, 2),
	"black": Vector2i(0, 4),
	"grey": Vector2i(0, 1),
	"silver": Vector2i(0, 2),
	"white": Vector2i(0, 3),
	"brown": Vector2i(6, 1)
}

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

func do_movement(action: TurnActions) -> void:
	for unit in get_units_with_effect("you"):
		if action != TurnActions.IDLE:
			unit.move(directions[action][0], directions[action][1], false)

func block(action: TurnActions) -> void:
	for color in colors.keys():
		for unit in get_units_with_effect(color):
			unit.color = get_palette_color(colors[color])

func _process(_delta) -> void:
	if not Engine.is_editor_hint():
		var camera_direction = Global.camera.global_transform.basis.z
		var action: TurnActions
		var do_action = false
		if feature_index.has("you"):
			if Input.is_action_just_pressed("game_right"):
				action = TurnActions.RIGHT
				do_action = true
			if Input.is_action_just_pressed("game_forward"):
				action = TurnActions.FORAWRD
				do_action = true
			if Input.is_action_just_pressed("game_left"):
				action = TurnActions.LEFT
				do_action = true
			if Input.is_action_just_pressed("game_backward"):
				action = TurnActions.BACKWARD
				do_action = true
			if Input.is_action_just_pressed("game_up"):
				action = TurnActions.UP
				do_action = true
			if Input.is_action_just_pressed("game_down"):
				action = TurnActions.DOWN
				do_action = true
			if Input.is_action_just_pressed("game_idle"):
				action = TurnActions.IDLE
				do_action = true
			if do_action:
				%SoundMove.play()
				turn(action)

func turn(action: TurnActions) -> void:
	for unit in units:
		unit.color = Global.get_palette_color(unit.base_color)
	do_movement(action)
	for move in movement:
		var unit: Unit = move[0]
		var to: Vector3i = move[1]
		unit.pos = to
	movement = []
	parse_text()
	handle_transforms()
	block(action)

func flatten_array(arr):
	var flat = []
	for element in arr:
		if element is Array:
			flat.append_array(flatten_array(element))
		else:
			flat.append(element)
	return flat

func parse_text() -> void:
		var parsing_directions = [Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)]
		feature_index = {}
		for rule in baserules:
			for used_word in flatten_array(rule):
				if !feature_index.has(used_word): feature_index[used_word] = []
				feature_index[used_word].append({rule_units = [], rule_dict = rule, tags = ["baserule"]})
		for direction in parsing_directions:
			for unit in units:
				var is_text_unit: = (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")
				if is_text_unit:
					if unit.text_type == unit.TextType.VERB:
						var found_nouns: Array[Unit] = []
						var found_props: Array[Unit] = []
						var found_prefixes: Array[Unit] = []
						var found_infixes: Array[Unit] = []
						var second_nouns: Array[Unit] = []
						
						for potential_noun in units_at(unit.pos-direction):
							if (potential_noun.unit_name.substr(0,5) == "text_") and (potential_noun.unit_type == "text") and potential_noun.text_type == potential_noun.TextType.NOUN:
								found_nouns.append(potential_noun)
						
						for fn in found_nouns:
							for potential_infix in units_at(fn.pos - direction):
								if (potential_infix.unit_name.substr(0,5) == "text_") and (potential_infix.unit_type == "text") and potential_infix.text_type == potential_infix.TextType.INFIX:
									found_infixes.append(potential_infix)
								for potential_second_noun in units_at(potential_infix.pos - direction):
									if (potential_second_noun.unit_name.substr(0,5) == "text_") and (potential_second_noun.unit_type == "text") and (potential_second_noun.text_type == potential_second_noun.TextType.NOUN or potential_second_noun.text_type == potential_infix.arg_type[0]):
										second_nouns.append(potential_second_noun)
							
						if !found_infixes.is_empty() and !second_nouns.is_empty() and !found_nouns.is_empty():
							var temp = found_nouns
							found_nouns = second_nouns
							second_nouns = temp
							
						for fn in found_nouns:
							for potential_prefix in units_at(fn.pos-direction):
								if (potential_prefix.unit_name.substr(0,5) == "text_") and (potential_prefix.unit_type == "text") and potential_prefix.text_type == potential_prefix.TextType.PREFIX:
									found_prefixes.append(potential_prefix)
							
						for potential_prop in units_at(Vector3i(unit.pos)+direction):
							if (potential_prop.unit_name.substr(0,5) == "text_") and (potential_prop.unit_type == "text") and ((potential_prop.text_type == potential_prop.TextType.PROP) or (potential_prop.text_type == potential_prop.TextType.NOUN)):
								found_props.append(potential_prop)
						
						
						for found_noun in found_nouns:
							for found_prop in found_props:
								var rule = [found_noun.read_name, unit.read_name, found_prop.read_name, []]
								var rule_units = [found_noun, unit, found_prop]
								
								if !found_prefixes.is_empty():
									for found_prefix in found_prefixes:
										rule[3].append([found_prefix.read_name, []])
										rule_units.append(found_prefix)
								
								if !found_infixes.is_empty() and !second_nouns.is_empty():
									for found_infix in found_infixes:
										for second_noun in second_nouns:
											rule[3].append([found_infix.read_name, [second_noun.read_name]])
											rule_units.append(found_infix)
											rule_units.append(second_noun)
								
								for used_word in flatten_array(rule):
									if !feature_index.has(used_word): feature_index[used_word] = []
									feature_index[used_word].append({rule_units = rule_units, rule_dict = rule, tags = ["baserule"]})
		for feature_name in feature_index:
			var feature = feature_index[feature_name]
			for rule in feature:
				for unit in rule["rule_units"]:
					unit.color = Global.get_palette_color(unit.active_color)

func check_condition(rule, unit):
	if len(rule["rule_dict"]) > 3 and !rule["rule_dict"][3].is_empty():
		var res = true
		for condition in rule["rule_dict"][3]:
			if condition[1].is_empty():
				res = res and prefix_conditions[condition[0]].call(unit)
			else:
				res = res and infix_conditions[condition[0]].call(unit, condition[1][0])
		return res
	return true

func handle_transforms() -> void:
	var transforms = []
	if feature_index.has("is"):
		for rule in feature_index["is"]:
			if level.object_palette.has(rule["rule_dict"][2]) or rule["rule_dict"][2] == "text":
				for unit in units:
					if unit.unit_name == rule["rule_dict"][0]:
						if check_condition(rule, unit):
							if rule["rule_dict"][2] == "text":
								transforms.append([unit, "text_" + unit.read_name])
							else:
								transforms.append([unit, rule["rule_dict"][2]])
	for transfomer in transforms:
		transfomer[0].transform_to(transfomer[1])

func get_units_with_effect(prop: String) -> Array[Unit]:
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
					if check_condition(rule, unit):
						returns.append(unit)
	return returns

func hasfeature(target_unit: Unit, ruleVerb: String, ruleProp: String, at: Vector3i) -> bool:
	if target_unit.unit_type == "text":
		if feature_index.has("text"):
			for unit in units:
				if unit != target_unit: continue
				if unit.unit_type == "text":
					for rule in feature_index["text"]:
						if (rule["rule_dict"][1] == ruleVerb) and (rule["rule_dict"][2] == ruleProp):
							if (unit.pos == at):
								if check_condition(rule, unit):
									return true
	else:
		var hasrule = false
		if feature_index.has(target_unit.unit_name):
			for rule in feature_index[target_unit.unit_name]:
				if (rule["rule_dict"][1] == ruleVerb) and (rule["rule_dict"][2] == ruleProp):
					if check_condition(rule, target_unit):
						hasrule = true
			for i in units.size():
				var unit: Unit = units[i]
				if unit != target_unit: continue
				if (unit.unit_name == target_unit.unit_name) and (unit.pos == at) and hasrule:
					return true
	return false

func units_at(pos: Vector3i) -> Array[Unit]:
	var returns: Array[Unit] = []
	for i in units.size():
		var unit: Unit = units[i]
		if unit.pos == pos:
			returns.append(unit)
	return returns
