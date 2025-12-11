extends Node

# Manages time of day (day/night) for parallax backgrounds
# Supports different environments (desert, etc.) with extensible structure

enum TimeOfDay {
	DAY,
	NIGHT
}

var current_time_of_day: TimeOfDay = TimeOfDay.DAY
var current_environment: String = "desert"  # Default to desert, can be extended
var parallax_background: ParallaxBackground = null
var ground_node: Node2D = null

# Layer paths for easy access
const LAYER_PATHS = [
	".",
	"ParallaxLayer",
	"ParallaxLayer2",
	"ParallaxLayer3"
]

func initialize(parallax_bg: ParallaxBackground, ground: Node2D):
	parallax_background = parallax_bg
	ground_node = ground
	# Ensure we start with day
	set_time_of_day(TimeOfDay.DAY)

func set_environment(environment: String):
	# Set the current environment (e.g., "desert", "forest", etc.)
	current_environment = environment
	# Update textures for current time of day in new environment
	set_time_of_day(current_time_of_day)

func toggle_time_of_day():
	# Toggle between day and night
	if current_time_of_day == TimeOfDay.DAY:
		set_time_of_day(TimeOfDay.NIGHT)
	else:
		set_time_of_day(TimeOfDay.DAY)

func set_time_of_day(time: TimeOfDay):
	current_time_of_day = time
	_update_background_textures()

func _update_background_textures():
	if not parallax_background:
		print("[TimeOfDayController] ERROR: ParallaxBackground not set")
		return

	var time_folder = "day" if current_time_of_day == TimeOfDay.DAY else "night"
	var base_path = "res://assets/img/background/" + current_environment + "/" + time_folder + "/"

	# Update parallax background layers (plx-1 through plx-4)
	for i in range(LAYER_PATHS.size()):
		var layer_path = LAYER_PATHS[i]
		var sprite_path = layer_path + "/Sprite2D"
		
		if parallax_background.has_node(sprite_path):
			var sprite = parallax_background.get_node(sprite_path) as Sprite2D
			if sprite:
				var texture_path = base_path + "plx-" + str(i + 1) + ".png"
				var texture = load(texture_path)
				if texture:
					sprite.texture = texture
					print("[TimeOfDayController] Updated ", layer_path, " to ", texture_path)
				else:
					print("[TimeOfDayController] WARNING: Could not load texture: ", texture_path)
			else:
				print("[TimeOfDayController] WARNING: Node at ", sprite_path, " is not a Sprite2D")
		else:
			print("[TimeOfDayController] WARNING: Node not found at ", sprite_path)

	# Update ground textures (Ground1 and Ground2)
	if ground_node:
		var ground_texture_path = base_path + "solid.png"
		var ground_texture = load(ground_texture_path)
		
		if ground_texture:
			# Update Ground1 sprite
			if ground_node.has_node("Ground1/Sprite2D"):
				var ground1_sprite = ground_node.get_node("Ground1/Sprite2D") as Sprite2D
				if ground1_sprite:
					ground1_sprite.texture = ground_texture
					print("[TimeOfDayController] Updated Ground1 to ", ground_texture_path)
			
			# Update Ground2 sprite
			if ground_node.has_node("Ground2/Sprite2D"):
				var ground2_sprite = ground_node.get_node("Ground2/Sprite2D") as Sprite2D
				if ground2_sprite:
					ground2_sprite.texture = ground_texture
					print("[TimeOfDayController] Updated Ground2 to ", ground_texture_path)
		else:
			print("[TimeOfDayController] WARNING: Could not load ground texture: ", ground_texture_path)
	else:
		print("[TimeOfDayController] WARNING: Ground node not set")

func get_current_time_of_day() -> TimeOfDay:
	return current_time_of_day

func is_day() -> bool:
	return current_time_of_day == TimeOfDay.DAY

func is_night() -> bool:
	return current_time_of_day == TimeOfDay.NIGHT

func reset():
	# Reset to day when starting a new game
	set_time_of_day(TimeOfDay.DAY)
