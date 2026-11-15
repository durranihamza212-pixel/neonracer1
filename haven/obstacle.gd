extends Area2D

@export var speed: float = 350.0

func _process(delta):
	position.x -= speed * delta

	if position.x < -200:
		queue_free()
