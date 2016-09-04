
extends Node

var sv_maxplayers

var cl_id
var cl_name
var cl_chatting

var spawnpoints
var spawnpoint_path

var players
var players_path

var mainmenu

var world
var world_shortpath

var prefab_player

func _init():
	cl_name = ""
	cl_chatting = false

	spawnpoints = []
	spawnpoint_path = "../env/spawnpoints/"

	players_path = "../env/players/"

	world_shortpath = null

	reset_variables()

func reset_variables():
	players = {}
	spawnpoints = []
	cl_chatting = false

func _ready():
	get_tree().connect("network_peer_connected", self, "_peer_connected");
	get_tree().connect("network_peer_disconnected", self, "_peer_disconnected");

	get_tree().connect("connected_to_server", self, "_client_success");
	get_tree().connect("connection_failed", self, "_client_failed");
	get_tree().connect("server_disconnected", self, "_client_disconnected");

	prefab_player = load("res://prefabs/player.tscn")

func create_game(port, maxplayers):
	sv_maxplayers = maxplayers

	var net = NetworkedMultiplayerENet.new()

	if net.create_server(port, maxplayers) != OK:
		print("Could not start server on port ", port)
		return false

	get_tree().set_network_peer(net)

	create_world()

	print("Started server on port ", port)

	return true

func join_game(ip, port):
	var net = NetworkedMultiplayerENet.new()

	if net.create_client(ip, port) != OK:
		print("Could not connect to ", ip, ":", port)
		return false

	get_tree().set_network_peer(net)

	print("Connecting to ", ip, ":", port)

	return true

func end_game():
	mainmenu.set_join_disable(false)

	if world != null:
		mainmenu.show()

		world.get_parent().remove_child(world)
		world.call_deferred("free")
		world = null

	reset_variables()
	get_tree().call_deferred("set_network_peer", null)

func _peer_connected(id):
	if !get_tree().is_network_server():
		return

	players[id] = null

func _peer_disconnected(id):
	if !get_tree().is_network_server():
		return

	if players.has(id):
		player_disconnected(id)
		players.erase(id)

func _client_success():
	rpc("player_joined", get_tree().get_network_unique_id(), cl_name)

func _client_failed():
	print("Failed connecting to server")
	end_game()

func _client_disconnected():
	print("Disconnected from server")
	end_game()

master func player_joined(id, name):
	if !players.has(id) || players[id] != null || !get_tree().is_network_server():
		return

	players[id] = name
	player_connected(id)

master func player_ready(id):
	if !players.has(id) || players[id] == null || !get_tree().is_network_server():
		return

	if id != 1:
		rpc_id(id, "clean_players")

		for i in world.get_node(players_path).get_children():
			var pid = i.get_name().to_int()

			if pid == id:
				continue

			var pos = i.get_global_transform()

			rpc_id(id, "spawn_player", pid, players[pid], pos)

	var spawn_pos = get_spawnpoint()
	rpc("spawn_player", id, players[id], spawn_pos)

	print("Player #", id, " joined")

func player_connected(id):
	if id != 1:
		rpc_id(id, "create_world")

func player_disconnected(id):
	rpc("despawn_player", id)

	print("Player #", id, "disconnected")

remote func create_world():
	world = load(world_shortpath + ".tscn").instance()
	world.set_name("env")

	get_tree().get_root().call_deferred("add_child", world)

func create_host_player():
	if !get_tree().is_network_server():
		return

	_peer_connected(1)
	player_joined(1, cl_name)
	player_ready(1)

func world_ready():
	mainmenu.hide()

	if !get_tree().is_network_server():
		rpc("player_ready", get_tree().get_network_unique_id())
	else:
		setup_spawnpoints()
		create_host_player()

remote func clean_players():
	if !world:
		return

	for i in get_players():
		i.queue_free()

sync func spawn_player(id, name, pos = null):
	if player_by_id(id) != null:
		return

	var inst = prefab_player.instance()

	if id == get_tree().get_network_unique_id():
		cl_id = id

	inst.set_name(str(id))
	inst.player_name = str(name)

	if pos != null:
		inst.set_global_transform(pos)

	if id == get_tree().get_network_unique_id():
		inst.set_network_mode(NETWORK_MODE_MASTER)
	else:
		inst.set_network_mode(NETWORK_MODE_SLAVE)

	world.get_node(players_path).add_child(inst)

sync func despawn_player(id):
	var node = player_by_id(id)

	if node == null:
		return

	node.queue_free()

func player_by_id(id):
	var path = players_path + str(id)

	if !world.has_node(path):
		return null

	return world.get_node(path)

func setup_spawnpoints():
	spawnpoints.clear()
	for i in world.get_node(spawnpoint_path).get_children():
		var pos = i.get_global_transform()
		spawnpoints.append(pos)

func get_spawnpoint():
	return spawnpoints[int(rand_range(0, spawnpoints.size()))]

func get_players():
	var ret = []

	for i in world.get_node(players_path).get_children():
		if !players.has(i.get_name().to_int()):
			continue

		ret.append(i)

	return ret

func apply_effects(world):
	var sun = world.get_node("sun")
	sun.set_project_shadows(mainmenu.config.get_value("effects", "shadow_enabled"))

	var env = world.get_environment()

	env.set_enable_fx(Environment.FX_GLOW, mainmenu.config.get_value("effects", "bloom_enabled"))
	env.set_enable_fx(Environment.FX_HDR, mainmenu.config.get_value("effects", "hdr_enabled"))

	world.set_environment(env)