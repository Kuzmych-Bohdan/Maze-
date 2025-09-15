# G.gd
extends Node

var positionClearSector = {
	"positionClearSectorX": [],
	"positionClearSectorY": []
}

var positionWallSector = {
	"positionWallSectorX": [],
	"positionWallSectorY": []    
}

var previous_positionFromPythonX = {
	"linearX": [],
	"polynomialX": [],
	"ridgeX": [],
	"svrX": [],
	"random_forestX": []
}

var previous_positionFromPythonY = {
	"linearY": [],
	"polynomialY": [],
	"ridgeY": [],
	"svrY": [],
	"random_forestY": []
}

func get_message_data():
	# Повертає дані для відправки, перевіряючи їх наявність
	var message = {
		"clearSector": {
			"positionClearSectorX": positionClearSector["positionClearSectorX"].duplicate(),
			"positionClearSectorY": positionClearSector["positionClearSectorY"].duplicate()
		},
		"wallSector": {
			"positionWallSectorX": positionWallSector["positionWallSectorX"].duplicate(),
			"positionWallSectorY": positionWallSector["positionWallSectorY"].duplicate()
		},
		"collisions": collisions.duplicate()
	}
	return message

func process_server_data(data):
	# Очищаємо попередні дані
	for model in previous_positionFromPythonX:
		previous_positionFromPythonX[model].clear()
		previous_positionFromPythonY[model.replace("X", "Y")].clear()
	
	# Обробляємо отримані дані
	if data.has("models"):
		for model in ["linear", "polynomial", "ridge", "svr", "random_forest"]:
			var x_key = model + "_X"
			var y_key = model + "_Y"
			
			if data["models"].has(x_key) and data["models"].has(y_key):
				previous_positionFromPythonX[model + "X"] = data["models"][x_key]
				previous_positionFromPythonY[model + "Y"] = data["models"][y_key]
	
	# Виводимо отримані дані для дебагу

	#for model in ["linear", "polynomial", "ridge", "svr", "random_forest"]:
		#print("Модель %s:" % model)
		#print("  X:", previous_positionFromPythonX[model + "X"])
		#print("  Y:", previous_positionFromPythonY[model + "Y"])
	on_new_data_received()
	
func clear_data():
	positionClearSector["positionClearSectorX"].clear()
	positionClearSector["positionClearSectorY"].clear()
	positionWallSector["positionWallSectorX"].clear()
	positionWallSector["positionWallSectorY"].clear()

var has_new_data = false
func on_new_data_received():
	print("work")
	has_new_data = true
	
# Додаємо обробник зіткнень
var collisions = []  # Новий масив для збереження зіткнень

func register_collision(collision_data):
	collisions.append(collision_data)

var modelNow  = "linear"

#рух до прогнозованого
var should_follow_prediction := false
# для режиму АІ
var finish_position = {}

var prediction_wall_hits := 0

