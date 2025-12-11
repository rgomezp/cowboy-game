extends Node

# Centralized controller for enabling/disabling all spawning systems

var obstacle_manager: Node
var foe_spawner: Node
var coin_spawner: Node
var butterfly_spawner: Node
var distance: int = 0  # Reference to distance for syncing

func initialize(obstacle_mgr: Node, foe_spr: Node, coin_spr: Node, butterfly_spr: Node, distance_ref: int):
	obstacle_manager = obstacle_mgr
	foe_spawner = foe_spr
	coin_spawner = coin_spr
	butterfly_spawner = butterfly_spr
	distance = distance_ref

func set_distance(distance_value: int):
	distance = distance_value

func set_obstacle_spawning_enabled(enabled: bool):
	var was_disabled = not obstacle_manager.is_spawning_enabled()
	print("[SpawningController] set_obstacle_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	obstacle_manager.set_spawning_enabled(enabled)
	# Sync distance when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[SpawningController] Syncing obstacle distance...")
		obstacle_manager.sync_distance(distance)

func set_foe_spawning_enabled(enabled: bool):
	var was_disabled = not foe_spawner.is_spawning_enabled()
	print("[SpawningController] set_foe_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	foe_spawner.set_spawning_enabled(enabled)
	# Sync distance when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[SpawningController] Syncing foe distance...")
		foe_spawner.sync_distance(distance)

func set_coin_spawning_enabled(enabled: bool):
	var was_disabled = not coin_spawner.is_spawning_enabled()
	print("[SpawningController] set_coin_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	coin_spawner.set_spawning_enabled(enabled)
	# Reset timer when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[SpawningController] Resetting coin timer...")
		coin_spawner.reset_timer()

func set_butterfly_spawning_enabled(enabled: bool):
	var was_disabled = not butterfly_spawner.is_spawning_enabled()
	print("[SpawningController] set_butterfly_spawning_enabled: enabled=", enabled, ", was_disabled=", was_disabled, ", distance=", distance)
	butterfly_spawner.set_spawning_enabled(enabled)
	# Reset timer when re-enabling to fix timing after powerups
	if enabled and was_disabled:
		print("[SpawningController] Resetting butterfly timer...")
		butterfly_spawner.reset_timer()

# Convenience method to enable/disable all spawning
func set_all_spawning_enabled(enabled: bool):
	set_obstacle_spawning_enabled(enabled)
	set_foe_spawning_enabled(enabled)
	set_coin_spawning_enabled(enabled)
	set_butterfly_spawning_enabled(enabled)
