extends CharacterBody2D

var speed = 120
var frame_count = 0

func _physics_process(delta):
	frame_count += 1

	# If no target, use finish position as temporary target
	if G.target_position == Vector2.ZERO:
		if G.finish_position != Vector2.ZERO:
			G.target_position = G.finish_position
		else:
			return

	var dir = (G.target_position - global_position)

	if dir.length() < 5:
		velocity = Vector2.ZERO
		return

	dir = dir.normalized()

	velocity = dir * speed
	move_and_slide()

	# Record position every frame
	if frame_count % 2 == 0:  # Record every 2nd frame to reduce data volume
		G.clear_positions_x.append(global_position.x)
		G.clear_positions_y.append(global_position.y)
