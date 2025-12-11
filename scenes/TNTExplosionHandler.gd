extends Node

# Handles TNT explosion logic and collision responses

signal explosion_started()
signal explosion_finished()

var obstacle_manager: Node
var lives_manager: Node
var main_node: Node
var explosion_in_progress: bool = false

func initialize(obstacle_mgr: Node, lives_mgr: Node, main: Node):
	obstacle_manager = obstacle_mgr
	lives_manager = lives_mgr
	main_node = main

func handle_tnt_collision(obstacle: Node) -> bool:
	# Returns true if TNT was handled, false otherwise
	if not _is_tnt(obstacle):
		return false

	# Remove from obstacle manager immediately
	if obstacle_manager.obstacles.has(obstacle):
		obstacle_manager.obstacles.erase(obstacle)

	# Trigger explosion animation
	if obstacle.has_method("trigger_explosion"):
		# Check if player has lives - if so, use a life after explosion (no bounce)
		if lives_manager and lives_manager.has_lives():
			# Connect to explosion finished signal to use a life
			if obstacle.has_signal("explosion_finished"):
				# Disconnect first to avoid duplicate connections
				if obstacle.explosion_finished.is_connected(_on_tnt_explosion_finished_with_life):
					obstacle.explosion_finished.disconnect(_on_tnt_explosion_finished_with_life)
				obstacle.explosion_finished.connect(_on_tnt_explosion_finished_with_life)
			# Trigger explosion with from_collision=true but apply_bounce=false (no bounce, just animation)
			obstacle.trigger_explosion(true, false)
		else:
			# No lives - connect to game over handler (apply bounce for game over effect)
			if obstacle.has_signal("explosion_finished"):
				# Disconnect first to avoid duplicate connections
				if obstacle.explosion_finished.is_connected(_on_tnt_explosion_finished_game_over):
					obstacle.explosion_finished.disconnect(_on_tnt_explosion_finished_game_over)
				obstacle.explosion_finished.connect(_on_tnt_explosion_finished_game_over)
			# Trigger explosion with bounce (game over scenario)
			obstacle.trigger_explosion(true, true)
	else:
		# Fallback if script not attached
		# Check if player has lives
		if lives_manager and lives_manager.has_lives():
			lives_manager.remove_life()
		else:
			explosion_finished.emit()
			return true

	explosion_in_progress = true
	explosion_started.emit()
	return true

func _on_tnt_explosion_finished_with_life() -> void:
	# TNT explosion finished - player has lives, so use a life
	explosion_in_progress = false
	explosion_finished.emit()
	if lives_manager and lives_manager.has_lives():
		lives_manager.remove_life()
		# Note: _on_life_lost will handle the blinking and immunity

func _on_tnt_explosion_finished_game_over() -> void:
	# Trigger game over after explosion animation finishes
	# Reset explosion flag (though game_over will pause anyway)
	explosion_in_progress = false
	explosion_finished.emit()
	# No lives remaining - proceed with game over
	if main_node and main_node.has_method("game_over"):
		main_node.game_over()

func _is_tnt(obstacle: Node) -> bool:
	# Check if obstacle is TNT by name or script path
	if obstacle.name == "TNT":
		return true
	if obstacle.get_script() != null and obstacle.get_script().resource_path != null:
		if "tnt" in obstacle.get_script().resource_path.to_lower():
			return true
	# Check scene file path if available
	if obstacle.has_method("get_scene_file_path"):
		var scene_path = obstacle.get_scene_file_path()
		if scene_path and "tnt" in scene_path.to_lower():
			return true
	return false

func set_explosion_in_progress(value: bool) -> void:
	# Setter method for TNT script to control explosion state
	explosion_in_progress = value

func is_explosion_in_progress() -> bool:
	return explosion_in_progress

func reset():
	explosion_in_progress = false
