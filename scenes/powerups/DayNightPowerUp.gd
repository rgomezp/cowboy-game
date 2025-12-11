extends "res://scenes/powerups/PowerUpBase.gd"

# Day/Night powerup:
# - Toggles between day and night for the parallax background
# - Instant effect (no duration)
# - Can be used multiple times

func _init():
	# Duration of 0 means it's instant
	super._init("day_night", 0.0)

func _on_activate(main_node: Node) -> void:
	# Toggle time of day
	# TimeOfDayController is a child node of main
	if main_node.has_node("TimeOfDayController"):
		var time_controller = main_node.get_node("TimeOfDayController")
		if time_controller and time_controller.has_method("toggle_time_of_day"):
			time_controller.toggle_time_of_day()
			print("[DayNightPowerUp] Toggled time of day")
		else:
			print("[DayNightPowerUp] ERROR: TimeOfDayController missing toggle_time_of_day method")
	else:
		print("[DayNightPowerUp] ERROR: TimeOfDayController node not found")

func _on_update(_delta: float, _main_node: Node) -> void:
	# No update needed - instant effect
	pass

func _on_deactivate(_main_node: Node) -> void:
	# No cleanup needed - instant effect
	pass
