extends "res://scenes/powerups/PowerUpBase.gd"

# Heart powerup:
# - Awards the player one life (up to max of 3)

var main_node: Node
var lives_manager: Node = null

func _init():
	super._init("heart_powerup", 0.0)  # Instant powerup, no duration

func _on_activate(main_node_ref: Node) -> void:
	main_node = main_node_ref
	
	# Get the lives manager
	if main_node.has_node("LivesManager"):
		lives_manager = main_node.get_node("LivesManager")
	elif main_node.has_method("get") and "lives_manager" in main_node:
		lives_manager = main_node.lives_manager
	else:
		push_error("[HeartPowerUp] LivesManager not found!")
		return
	
	# Add a life
	if lives_manager:
		var added = lives_manager.add_life()
		if added:
			print("[HeartPowerUp] Life added! Current lives: ", lives_manager.get_lives())
		else:
			print("[HeartPowerUp] Could not add life - already at max (", lives_manager.get_lives(), ")")
	
	# Deactivate immediately since this is an instant powerup
	deactivate(main_node_ref)

func _on_update(_delta: float, _main_node_ref: Node) -> void:
	# No update needed for instant powerup
	pass

func _on_deactivate(_main_node_ref: Node) -> void:
	# Cleanup if needed
	pass
