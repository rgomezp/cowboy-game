extends Node

signal player_hit_obstacle(obstacle: Node)
signal player_bounced_on_butterfly(obstacle: Node)

var player: CharacterBody2D

func initialize(player_node: CharacterBody2D):
	player = player_node

func handle_obstacle_collision(body: Node, obstacle: Node):
	# Check if body is the player (could be named "Player" or "Player2" depending on scene)
	var is_player = body == player or body.name == "Player" or body.name == "Player2"
	if is_player:
		# Coins handle their own collection, so skip them here
		if obstacle.name == "Coin" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "coin.gd" in obstacle.get_script().resource_path):
			return
		
		# If this is a butterfly, check if player is also overlapping the top collision
		if obstacle.has_node("TopCollision"):
			var top_collision = obstacle.get_node("TopCollision")
			if top_collision is Area2D:
				var overlapping_bodies = top_collision.get_overlapping_bodies()
				if overlapping_bodies.has(player):
					# Player is overlapping top collision - ignore this collision
					return
		# Player hit the main collision but not the top - game over
		player_hit_obstacle.emit(obstacle)

func handle_top_collision(body: Node, obstacle: Node):
	# Check if body is the player
	var is_player = body == player or body.name == "Player" or body.name == "Player2"
	if is_player:
		# Player jumped on the butterfly from the top - bounce
		player_bounced_on_butterfly.emit(obstacle)

func connect_obstacle_signals(obstacle: Node):
	# Skip coins - they handle their own collision detection
	if obstacle.name == "Coin" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "coin.gd" in obstacle.get_script().resource_path):
		return
	
	# Only connect body_entered for Area2D nodes (butterflies, etc.)
	if obstacle is Area2D:
		obstacle.body_entered.connect(func(body): handle_obstacle_collision(body, obstacle))
	
	# If this is a butterfly, also connect to the top collision Area2D
	if obstacle.has_node("TopCollision"):
		var top_collision = obstacle.get_node("TopCollision")
		if top_collision is Area2D:
			top_collision.body_entered.connect(func(body): handle_top_collision(body, obstacle))
