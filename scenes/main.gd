extends Node

# preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")

var obstacle_types := [rock_scene, agave_scene]
var obstacles : Array
var last_obstacle
var last_obstacle_score : int = 0

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var score : int
var SCORE_MODIFIER : int = 100
var speed : float
const START_SPEED : float = 10.0
const SPEED_MODIFIER : int = 5000
const MAX_SPEED : int = 20
var screen_size : Vector2i
var game_running : bool
var ground_height : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size	# see how far we've scrolled
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	new_game()

func new_game():
	# reset variables
	score = 0
	last_obstacle_score = 0
	show_score()
	game_running = false

	# reset the nodes
	$Player.position = PLAYER_START_POS
	$Player.velocity = Vector2i(0, 0)
	$Camera2D.position = CAMERA_START_POS
	$Ground.position = Vector2i(0, 0)

	#reset hud
	$Hud.get_node("StartLabel").show()


# Game logic happens here
func _process(delta: float) -> void:
	if game_running:
		speed = START_SPEED + score / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		# generate obstacles
		generate_obs()

		# move player position & camera
		$Player.position.x += speed
		$Camera2D.position.x += speed

		# update score
		score += speed
		show_score()

		# update ground position
		if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
			$Ground.position.x += screen_size.x
	else:
		if Input.is_action_pressed("ui_accept"):
			game_running = true
			$Hud.get_node("StartLabel").hide()

func show_score():
	$Hud.get_node("ScoreValue").text = str(score / SCORE_MODIFIER)

func generate_obs():
	var should_generate = false
	if obstacles.is_empty():
		should_generate = true
	else:
		# Calculate distance from last obstacle based on score difference
		var distance_since_last = score - last_obstacle_score
		# Use a much larger, more varied random range for spacing
		# This creates sparse, unpredictable spacing between obstacles
		var min_spacing = randi_range(1500, 3000)
		var max_spacing = randi_range(4000, 5000)
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

		
func add_obs(obs, x, y):
		last_obstacle = obs
		obs.position = Vector2i(x, y)
		add_child(obs)
		obstacles.append(obs)
