
extends Node2D

# ROAD SPEED
@export var speed: float = 280.0
@export var speed_increase: float = 12.0
@export var max_road_speed: float = 750.0

# OBSTACLE SETTINGS
@export var obstacle_scene: PackedScene
@export var obstacle_speed: float = 550.0
@export var obstacle_speed_increase: float = 6.0
@export var max_obstacle_speed: float = 900.0

# SPAWNING SETTINGS
@export var min_spawn_delay: float = 2.5
@export var max_spawn_delay: float = 4.5
@export var spawn_distance: float = 300.0
@export var remove_distance: float = 1500.0
@export var spawn_height_range: float = 45.0

@onready var road1: Sprite2D = $Road1
@onready var road2: Sprite2D = $Road2
@onready var car: CharacterBody2D = $cat
@onready var rest_sound: AudioStreamPlayer2D = $RestSound

var road_width: float
var spawn_timer: float = 0.0
var next_spawn: float = 2.0

var obstacles: Array[Node2D] = []
var game_over: bool = false
var game_started: bool = false

# SCORE
var score: float = 0.0
var score_timer: float = 0.0
var score_label: Label

# HIGH SCORE
var high_score: int = 0
var high_score_label: Label
var new_record: bool = false

# GUI
var ui: CanvasLayer
var start_screen: Control

# LANDING DETECTION
var was_car_jumping: bool = false


func _ready():

	randomize()
	load_high_score()

	rest_sound.play()

	road_width = road1.texture.get_width() * road1.scale.x

	road2.global_position.x = road1.global_position.x + road_width
	road2.global_position.y = road1.global_position.y

	next_spawn = randf_range(min_spawn_delay, max_spawn_delay)

	create_gui()


# ==========================================
# GUI
# ==========================================

func create_gui():

	ui = CanvasLayer.new()
	ui.layer = 100
	add_child(ui)

	create_score_gui()
	create_high_score_gui()
	create_start_screen()


func create_score_gui():

	score_label = Label.new()

	score_label.text = "SCORE: 0"
	score_label.position = Vector2(25, 20)

	score_label.add_theme_font_size_override("font_size", 29)
	score_label.add_theme_color_override("font_color", Color.WHITE)

	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)

	ui.add_child(score_label)


func create_high_score_gui():

	var panel = PanelContainer.new()

	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)

	panel.offset_left = -225
	panel.offset_right = -20
	panel.offset_top = 20
	panel.offset_bottom = 92

	var style = StyleBoxFlat.new()

	style.bg_color = Color(0.02, 0.02, 0.05, 0.8)
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)

	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)

	panel.add_theme_stylebox_override("panel", style)

	ui.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)

	panel.add_child(layout)

	var heading = Label.new()

	heading.text = "PERSONAL BEST"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	layout.add_child(heading)

	high_score_label = Label.new()

	high_score_label.text = str(high_score)
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	high_score_label.add_theme_font_size_override("font_size", 30)
	high_score_label.add_theme_color_override("font_color", Color.WHITE)

	layout.add_child(high_score_label)


# ==========================================
# START SCREEN
# ==========================================

func create_start_screen():

	start_screen = Control.new()
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	ui.add_child(start_screen)

	var background = ColorRect.new()

	background.color = Color(0, 0, 0, 0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	start_screen.add_child(background)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	start_screen.add_child(center)

	var layout = VBoxContainer.new()

	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)

	center.add_child(layout)

	var title = Label.new()

	title.text = "NEON RACER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	title.add_theme_font_size_override("font_size", 55)
	title.add_theme_color_override("font_color", Color.WHITE)

	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)

	layout.add_child(title)

	var subtitle = Label.new()

	subtitle.text = "SURVIVE THE ROAD"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	layout.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 15

	layout.add_child(spacer)

	var prompt = Label.new()

	prompt.text = "PRESS ANY KEY TO START"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	prompt.add_theme_font_size_override("font_size", 21)
	prompt.add_theme_color_override("font_color", Color.WHITE)

	layout.add_child(prompt)

	var tween = create_tween().set_loops()

	tween.tween_property(prompt, "modulate:a", 0.3, 0.7)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.7)


