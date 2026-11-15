extends Area2D

@export var speed: float = 350.0
@export var obstacle_textures: Array[Texture2D]

func _ready():
	if obstacle_textures.size() > 0:
		$Sprite2D.texture = obstacle_textures.pick_random()

func _process(delta):
	position.x -= speed * delta

	if position.x < -500:
		queue_free()
