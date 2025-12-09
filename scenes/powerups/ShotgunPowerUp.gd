extends "res://scenes/powerups/PowerUpBase.gd"

# Shotgun powerup:
# - Auto-destroy foes, butterflies, and TNT that enter GunProximityArea
# - Uses signal-based detection with polling fallback for immediate response
# - Active until manually deactivated or duration expires

var main_node: Node
var player: CharacterBody2D
var gun_proximity_area: Area2D = null
var destroyed_targets: Array = []

func _init():
	super._init("shotgun", 20.0)  # 10 seconds duration

# ============================================================================
# ACTIVATION / DEACTIVATION
# ============================================================================

func _on_activate(main_node_ref: Node) -> void:
	main_node = main_node_ref
	player = main_node.get_node("Player")

	# Get or create the GunProximityArea
	if player.has_node("GunProximityArea"):
		gun_proximity_area = player.get_node("GunProximityArea")
	else:
		push_error("[ShotgunPowerUp] GunProximityArea not found on player!")
		return

	# Enable monitoring and connect signal for immediate detection
	gun_proximity_area.monitoring = true
	# Set collision_mask to detect targets on layer 1 (default layer for Area2D)
	gun_proximity_area.collision_mask = 1
	gun_proximity_area.area_entered.connect(_on_target_entered)
	
	print("[ShotgunPowerUp] GunProximityArea - monitoring: ", gun_proximity_area.monitoring, " monitorable: ", gun_proximity_area.monitorable, " collision_mask: ", gun_proximity_area.collision_mask)
	print("[ShotgunPowerUp] GunProximityArea position: ", gun_proximity_area.position, " scale: ", gun_proximity_area.scale)
	if gun_proximity_area.has_node("CollisionShape2D"):
		var cs = gun_proximity_area.get_node("CollisionShape2D")
		print("[ShotgunPowerUp] GunProximityArea shape pos: ", cs.position, " scale: ", cs.scale, " shape: ", cs.shape)

	# Check for already-overlapping areas when powerup activates
	# The area_entered signal only fires for NEW entries
	check_existing_overlaps()

	print("[ShotgunPowerUp] Activated - GunProximityArea enabled")

func _on_deactivate(_main_node_ref: Node) -> void:
	# Disconnect signal and disable monitoring
	if gun_proximity_area and is_instance_valid(gun_proximity_area):
		if gun_proximity_area.area_entered.is_connected(_on_target_entered):
			gun_proximity_area.area_entered.disconnect(_on_target_entered)
		gun_proximity_area.monitoring = false

	destroyed_targets.clear()
	print("[ShotgunPowerUp] Deactivated")

# ============================================================================
# UPDATE / POLLING
# ============================================================================

func _on_update(_delta: float, _main_node_ref: Node) -> void:
	# Poll for overlapping areas to catch targets that the signal might miss
	if not is_active or not gun_proximity_area or not gun_proximity_area.monitoring:
		return
	
	# Try get_overlapping_areas() first
	var overlapping_areas = gun_proximity_area.get_overlapping_areas()
	if overlapping_areas.size() > 0:
		# Filter out child collision areas before processing
		var valid_areas = []
		for area in overlapping_areas:
			# Skip child collision areas
			if area.name == "CollisionBoxTop" or area.name == "TopCollision":
				continue
			# Skip if this is a child of another Area2D
			if area.get_parent() and area.get_parent() is Area2D:
				continue
			valid_areas.append(area)
		
		if valid_areas.size() > 0:
			for area in valid_areas:
				_on_target_entered(area)
		return
	
	# Fallback: Manually check all potential targets for proximity
	check_manual_proximity()

func check_existing_overlaps() -> void:
	# Check for areas that are already overlapping when powerup activates
	if not gun_proximity_area:
		return

	var overlapping_areas = gun_proximity_area.get_overlapping_areas()
	print("[ShotgunPowerUp] Checking existing overlaps on activation: ", overlapping_areas.size(), " areas found")

	for area in overlapping_areas:
		_on_target_entered(area)

func check_manual_proximity() -> void:
	# Fallback: Manually check all potential targets for proximity using distance
	var gun_rect = _get_gun_proximity_rect()
	if gun_rect == null:
		return
	
	# Check all foes
	_check_foes_in_proximity(gun_rect)
	
	# Check all obstacles (butterflies and TNT only)
	_check_obstacles_in_proximity(gun_rect)

