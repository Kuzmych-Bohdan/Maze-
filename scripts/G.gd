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
#   КОЛІЗІЇ (🔥 ОСЬ НОВЕ)
# =========================
var collisions: Array = []


# =========================
#   ФІНІШ
# =========================
var finish_position: Vector2 = Vector2.ZERO


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
		wall_positions_x.append(data["position"]["x"])
		wall_positions_y.append(data["position"]["y"])

	elif type == "finish_position":
		finish_position = Vector2(data["x"], data["y"])
		target_position = finish_position
