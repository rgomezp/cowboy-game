extends Node

signal player_hit_obstacle(obstacle: Node)
signal player_bounced_on_butterfly(obstacle: Node)

var player: CharacterBody2D

func initialize(player_node: CharacterBody2D):
	player = player_node

func handle_obstacle_collision(body: Node, obstacle: Node):
	if body.name == "Player":
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
	if body.name == "Player":
		# Player jumped on the butterfly from the top - bounce
		player_bounced_on_butterfly.emit(obstacle)

func connect_obstacle_signals(obstacle: Node):
	obstacle.body_entered.connect(func(body): handle_obstacle_collision(body, obstacle))
	
	# If this is a butterfly, also connect to the top collision Area2D
	if obstacle.has_node("TopCollision"):
		var top_collision = obstacle.get_node("TopCollision")
		if top_collision is Area2D:
			top_collision.body_entered.connect(func(body): handle_top_collision(body, obstacle))
