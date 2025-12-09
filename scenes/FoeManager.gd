extends Node

signal foe_added(foe: Node)
signal foe_removed(foe: Node)

var foes: Array = []
var screen_size: Vector2i
var obstacle_manager: Node = null  # Reference to obstacle manager for coordination
const MIN_SPAWN_DISTANCE: int = 500  # Minimum X distance between obstacles and foes

func initialize(size: Vector2i, obs_mgr: Node = null):
	self.screen_size = size
	obstacle_manager = obs_mgr

func reset():
	clear_all_foes()

func clear_all_foes():
	for foe in foes:
		if is_instance_valid(foe):
			foe.queue_free()
	foes.clear()

func add_foe(foe: Node):
	add_child(foe)
	foes.append(foe)
	foe_added.emit(foe)

func remove_foe(foe: Node):
	if foes.has(foe):
		foes.erase(foe)
		if is_instance_valid(foe):
			foe.queue_free()
		foe_removed.emit(foe)

func cleanup_off_screen_foes(camera_x: float):
	var cleanup_threshold = camera_x - screen_size.x * 2
	for foe in foes.duplicate():
		if not is_instance_valid(foe):
			foes.erase(foe)
			continue
		if foe.position.x < cleanup_threshold:
			remove_foe(foe)

func is_position_too_close_to_obstacles(x_position: int) -> bool:
	# Check if position is too close to any existing obstacle
	if not obstacle_manager:
		return false
	
	for obs in obstacle_manager.obstacles:
		if not is_instance_valid(obs):
			continue
		var distance = abs(obs.position.x - x_position)
		if distance < MIN_SPAWN_DISTANCE:
			return true
	return false

func is_position_too_close_to_foes(x_position: int) -> bool:
	# Check if position is too close to any existing foe
	for foe in foes:
		if not is_instance_valid(foe):
			continue
		var distance = abs(foe.position.x - x_position)
		if distance < MIN_SPAWN_DISTANCE:
			return true
	return false
