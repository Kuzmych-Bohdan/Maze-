extends Node2D

var finish_registered = false

func _ready():
	var finish_data = {
		"x": position.x,
		"y": position.y
	}
	G.register_collision("finish_position", finish_data)
	
	# Initialize target to finish position
	G.target_position = Vector2(position.x, position.y)
	G.finish_position = Vector2(position.x, position.y)
	print("🎯 Finish position set: ", G.target_position)
	finish_registered = true


func _process(delta):
	# Finish position is registered only once in _ready()
	pass
