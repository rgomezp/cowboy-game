extends RefCounted
class_name SpecialSpriteData

# Mapping of special sprite scene paths to whether they're "good" (makes sense) or "bad" (hwwat?)
const SPRITE_QUALITY: Dictionary = {
	"res://scenes/specials/texas_flag.tscn": true,  # true = "makes sense" (good)
	"res://scenes/specials/us_flag.tscn": true,     # true = "makes sense" (good)
	"res://scenes/specials/cheerleader.tscn": true, # true = "makes sense" (good)
	"res://scenes/specials/smoker.tscn": true,      # true = "makes sense" (good)
	"res://scenes/specials/hollywood_2.tscn": true, # true = "makes sense" (good)
	"res://scenes/specials/rods_bbq.tscn": true,     # true = "makes sense" (good)
	"res://scenes/specials/motorcycle.tscn": true,   # true = "makes sense" (good)
	"res://scenes/specials/devil_plush.tscn": false, # false = "hwwat?" (bad)
	"res://scenes/specials/man_baby.tscn": false,   # false = "hwwat?" (bad)
	"res://scenes/specials/go_vegan.tscn": false,   # false = "hwwat?" (bad)
}

static func is_good_sprite(scene_path: String) -> bool:
	return SPRITE_QUALITY.get(scene_path, false)
