extends Node2D
const Spawner = preload("res://scripts/Spawner.gd")

func _ready():
	var spawner = Spawner.new()
	add_child(spawner)
	print("🟢 Spawner активний")
