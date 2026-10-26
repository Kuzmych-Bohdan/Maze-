extends Node2D
const Spawner = preload("res://scripts/Spawner.gd")

func _ready():
	var spawner = Spawner.new()
	add_child(spawner)
	model_now.text = G.selected_regression
	G.log_message("Spawner активний")


@onready var model_now = $modelNow
@onready var finish_text: Label = $finishText


func _process(_delta):
	if model_now.text != G.selected_regression:
		model_now.text = G.selected_regression
	if finish_text.text != G.finish_result_text:
		finish_text.text = G.finish_result_text
