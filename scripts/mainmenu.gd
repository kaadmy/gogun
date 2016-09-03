
extends Control

var config
var connected

var options = [
	["user", "nickname", "Gogunner"],

	["effects", "shadow_enabled", true],
	["effects", "bloom_enabled", true],
	["effects", "hdr_enabled", true],
]

func _ready():
	gamestate.mainmenu = self

	connected = false

	get_node("button_quit").connect("pressed", self, "_button_quit_pressed")

	get_node("tabs/Multiplayer/button_create").connect("pressed", self, "_button_create_pressed")
	get_node("tabs/Multiplayer/button_join").connect("pressed", self, "_button_join_pressed")
	get_node("tabs/Multiplayer/button_disconnect").connect("pressed", self, "_button_disconnect_pressed")

	config = ConfigFile.new()
	config.load("user://config.cfg")

	for opt in options:
		if not config.has_section_key(opt[0], opt[1]):
			config.set_value(opt[0], opt[1], opt[2])

	get_node("tabs/Options/options_nickname").set_text(config.get_value("user", "nickname"))

	get_node("tabs/Options/options_shadow_enabled").set_pressed(config.get_value("effects", "shadow_enabled"))
	get_node("tabs/Options/options_shadow_enabled").connect("pressed", self, "_options_shadow_enabled_pressed")

	get_node("tabs/Options/options_bloom_enabled").set_pressed(config.get_value("effects", "bloom_enabled"))
	get_node("tabs/Options/options_bloom_enabled").connect("pressed", self, "_options_bloom_enabled_pressed")

	get_node("tabs/Options/options_hdr_enabled").set_pressed(config.get_value("effects", "hdr_enabled"))
	get_node("tabs/Options/options_hdr_enabled").connect("pressed", self, "_options_hdr_enabled_pressed")

	get_node("tabs/Options/apply_effects").connect("pressed", self, "_apply_effects_pressed")

	set_process_input(true)

func _input(ie):
	if ie.type == InputEvent.KEY && !gamestate.cl_chatting && connected:
		if ie.pressed && ie.scancode == KEY_ESCAPE:
			if is_hidden():
				set_mouse_capture(false)
				show()
			else:
				set_mouse_capture(true)
				hide()

func save_config():
	config.set_value("user", "nickname", get_node("tabs/Options/options_nickname").get_text())
	config.save("user://config.cfg")

func _notification(id):
	if id == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_config()

func _button_quit_pressed():
	save_config()
	gamestate.end_game()
	get_tree().quit()

func _button_create_pressed():
	if !gamestate.world_shortpath:
		print("No world selected")
		return

	var name = get_node("tabs/Options/options_nickname").get_text()
	var port = int(get_node("tabs/Multiplayer/net_port").get_value())
	var maxplayers = int(get_node("tabs/Multiplayer/create_maxplayers").get_value())

	gamestate.cl_name = name

	if !gamestate.create_game(port, maxplayers):
		return

	set_join_disable(true)

func _button_join_pressed():
	var name = get_node("tabs/Options/options_nickname").get_text()
	var ip = get_node("tabs/Multiplayer/net_ip").get_text()
	var port = int(get_node("tabs/Multiplayer/net_port").get_value())

	gamestate.cl_name = name

	if !gamestate.join_game(ip, port):
		return

	set_join_disable(true)

func _button_disconnect_pressed():
	gamestate.end_game()

func set_mouse_capture(c):
	if c:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func set_join_disable(c):
	get_node("tabs/Multiplayer/button_create").set_disabled(c)

	get_node("tabs/Multiplayer/button_join").set_hidden(c)
	get_node("tabs/Multiplayer/button_join").set_disabled(c)

	get_node("tabs/Multiplayer/button_disconnect").set_hidden(!c)
	get_node("tabs/Multiplayer/button_disconnect").set_disabled(!c)

	if c == false:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	connected = c

func _options_shadow_enabled_pressed():
	config.set_value("effects", "shadow_enabled", !config.get_value("effects", "shadow_enabled"))

func _options_bloom_enabled_pressed():
	config.set_value("effects", "bloom_enabled", !config.get_value("effects", "bloom_enabled"))

func _options_hdr_enabled_pressed():
	config.set_value("effects", "hdr_enabled", !config.get_value("effects", "hdr_enabled"))

func _apply_effects_pressed():
	if has_node("/root/env"):
		gamestate.apply_effects(get_node("/root/env"))
