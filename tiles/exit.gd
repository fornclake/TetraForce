extends Area2D

export(String) var map
export(String) var player_position
export(String) var entrance
export(String, ".tmx", ".tscn") var file_format = ".tmx"
func _ready():
	connect("body_entered", self, "body_entered")

func body_entered(body):
	if body.is_in_group("player") && body.is_network_master():
		body.state = "interact"
		global.change_map(map, file_format, entrance)
