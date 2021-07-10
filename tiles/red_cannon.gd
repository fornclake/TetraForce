extends StaticBody2D

var spritedir = "Right"

var TYPE = "PLAYER"
var fired = false
var mouth = false

signal update_persistent_state

func _ready():
	add_to_group("interactable")
	
func _physics_process(delta):
	pass
	
func interact(node : Entity):
	if node:
		if node.spritedir == "Left" && spritedir =="Right":
			mouth = true
		else:
			mouth = false
	if network.is_map_host():
		on_interact()
	else:
		network.peer_call_id(network.get_map_host(), self, "on_interact")
	
func on_interact():
	if fired == false && mouth == false:
		if network.is_map_host():
			network.peer_call(self, "on_interact")
		$AnimationPlayer.play("fuse" + spritedir)
		yield(get_tree().create_timer(2.5), "timeout")
		$AnimationPlayer.play("shot" + spritedir)
		use_weapon("CannonBall")
		fired = true

sync func use_weapon(weapon_name, input="A"):
	var weapon = global.weapons_def[weapon_name]
	var new_weapon = load(weapon.path).instance()
	var weapon_group = str(weapon_name, name)
	new_weapon.add_to_group(weapon_group)
	new_weapon.add_to_group(name)
	add_child(new_weapon)
	
	new_weapon.set_network_master(get_network_master())
	
	if get_tree().get_nodes_in_group(weapon_group).size() > new_weapon.MAX_AMOUNT:
		new_weapon.delete()
		return
	
	new_weapon.input = input
	new_weapon.start()
