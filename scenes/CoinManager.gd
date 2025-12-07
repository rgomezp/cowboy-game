extends Node

signal coin_added(coin: Node)
signal coin_removed(coin: Node)

var coins: Array = []
var screen_size: Vector2i

func initialize(size: Vector2i):
	self.screen_size = size

func reset():
	clear_all_coins()

func clear_all_coins():
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	coins.clear()

func add_coin(coin: Node):
	add_child(coin)
	coins.append(coin)
	coin_added.emit(coin)

func remove_coin(coin: Node):
	if coins.has(coin):
		coins.erase(coin)
		# Don't queue_free here - let the coin handle its own cleanup after animation
		# The coin will call queue_free() itself after the animation finishes
		coin_removed.emit(coin)

func cleanup_off_screen_coins(camera_x: float):
	# Add a buffer to ensure coins are well off-screen before removal
	var cleanup_threshold = camera_x - screen_size.x * 2
	for coin in coins.duplicate():
		# Check if object is still valid (not freed)
		if not is_instance_valid(coin):
			# Remove invalid references from array
			coins.erase(coin)
			continue
		if coin.position.x < cleanup_threshold:
			remove_coin(coin)