func _get_gun_proximity_rect() -> Rect2:
	# Get the GunProximityArea's collision shape
	var gun_shape_node = gun_proximity_area.get_node("CollisionShape2D")
	if not gun_shape_node or not gun_shape_node.shape:
		return Rect2()
	
	# Get shape size (RectangleShape2D)
	var gun_shape = gun_shape_node.shape as RectangleShape2D
	if not gun_shape:
		return Rect2()
	
	# Calculate the proximity area bounds accounting for player scale (7x)
	var player_scale = player.scale if player else Vector2(1, 1)
	var gun_size = gun_shape.size * player_scale
	var shape_offset = gun_shape_node.position * player_scale
	var player_global_pos = player.global_position
	var gun_world_pos = player_global_pos + gun_proximity_area.position * player_scale + shape_offset
	return Rect2(gun_world_pos - gun_size / 2, gun_size)

func _check_foes_in_proximity(gun_rect: Rect2) -> void:
	if not main_node.foe_manager or main_node.foe_manager.foes.is_empty():
		return
	
	for foe in main_node.foe_manager.foes:
		if is_instance_valid(foe) and foe is Area2D and not destroyed_targets.has(foe):
			if gun_rect.has_point(foe.global_position):
				print("[ShotgunPowerUp] Manual check: Foe in proximity: ", foe.name)
				_on_target_entered(foe)

func _check_obstacles_in_proximity(gun_rect: Rect2) -> void:
	if not main_node.obstacle_manager or main_node.obstacle_manager.obstacles.is_empty():
		return
	
	for obstacle in main_node.obstacle_manager.obstacles:
		if is_instance_valid(obstacle) and obstacle is Area2D and not destroyed_targets.has(obstacle):
			# Only check if it's a valid target (butterfly or TNT, not Rock/Agave)
			if _is_valid_target(obstacle):
				var obstacle_pos = obstacle.global_position
				var is_butterfly = _is_butterfly(obstacle)
				var in_range = false
				
				if is_butterfly:
					# For butterflies, check if they're within X range (they can be at different Y heights: 150 or -300)
					# The gun proximity area extends forward, so check X distance from player
					var gun_center_x = gun_rect.position.x + gun_rect.size.x / 2
					var distance_x = obstacle_pos.x - gun_center_x
					# Check if butterfly is in front of the gun (positive X) and within range
					# Butterflies can be at Y=150 or Y=-300, so we need a larger Y tolerance
					var gun_center_y = gun_rect.position.y + gun_rect.size.y / 2
					var distance_y = abs(obstacle_pos.y - gun_center_y)
					# Check if within X range (forward) and Y range (accounting for butterfly heights)
					in_range = distance_x >= -gun_rect.size.x / 2 and distance_x <= gun_rect.size.x and distance_y < gun_rect.size.y * 1.5
					
					if in_range:
						print("[ShotgunPowerUp] Manual check: Butterfly in proximity: ", obstacle.name, " at ", obstacle_pos, " gun_center: (", gun_center_x, ", ", gun_center_y, ") dist_x: ", distance_x, " dist_y: ", distance_y)
				else:
					# For other obstacles (TNT), use standard point check
					in_range = gun_rect.has_point(obstacle_pos)
					if in_range:
						print("[ShotgunPowerUp] Manual check: Target in proximity: ", obstacle.name, " at ", obstacle_pos)
				
				if in_range:
					_on_target_entered(obstacle)

# ============================================================================
# TARGET IDENTIFICATION
# ============================================================================

func _on_target_entered(area: Area2D) -> void:
	# Validation checks
	if not is_active:
		return
	if destroyed_targets.has(area):
		return
	if area == player or (player and player.is_ancestor_of(area)):
		return
	
	# Skip child collision areas (CollisionBoxTop, TopCollision, etc.)
	# These are child nodes of foes/butterflies used for top collision detection
	if area.name == "CollisionBoxTop" or area.name == "TopCollision":
		return
	
	# Skip if this is a child of a foe/butterfly (it's a collision helper area)
	# We only want the root Area2D nodes (Furry, Troll, Butterfly, TNT)
	if area.get_parent() and area.get_parent() is Area2D:
		# This is a child of another Area2D, skip it
		return

	# Identify target type
	var target_info = _identify_target(area)
	if target_info.is_valid:
		print("[ShotgunPowerUp] Target detected via GunProximityArea: ", area.name, " (is_foe=", target_info.is_foe, " is_butterfly=", target_info.is_butterfly, " is_tnt=", target_info.is_tnt, ")")
		destroy_target(area, target_info)

