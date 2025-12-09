extends Node

signal player_hit_obstacle(obstacle: Node)
signal player_bounced_on_butterfly(obstacle: Node)
signal player_jumped_on_foe(foe: Node)

var player: CharacterBody2D
var main_node: Node = null  # Reference to main node to check powerup state

func initialize(player_node: CharacterBody2D, main_node_ref: Node = null):
	player = player_node
	main_node = main_node_ref

func handle_obstacle_collision(body: Node, obstacle: Node):
	print("[CollisionHandler] handle_obstacle_collision called - body: ", body.name, " obstacle: ", obstacle.name)
	# Check if body is the player (could be named "Player" or "Player2" depending on scene)
	var is_player = body == player or body.name == "Player" or body.name == "Player2"
	print("[CollisionHandler] is_player=", is_player, " body==player=", (body == player), " body.name=", body.name)

	# If a shotgun target is already marked for destruction, ignore immediately
	if main_node and main_node.powerup_manager:
		var active_powerup = main_node.powerup_manager.get_active_powerup()
		if active_powerup and active_powerup.name == "shotgun":
			if active_powerup.destroyed_targets.has(obstacle):
				print("[CollisionHandler] Obstacle already marked for shotgun destruction, ignoring collision")
				return

	if is_player:
		# Coins handle their own collection, so skip them here
		if obstacle.name == "Coin" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "coin.gd" in obstacle.get_script().resource_path):
			return

		# Check for top collision FIRST (before checking destroyed flag) to handle race conditions
		# If this is a foe, check if player is also overlapping the top collision
		var is_foe = obstacle.name == "Furry" or obstacle.name == "Troll" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "foe_base.gd" in obstacle.get_script().resource_path)
		if is_foe and obstacle.has_node("CollisionBoxTop"):
			var top_collision = obstacle.get_node("CollisionBoxTop")
			if top_collision is Area2D:
				var overlapping_bodies = top_collision.get_overlapping_bodies()
				if overlapping_bodies.has(player):
					# Player is overlapping top collision - ignore this collision
					return

		# If this is a butterfly, check if player is also overlapping the top collision
		var is_butterfly = obstacle.name == "Butterfly" or (obstacle.has_node("AnimatedSprite2D") and obstacle.get_node("AnimatedSprite2D").get_script() != null and obstacle.get_node("AnimatedSprite2D").get_script().resource_path != null and "butterfly.gd" in obstacle.get_node("AnimatedSprite2D").get_script().resource_path)
		if is_butterfly and obstacle.has_node("TopCollision"):
			var top_collision = obstacle.get_node("TopCollision")
			if top_collision is Area2D:
				var overlapping_bodies = top_collision.get_overlapping_bodies()
				if overlapping_bodies.has(player):
					# Player is overlapping top collision - ignore this collision
					return

		# If this is a butterfly, check if it's already being destroyed (after top collision check)
		if is_butterfly:
			if obstacle.has_node("AnimatedSprite2D"):
				var animated_sprite = obstacle.get_node("AnimatedSprite2D")
				if animated_sprite.has_method("is_destroyed") and animated_sprite.is_destroyed:
					# Butterfly is already being destroyed, ignore this collision
					return
			# Also check if main collision is disabled
			if obstacle.has_node("CollisionShape2D") and obstacle.get_node("CollisionShape2D").disabled:
				# Main collision already disabled, ignore
				return
			# Also check if monitoring is disabled
			if not obstacle.monitoring:
				# Monitoring disabled, ignore
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

		# Check if shotgun powerup is active and this obstacle is being destroyed by it
		if main_node and main_node.powerup_manager:
			var active_powerup = main_node.powerup_manager.get_active_powerup()
			if active_powerup and active_powerup.name == "shotgun":
				# If obstacle is already in destroyed_targets, ignore collision
				if active_powerup.destroyed_targets.has(obstacle):
					print("[CollisionHandler] Obstacle already being destroyed by shotgun, ignoring collision")
					return

				# Check if this is a valid target for shotgun (foe, butterfly, or TNT only - not Rock/Agave)
				var is_tnt = obstacle.name == "TNT" or (
					obstacle.get_script() != null
					and obstacle.get_script().resource_path != null
					and "tnt" in obstacle.get_script().resource_path.to_lower()
				)
				var is_valid_target = is_foe or is_butterfly or is_tnt

				if is_valid_target:
					# Check if obstacle is currently overlapping with GunProximityArea
					# This handles the case where collision happens before area_entered signal fires
					var should_destroy = false
					if player.has_node("GunProximityArea"):
						var gun_area = player.get_node("GunProximityArea")
						if gun_area and gun_area.monitoring:
							var overlapping_areas = gun_area.get_overlapping_areas()
							print("[CollisionHandler] Checking overlap - obstacle: ", obstacle.name, " overlapping_areas count: ", overlapping_areas.size())
							if overlapping_areas.has(obstacle):
								should_destroy = true
								print("[CollisionHandler] Obstacle overlaps with GunProximityArea")

					# If not overlapping but shotgun is active and it's a valid target, destroy it anyway
					# This is a safety fallback - if player is colliding with target while shotgun is active, destroy it
					if not should_destroy:
						# Check if target is in front of player (within reasonable range)
						# Since collision happened, target is definitely close enough
						should_destroy = true
						print("[CollisionHandler] Shotgun active and valid target detected via collision - destroying: ", obstacle.name)

					if should_destroy:
						# Disable collision using deferred calls to avoid flushing queries error
						if obstacle is Area2D:
							obstacle.set_deferred("monitoring", false)
							obstacle.set_deferred("monitorable", false)
						if obstacle.has_node("CollisionPolygon2D"):
							obstacle.get_node("CollisionPolygon2D").set_deferred("disabled", true)
						if obstacle.has_node("CollisionShape2D"):
							obstacle.get_node("CollisionShape2D").set_deferred("disabled", true)
						if obstacle.has_node("CollisionBox"):
							obstacle.get_node("CollisionBox").set_deferred("disabled", true)
						# Trigger destruction using deferred call to avoid flushing queries error
						# This handles race conditions where collision happens before area_entered signal
						call_deferred("_trigger_shotgun_destruction", active_powerup, obstacle)
						return

		# Player hit the main collision but not the top - game over
		print("[CollisionHandler] GAME OVER - Player hit obstacle: ", obstacle.name)
		player_hit_obstacle.emit(obstacle)

