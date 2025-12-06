extends Node

signal player_hit_obstacle(obstacle: Node)
signal player_bounced_on_butterfly(obstacle: Node)
signal player_jumped_on_foe(foe: Node)

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
		
		# Check for top collision FIRST (before checking destroyed flag) to handle race conditions
		# If this is a foe, check if player is also overlapping the top collision
		var is_foe = obstacle.name == "Furry" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "furry.gd" in obstacle.get_script().resource_path)
		if is_foe and obstacle.has_node("CollisionBoxTop"):
			var top_collision = obstacle.get_node("CollisionBoxTop")
			if top_collision is Area2D:
				var overlapping_bodies = top_collision.get_overlapping_bodies()
				if overlapping_bodies.has(player):
					# Player is overlapping top collision - ignore this collision
					return
		
		# If this is a butterfly, check if player is also overlapping the top collision
		if obstacle.has_node("TopCollision"):
			var top_collision = obstacle.get_node("TopCollision")
			if top_collision is Area2D:
				var overlapping_bodies = top_collision.get_overlapping_bodies()
				if overlapping_bodies.has(player):
					# Player is overlapping top collision - ignore this collision
					return
		
		# If this is a foe, check if it's already being destroyed (after top collision check)
		if is_foe:
			if obstacle.has_method("is_destroyed") and obstacle.is_destroyed:
				# Foe is already being destroyed, ignore this collision
				return
			# Also check if main collision is disabled
			if obstacle.has_node("CollisionBox") and obstacle.get_node("CollisionBox").disabled:
				# Main collision already disabled, ignore
				return
			# Also check if monitoring is disabled
			if not obstacle.monitoring:
				# Monitoring disabled, ignore
				return
		
		# Player hit the main collision but not the top - game over
		player_hit_obstacle.emit(obstacle)

func handle_top_collision(body: Node, obstacle: Node):
	# Check if body is the player
	var is_player = body == player or body.name == "Player" or body.name == "Player2"
	if is_player:
		# Check if this is a foe (has furry.gd script or name is Furry)
		var is_foe = obstacle.name == "Furry" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "furry.gd" in obstacle.get_script().resource_path)
		if is_foe:
			# Immediately disable main collision BEFORE emitting signal to prevent race condition
			if obstacle.has_node("CollisionBox"):
				obstacle.get_node("CollisionBox").disabled = true
			# Disable main Area2D monitoring immediately
			obstacle.monitoring = false
			obstacle.monitorable = false
			# Don't set is_destroyed here - let destroy() method handle it and play animation
			# Player jumped on the foe from the top - destroy it
			player_jumped_on_foe.emit(obstacle)
		else:
			# Player jumped on the butterfly from the top - bounce
			player_bounced_on_butterfly.emit(obstacle)

func connect_obstacle_signals(obstacle: Node):
	# Skip coins - they handle their own collision detection
	if obstacle.name == "Coin" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "coin.gd" in obstacle.get_script().resource_path):
		return
	
	# Only connect body_entered for Area2D nodes (butterflies, foes, etc.)
	if obstacle is Area2D:
		obstacle.body_entered.connect(func(body): handle_obstacle_collision(body, obstacle))
	
	# If this is a butterfly, also connect to the top collision Area2D
	if obstacle.has_node("TopCollision"):
		var top_collision = obstacle.get_node("TopCollision")
		if top_collision is Area2D:
			top_collision.body_entered.connect(func(body): handle_top_collision(body, obstacle))
	
	# If this is a foe, also connect to the CollisionBoxTop Area2D
	if obstacle.has_node("CollisionBoxTop"):
		var top_collision = obstacle.get_node("CollisionBoxTop")
		if top_collision is Area2D:
			top_collision.body_entered.connect(func(body): handle_top_collision(body, obstacle))
