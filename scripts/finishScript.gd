extends StaticBody2D

var finishObj = false
var deltaForEnd = 0.0

var finishPositionX
var finishPositionY

var positionUpdateTimer = 0.0
const POSITION_UPDATE_INTERVAL = 0.3  # секунди

func _ready():
	finishPositionX = position.x
	finishPositionY = position.y

	# Для AI
	G.finish_position = {
		"x": position.x,
		"y": position.y
	}

	print("📍 Координати фінішу: (", finishPositionX, ", ", finishPositionY, ")")

	send_finish_position()  # перший запуск

func _process(delta):
	if not finishObj:
		deltaForEnd += delta
	else:
		send_finish_result()
		finishObj = false

	positionUpdateTimer += delta
	if positionUpdateTimer >= POSITION_UPDATE_INTERVAL:
		send_finish_position()
		positionUpdateTimer = 0.0

func _on_finish_for_obj_body_entered(body):
	finishObj = true
	#print("✅ Фініш досягнуто об'єктом: ", body)

func send_finish_position():
	var finish_data = {
		"finish_position": {
			"x": position.x,
			"y": position.y
		}
	}
	var repetition = 1
	for i in range(repetition):
		if G:
			G.register_collision({
				"type": "finish_position",
				"data": finish_data
			})

func send_finish_result():
	var model = G.modelNow

	var wall_hits = 0
	if "prediction_wall_hits" in G:
		wall_hits = G.prediction_wall_hits


	# Формула MSE:
	# Менше ударів і більше часу без ударів = вищий результат
	var base_score: float = 100.0
	var base_penalty: float = 5.0
	var time_factor: float = clamp(deltaForEnd / 10.0, 0.5, 2.0)
	var penalty: float = wall_hits * base_penalty / time_factor
	var mse: float = clamp(base_score - penalty, 0, base_score)


	var result_data = {
		"model": model,
		"time_to_finish": deltaForEnd,
		"wall_hits": wall_hits,
		"mse": mse,
		"position": {
			"x": position.x,
			"y": position.y
		}
	}

	if G:
		G.register_collision({
			"type": "finish_result",
			"data": result_data
		})
		print("📤 Надсилаємо результат фінішу:")
		print("  ▶️ Модель:", model)
		print("  ⏱️ Час до фінішу:", str(deltaForEnd), "сек")
		print("  💥 Кількість ударів:", wall_hits)
		print("  📊 MSE (ефективність):", str(mse), "%")
		print("  📍 Позиція:", result_data["position"])