func _disable_foe_collisions(obstacle: Node):
	# Helper function to disable foe collisions after signal completes
	if obstacle.has_node("CollisionBox"):
		obstacle.get_node("CollisionBox").disabled = true
	if obstacle is Area2D:
		obstacle.monitoring = false
		obstacle.monitorable = false

func _disable_butterfly_collisions(obstacle: Node):
	# Helper function to disable butterfly collisions after signal completes
	if obstacle.has_node("CollisionShape2D"):
		obstacle.get_node("CollisionShape2D").disabled = true
	if obstacle is Area2D:
		obstacle.monitoring = false
		obstacle.monitorable = false
	if obstacle.has_node("TopCollision"):
		var top_collision = obstacle.get_node("TopCollision")
		if top_collision is Area2D:
			top_collision.monitoring = false
			top_collision.monitorable = false

func handle_top_collision(body: Node, obstacle: Node):
	# Check if body is the player
	var is_player = body == player or body.name == "Player" or body.name == "Player2"
	if is_player:
		# Check if this is a foe (uses foe_base.gd script or name is Furry/Troll)
		var is_foe = obstacle.name == "Furry" or obstacle.name == "Troll" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "foe_base.gd" in obstacle.get_script().resource_path)
		if is_foe:
			# Defer disabling collisions to avoid flushing queries error
			call_deferred("_disable_foe_collisions", obstacle)
			# Don't set is_destroyed here - let destroy() method handle it and play animation
			# Player jumped on the foe from the top - destroy it
			player_jumped_on_foe.emit(obstacle)
		else:
			# Defer disabling collisions to avoid flushing queries error
			call_deferred("_disable_butterfly_collisions", obstacle)
			# Player jumped on the butterfly from the top - bounce
			player_bounced_on_butterfly.emit(obstacle)

func _trigger_shotgun_destruction(powerup: RefCounted, target: Node) -> void:
	# Helper to trigger shotgun destruction from collision handler
	# This handles the case where collision happens before area_entered signal
	# Note: powerup is RefCounted (PowerUpBase), not Node
	print("[CollisionHandler] _trigger_shotgun_destruction called for: ", target.name)
	if powerup and is_instance_valid(target) and target is Area2D:
		# Manually trigger the target entered handler
		if powerup.has_method("_on_target_entered"):
			print("[CollisionHandler] Calling _on_target_entered on powerup")
			powerup._on_target_entered(target)
		else:
			print("[CollisionHandler] ERROR: powerup does not have _on_target_entered method")
	else:
		print("[CollisionHandler] ERROR: Invalid powerup or target - powerup=", powerup, " target=", target, " is_Area2D=", (target is Area2D))

func connect_obstacle_signals(obstacle: Node):
	# Skip coins - they handle their own collision detection
	if obstacle.name == "Coin" or (obstacle.get_script() != null and obstacle.get_script().resource_path != null and "coin.gd" in obstacle.get_script().resource_path):
		return

	# Skip powerup-related Area2D nodes (like GunProximityArea)
	if obstacle.name == "GunProximityArea":
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
