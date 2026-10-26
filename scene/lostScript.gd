extends Area2D

var wall = 1


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	if body != G.active_character:
		return

	var wall_data = {
		"wall": wall,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		}
	}

	if G:
		G.register_collision("wall_hit", wall_data)
