extends CharacterBody2D

# FOV properties
@export_group("FOV")
@export var default_zoom = Vector2(0.73, 0.73)  # Match your current camera zoom
@export var sprint_zoom = Vector2(0.65, 0.65)  # Zoomed out while sprinting
@export var zoom_lerp_speed = 5.0  # How fast the FOV changes

# Movement properties
@export_group("Movement")
@export var speed = 300
@export var sprint_speed_multiplier = 1.6  # How much faster sprint is
@export var acceleration = 0.2
@export var deceleration = 0.1
@export var air_control = 0.1  # Control in air (was missing)

# Stamina properties
@export_group("Stamina")
@export var max_stamina = 100.0
@export var stamina_drain_rate = 30.0  # How fast stamina drains while sprinting
@export var stamina_regen_rate = 20.0  # How fast stamina regenerates
@export var stamina_regen_delay = 1.0  # Delay before stamina starts regenerating
@export var stamina_bar_hide_delay = 2.0  # Time before hiding full stamina bar
@export var stamina_bar_fade_duration = 0.3  # How long the fade transition takes
var current_stamina = 100.0
var stamina_regen_timer = 0.0
var stamina_bar_hide_timer = 0.0
var is_sprinting = false
var should_show_stamina_bar = false
var stamina_bar_alpha = 0.0

# Jump properties
@export_group("Jump")
@export var jump_px_height = 80
@onready var jump_force = -sqrt(2 * gravity * jump_px_height) #convert jump px to velocity
@export var gravity = 980
@export var fall_gravity_multiplier = 1.5  # Faster falling
@export var coyote_time = 0.15
@export var jump_buffer = 0.2
@export var variable_jump_height_multiplier = 0.5

# Combat properties
@export_group("Combat")
@export var weapon_cooldown = 0.3
@export var projectile_speed = 600
@export var projectile_gravity = 100

# State tracking
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var can_double_jump = false
var weapon_timer = 0.0
var facing_direction = 1  # 1 for right, -1 for left

# Preloaded scenes
var projectile_scene = preload("res://weapons/projectile.tscn")

# Animation states
enum PlayerState {IDLE, RUN, JUMP, FALL, ATTACK}
var current_state = PlayerState.IDLE

@onready var camera = $Camera2D
@onready var stamina_bar = $StaminaBar

func _ready():
	current_stamina = max_stamina
	update_facing_direction(1)
	camera.zoom = default_zoom
	
	# Initialize stamina bar
	if stamina_bar:
		stamina_bar.modulate.a = 0.0

func _process(delta):
	if stamina_bar:
		# Update stamina bar value
		stamina_bar.value = (current_stamina / max_stamina) * 100
		
		# Handle stamina bar visibility
		update_stamina_bar_visibility(delta)

func _physics_process(delta):
	# Update timers
	update_timers(delta)
	
	# Handle stamina
	handle_stamina(delta)
	
	# Handle movement
	handle_movement(delta)
	
	# Handle jumping
	handle_jump(delta)
	
	# Apply gravity
	apply_gravity(delta)
	
	# Apply velocity
	move_and_slide()
	
	# Handle attacks
	handle_attack(delta)
	
	# Update animation state
	update_animation_state()
	
	# Update FOV
	update_fov(delta)

