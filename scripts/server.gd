extends Node

var socket := WebSocketPeer.new()
var connected := false
var send_cooldown = 0.3  # Затримка між надсиланнями (секунди)
var send_timer = 0.0


func _ready():
	var err = socket.connect_to_url("ws://localhost:6000")

	if err != OK:
		print("❌ Не вдалося підключитися")
	else:
		print("🔄 Підключення...")


func _process(delta):
	socket.poll()
	send_timer -= delta

	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			print("✅ Connected to Python")

		send_data()
		receive_data()

	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			print("❌ Connection closed")
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
		"collisions": G.collisions
	}

	if G.clear_positions_x.size() > 0 and send_timer <= 0:
		print("📤 Sending: ", G.clear_positions_x.size(), " positions")
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
			print("❌ JSON parse failed")
			return

		if not parsed.has("status"):
			print("❌ No status in response")
			return

		if parsed["status"] != "success":
			if parsed["status"] == "waiting":
				pass  # Collecting data, wait
			else:
				print("⚠️ Server status: ", parsed["status"])
			return

		if not parsed.has("models") or not parsed["models"].has("linear"):
			print("❌ Invalid response structure")
			return

		var pos = parsed["models"]["linear"][0]

		if pos is Array and pos.size() >= 2:
			G.target_position = Vector2(pos[0], pos[1])
			G.has_new_data = true
			print("✅ Prediction received: ", G.target_position)
		
			# Keep last 2 positions for continuous data flow
			if G.clear_positions_x.size() > 2:
				G.clear_positions_x = G.clear_positions_x.slice(-2)
				G.clear_positions_y = G.clear_positions_y.slice(-2)
			if G.wall_positions_x.size() > 2:
				G.wall_positions_x = G.wall_positions_x.slice(-2)
				G.wall_positions_y = G.wall_positions_y.slice(-2)
			print("🔄 Keeping last 2 positions for next batch")
