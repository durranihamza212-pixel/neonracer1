
extends CharacterBody2D

@export var move_speed: float = 300.0
@export var jump_force: float = 500.0
@export var jump_gravity: float = 1200.0
@export var rotation_amount: float = 10.0
@export var rotation_smoothness: float = 8.0
@export var roll_duration: float = 0.45
@export var flip_boost: float = 400.0
@export var flip_cooldown: float = 5.0

# JUMP CHARGE SETTINGS
@export var small_jump_boost: float = 110.0
@export var big_jump_boost: float = 320.0

@onready var car_sprite: Sprite2D = $Sprite2D

var accelerate_sound: AudioStreamPlayer
var brake_sound: AudioStreamPlayer

var jumping := false
var ground_y: float
var is_rolling := false
var ground_rotation: float
var cooldown_timer: float = 0.0

var dust_trail: GPUParticles2D
var jump_charge: float = 0.0


func _ready():
	ground_y = global_position.y
	ground_rotation = car_sprite.rotation

	accelerate_sound = get_node_or_null("../AccelerateSound") as AudioStreamPlayer
	brake_sound = get_node_or_null("../BrakeSound") as AudioStreamPlayer

	if accelerate_sound == null:
		push_warning("AccelerateSound not found. Check Main scene.")

	if brake_sound == null:
		push_warning("BrakeSound not found. Check Main scene.")

	create_dust_trail()


func create_particle_texture() -> Texture2D:
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)

	for y in range(8):
		for x in range(8):
			var distance = Vector2(x - 3.5, y - 3.5).length()
			var alpha = clamp(1.0 - distance / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)


func create_dust_trail():
	dust_trail = GPUParticles2D.new()

	dust_trail.amount = 35
	dust_trail.lifetime = 0.3
	dust_trail.explosiveness = 0.0
	dust_trail.emitting = false
	dust_trail.local_coords = false
	dust_trail.top_level = true
	dust_trail.texture = create_particle_texture()

	var particle_material = ParticleProcessMaterial.new()

	particle_material.direction = Vector3(1, 0, 0)
	particle_material.spread = 15.0
	particle_material.initial_velocity_min = 20.0
	particle_material.initial_velocity_max = 45.0
	particle_material.gravity = Vector3(0, 40, 0)
	particle_material.scale_min = 0.5
	particle_material.scale_max = 5
	particle_material.color = Color.BLUE

	dust_trail.process_material = particle_material

	add_child(dust_trail)


func update_dust_trail():
	if car_sprite.texture == null:
		return

	var size = car_sprite.texture.get_size() * car_sprite.scale

	var trail_pos = Vector2(
		size.x * -0.1,
		size.y * 0.5 - 24
	)

	dust_trail.global_position = car_sprite.to_global(trail_pos)

	dust_trail.emitting = Input.is_key_pressed(KEY_A)


func perform_roll():
	if is_rolling or not jumping or cooldown_timer > 0.0:
		return

	is_rolling = true
	cooldown_timer = flip_cooldown

	velocity.y = -flip_boost

	var tween = create_tween()

	tween.tween_property(
		car_sprite,
		"rotation",
		car_sprite.rotation - TAU,
		roll_duration
	).set_trans(Tween.TRANS_LINEAR)

	tween.tween_callback(func():
		car_sprite.rotation = ground_rotation
		is_rolling = false
	)


func _physics_process(delta):

	# ACCELERATION SOUND - D
	if accelerate_sound != null:
		if Input.is_key_pressed(KEY_D):
			if not accelerate_sound.playing:
				accelerate_sound.play()
		else:
			if accelerate_sound.playing:
				accelerate_sound.stop()

	# BRAKE SOUND - A
	if brake_sound != null:
		if Input.is_key_pressed(KEY_A):
			if not brake_sound.playing:
				brake_sound.play()
		else:
			if brake_sound.playing:
				brake_sound.stop()

	# JUMP CHARGING
	if not jumping and Input.is_key_pressed(KEY_A):
		jump_charge = min(jump_charge + delta, 2.0)

	# FLIP COOLDOWN
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var direction = Input.get_axis("left", "right")
	velocity.x = direction * move_speed

	# JUMP WITH CHARGE
	if Input.is_action_just_pressed("ui_accept") and not jumping:

		var extra_boost = 0.0

		if jump_charge >= 2.0:
			extra_boost = big_jump_boost
		elif jump_charge >= 1.0:
			extra_boost = small_jump_boost

		jumping = true
		velocity.y = -(jump_force + extra_boost)

		jump_charge = 0.0

	# BACKFLIP
	if Input.is_key_pressed(KEY_W) and jumping and not is_rolling and cooldown_timer <= 0.0:
		perform_roll()

	# GRAVITY
	if jumping:
		velocity.y += jump_gravity * delta

		if not is_rolling:
			var target_rotation = ground_rotation

			if velocity.y < -20:
				target_rotation = ground_rotation - deg_to_rad(rotation_amount)
			elif velocity.y > 20:
				target_rotation = ground_rotation + deg_to_rad(rotation_amount)

			car_sprite.rotation = lerp_angle(
				car_sprite.rotation,
				target_rotation,
				clamp(rotation_smoothness * delta, 0.0, 1.0)
			)

	move_and_slide()

	# LANDING
	if jumping and velocity.y > 0 and global_position.y >= ground_y:
		global_position.y = ground_y
		velocity.y = 0
		jumping = false

	update_dust_trail()

	# RESET ROTATION
	if not jumping and not is_rolling:
		car_sprite.rotation = lerp_angle(
			car_sprite.rotation,
			ground_rotation,
			clamp(rotation_smoothness * delta, 0.0, 1.0)
		)
