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
var last_turn_action: TurnActions

const UNIT_FILE = preload("res://unit.tscn")

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
	
	"facing": func(obj1, obj2_name):
		match obj2_name:
			"right":
				return obj1.dir == Unit.Direction.RIGHT
			"up":
				return obj1.dir == Unit.Direction.UP
			"left":
				return obj1.dir == Unit.Direction.LEFT
			"down":
				return obj1.dir == Unit.Direction.DOWN
			"forward":
				return obj1.dir == Unit.Direction.FORAWRD
			"backward":
				return obj1.dir == Unit.Direction.BACKWARD
			_:
				pass
		return false,
	
	"feeling": func(obj1, obj2_name):
		for unit in get_units_with_effect(obj2_name):
			if unit == obj1:
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
	"idle": func(obj: Unit):
		return last_turn_action == TurnActions.IDLE,
	"often": func(obj: Unit):
		return randf() <= 3.0 / 4.0,
	"powered": func(obj: Unit): #should probably do this automatically
		return !get_units_with_effect("power").is_empty(),
	"powered2": func(obj: Unit):
		return !get_units_with_effect("power2").is_empty(),
	"powered3": func(obj: Unit):
		return !get_units_with_effect("power3").is_empty(),
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
	apply_movement()
	for unit in get_units_with_effect("move"):
		if !unit.move(unit.direction_vectors[unit.dir], unit.dir, false):
			unit.dir = unit.directions_180[unit.dir]
			unit.move(unit.direction_vectors[unit.dir], unit.dir, false)
	apply_movement()
	for unit in get_units_with_effect("shift"):
		for unit2 in units_at(unit.pos):
			if unit2 != unit:
				unit2.move(unit.direction_vectors[unit.dir], unit.dir, false)
	apply_movement()

func block(action: TurnActions) -> void:
	for color in colors.keys():
		for unit in get_units_with_effect(color):
			unit.color = get_palette_color(colors[color])
	
	var makes = []
	if feature_index.has("make"):
		for rule in feature_index["make"]:
			if level.object_palette.has(rule["rule_dict"][2]) or rule["rule_dict"][2] == "text":
				for unit in units:
					if unit.unit_name == rule["rule_dict"][0]:
						if check_condition(rule, unit):
							if rule["rule_dict"][2] == "text":
								makes.append(["text_" + unit.read_name, unit.pos, unit.dir])
							else:
								makes.append([rule["rule_dict"][2], unit.pos, unit.dir])
	for make in makes:
		make_unit(make[0], make[1], make[2])

func make_unit(what: String, at: Vector3i, dir: Unit.Direction):
	var units_node = level.get_node("%Units")
	var made_unit: Unit = UNIT_FILE.instantiate()
	made_unit.level = level
	made_unit.pos = at
	made_unit.dir = dir
	made_unit.global_position = Vector3(at.x+0.5, -(at.y+0.5), at.z+0.5)
	made_unit.transform_to(what, true)
	units_node.add_child(made_unit)

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
	last_turn_action = action
	for unit in units:
		unit.color = Global.get_palette_color(unit.base_color)
	do_movement(action)
	parse_text()
	handle_transforms()
	block(action)

