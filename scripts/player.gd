
extends RigidBody

var physics_accel = 30.0
var physics_decel = 60.0
var physics_jumpforce = 10.0

var physics_maxspeed = 9.0

slave var local_dir = Vector3()
slave var local_keys = [0, 0]

sync var linear_velocity = Vector3()
sync var transform_pos = Vector3()
sync var head_aim = Vector3()

onready var head = get_node("head")
onready var player_model = get_node("player_model")
onready var player_shadow = get_node("player_shadow")
onready var player_model_anim = get_node("player_model/AnimationPlayer")
onready var player_shadow_anim = get_node("player_shadow/AnimationPlayer")

sync var health = 0.0
sync var dead = false

var on_floor = false
var moving = false
var jumping = false

var next_shot = 0.0

var player_name = ""

var currentweapon = "shotgun"

func _init():
	health = 100.0
	dead = false

	moving = false
	jumping = false
	on_floor = false

	next_shot = 0.0

	player_name = ""

func _ready():
	head.set_active(true)

	player_shadow.get_node("armature/player").set_cast_shadows_setting(GeometryInstance.SHADOW_CASTING_SETTING_OFF)
	player_shadow.get_node("armature/player").set_cast_shadows_setting(GeometryInstance.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

	if get_name() == str(gamestate.cl_id):
		set_self_visible("model", false)

	set_process(true)
	set_fixed_process(true)

func _process(d):
	update_gui()
	dead_think()

func _fixed_process(d):
	update_animation()
	local_input()
	shoot_think()

func _integrate_forces(state):
	if is_network_master():
		client_movement(state)

	if get_tree().is_network_server():
		server_movement(state)
	else:
		client_update(state)

func set_self_visible(n, c):
	if c:
		player_model.show()
	else:
		player_model.hide()

func get_player_name():
	if is_network_master():
		return ""
	else:
		return player_name

func update_gui():
	pass

func update_animation():
	if dead:
		set_animation("dying")
		return

	var hv_len = linear_velocity;
	hv_len.y = 0
	hv_len = hv_len.length()

	if hv_len > 0.5:
		set_animation("walk")
		return

	set_animation("idle");

func set_animation(anim, speed = 1.0, force = false):
	if player_model_anim.get_current_animation() != anim || force:
		player_model_anim.play(anim)
		player_shadow_anim.play(anim)
	if player_model_anim.get_speed() != speed || force:
		player_model_anim.set_speed(speed)
		player_shadow_anim.set_speed(speed)

func local_input():
	if gamestate.cl_chatting:
		local_keys[0] = false
		local_keys[1] = false
	else:
		local_keys[0] = Input.is_action_pressed("player_jump")
		local_keys[1] = Input.is_action_pressed("player_shoot")

	rset_unreliable("local_keys", local_keys)

	head_aim = -head.get_global_transform().basis[2]
	rset_unreliable("head_aim", head_aim)

func dead_think():
	if !dead || !get_tree().is_network_server():
		return

	set_global_transform(Transform(Matrix3(), gamestate.get_random_spawnpoint()));

	print("Respawning not implemented, this is a hack")

	rset("health", 100.0)
	rset("dead", false)

func shoot_think():
	if !get_tree().is_network_server() || dead:
		return;

	if gamestate.world.time < next_shot || !local_keys[1]:
		return;

	var pos = get_node("head/shoot_pos").get_global_transform().origin;
	var impulse = (head_aim + Vector3(0, 0.1, 0))*30;

	rpc("fire_weapon", get_name().to_int(), pos, currentweapon)
	next_shot = gamestate.world.time + 1.0

func hurt_player(attacker, dmg):
	if !get_tree().is_network_server() || dead:
		return;

	health = clamp(health - dmg, 0.0, 100.0)
	rset("health", health)

	if health <= 0.0:
		rset("is_dying", true);

func client_movement(state):
	var dir = Vector3()
	var facing = get_global_transform().basis

	if !gamestate.cl_chatting:
		if Input.is_action_pressed("player_left"):
			dir -= facing[0]
		if Input.is_action_pressed("player_right"):
			dir += facing[0]
		if Input.is_action_pressed("player_forward"):
			dir -= facing[2]
		if Input.is_action_pressed("player_backward"):
			dir += facing[2]

	dir = dir.normalized()
	local_dir = dir

	rset_unreliable("local_dir", local_dir)

func server_movement(state):
	var lv = state.get_linear_velocity()
	var g = state.get_total_gravity()
	var delta = state.get_step()

	lv += g * delta # Apply gravity

	var up = -g.normalized() # (up is against gravity)
	var vv = up.dot(lv) # Vertical velocity
	var hv = lv - up*vv # Horizontal velocity

	var hdir = hv.normalized() # Horizontal direction
	var hspeed = hv.length() # Horizontal speed

	var floor_velocity
	var onfloor = false

	var dir = Vector3()
	if !dead:
		dir = local_dir

	var speed = physics_maxspeed

	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			if state.get_contact_local_shape(i) != 1:
				continue

			onfloor = true
			break

	var jump_attempt = local_keys[0] && !dead
	var target_dir = (dir - up * dir.dot(up)).normalized()

	moving = false

	if onfloor:
		if dir.length() > 0.1:
			hdir = target_dir

			if hspeed < speed:
				hspeed = min(hspeed + (physics_accel * delta), speed)
			else:
				hspeed = speed

			moving = true
		else:
			hspeed -= physics_decel * delta
			hspeed = max(hspeed, 0)

		hv = hdir * hspeed

		if not jumping and jump_attempt:
			vv = physics_jumpforce

			jumping = true
	else:
		if dir.length() > 0.1:
			hv += target_dir * (physics_accel * 0.2) * delta
			if hv.length() > speed:
				hv = hv.normalized()*speed

	if jumping and vv < 0:
		jumping = false

	lv = hv + up * vv
	on_floor = onfloor

	state.set_linear_velocity(lv)

	linear_velocity = lv
	rset_unreliable("linear_velocity", linear_velocity)

	transform_pos = state.get_transform().origin
	rset_unreliable("transform_pos", state.get_transform().origin)

func client_update(state):
	var transform = state.get_transform()

	if transform.origin.distance_to(transform_pos) < 2.0:
		transform.origin = transform.origin.linear_interpolate(transform_pos, 10 * state.get_step())
	else:
		transform.origin = transform_pos

	state.set_transform(transform)
	state.set_linear_velocity(linear_velocity)