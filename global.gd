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
		return false
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

func block(action: TurnActions) -> void:
	for unit in get_units_with_effect("you"):
		unit.move(directions[action][0], directions[action][1], false)

func _process(_delta) -> void:
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
		feature_index = {}
		for rule in baserules:
			if !feature_index.has(rule[0]): feature_index[rule[0]] = []
			if !feature_index.has(rule[1]): feature_index[rule[1]] = []
			if !feature_index.has(rule[2]): feature_index[rule[2]] = []
			feature_index[rule[0]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
			feature_index[rule[1]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
			feature_index[rule[2]].append({rule_units = [], rule_dict = [rule[0], rule[1], rule[2]], tags = ["baserule"]})
		for direction in parsing_directions:
			for unit in units:
				var is_text_unit: = (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")
				if is_text_unit:
					unit.color = Global.get_palette_color(unit.base_color)
					if unit.text_type == unit.TextType.VERB:
						var found_nouns: Array[Unit] = []
						var found_props: Array[Unit] = []
						var found_prefixes: Array[Unit] = []
						var found_infixes: Array[Unit] = []
						var second_nouns: Array[Unit] = []
						
						for potential_noun in units_at(Vector3i(unit.pos)-direction):
							if (potential_noun.unit_name.substr(0,5) == "text_") and (potential_noun.unit_type == "text") and potential_noun.text_type == potential_noun.TextType.NOUN:
								found_nouns.append(potential_noun)
							
						for potential_infix in units_at(Vector3i(unit.pos) - direction * 2):
							if (potential_infix.unit_name.substr(0,5) == "text_") and (potential_infix.unit_type == "text") and potential_infix.text_type == potential_infix.TextType.INFIX:
								found_infixes.append(potential_infix)
						
						for potential_second_noun in units_at(Vector3i(unit.pos) - direction * 3):
							if (potential_second_noun.unit_name.substr(0,5) == "text_") and (potential_second_noun.unit_type == "text") and potential_second_noun.text_type == potential_second_noun.TextType.NOUN:
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
										if !feature_index.has(found_prefix.read_name): feature_index[found_prefix.read_name] = []
										rule[3].append([found_prefix.read_name, []])
										rule_units.append(found_prefix)
										feature_index[found_prefix.read_name].append({rule_units = rule_units, rule_dict = rule, tags = []})
								
								if !found_infixes.is_empty() and !second_nouns.is_empty():
									for found_infix in found_infixes:
										if !feature_index.has(found_infix.read_name): feature_index[found_infix.read_name] = []
										for second_noun in second_nouns:
											if !feature_index.has(second_noun.read_name): feature_index[second_noun.read_name] = []
											rule[3].append([found_infix.read_name, [second_noun.read_name]])
											rule_units.append(found_infix)
											rule_units.append(second_noun)
											feature_index[found_infix.read_name].append({rule_units = rule_units, rule_dict = rule, tags = []})
								
								if !feature_index.has(found_noun.read_name): feature_index[found_noun.read_name] = []
								if !feature_index.has(unit.read_name): feature_index[unit.read_name] = []
								if !feature_index.has(found_prop.read_name): feature_index[found_prop.read_name] = []
								
								feature_index[found_noun.read_name].append({rule_units = rule_units, rule_dict = rule, tags = []})
								feature_index[unit.read_name].append({rule_units = rule_units, rule_dict = rule, tags = []})
								feature_index[found_prop.read_name].append({rule_units = rule_units, rule_dict = rule, tags = []})
		for feature_name in feature_index:
			var feature = feature_index[feature_name]
			for rule in feature:
				for unit in rule["rule_units"]:
					unit.color = Global.get_palette_color(unit.active_color)

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