func start_game():

	if game_started:
		return

	game_started = true

	if rest_sound.playing:
		rest_sound.stop()

	var tween = create_tween()

	tween.tween_property(start_screen, "modulate:a", 0.0, 0.3)
	tween.tween_callback(start_screen.queue_free)


# ==========================================
# GAME OVER SCREEN
# ==========================================

func show_game_over_screen():

	var overlay = Control.new()

	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	ui.add_child(overlay)

	var background = ColorRect.new()

	background.color = Color(0, 0, 0, 0.78)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	overlay.add_child(background)

	var center = CenterContainer.new()

	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	overlay.add_child(center)

	var layout = VBoxContainer.new()

	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 15)

	center.add_child(layout)

	var title = Label.new()

	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	title.add_theme_font_size_override("font_size", 55)
	title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.12))

	layout.add_child(title)

	var final_score = Label.new()

	final_score.text = "SCORE: " + str(int(score))
	final_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	final_score.add_theme_font_size_override("font_size", 30)
	final_score.add_theme_color_override("font_color", Color.WHITE)

	layout.add_child(final_score)

	var best = Label.new()

	best.text = "PERSONAL BEST: " + str(high_score)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	best.add_theme_font_size_override("font_size", 20)
	best.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

	layout.add_child(best)

	if new_record:

		var record = Label.new()

		record.text = "NEW PERSONAL BEST!"
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		record.add_theme_font_size_override("font_size", 22)
		record.add_theme_color_override("font_color", Color.YELLOW)

		layout.add_child(record)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10

	layout.add_child(spacer)

	var restart_button = Button.new()

	restart_button.text = "RESTART"
	restart_button.custom_minimum_size = Vector2(190, 55)

	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	restart_button.add_theme_font_size_override("font_size", 23)

	restart_button.add_theme_color_override("font_color", Color.WHITE)
	restart_button.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.3))

	layout.add_child(restart_button)

	restart_button.pressed.connect(_on_restart_pressed)

	overlay.modulate.a = 0.0

	var tween = create_tween()

	tween.tween_property(overlay, "modulate:a", 1.0, 0.4)


# ==========================================
# INPUT
# ==========================================

func _input(event):

	if game_over:
		return

	if not game_started:

		if event is InputEventKey and event.pressed and not event.echo:
			start_game()

		elif event is InputEventMouseButton and event.pressed:
			start_game()

		return

	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_D:
			dust_behind_car()


# ==========================================
# MAIN GAME LOOP
# ==========================================

func _process(delta):

	if game_over or not game_started:
		return

	# DIE ONLY IF CAR LEAVES LEFT OR RIGHT EDGE

	var screen_size = get_viewport_rect().size

	if car.global_position.x < -50 or car.global_position.x > screen_size.x + 50:
		end_game()
		return

	# LANDING DETECTION

	var car_is_jumping = car.get("jumping")

	if was_car_jumping and not car_is_jumping:
		landing_effect()

	was_car_jumping = car_is_jumping

	# SCORE

	score_timer += delta

	if score_timer >= 2.0:
		score += 1.0
		score_timer -= 2.0

	score_label.text = "SCORE: " + str(int(score))

	# ROAD SPEED

	speed = min(speed + speed_increase * delta, max_road_speed)

	# OBSTACLE SPEED

	obstacle_speed = min(
		obstacle_speed + obstacle_speed_increase * delta,
		max_obstacle_speed
	)

	# ROAD LOOPING

	road1.global_position.x -= speed * delta
	road2.global_position.x -= speed * delta

	var left_road = road1
	var right_road = road2

	if road2.global_position.x < road1.global_position.x:
		left_road = road2
		right_road = road1

	if left_road.global_position.x + road_width / 2.0 <= 0:
		left_road.global_position.x = right_road.global_position.x + road_width

	# SPAWNING

	spawn_timer += delta

	if spawn_timer >= next_spawn:

		spawn_timer = 0.0
		next_spawn = randf_range(min_spawn_delay, max_spawn_delay)

		spawn_obstacle()

	# MOVE OBSTACLES

	for obstacle in obstacles:

		if is_instance_valid(obstacle):

			obstacle.global_position.x -= obstacle_speed * delta

			if obstacle.global_position.x < -remove_distance:
				obstacle.queue_free()

	obstacles = obstacles.filter(func(o): return is_instance_valid(o))


