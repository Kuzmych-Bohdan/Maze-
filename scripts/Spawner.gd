extends Node2D

const AUDIT = preload("res://scene/audit.tscn")
var spawned_objects: Array = []
@onready var spawn_marker = $Marker2D

var spawn_queue = []
var spawn_index := 0
var spawn_delay := 0.1
var timer_position := 0.0
var spawning_in_progress := false

var last_spawned_obj: Node2D = null

# Додано: модель, яку вибрано для спавну (за замовчуванням — всі)
var selected_model := "linear"


func _ready():
	position = Vector2.ZERO


func _process(delta: float) -> void:
	# Вибір моделі через клавіші 1–5
	if Input.is_action_just_pressed("ui_select_model_1"):
		selected_model = "linear"
		G.modelNow = selected_model
		print("🔢 Обрано модель: linear")
	elif Input.is_action_just_pressed("ui_select_model_2"):
		selected_model = "polynomial"
		print("🔢 Обрано модель: polynomial")
		G.modelNow = selected_model
	elif Input.is_action_just_pressed("ui_select_model_3"):
		selected_model = "ridge"
		print("🔢 Обрано модель: ridge")
		G.modelNow = selected_model
	elif Input.is_action_just_pressed("ui_select_model_4"):
		selected_model = "svr"
		print("🔢 Обрано модель: svr")
		G.modelNow = selected_model
	elif Input.is_action_just_pressed("ui_select_model_5"):
		selected_model = "random_forest"
		print("🔢 Обрано модель: random_forest")
		G.modelNow = selected_model

	if G.has_new_data:
		queue_spawn_data()
		G.has_new_data = false

	if spawning_in_progress:
		timer_position += delta
		if timer_position >= spawn_delay:
			timer_position = 0.0
			spawn_next_object()


func queue_spawn_data():
	if G.previous_positionFromPythonX.is_empty():
		return

	clear_old_objects()
	spawn_queue.clear()
	spawn_index = 0
	timer_position = 0.0
	spawning_in_progress = true

	for model_key in G.previous_positionFromPythonX:
		var model_name = model_key.replace("X", "")
		if selected_model != "" and model_name != selected_model:
			continue

		var y_model = model_key.replace("X", "Y")
		var x_coords = G.previous_positionFromPythonX[model_key]
		var y_coords = G.previous_positionFromPythonY[y_model]

		for i in range(min(x_coords.size(), y_coords.size())):
			spawn_queue.append({
				"position": Vector2(x_coords[i], y_coords[i]),
				"model": model_name
			})


func spawn_next_object():
	if spawn_index < spawn_queue.size():
		var data = spawn_queue[spawn_index]
		create_audit_object(data["position"], data["model"])
		spawn_index += 1
	else:
		spawning_in_progress = false
		print("✅ Створено %d об'єктів" % spawned_objects.size())


func create_audit_object(target_position: Vector2, model: String):
	if is_instance_valid(last_spawned_obj):
		last_spawned_obj.queue_free()

	var new_obj = AUDIT.instantiate()
	get_parent().add_child(new_obj)
	new_obj.initialize(target_position, model)
	spawned_objects.append(new_obj)
	last_spawned_obj = new_obj


func clear_old_objects():
	for obj in spawned_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	spawned_objects.clear()
