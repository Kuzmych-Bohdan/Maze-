# server.gd
extends Node

var client = WebSocketPeer.new()
var url = "ws://localhost:6000"
var send_timer = 0.0
var send_interval = 1.0  # Відправляти кожну секунду

func _ready():
	var err = client.connect_to_url(url)
	if err != OK:
		push_error("Не вдалося підключитися до сервера")
	else:
		print("✅ Успішне підключення до сервера")

func _process(delta):
	client.poll()
	
	# Таймер для відправки даних
	send_timer += delta
	if send_timer >= send_interval:
		send_timer = 0.0
		send_data()
	
	# Обробка вхідних повідомлень
	while client.get_available_packet_count() > 0:
		var packet = client.get_packet()
		handle_server_response(packet.get_string_from_utf8())

func send_data():
	if client.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("⚠️ З'єднання не встановлено")
		return
	

	var message = G.get_message_data()

	

	client.put_packet(JSON.stringify(message).to_utf8_buffer())

func handle_server_response(response):
	var json_data = JSON.parse_string(response)
	if json_data == null:
		push_error("Не вдалося розібрати відповідь сервера")
		return
	
	if json_data.has("error"):
		push_error("Помилка сервера: " + str(json_data["error"]))
	else:
		G.process_server_data(json_data)
