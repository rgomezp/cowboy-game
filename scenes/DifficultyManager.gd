extends Node

# Manages difficulty levels and speed transitions based on distance traveled

signal difficulty_level_changed(new_level: int)

var current_difficulty_level: int = 1
var previous_difficulty_level: int = 1  # Track previous level to detect changes
var target_speed: float = 10.0  # Target speed for current difficulty level
var transition_start_speed: float = 10.0  # Speed when transition started
var speed_transition_timer: float = 0.0  # Timer for speed transition (0-5 seconds)

const LEVEL_1_THRESHOLD: int = 0       # Start at level 1
const LEVEL_2_THRESHOLD: int = 37500  # Switch to level 2 at 37.5k distance
const LEVEL_3_THRESHOLD: int = 75000  # Switch to level 3 at 75k distance
const LEVEL_4_THRESHOLD: int = 112500 # Switch to level 4 at 112.5k distance
const SPEED_TRANSITION_DURATION: float = 5.0  # 5 seconds to reach new speed

func reset():
	current_difficulty_level = 1
	previous_difficulty_level = 1
	target_speed = 10.0
	transition_start_speed = 10.0
	speed_transition_timer = SPEED_TRANSITION_DURATION  # Set to complete so speed is immediately at target

func update_difficulty_level(distance: int):
	# Determine difficulty level based on distance
	var new_level = 1
	if distance >= LEVEL_4_THRESHOLD:
		new_level = 4
	elif distance >= LEVEL_3_THRESHOLD:
		new_level = 3
	elif distance >= LEVEL_2_THRESHOLD:
		new_level = 2
	else:
		new_level = 1

	# Calculate target speed for the current/new level
	var new_target_speed = 10.0
	if new_level == 1:
		new_target_speed = 10.0
	elif new_level == 2:
		new_target_speed = 12.0
	elif new_level == 3:
		new_target_speed = 14.0
	else:  # Level 4
		new_target_speed = 16.0

	# Check if level changed
	if new_level != current_difficulty_level:
		# Level changed - start speed transition
		previous_difficulty_level = current_difficulty_level
		current_difficulty_level = new_level
		target_speed = new_target_speed
		difficulty_level_changed.emit(current_difficulty_level)
		print("[DifficultyManager] Difficulty level changed to ", current_difficulty_level, ", transitioning speed to ", target_speed)
	else:
		# Level didn't change, but ensure target_speed is set (for initial case)
		target_speed = new_target_speed

func update_speed_transition(delta: float, _current_speed: float) -> float:
	# Calculate speed with gradual transition
	# If we're in a transition, interpolate between start and target speed
	if speed_transition_timer < SPEED_TRANSITION_DURATION:
		speed_transition_timer += delta
		var progress = min(speed_transition_timer / SPEED_TRANSITION_DURATION, 1.0)  # Clamp to 0-1
		# Linear interpolation from start speed to target speed
		return lerpf(transition_start_speed, target_speed, progress)
	else:
		# Transition complete, use target speed directly
		return target_speed

func start_speed_transition(from_speed: float):
	# Start a new speed transition
	transition_start_speed = from_speed
	speed_transition_timer = 0.0

func get_current_level() -> int:
	return current_difficulty_level

func get_target_speed() -> float:
	return target_speed
