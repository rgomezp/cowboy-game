extends Node

# preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")
var butterfly_scene = preload("res://scenes/obstacles/butterfly.tscn")

var obstacle_types := [rock_scene, agave_scene]
var obstacles : Array
var last_obstacle
var last_obstacle_score : int = 0
var butterfly_heights := [150, -300]

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var score : int
var high_score : int
var SCORE_MODIFIER : int = 100
var speed : float
const START_SPEED : float = 10.0
const SPEED_MODIFIER : int = 10_000
const MAX_SPEED : int = 15
var screen_size : Vector2i
var game_running : bool
var ground_height : int
var last_butterfly_time : float = 0.0
var next_butterfly_interval : float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size	# see how far we've scrolled
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("Button").pressed.connect(new_game)
	new_game()

func new_game():
	# reset variables
	score = 0
	last_obstacle_score = 0
	last_butterfly_time = 0.0
	next_butterfly_interval = randf_range(1.0, 5.0)
	show_score()
	game_running = false
	get_tree().paused = false
	
	# delete all obstacles
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()

	# reset the nodes
	$Player.position = PLAYER_START_POS
	$Player.velocity = Vector2i(0, 0)
	$Camera2D.position = CAMERA_START_POS
	$Ground.position = Vector2i(0, 0)

	#reset hud and game over scene
	$Hud.get_node("StartLabel").show()
	$GameOver.hide()


# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		speed = START_SPEED + score / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		# generate obstacles
		generate_obs()
		# check butterfly spawning
		check_butterfly_spawn(delta)

		# move player position & camera
		$Player.position.x += speed
		$Camera2D.position.x += speed

		# update score
		score += speed
		show_score()

		# update ground position
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x

		for obs in obstacles:
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$Hud.get_node("StartLabel").hide()

func show_score():
	$Hud.get_node("ScoreValue").text = str(score / SCORE_MODIFIER)

func check_high_score():
	if score > high_score:
		high_score = score
	$Hud.get_node("HighScoreValue").text = str(high_score / SCORE_MODIFIER)

func generate_obs():
	var should_generate = false
	if obstacles.is_empty():
		should_generate = true
	else:
		# Calculate distance from last obstacle based on score difference
		var distance_since_last = score - last_obstacle_score
		# Use a much larger, more varied random range for spacing
		# This creates sparse, unpredictable spacing between obstacles
		var min_spacing = randi_range(4000, 7000)
		var max_spacing = randi_range(10000, 20000)
		var required_spacing = randi_range(min_spacing, max_spacing)
		should_generate = distance_since_last >= required_spacing

	if should_generate:
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs
		obs = obs_type.instantiate()
		var obs_sprite = obs.get_node("Sprite2D")
		var obs_height = obs_sprite.texture.get_height()
		var obs_scale = obs_sprite.scale
		var obs_sprite_offset = obs_sprite.position
		var ground_sprite = $Ground.get_node("Sprite2D")
		var ground_top_y = ground_sprite.offset.y
		# Add some randomness to the x position as well
		var base_x = screen_size.x + score + 100
		var random_offset = randi_range(-50, 50)
		var obs_x : int = base_x + random_offset
		# Position rock so its bottom edge sits on top of the ground
		# Ground top is at ground_sprite.offset.y
		# Rock sprite is centered, so its bottom is at: obs.position.y + obs_sprite_offset.y + (obs_height * obs_scale.y / 2)
		# We need: obs.position.y + obs_sprite_offset.y + (obs_height * obs_scale.y / 2) = ground_top_y
		# Add a small offset to push it slightly lower
		var obs_y : int = ground_top_y - obs_sprite_offset.y - (obs_height * obs_scale.y / 2) + 10
		add_obs(obs, obs_x, obs_y)
		last_obstacle_score = score

func check_butterfly_spawn(delta: float):
	last_butterfly_time += delta
	if last_butterfly_time >= next_butterfly_interval:
		# Spawn a butterfly
		var obs = butterfly_scene.instantiate()
		var obs_x : int = screen_size.x + score + 100
		var obs_y : int = butterfly_heights[randi() % butterfly_heights.size()]
		add_obs(obs, obs_x, obs_y)
		# Reset timer and set next random interval
		last_butterfly_time = 0.0
		next_butterfly_interval = randf_range(5.0, 15.0)


func add_obs(obs, x, y):
		last_obstacle = obs
		obs.position = Vector2i(x, y)
		obs.body_entered.connect(hit_obs)
		add_child(obs)
		obstacles.append(obs)

func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)

func hit_obs(body):
	if body.name == "Player":
		game_over()
		
func game_over():
	check_high_score()
	get_tree().paused = true
	game_running = false
	$GameOver.show()
