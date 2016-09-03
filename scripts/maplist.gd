
extends Tree

func _ready():
	var dir = Directory.new()

	if dir.open("res://maps/") != OK:
		return

	dir.list_dir_begin()

	var mappaths = []

	while true:
		var file = dir.get_next()

		if file == "":
			break
		elif file.ends_with(".tscn"):
			mappaths.append(file)

	dir.list_dir_end()

	var parent = create_item()
	set_hide_root(true)

	for mapfile in mappaths:
		var path = mapfile.split("/")
		var mapname = path[path.size() - 1].split(".")[0]

		var it = create_item(parent)
		it.set_text(0, mapname)

	connect("item_activated", self, "select_map")

func select_map():
	var shortpath = "res://maps/" + (get_selected().get_text(0))

	gamestate.world_shortpath = shortpath

	var file = File.new()

	var image = Image()
	if file.file_exists(shortpath + ".png"):
		image.load(shortpath + ".png")
	else:
		print("Could not find mapshot for map '" + (get_selected().get_text(0)) + "'")
		image.load("res://icon.png")

	var texture = ImageTexture.new()
	texture.create_from_image(image)

	get_node("../mapicon").set_texture(texture)