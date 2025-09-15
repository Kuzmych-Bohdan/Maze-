extends StaticBody2D

var wall := 0
var model_name := ""




@onready var area: Area2D = $Area2D

func initialize(spawn_position: Vector2, model: String):
	model_name = model
	wall = 0
	global_position = spawn_position
	#print("🟢 Створено [", model_name, "] на позиції: ", global_position)
	G.should_follow_prediction = true
	
	
func _on_area_body_entered(body: Node) -> void:
	if  wall == 0:
		wall = 1
		#print("🛑 Модель [", model_name, "] зафіксувала [", body, "] на ", global_position)
		send_collision_data()

func send_collision_data():
	var collision_data = {
		"model": model_name,
		"wall": wall,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		}
	}
	if G:
		G.register_collision(collision_data)


func _on_area_2d_body_entered(body):

	wall = 0
	#print("🟢 Модель [", model_name, "] не зафіксувала стіни на ", global_position)
	send_collision_data()



