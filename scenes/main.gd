extends Node

# preload obstacles
var rock_scene = preload("res://scenes/obstacles/rock.tscn")
var agave_scene = preload("res://scenes/obstacles/agave.tscn")

var obstacle_types := [rock_scene, agave_scene]
var obstacles : Array
var last_obstacle

const PLAYER_START_POS := Vector2i(19, 166)
const CAMERA_START_POS := Vector2i(540, 960)

var score : int
var SCORE_MODIFIER : int = 100
var speed : float
const START_SPEED : float = 10.0
const MAX_SPEED : int = 25
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
		speed = START_SPEED

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
	if obstacles.is_empty():
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs
		obs = obs_type.instantiate()
		var obs_sprite = obs.get_node("Sprite2D")
		var obs_height = obs_sprite.texture.get_height()
		var obs_scale = obs_sprite.scale
		var obs_sprite_offset = obs_sprite.position
		var ground_sprite = $Ground.get_node("Sprite2D")
		var ground_top_y = ground_sprite.offset.y
		var obs_x : int = screen_size.x + score + 100
		# Position rock so its bottom edge sits on top of the ground
		# Ground top is at ground_sprite.offset.y
		# Rock sprite is centered, so its bottom is at: obs.position.y + obs_sprite_offset.y + (obs_height * obs_scale.y / 2)
		# We need: obs.position.y + obs_sprite_offset.y + (obs_height * obs_scale.y / 2) = ground_top_y
		# Add a small offset to push it slightly lower
		var obs_y : int = ground_top_y - obs_sprite_offset.y - (obs_height * obs_scale.y / 2) + 10
		last_obstacle = obs
		obs.position = Vector2i(obs_x, obs_y)
		add_child(obs)
		obstacles.append(obs)