func _identify_target(area: Area2D) -> Dictionary:
	# Returns a dictionary with target type information
	var is_foe = _is_foe(area)
	var is_butterfly = _is_butterfly(area)
	var is_tnt = _is_tnt(area)
	
	return {
		"is_valid": is_foe or is_butterfly or is_tnt,
		"is_foe": is_foe,
		"is_butterfly": is_butterfly,
		"is_tnt": is_tnt
	}

func _is_valid_target(area: Node) -> bool:
	# Check if area is a valid target for shotgun (foe, butterfly, or TNT only)
	return _is_foe(area) or _is_butterfly(area) or _is_tnt(area)

func _is_foe(area: Node) -> bool:
	return area.name == "Furry" or area.name == "Troll" or \
		(area.get_script() != null and area.get_script().resource_path != null and "foe_base.gd" in area.get_script().resource_path)

func _is_butterfly(area: Node) -> bool:
	return area.name == "Butterfly" or \
		(area.has_node("AnimatedSprite2D") and area.get_node("AnimatedSprite2D").get_script() != null and \
		area.get_node("AnimatedSprite2D").get_script().resource_path != null and "butterfly.gd" in area.get_node("AnimatedSprite2D").get_script().resource_path)

func _is_tnt(area: Node) -> bool:
	if area.name == "TNT":
		return true
	if area.get_script() != null and area.get_script().resource_path != null and "tnt" in area.get_script().resource_path.to_lower():
		return true
	# If the scene path is available (for PackedScene instances), check that too
	if area.has_method("get_scene_file_path"):
		var scene_path = area.get_scene_file_path()
		if scene_path and "tnt" in scene_path.to_lower():
			return true
	return false

# ============================================================================
# TARGET DESTRUCTION
# ============================================================================

func destroy_target(target: Node, target_info: Dictionary) -> void:
	if not is_instance_valid(target):
		return

	# CRITICAL: Disable collision IMMEDIATELY to prevent game over
	_disable_target_collisions(target)

	# Add to destroyed targets list
	destroyed_targets.append(target)
	print("[ShotgunPowerUp] Destroying target: ", target.name)

	# Handle destruction based on target type
	if target_info.is_foe:
		_destroy_foe(target)
	elif target_info.is_butterfly:
		_destroy_butterfly(target)
	elif target_info.is_tnt:
		_destroy_tnt(target)

func _disable_target_collisions(target: Node) -> void:
	# Disable all collision detection on the target
	if target is Area2D:
		# Use deferred to avoid flushing queries
		target.set_deferred("monitoring", false)
		target.set_deferred("monitorable", false)
	
	# Disable collision shapes
	if target.has_node("CollisionPolygon2D"):
		target.get_node("CollisionPolygon2D").set_deferred("disabled", true)
	if target.has_node("CollisionShape2D"):
		target.get_node("CollisionShape2D").set_deferred("disabled", true)
	if target.has_node("CollisionBox"):
		target.get_node("CollisionBox").set_deferred("disabled", true)

func _destroy_foe(target: Node) -> void:
	# Destroy foe - let the destroy() method handle the animation and cleanup
	if target.has_method("destroy"):
		target.destroy()
	
	# Remove from foe manager's list but don't queue_free - let destroy() animation finish
	if main_node.foe_manager.foes.has(target):
		main_node.foe_manager.foes.erase(target)
	
	# Award points
	main_node.score_manager.add_score(200 * 100, true)

func _destroy_butterfly(target: Node) -> void:
	# Destroy butterfly - let the destroy() method handle the animation and cleanup
	if target.has_node("AnimatedSprite2D"):
		var animated_sprite = target.get_node("AnimatedSprite2D")
		if animated_sprite.has_method("destroy"):
			animated_sprite.destroy()
	
	# Remove from obstacle manager's list but don't queue_free - let destroy() animation finish
	if main_node.obstacle_manager.obstacles.has(target):
		main_node.obstacle_manager.obstacles.erase(target)
	
	# Award points
	main_node.score_manager.add_score(100 * 100, true)

func _destroy_tnt(target: Node) -> void:
	# TNT doesn't have a destroy animation, so remove it immediately
	if main_node.obstacle_manager.obstacles.has(target):
		main_node.obstacle_manager.obstacles.erase(target)
	
	if is_instance_valid(target):
		target.queue_free()
	
	# No points for TNT (just destroyed to prevent game over)
