extends Node2D

@onready var G = get_node("/root/G")

var last_spawned_obj: Node2D = null
var selected_model = "linear"

func _process(delta):

	if G.has_new_data:
		print("🎯 Spawner activated! Spawning at: ", G.target_position)
		spawn_prediction(G.target_position)
		G.has_new_data = false


func spawn_prediction(pos: Vector2):

	# видаляємо старий
	if last_spawned_obj:
		last_spawned_obj.queue_free()

	# створюємо новий
	var obj = Node2D.new()
	obj.position = pos

	add_child(obj)
	last_spawned_obj = obj
