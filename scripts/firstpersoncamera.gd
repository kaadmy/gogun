
extends Spatial

var pitch = 0.0
var yaw = 0.0
var sensitivity = 0.3

var camera

func _ready():
	camera = get_node("camera")

func set_active(active):
	if (active):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	set_process(active)
	set_fixed_process(active)
	set_process_input(active)

func _input(ie):
	if (Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED):
		return

	if (ie.type == InputEvent.MOUSE_MOTION):
		pitch = clamp(pitch - (ie.relative_y * sensitivity), -89.0, 89.0)
		yaw = fmod(yaw - (ie.relative_x * sensitivity), 360.0)

func _process(delta):
	set_rotation_deg(Vector3(pitch, 0, 0))
	get_parent().set_rotation_deg(Vector3(0, yaw, 0))