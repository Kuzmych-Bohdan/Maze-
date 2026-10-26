extends Node

var socket := WebSocketPeer.new()
var connected := false
var send_cooldown = 0.3  # Затримка між надсиланнями (секунди)
var send_timer = 0.0


func _ready():
	var err = socket.connect_to_url("ws://localhost:6000")

	if err != OK:
		G.log_message("Не вдалося підключитися")
	else:
		G.log_message("Підключення...")


func _process(delta):
	socket.poll()
	send_timer -= delta

	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			G.log_message("Connected to Python")

		send_data()
		receive_data()

	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			G.log_message("Connection closed")
			connected = false


# =========================
# ВІДПРАВКА
# =========================
func send_data():

	var data = {
		"clearSector": {
			"positionClearSectorX": G.clear_positions_x,
			"positionClearSectorY": G.clear_positions_y
		},
		"wallSector": {
			"positionWallSectorX": G.wall_positions_x,
			"positionWallSectorY": G.wall_positions_y
		},
		"collisions": G.collisions,
		"selectedRegression": G.selected_regression
	}

	if G.clear_positions_x.size() > 0 and send_timer <= 0:
		G.log_message("Sending: %d positions" % G.clear_positions_x.size())
		socket.send_text(JSON.stringify(data))
		send_timer = send_cooldown  # Встановити затримку

	G.collisions.clear()


# =========================
# ОТРИМАННЯ
# =========================
func receive_data():

	while socket.get_available_packet_count() > 0:

		var msg = socket.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(msg)

		if parsed == null:
			G.log_message("JSON parse failed")
			return

		if not parsed.has("status"):
			G.log_message("No status in response")
			return

		if parsed["status"] != "success":
			if parsed["status"] == "waiting":
				pass  # Collecting data, wait
			else:
				G.log_message("Server status: %s" % parsed["status"])
			return

		if not parsed.has("models") or not parsed["models"].has(G.selected_regression):
			G.log_message("Invalid response structure")
			return

		var model_predictions = parsed["models"][G.selected_regression]
		if not model_predictions is Array or model_predictions.is_empty():
			G.log_message("Empty regression prediction")
			return
		var pos = model_predictions[0]

		if pos is Array and pos.size() >= 2:
			G.target_position = Vector2(pos[0], pos[1])
			G.has_new_data = true
			G.log_message("%s prediction received: %s" % [G.selected_regression, G.target_position])
		
			# Keep last 2 positions for continuous data flow
			if G.clear_positions_x.size() > 2:
				G.clear_positions_x = G.clear_positions_x.slice(-2)
				G.clear_positions_y = G.clear_positions_y.slice(-2)
			if G.wall_positions_x.size() > 2:
				G.wall_positions_x = G.wall_positions_x.slice(-2)
				G.wall_positions_y = G.wall_positions_y.slice(-2)
			G.log_message("Keeping last 2 positions for next batch")