func apply_movement():
	for move in movement:
		var unit: Unit = move[0]
		var to: Vector3i = move[1]
		unit.pos = to
	movement = []

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
		
		var text_units = []
		var first_verbs = []
		for direction in parsing_directions:
			for unit in units:
				var is_text_unit: = (unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")
				if is_text_unit:
					text_units.append(unit)
					if unit.text_type == Unit.TextType.VERB:
						if !units_at(unit.pos + direction).filter(func(at): return ((at.unit_name.substr(0,5) == "text_") and (at.unit_type == "text"))).is_empty():
							if !units_at(unit.pos - direction).filter(func(at): return ((at.unit_name.substr(0,5) == "text_") and (at.unit_type == "text"))).is_empty():
								first_verbs.append([unit, direction])
		
		# this finds text blocks and stacked ones n shit
		var sentences = []
		for first_verb_dir in first_verbs:
			var first_verb = first_verb_dir[0]
			var direction = first_verb_dir[1]
			var sentence = [[first_verb.read_name, first_verb.text_type, [first_verb], 1]]
			var last_unit = first_verb
			var i = 0
			while true:
				i += 1
				
				var units = units_at(first_verb.pos + (direction * i))
				if units.is_empty():
					break
				var unit = units[0]
				if not ((unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")):
					break
				if last_unit.text_type == Unit.TextType.VERB:
					if not (first_verb.arg_type.has(unit.text_type) or unit.text_type == Unit.TextType.NOT):
						break
				if last_unit.text_type == Unit.TextType.PROP:
					if not unit.text_type == Unit.TextType.AND:
						break
				if last_unit.text_type == Unit.TextType.NOUN:
					if not unit.text_type == Unit.TextType.AND:
						break
				sentence.push_back([unit.read_name, unit.text_type, [unit], 1])
				last_unit = unit
			sentence.reverse()
			i = 0
			last_unit = first_verb
			while true:
				i += -1
				
				var units = units_at(first_verb.pos + (direction * i))
				if units.is_empty():
					break
				var unit = units[0]
				if not ((unit.unit_name.substr(0,5) == "text_") and (unit.unit_type == "text")):
					break
				
				if last_unit.text_type == Unit.TextType.VERB:
					if not (unit.text_type == Unit.TextType.NOUN or unit.text_type == Unit.TextType.PROP):
						break
				if last_unit.text_type == Unit.TextType.NOUN:
					if not (unit.text_type == Unit.TextType.NOT or unit.text_type == Unit.TextType.PREFIX or unit.text_type == Unit.TextType.INFIX or unit.text_type == Unit.TextType.AND):
						break
				if last_unit.text_type == Unit.TextType.PREFIX:
					if not (unit.text_type == Unit.TextType.AND or unit.text_type == Unit.TextType.NOT):
						break
				if last_unit.text_type == Unit.TextType.INFIX:
					if not (unit.text_type == Unit.TextType.NOUN or unit.text_type == Unit.TextType.NOT):
						break
				sentence.push_back([unit.read_name, unit.text_type, [unit], 1])
				last_unit = unit
			sentence.reverse()
			if len(sentence) >= 3 and (sentence[0][1] == Unit.TextType.NOT or sentence[0][1] == Unit.TextType.NOUN or sentence[0][1] == Unit.TextType.PREFIX or sentence[0][1] == Unit.TextType.INFIX):
				sentences.append(sentence)
		
		# Additional validation:
		# Sometimes you just gotta check the right way around.
		#var validated_sentences = []
		#for i in len(sentences):
			#var validated_sentence = []
			#var sentence = sentences[i]
			#for j in len(sentence):
				#var word = sentence[j]
				#var last_word = null
				#var next_word = null
				#if j>0:
					#last_word = sentence[j-1]
				#if j<len(sentence)-1:
					#next_word = sentence[j+1]
				#if word[1] == Unit.TextType.INFIX:
					#if last_word == null:
						#continue
					#if not (word[2][0].arg_type.has(next_word[1]) or word[2][0].arg_extra.has(next_word[0])):
						#continue
				#if word[1] == Unit.TextType.PROP:
					#if last_word == null:
						#continue
					#if not (last_word[2][0].arg_type.has(word[1]) or last_word[2][0].arg_extra.has(word[0])):
						#continue
				#if word[1] == Unit.TextType.NOUN:
					#if next_word == null:
						#continue
					#if not (next_word[1] == Unit.TextType.AND or next_word[1] == Unit.TextType.VERB or next_word[1] == Unit.TextType.INFIX):
						#continue
				#validated_sentence.append(word)
			#if len(validated_sentence) >= 3:
				#validated_sentences.append(validated_sentence)
		#sentences = validated_sentences
			
		#var unique_sentences = []
		#var seen_sentence_nodes = []
		#
		#for sentence in sentences:
			#var sentence_nodes_set = sentence.map(func(word): return word[2])
			#sentence_nodes_set.sort()
			#if sentence_nodes_set not in seen_sentence_nodes:
				#unique_sentences.append(sentence)
				#seen_sentence_nodes.append(sentence_nodes_set)
		#sentences = unique_sentences
		
		print(sentences)
		
		# This block assumes the sentences provided to it are valid, contain only ands in conditions, and there are only 1 nots or none
		for i in len(sentences):
			var sentence = sentences[i]
			
			var target = null
			var verb = null
			var property = null
			
			var doing_conds = false
			
			var conds = []
			
			var rule_units = []
			var rule_dict = []
			
			for j in len(sentence):
				var word = sentence[j]
				var last_word = null
				if j>0:
					last_word = sentence[j-1]
				if word[1] == Unit.TextType.PREFIX:
					conds.append([word[0], []])
					rule_units.append(word[2])
					continue
				if word[1] == Unit.TextType.INFIX:
					if last_word != null and last_word[1] == Unit.TextType.NOUN:
						conds.append([word[0], [sentence[j+1][0]]])
						rule_units.append(word[2])
					continue
				if word[1] == Unit.TextType.NOUN and !target:
					target = word
					rule_units.append(word[2])
					continue
				if word[1] == Unit.TextType.VERB:
					verb = word
					rule_units.append(word[2])
					continue
				if word[1] == Unit.TextType.PROP || word[1] == Unit.TextType.NOUN:
					property = word
					rule_units.append(word[2])
					continue
			if !feature_index.has(target[0]): feature_index[target[0]] = []
			if !feature_index.has(verb[0]): feature_index[verb[0]] = []
			if !feature_index.has(property[0]): feature_index[property[0]] = []
			rule_dict = [target[0], verb[0], property[0], conds]
			feature_index[target[0]].append({rule_units = rule_units, rule_dict = rule_dict, tags = []})
			feature_index[verb[0]].append({rule_units = rule_units, rule_dict = rule_dict, tags = []})
			feature_index[property[0]].append({rule_units = rule_units, rule_dict = rule_dict, tags = []})
		
		print(feature_index)
		for feature_name in feature_index:
			var feature = feature_index[feature_name]
			for rule in feature:
				for rule_units in rule["rule_units"]:
					for unit in rule_units:
						unit.color = Global.get_palette_color(unit.active_color)
		#for unit in units:
			#if unit.unit_type == "text":
				#unit.color = Global.get_palette_color(unit.active_color)

func post_rules():
	#where all, group, not NOUN, not VERB, and text are handled
	pass

func cartesian_product(arrays: Array, current_index: int = 0, current_combination: Array = []):
	if current_index == arrays.size():
		return current_combination
	
	var result = []
	for element in arrays[current_index]:
		var new_combination = current_combination.duplicate()
		new_combination.append(element)
		result += cartesian_product(arrays, current_index + 1, new_combination)
	
	return result

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
