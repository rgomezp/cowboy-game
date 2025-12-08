extends CanvasLayer

signal button_pressed(is_good: bool)
signal buttons_hidden(was_pressed: bool, too_early: bool)  # Emitted when buttons hide, indicates if a button was pressed and if it was too early

var timer: float = 0.0
var buttons_visible: bool = false
var sprite_entered_view: bool = false  # Track if sprite has entered view
var force_hide: bool = false  # Flag to force hide (e.g., when button is pressed)
var buttons_hidden_for_event: bool = false  # Flag to prevent re-showing after hidden
const TIMEOUT_AFTER_VIEW: float = 2.0  # 2 seconds after sprite enters view

func _ready():
	# Initialize as hidden, but don't use hide_buttons() to avoid triggering protection logic
	buttons_visible = false
	sprite_entered_view = false
	force_hide = false
	buttons_hidden_for_event = false
	timer = 0.0
	visible = false
	$MakesSenseButton.disabled = true
	$HwwatButton.disabled = true

func reset_for_new_event():
	# Reset flags for a new special event
	buttons_hidden_for_event = false
	sprite_entered_view = false
	force_hide = false
	timer = 0.0

func _process(delta: float):
	if buttons_visible:
		# If sprite has entered view, start counting down
		if sprite_entered_view:
			timer += delta
			# Only hide buttons after 2 full seconds have passed since sprite entered view
			# OR if force_hide is set (button was pressed)
			if force_hide:
				# Button was pressed - allow hiding
				hide_buttons()
			elif timer >= TIMEOUT_AFTER_VIEW:
				# 2 seconds have passed - safe to hide now
				hide_buttons()

func show_buttons():
	# Show buttons when event starts (before sprite enters view)
	# Don't show if buttons were already hidden for this event
	if buttons_hidden_for_event:
		return
	
	buttons_visible = true
	sprite_entered_view = false
	force_hide = false
	timer = 0.0
	visible = true
	$MakesSenseButton.disabled = false
	$HwwatButton.disabled = false

func on_sprite_entered_view():
	# Called when sprite enters camera view - start the 2 second timer
	# Only start timer if buttons are visible
	if buttons_visible and not sprite_entered_view:
		sprite_entered_view = true
		timer = 0.0  # Reset timer when sprite enters view
		# Ensure buttons stay visible - this flag prevents premature hiding
		# Once sprite enters view, buttons MUST stay visible for 2 full seconds

func get_is_visible() -> bool:
	# Public getter to check if buttons are currently visible
	# Return both buttons_visible AND visible to ensure consistency
	return buttons_visible and visible

func has_sprite_entered_view() -> bool:
	# Public getter to check if sprite has entered view
	return sprite_entered_view

func get_timer_value() -> float:
	# Public getter to get the current timer value (time since sprite entered view)
	return timer

func hide_buttons():
	# STRICT Protection: Once sprite has entered view, buttons MUST stay visible for 2 full seconds
	# Only allow hiding if:
	# 1. Timer has expired (>= 2 seconds since sprite entered view), OR
	# 2. force_hide is set (button was pressed), OR
	# 3. Sprite hasn't entered view yet (buttons can be hidden before sprite appears)
	if buttons_visible and sprite_entered_view and not force_hide:
		# Sprite has entered view - enforce the 2 second minimum visibility
		if timer < TIMEOUT_AFTER_VIEW:
			# Not enough time has passed - absolutely do not hide
			return

	# Emit signal before hiding to indicate if a button was pressed
	var was_pressed = force_hide
	buttons_hidden.emit(was_pressed, false)  # false = not too early

	# Safe to hide now (either timer expired, force_hide is set, or sprite hasn't entered view yet)
	buttons_visible = false
	sprite_entered_view = false
	force_hide = false
	buttons_hidden_for_event = true  # Prevent re-showing for this event
	timer = 0.0
	visible = false
	$MakesSenseButton.disabled = true
	$HwwatButton.disabled = true

func force_hide_immediately():
	# Immediately hide buttons without any protection logic (for early button presses)
	# Emit signal to indicate button was pressed (but too early)
	buttons_hidden.emit(true, true)  # true = too early

	buttons_visible = false
	sprite_entered_view = false
	force_hide = false
	buttons_hidden_for_event = true  # Prevent re-showing for this event
	timer = 0.0
	visible = false
	$MakesSenseButton.disabled = true
	$HwwatButton.disabled = true

func _on_makes_sense_button_pressed():
	# If sprite hasn't entered view yet, hide immediately
	if not sprite_entered_view:
		force_hide_immediately()
		button_pressed.emit(true)
		return

	button_pressed.emit(true)
	# Force hide when button is pressed
	force_hide = true

func _on_hwwat_button_pressed():
	# If sprite hasn't entered view yet, hide immediately
	if not sprite_entered_view:
		force_hide_immediately()
		button_pressed.emit(false)
		return

	button_pressed.emit(false)
	# Force hide when button is pressed
	force_hide = true
