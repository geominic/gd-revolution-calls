extends CharacterBody2D

# Movement properties
@export_group("Movement")
@export var speed = 300
@export var acceleration = 0.2
@export var deceleration = 0.1
@export var air_control = 0.1  # Control in air (was missing)

# Jump properties
@export_group("Jump")
@export var jump_force = -600
@export var gravity = 980
@export var fall_gravity_multiplier = 1.5  # Faster falling
@export var coyote_time = 0.15
@export var jump_buffer = 0.2
@export var variable_jump_height_multiplier = 0.5

# Combat properties
@export_group("Combat")
@export var weapon_cooldown = 0.3
@export var projectile_speed = 400

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

func _ready():
	# Initialize any components or state here
	update_facing_direction(1)

func _physics_process(delta):
	# Update timers
	update_timers(delta)
	
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

func update_timers(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
	if weapon_timer > 0:
		weapon_timer -= delta
	
	# Coyote time logic moved to handle_jump for better organization

func handle_movement(delta):
	var direction = Input.get_axis("move_left", "move_right")
	
	# Update facing direction when moving
	if direction != 0:
		update_facing_direction(direction)
	
	# Different handling for ground vs air
	if is_on_floor():
		if direction != 0:
			# Accelerate
			velocity.x = lerp(velocity.x, direction * speed, acceleration)
		else:
			# Decelerate to stop
			velocity.x = lerp(velocity.x, 0.0, deceleration)
	else:
		# Air control should be less responsive
		if direction != 0:
			velocity.x = lerp(velocity.x, direction * speed, air_control)
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
	projectile.direction = Vector2(facing_direction, 0)
	projectile.speed = projectile_speed
	get_parent().add_child(projectile)
	
	# Optional: add attack animation trigger here
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
