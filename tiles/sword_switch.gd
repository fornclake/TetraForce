extends "res://engine/switch.gd"

func _update_sprite():
	if activated:
		$Sprite.frame_coords.x = 1
	else:
		$Sprite.frame_coords.x = 0

func _on_HitBox_area_entered(area: Area2D):
	update_state()