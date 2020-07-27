extends Entity

class_name Player

onready var nametag = $nametag
onready var ray = $RayCast2D

var push_counter = 0

func initialize():
	add_to_group("player")
	if is_network_master():
		global.player = self
		set_physics_process(false)
		state = "default"
		
		position = get_parent().get_node(global.next_entrance).position
		var offset = get_parent().get_node(global.next_entrance).player_position
		match offset:
			"up":
				position.y -= 16
				spritedir = "Up"
			"down":
				position.y += 16
				spritedir = "Down"
			"left":
				position.x -= 16
				spritedir = "Left"
				sprite.flip_h = true
			"right":
				position.x += 16
				spritedir = "Right"

		home_position = position

		connect_camera()
		camera.initialize(self)

		anim_switch("idle")

		var hud = preload("res://ui/hud.tscn").instance()
		add_child(hud)
		hud.initialize(self)

		yield(screenfx, "animation_finished")

		set_physics_process(true)
	network.current_map.emit_signal("player_entered", int(name))

func _physics_process(_delta):
	if !is_network_master():
		sprite.flip_h = (spritedir == "Left")
		return

	match state:
		"default":
			state_default()
		"swing":
			state_swing()
		"hold":
			state_hold()
		"spin":
			state_spin()
		"die":
			state_die()

func state_default():
	loop_controls()
	loop_movement()
	loop_spritedir()
	loop_damage()
	loop_action_button()
	loop_interact()
	
	if movedir.length() == 1:
		ray.cast_to = movedir * 8
	
	if movedir == Vector2.ZERO:
		anim_switch("idle")
		push_counter = 0
	elif is_on_wall() && ray.is_colliding() && !ray.get_collider().is_in_group("nopush") && movedir != Vector2.ZERO:
		anim_switch("push")
		push_counter += get_physics_process_delta_time()
	else:
		anim_switch("walk")
		push_counter = 0

func state_swing():
	anim_switch("swing")
	loop_movement()
	loop_damage()
	movedir = Vector2.ZERO

func state_hold():
	loop_controls()
	loop_movement()
	loop_damage()
	if movedir == Vector2.ZERO:
		anim_switch("idle")
		push_counter = 0
	elif is_on_wall() && ray.is_colliding():
		anim_switch("walk")
		push_counter += get_physics_process_delta_time()
	else:
		anim_switch("walk")
		push_counter = 0
	
	if !has_node("Sword"):
		state = "default"

func state_spin():
	anim_switch("spin")
	loop_movement()
	loop_damage()
	movedir = Vector2.ZERO

func state_die():
	if anim.assigned_animation != "die":
		animation = "die"
		anim.play("die")

func respawn():
	if is_network_master():
		knockdir = Vector2(0,0)
		position = home_position
		set_health(MAX_HEALTH)
		emit_signal("health_changed")
		state = "default"

func check_for_death():
	if health <= 0:
		state = "die"

func loop_controls():
	movedir = Vector2.ZERO
	
	var LEFT = Input.is_action_pressed("LEFT")
	var RIGHT = Input.is_action_pressed("RIGHT")
	var UP = Input.is_action_pressed("UP")
	var DOWN = Input.is_action_pressed("DOWN")
	
	movedir.x = -int(LEFT) + int(RIGHT)
	movedir.y = -int(UP) + int(DOWN)

func loop_action_button():
	if Input.is_action_just_pressed("B"):
		use_item("res://items/sword.tscn", "B")
		network.peer_call(self, "use_item", ["res://items/sword.tscn", "B"])

func loop_interact():
	if ray.is_colliding():
		var collider = ray.get_collider()
		if collider.is_in_group("interactable") && Input.is_action_just_pressed("A"):
			collider.interact(self)
		elif is_on_wall() && collider.is_in_group("pushable") && push_counter >= 0.75:
			collider.interact(self)
			push_counter = 0

func connect_camera():
	camera.connect("screen_change_started", self, "screen_change_started")
	camera.connect("screen_change_completed", self, "screen_change_completed")

func screen_change_started():
	set_physics_process(false)

func screen_change_completed():
	set_physics_process(true)
