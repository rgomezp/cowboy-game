extends Node2D

signal entered_camera_view()

var screen_size: Vector2i
var main_scene: Node = null
var initial_camera_x: float = 0.0  # Track camera position when flag was spawned
var has_entered_view: bool = false  # Track if we've already emitted the signal

const GROUND_LEVEL_Y: float = 1300.0  # Ground level y coordinate

func initialize(_speed: float, size: Vector2i, camera_x: float):
	self.screen_size = size
	initial_camera_x = camera_x  # Store initial camera position

func _ready():
	# Get main scene reference after node is added to tree
	var tree = get_tree()
	if tree:
		main_scene = tree.current_scene

func _process(_delta: float) -> void:
	# Get main scene reference if not set yet
	if not main_scene:
		var tree = get_tree()
		if tree:
			main_scene = tree.current_scene

	# Get current camera position
	var camera_x = 0.0
	if main_scene and main_scene.has_node("Camera2D"):
		camera_x = main_scene.get_node("Camera2D").position.x

	# For parallax: flag moves at 30% of camera movement
	# Camera moves at full speed, so flag lags behind creating parallax effect
	# Calculate position relative to initial camera position
	var camera_delta = camera_x - initial_camera_x
	var flag_delta = camera_delta * 0.25  # Flag moves 30% of camera movement
	var spawn_offset = screen_size.x + 100  # Original spawn offset
	position.x = initial_camera_x + spawn_offset + flag_delta

	# Check if flag has entered camera view (right edge of screen)
	if not has_entered_view and position.x <= camera_x + screen_size.x:
		has_entered_view = true
		entered_camera_view.emit()

	# Check if off-screen and remove
	var cleanup_threshold = camera_x - screen_size.x * 2
	if position.x < cleanup_threshold:
		queue_free()