func update_timers(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
	if weapon_timer > 0:
		weapon_timer -= delta
	
	# Coyote time logic moved to handle_jump for better organization

func handle_stamina(delta):
	# Check for sprint input - now works in air too
	is_sprinting = Input.is_action_pressed("sprint") and current_stamina > 0
	
	if is_sprinting and abs(velocity.x) > 0:
		# Drain stamina while sprinting
		current_stamina = max(0, current_stamina - stamina_drain_rate * delta)
		stamina_regen_timer = stamina_regen_delay
		should_show_stamina_bar = true
		stamina_bar_hide_timer = stamina_bar_hide_delay
	else:
		# Regenerate stamina after delay
		if stamina_regen_timer <= 0:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
			
			# Start hide timer when stamina is full
			if current_stamina >= max_stamina:
				if stamina_bar_hide_timer > 0:
					stamina_bar_hide_timer -= delta
				else:
					should_show_stamina_bar = false
			else:
				should_show_stamina_bar = true
				stamina_bar_hide_timer = stamina_bar_hide_delay
		else:
			stamina_regen_timer -= delta

func handle_movement(delta):
	var direction = Input.get_axis("move_left", "move_right")
	
	# Update facing direction when moving
	if direction != 0:
		update_facing_direction(direction)
	
	# Calculate target speed based on sprint state
	var target_speed = speed * (sprint_speed_multiplier if is_sprinting else 1.0)
	
	# Different handling for ground vs air
	if is_on_floor():
		if direction != 0:
			# Accelerate
			velocity.x = lerp(velocity.x, direction * target_speed, acceleration)
		else:
			# Decelerate to stop
			velocity.x = lerp(velocity.x, 0.0, deceleration)
	else:
		# Air control - still affected by sprint
		if direction != 0:
			velocity.x = lerp(velocity.x, direction * target_speed, air_control)
		else:
			# Slight air resistance when not controlling
			velocity.x = lerp(velocity.x, 0.0, air_control * 0.5)

func handle_jump(delta):
	# Update coyote timer
	if not is_on_floor():
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time
		can_double_jump = true
	
	# Jump input buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	
	# Execute jump if buffered and possible
	if jump_buffer_timer > 0:
		if coyote_timer > 0:
			# Normal jump
			velocity.y = jump_force
			jump_buffer_timer = 0
		elif can_double_jump:
			# Double jump
			velocity.y = jump_force * 0.8  # Slightly weaker double jump
			can_double_jump = false
			jump_buffer_timer = 0
	
	# Variable jump height when releasing jump early
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= variable_jump_height_multiplier

func apply_gravity(delta):
	if not is_on_floor():
		# Apply stronger gravity when falling for better game feel
		var gravity_multiplier = fall_gravity_multiplier if velocity.y > 0 else 1.0
		velocity.y += gravity * gravity_multiplier * delta

func handle_attack(delta):
	if Input.is_action_just_pressed("attack") and weapon_timer <= 0:
		throw_weapon()
		weapon_timer = weapon_cooldown  # Apply cooldown

func throw_weapon():
	var projectile = projectile_scene.instantiate()
	projectile.global_position = $WeaponSpawn.global_position
	projectile.speed = projectile_speed
	projectile.gravity_strength = projectile_gravity
	get_tree().current_scene.add_child(projectile)  # Add to the active scene root for proper positioning
	
	# Optional: trigger attack animation
	# $AnimationPlayer.play("attack")

func update_animation_state():
	var new_state
	
	if is_on_floor():
		if abs(velocity.x) > 10:  # Small threshold to avoid jitter
			new_state = PlayerState.RUN
		else:
			new_state = PlayerState.IDLE
	else:
		if velocity.y < 0:
			new_state = PlayerState.JUMP
		else:
			new_state = PlayerState.FALL
	
	# Only update animation if state changed
	if new_state != current_state:
		current_state = new_state
		play_animation_for_state(current_state)

func play_animation_for_state(state):
	# Assuming you have an AnimationPlayer or AnimatedSprite
	match state:
		PlayerState.IDLE:
			pass # $AnimationPlayer.play("idle")
		PlayerState.RUN:
			pass # $AnimationPlayer.play("run")
		PlayerState.JUMP:
			pass # $AnimationPlayer.play("jump")
		PlayerState.FALL:
			pass # $AnimationPlayer.play("fall")
		PlayerState.ATTACK:
			pass # $AnimationPlayer.play("attack")

func update_facing_direction(direction):
	if direction == 0:
		return
		
	if facing_direction != direction:
		facing_direction = direction
		
		# Update sprite direction using flip_h (simpler method)
		$Sprite2D.flip_h = facing_direction < 0

func update_fov(delta):
	var target_zoom = default_zoom
	
	# Change FOV based on sprinting and horizontal speed
	if is_sprinting and abs(velocity.x) > speed * 0.5:
		target_zoom = sprint_zoom
		
		# Optional: Add slight tilt based on movement direction
		camera.rotation = lerp(camera.rotation, 0.05 * sign(velocity.x), delta * 2.0)
	else:
		camera.rotation = lerp(camera.rotation, 0.0, delta * 2.0)
	
	# Smoothly interpolate to target zoom
	camera.zoom = camera.zoom.lerp(target_zoom, delta * zoom_lerp_speed)

func update_stamina_bar_visibility(delta):
	var target_alpha = 1.0 if should_show_stamina_bar else 0.0
	
	# Smoothly interpolate the alpha
	stamina_bar_alpha = move_toward(stamina_bar_alpha, target_alpha, delta / stamina_bar_fade_duration)
	stamina_bar.modulate.a = stamina_bar_alpha