# ==========================================
# HIGH SCORE
# ==========================================

func load_high_score():

	var save_file = ConfigFile.new()

	var error = save_file.load("user://high_score.cfg")

	if error == OK:
		high_score = save_file.get_value("scores", "high_score", 0)
	else:
		high_score = 0


func save_high_score():

	var save_file = ConfigFile.new()

	save_file.set_value("scores", "high_score", high_score)
	save_file.save("user://high_score.cfg")


func update_high_score():

	if int(score) > high_score:

		high_score = int(score)
		new_record = true

		save_high_score()

	high_score_label.text = str(high_score)


# ==========================================
# OBSTACLES
# ==========================================

func spawn_obstacle():

	if obstacle_scene == null:
		print("ERROR: Obstacle scene is not assigned!")
		return

	var obstacle = obstacle_scene.instantiate() as Area2D

	if obstacle == null:
		return

	add_child(obstacle)

	var random_y = randf_range(
		car.global_position.y - spawn_height_range,
		car.global_position.y + spawn_height_range
	)

	obstacle.global_position = Vector2(
		get_viewport_rect().size.x + spawn_distance,
		random_y
	)

	obstacle.body_entered.connect(_on_obstacle_body_entered)

	obstacles.append(obstacle)


func _on_obstacle_body_entered(body: Node2D):

	if body == car:
		end_game()


# ==========================================
# LANDING EFFECT
# ==========================================

func landing_effect():

	var landing_position = car.global_position + Vector2(0, 300)

	for i in range(36):

		var particle = Polygon2D.new()
		var particle_size = randf_range(3.0, 7.0)

		particle.polygon = PackedVector2Array([
			Vector2(-particle_size, -particle_size),
			Vector2(particle_size, -particle_size),
			Vector2(particle_size, particle_size),
			Vector2(-particle_size, particle_size)
		])

		particle.color = [
			Color(0.75, 0.72, 0.65, 0.9),
			Color(0.6, 0.58, 0.52, 0.85),
			Color(0.9, 0.85, 0.75, 0.9),
			Color(0.5, 0.48, 0.43, 0.8)
		].pick_random()

		particle.global_position = landing_position
		particle.z_index = 150
		add_child(particle)

		var direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-0.8, -0.1)
		).normalized()

		var distance = randf_range(35.0, 90.0)
		var duration = randf_range(0.35, 0.65)

		var tween = create_tween()
		tween.set_parallel(true)

		tween.tween_property(particle, "global_position", particle.global_position + direction * distance, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2.ZERO, duration)

		tween.chain().tween_callback(particle.queue_free)


# ==========================================
# DUST EFFECT
# ==========================================

func dust_behind_car():

	var dust_position = car.global_position + Vector2(-35, 250)

	for i in range(14):

		var particle = Polygon2D.new()
		var particle_size = randf_range(12.0, 20.0)

		particle.polygon = PackedVector2Array([
			Vector2(-particle_size, -particle_size),
			Vector2(particle_size, -particle_size),
			Vector2(particle_size, particle_size),
			Vector2(-particle_size, particle_size)
		])

		particle.color = [
			Color(0.9, 0.1, 0.1, 0.8),
			Color(0.65, 0.05, 0.05, 0.75),
			Color(1.0, 0.25, 0.2, 0.8)
		].pick_random()

		particle.global_position = dust_position + Vector2(
			randf_range(-16.0, 16.0),
			randf_range(-16.0, 16.0)
		)

		particle.z_index = 150
		add_child(particle)

		var direction = Vector2(
			randf_range(-1.0, -0.2),
			randf_range(-0.7, -0.1)
		).normalized()

		var distance = randf_range(30.0, 80.0)
		var duration = 1.0

		var tween = create_tween()
		tween.set_parallel(true)

		tween.tween_property(particle, "global_position", particle.global_position + direction * distance, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2.ZERO, duration)

		tween.chain().tween_callback(particle.queue_free)


