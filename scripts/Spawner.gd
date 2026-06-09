extends Node2D

@onready var G = get_node("/root/G")

var last_spawned_obj: Node2D = null
var selected_model = "linear"
var spawn_cooldown = 1.5  # Затримка в секундах (об'єкт залишається 1.5 сек)
var spawn_timer = 0.0

func _process(delta):

	spawn_timer -= delta
	
	if G.has_new_data and spawn_timer <= 0:
		# Усереднити позицію: (прогноз + фініш) / 2
		var averaged_pos = (G.target_position + G.finish_position) / 2.0
		print("🎯 Spawner activated!")
		print("  Predicted: ", G.target_position)
		print("  Finish: ", G.finish_position)
		print("  Averaged: ", averaged_pos)
		spawn_prediction(averaged_pos)
		G.has_new_data = false
		spawn_timer = spawn_cooldown  # Встановити затримку


func spawn_prediction(pos: Vector2):

	# видаляємо старий
	if last_spawned_obj:
		last_spawned_obj.queue_free()

	# створюємо новий
	var obj = Node2D.new()
	obj.position = pos

	add_child(obj)
	last_spawned_obj = obj
