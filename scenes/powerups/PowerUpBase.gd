extends RefCounted
class_name PowerUpBase

# Base class for all powerups
# Each powerup should extend this and implement the required methods

var name: String
var duration: float
var is_active: bool = false
var elapsed_time: float = 0.0

func _init(powerup_name: String, powerup_duration: float):
	name = powerup_name
	duration = powerup_duration

# Called when powerup is activated
func activate(main_node: Node) -> void:
	# Prevent double activation
	if is_active:
		print("[PowerUpBase] Powerup ", name, " is already active, ignoring duplicate activation")
		return
	is_active = true
	elapsed_time = 0.0
	_on_activate(main_node)

# Called each frame while powerup is active
func update(delta: float, main_node: Node) -> void:
	if not is_active:
		return

	elapsed_time += delta
	_on_update(delta, main_node)

	if elapsed_time >= duration:
		deactivate(main_node)

# Called when powerup is deactivated
func deactivate(main_node: Node) -> void:
	is_active = false
	_on_deactivate(main_node)

# Override these methods in subclasses
func _on_activate(_main_node: Node) -> void:
	pass

func _on_update(_delta: float, _main_node: Node) -> void:
	pass

func _on_deactivate(_main_node: Node) -> void:
	pass