# ==========================================
# GAME OVER
# ==========================================

func end_game():

	if game_over:
		return

	game_over = true

	update_high_score()

	set_process(false)
	set_physics_process(false)

	car.set_physics_process(false)
	car.set_process(false)

	for obstacle in obstacles:

		if is_instance_valid(obstacle):

			obstacle.set_process(false)
			obstacle.set_physics_process(false)

	crash_effect()

	await get_tree().create_timer(0.65).timeout

	show_game_over_screen()


func crash_effect():

	var car_tween = create_tween()
	car_tween.set_parallel(true)

	car_tween.tween_property(car, "rotation", car.rotation + deg_to_rad(40), 0.2)
	car_tween.tween_property(car, "scale", car.scale * 1.4, 0.2)
	car_tween.tween_property(car, "modulate", Color(1.0, 0.2, 0.05), 0.2)

	var flash = ColorRect.new()

	flash.color = Color(1, 0.65, 0.2, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 150

	ui.add_child(flash)

	var flash_tween = create_tween()

	flash_tween.tween_property(flash, "color:a", 0.0, 0.45)
	flash_tween.tween_callback(flash.queue_free)

	for i in range(45):

		var spark = Polygon2D.new()
		var particle_size = randf_range(5.0, 15.0)

		spark.polygon = PackedVector2Array([
			Vector2(-particle_size, -particle_size),
			Vector2(particle_size, -particle_size),
			Vector2(particle_size, particle_size),
			Vector2(-particle_size, particle_size)
		])

		spark.color = [
			Color.ORANGE,
			Color.YELLOW,
			Color.RED,
			Color.WHITE,
			Color(1.0, 0.25, 0.0),
			Color(1.0, 0.65, 0.0)
		].pick_random()

		spark.global_position = car.global_position + Vector2(0, 200)
		spark.z_index = 200
		add_child(spark)

		var direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		var distance = randf_range(100.0, 280.0)

		var spark_tween = create_tween()
		spark_tween.set_parallel(true)

		spark_tween.tween_property(spark, "global_position", spark.global_position + direction * distance, 0.65)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.65)
		spark_tween.tween_property(spark, "scale", Vector2.ZERO, 0.65)

		spark_tween.chain().tween_callback(spark.queue_free)

	for i in range(18):

		var fire = Polygon2D.new()
		var size = randf_range(15.0, 30.0)

		fire.polygon = PackedVector2Array([
			Vector2(-size, -size),
			Vector2(size, -size),
			Vector2(size, size),
			Vector2(-size, size)
		])

		fire.color = [
			Color.RED,
			Color.ORANGE,
			Color.YELLOW
		].pick_random()

		fire.global_position = car.global_position + Vector2(
			randf_range(-35.0, 35.0),
			randf_range(-35.0, 35.0) + 200
		)

		fire.z_index = 190
		add_child(fire)

		var direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		var fire_tween = create_tween()
		fire_tween.set_parallel(true)

		fire_tween.tween_property(fire, "global_position", fire.global_position + direction * randf_range(80.0, 190.0), 0.8)
		fire_tween.tween_property(fire, "scale", Vector2.ZERO, 0.8)
		fire_tween.tween_property(fire, "modulate:a", 0.0, 0.8)

		fire_tween.chain().tween_callback(fire.queue_free)


# ==========================================
# RESTART
# ==========================================

func _on_restart_pressed():

	get_tree().reload_current_scene()
