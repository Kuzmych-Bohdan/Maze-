extends Node

# =========================
#   РУХ
# =========================
var target_position: Vector2 = Vector2.ZERO
var predicted_position: Vector2 = Vector2.ZERO
var has_new_data: bool = false


# =========================
#   ІСТОРІЯ
# =========================
var clear_positions_x: Array = []
var clear_positions_y: Array = []

var wall_positions_x: Array = []
var wall_positions_y: Array = []


# =========================
#   КОЛІЗІЇ 
# =========================
var collisions: Array = []


# =========================
#   ФІНІШ
# =========================
var finish_position: Vector2 = Vector2.ZERO

const REGRESSION_MODELS = ["linear", "polynomial", "ridge", "svr", "random_forest"]
var selected_regression: String = "linear"
var initial_regression: String = "linear"
var run_started: bool = false
var run_started_msec: int = 0
var active_character: CharacterBody2D
var wall_hit_count: int = 0
var movement_attempt_count: int = 0

var textFinish = 0
var finish_result_text: String = ""


func log_message(message: String):
	if textFinish == 0:
		print(message)


func begin_run():
	if run_started:
		return
	run_started = true
	initial_regression = selected_regression
	run_started_msec = Time.get_ticks_msec()
	wall_hit_count = 0
	movement_attempt_count = 0


func record_movement_attempt():
	if run_started:
		movement_attempt_count += 1


func get_wall_hit_percentage() -> float:
	if movement_attempt_count == 0:
		return 0.0
	return clampf(float(wall_hit_count) / movement_attempt_count * 100.0, 0.0, 100.0)


# =========================
#   ПРИЙОМ ВІД PYTHON
# =========================
func set_prediction(pos: Vector2):
	predicted_position = pos
	target_position = pos
	has_new_data = true


# =========================
#   КОЛІЗІЇ
# =========================
func register_collision(type: String, data):

	var event = {
		"type": type,
		"data": data
	}

	collisions.append(event)

	if type == "wall_hit":
		if run_started:
			wall_hit_count += 1
		wall_positions_x.append(data["position"]["x"])
		wall_positions_y.append(data["position"]["y"])

	elif type == "finish_position":
		finish_position = Vector2(data["x"], data["y"])
		target_position = finish_position
