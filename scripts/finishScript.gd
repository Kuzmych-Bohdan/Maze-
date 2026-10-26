extends Node2D

var finish_registered = false
var finish_completed = false

func _ready():
	var finish_data = {
		"x": position.x,
		"y": position.y
	}
	G.register_collision("finish_position", finish_data)
	
	# Initialize target to finish position
	G.target_position = Vector2(position.x, position.y)
	G.finish_position = Vector2(position.x, position.y)
	G.log_message("Finish position set: %s" % G.target_position)
	finish_registered = true


func _process(delta):
	# Finish position is registered only once in _ready()
	pass


func _on_finish_for_obj_body_entered(body):
	if finish_completed or not G.run_started or body != G.active_character:
		return

	finish_completed = true
	var elapsed_seconds = float(Time.get_ticks_msec() - G.run_started_msec) / 1000.0
	var hit_percentage = G.get_wall_hit_percentage()
	body.velocity = Vector2.ZERO
	G.run_started = false
	G.finish_result_text = "РЕЗУЛЬТАТ ПРОХОДЖЕННЯ\nПочаткова регресія: %s\nЧас проходження: %.2f с\nMSE (частота ударів об стіну): %.2f%% (%d із %d спроб руху)" % [G.initial_regression, elapsed_seconds, hit_percentage, G.wall_hit_count, G.movement_attempt_count]
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("\n".repeat(50))
	print("РЕЗУЛЬТАТ ПРОХОДЖЕННЯ")
	print("Початкова регресія: ", G.initial_regression)
	print("Час проходження: %.2f с" % elapsed_seconds)
	print("MSE проходження (частота ударів об стіну): %.2f%% (%d ударів із %d спроб руху)" % [hit_percentage, G.wall_hit_count, G.movement_attempt_count])
	G.textFinish = 1
