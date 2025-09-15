extends Node2D
@onready var textModelNow = $modelNow


func _process(delta):
	textModelNow.text = G.modelNow
