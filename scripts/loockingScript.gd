extends CharacterBody2D

var speed = 120
var frame_count = 0

# =========================
# РЕЖИМ НАВІГАЦІЇ
# =========================
var navigation_mode = "predicted"  # "predicted" або "obstacle_avoidance"
var avoidance_timer = 0.0
var avoidance_timeout = 3.0  # Макс час в режимі уникання

# =========================
# НАПРЯМИ (для уникання)
# =========================
var directions_8 = [
	Vector2.RIGHT,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.UP,
	Vector2(1, 1).normalized(),
	Vector2(-1, 1).normalized(),
	Vector2(-1, -1).normalized(),
	Vector2(1, -1).normalized()
]

# Зберігаємо останній робочий напрямок в режимі уникання
var last_working_direction = Vector2.ZERO

# Затримки для перевірки застою
var predicted_check_timer = 0.0
var predicted_check_interval = 0.25
var predicted_stuck_time = 0.0
var predicted_stuck_threshold = 0.75
var prev_predicted_position = Vector2.ZERO


func _physics_process(delta):
	frame_count += 1

	# Визначити цільову позицію
	if G.target_position == Vector2.ZERO:
		if G.finish_position != Vector2.ZERO:
			G.target_position = G.finish_position
		else:
			return

	if prev_predicted_position == Vector2.ZERO:
		prev_predicted_position = global_position

	# Логіка навігації
	if navigation_mode == "predicted":
		move_toward_predicted(delta)
	else:
		move_with_obstacle_avoidance(delta)

	# Запис позиції
	if frame_count % 2 == 0:
		G.clear_positions_x.append(global_position.x)
		G.clear_positions_y.append(global_position.y)


# =========================
# РЕЖИМ 1: РУХ ЗА ПРОГНОЗОМ
# =========================
func move_toward_predicted(delta):
	var avg_target = (G.target_position + G.finish_position) / 2.0
	var dir = (avg_target - global_position)

	if dir.length() < 5:
		velocity = Vector2.ZERO
		return

	dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()

	check_predicted_stagnation(delta)


# =========================
# РЕЖИМ 2: УНИКАННЯ ПЕРЕШКОД
# =========================
func move_with_obstacle_avoidance(delta):
	avoidance_timer += delta

	# Таймаут - повертаємося до прогнозу
	if avoidance_timer > avoidance_timeout:
		print("⏱️ Avoidance timeout! Returning to predicted mode")
		navigation_mode = "predicted"
		return

	# Спробуємо рухатися в останньому робочому напрямку
	if last_working_direction != Vector2.ZERO:
		velocity = last_working_direction * speed
		var prev_pos = global_position
		move_and_slide()

		# Перевіряємо, чи дійсно рухнулись
		var moved_distance = global_position.distance_to(prev_pos)
		
		if moved_distance > 3:
			# Успішно рухаємось - продовжуємо
			return
		else:
			# Застрявли - шукаємо новий напрям
			print("⚠️ Stuck in direction, finding new one...")
			find_best_avoidance_directions()
	else:
		# Якщо немає робочого напрямку, шукаємо
		find_best_avoidance_directions()


# =========================
# ПЕРЕВІРКА ЗАСТОЮ ПРИ ПРОГНОЗНОМУ РУХУ
# =========================
func check_predicted_stagnation(delta):
	predicted_check_timer += delta
	if predicted_check_timer < predicted_check_interval:
		return

	predicted_check_timer = 0.0
	var moved_distance = global_position.distance_to(prev_predicted_position)
	prev_predicted_position = global_position

	if moved_distance < 8:
		predicted_stuck_time += predicted_check_interval
	else:
		predicted_stuck_time = max(predicted_stuck_time - predicted_check_interval, 0.0)

	if predicted_stuck_time >= predicted_stuck_threshold:
		print("⚠️ Stuck near same coordinates too long, switching to avoidance")
		navigation_mode = "obstacle_avoidance"
		avoidance_timer = 0.0
		predicted_stuck_time = 0.0
		find_best_avoidance_directions()


# =========================
# ПОШУК НАЙКРАЩОГО НАПРЯМУ УНИКАННЯ
# =========================
func find_best_avoidance_directions():
	print("🧭 Alternative route search started: looking for detour around wall")
	var finish_dir = (G.finish_position - global_position).normalized()

	# Сортуємо напрями за близькістю до напрямку на фініш
	var sorted_directions = directions_8.duplicate()
	sorted_directions.sort_custom(func(a, b):
		var dist_a = a.angle_to(finish_dir)
		var dist_b = b.angle_to(finish_dir)
		return dist_a < dist_b
	)

	print("🧭 Searching for free direction...")
	for i in range(sorted_directions.size()):
		var test_dir = sorted_directions[i]
		
		# Спробуємо рухатися в цьому напрямку
		if try_move_in_direction(test_dir):
			print("  ✅ Direction ", i, " is FREE: ", test_dir)
			last_working_direction = test_dir
			return
		else:
			print("  ❌ Direction ", i, " is BLOCKED: ", test_dir)

	# Якщо немає вільних напрямів - спробуємо рандомний
	print("🎲 No free directions! Using random...")
	last_working_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()


# =========================
# СПРОБА РУХАТИСЬ В НАПРЯМКУ
# =========================
func try_move_in_direction(direction: Vector2) -> bool:
	# Зберігаємо позицію перед спробою
	var prev_pos = global_position
	
	# Спробуємо рухатися
	velocity = direction * speed
	move_and_slide()
	
	# Перевіряємо, чи дійсно рухнулись
	var moved_distance = global_position.distance_to(prev_pos)
	var success = moved_distance > 5
	
	# Повертаємось у вихідне положення якщо не змогли рухатися
	if not success:
		global_position = prev_pos
	
	return success
