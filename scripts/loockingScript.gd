extends CharacterBody2D

const SPEED = 100.0
const CLOSE_DISTANCE = 5.0

# Таймери
var startTimer = 0.0
var finishTimer = randi() % 3
var startTimerPosition = 0.0
var finishTimerPosition = 0.3
var startTimerFollowing = 0.0
var endTimerFollowing = 0.3

# Стан
var touchWallTrue = false
var startUserMove = false
var useAI = false
var epocha = 0
var ai_start_position: Vector2

# AI - уникнення перешкод
var ai_blocked_positions: Array[Vector2] = []

# Рух по прогнозованих точках
var path: Array[Vector2] = []
var path_index := 0
var followPredictedPath := false

func _ready():
	randomMove()
	ai_start_position = global_position

func _physics_process(delta):
	if Input.is_action_just_pressed('startUserMove'):
		startUserMove = true
		print("🕹️ Режим ручного керування:", startUserMove)
	if Input.is_action_just_pressed('AI'):
		useAI = true
		print("🤖 AI-режим активовано")

	if followPredictedPath and path.size() > 0:
		move_along_path()
	elif useAI:
		run_AI_mode()
	elif startUserMove:
		userMove()
	else:
		objectMove(delta)
		moveX()
		moveY()

	move_and_slide()
	positionTimer(delta)

	if G.should_follow_prediction:
		start_following_prediction()
		startTimerFollowing += delta
		if startTimerFollowing >= endTimerFollowing:
			G.should_follow_prediction = false

# === AI РУХ ===
func run_AI_mode():
	var finish = G.finish_position
	var target = Vector2(finish["x"], finish["y"])

	# Уникнення блокованих точок 
	for blocked in ai_blocked_positions:
		if global_position.distance_to(blocked) < CLOSE_DISTANCE:
			print("⛔ Обхід заблокованої точки: ", blocked)
			var avoid_direction = (global_position - blocked).normalized()
			var sidestep = Vector2(avoid_direction.y, -avoid_direction.x) * 50  # зміщення вбік
			var new_target = global_position + avoid_direction * 30 + sidestep
			var direction = (new_target - global_position).normalized()
			velocity = direction * SPEED
			return

	# Звичайний рух до фінішу
	var direction = (target - global_position).normalized()
	velocity = direction * SPEED


# === СПАВН ПІСЛЯ УДАРУ ===
func _on_body_area_body_entered(body):
	touchWallTrue = true
	G.positionWallSector["positionWallSectorX"].append(float(position.x))
	G.positionWallSector["positionWallSectorY"].append(float(position.y))

	if useAI:
		print("💥 AI вдарився об стіну, повертаємось на старт")
		ai_blocked_positions.append(global_position)
		global_position = ai_start_position
		epocha += 1
		print("🔁 Epocha:", epocha)

func _on_body_area_body_exited(body):
	touchWallTrue = false

# === РУХ ПО ПРОГНОЗУ ===
func move_along_path():
	if path_index >= path.size():
		followPredictedPath = false
		return

	# Якщо AI торкнувся стіни — випадковий обхід
	if touchWallTrue:
		G.prediction_wall_hits += 1  # 🔢 глобальний лічильник ударів
		var dir = randi() % 4
		match dir:
			0:
				velocity = Vector2(0, -1) * SPEED  # Вгору
			1:
				velocity = Vector2(0, 1) * SPEED   # Вниз
			2:
				velocity = Vector2(-1, 0) * SPEED  # Вліво
			3:
				velocity = Vector2(1, 0) * SPEED   # Вправо
		print("💥 Удар по прогнозу! Загальна кількість:", G.prediction_wall_hits)
		return

	var target = path[path_index]
	var direction = (target - global_position).normalized()
	velocity = direction * SPEED

	if global_position.distance_to(target) <= CLOSE_DISTANCE:
		path_index += 1


func start_following_prediction():
	path.clear()
	path_index = 0
	var x_list = G.previous_positionFromPythonX.get("linearX", [])
	var y_list = G.previous_positionFromPythonY.get("linearY", [])

	if x_list.size() != y_list.size() or x_list.is_empty():
		print("⚠️ Прогноз відсутній або некоректний")
		return

	for i in range(x_list.size()):
		path.append(Vector2(x_list[i], y_list[i]))

	followPredictedPath = true

# === ВИПАДКОВИЙ РУХ ===
var directionX = 0
var directionY = 0

func randomMove():
	if randf() < 0.5:
		directionX = -1 if randf() < 0.5 else 1
	if randf() < 0.5:
		directionY = -1 if randf() < 0.5 else 1

func objectMove(delta):
	if touchWallTrue:
		bodyTouchWall()
	else:
		randTimer(delta)

func userMove():
	if Input.is_action_just_pressed("ui_left"):
		directionX = -1
	if Input.is_action_just_pressed("ui_right"):
		directionX = 1
	if Input.is_action_just_pressed("ui_up"):
		directionY = -1
	if Input.is_action_just_pressed("ui_down"):
		directionY = 1

func moveX():
	velocity.x = directionX * SPEED if directionX else move_toward(velocity.x, 0, SPEED)

func moveY():
	velocity.y = directionY * SPEED if directionY else move_toward(velocity.y, 0, SPEED)

func randTimer(delta):
	startTimer += delta
	if startTimer >= finishTimer:
		randomMove()
		startTimer = 0.0
		finishTimer = randi() % 3

func positionTimer(delta):
	startTimerPosition += delta
	if startTimerPosition >= finishTimerPosition:
		positionInMaze()
		startTimerPosition = 0.0

func positionInMaze():
	if not touchWallTrue:
		G.positionClearSector["positionClearSectorX"].append(float(position.x))
		G.positionClearSector["positionClearSectorY"].append(float(position.y))

func bodyTouchWall():
	directionX *= -1
	directionY *= -1
