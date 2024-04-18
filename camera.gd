extends Node3D

const V_LOOK_SENS := 1
const H_LOOK_SENS := 1
const GLOBAL_SENS := 0.75

const SMOOTHNESS := 25

const ACCEL := 5.0
const DECEL := 10.0

var camera_input: Vector2
var rotation_velocity: Vector2

@onready var camera = $H/V/Camera3D
@onready var camera_y = $H/V
@onready var camera_h = $H
@onready var camera_root = self

func _ready():
	Global.camera = camera

func _input(event):
	if event is InputEventMouseMotion:
			camera_input = event.relative

func _process(delta):
	if Input.is_action_pressed("camera_drag"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		rotation_velocity = rotation_velocity.lerp(camera_input * GLOBAL_SENS, delta * SMOOTHNESS)
		camera_y.rotation_degrees.x -= rotation_velocity.y * V_LOOK_SENS
		camera_h.rotation_degrees.y -= rotation_velocity.x * H_LOOK_SENS
		
		camera_y.rotation_degrees.x = clamp(camera_y.rotation_degrees.x, -90, 90)
		camera_input = Vector2.ZERO
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
