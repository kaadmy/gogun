
extends Tree

var credit_text = [
	["Game Design", [
		["KaadmY", "https://github.com/kaadmy"],
		]
	],
#	["Sounds", [
#		["KaadmY", "https://github.com/kaadmy"],
#		]
#	],
]

func _ready():
	set_hide_root(true)
	var parent_root = create_item()

	for category in credit_text:
		var parent_category = create_item(parent_root)
		parent_category.set_text(0, category[0])

		for name in category[1]:
			var it = create_item(parent_category)
			it.set_text(0, name[0])

			if name.size() > 1:
				it.set_tooltip(0, name[1])