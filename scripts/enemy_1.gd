extends CharacterBody2D
class_name Enemy1

# Movement properties
@export_group("Movement")
@export var speed = 150
@export var jump_velocity = -300
@export var gravity = 980
@export var acceleration = 0.1
@export var deceleration = 0.2
@export var patrol_speed = 75  # Speed when not pursuing player

# Abilities
@export_group("Abilities")
@export var can_fly = true
@export var can_jump = false
@export var detection_range = 500
@export var jump_height_threshold = 20
@export var jump_cooldown = 1.0  # Prevent jump spam

# AI behavior
@export_group("AI Behavior")
@export var patrol_enabled = true
@export var patrol_wait_time = 2.0
@export var patrol_distance = 100

# State tracking
var facing_direction = -1  # -1 is left, 1 is right
var jump_timer = 0.0
var patrol_direction = 1
var patrol_origin = Vector2.ZERO
var patrol_wait_timer = 0.0
var is_pursuing = false
var patrol_time = 0.0  # Accumulated time for flying patrol motion

# Animation states
enum EnemyState {IDLE, WALK, PURSUE, JUMP, ATTACK}
var current_state = EnemyState.IDLE

# References
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	# Store initial position for patrol
	patrol_origin = global_position
	
	# Find player if not already in group
	find_player()
	
	# Initial direction
	update_facing_direction(-1)

func _physics_process(delta):
	patrol_time += delta  # accumulate time for flying patrol
	
	# Update timers
	update_timers(delta)
	
	# Decide behavior based on player detection
	if player == null:
		handle_no_player(delta)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Pursue player if within detection range
	if distance_to_player <= detection_range:
		is_pursuing = true
		pursue_player(delta)
	else:
		is_pursuing = false
		patrol_behavior(delta)
	
	# Apply velocity and move
	move_and_slide()
	
	# Update animation state
	update_animation_state()

func update_timers(delta):
	if jump_timer > 0:
		jump_timer -= delta
		
	if patrol_wait_timer > 0:
		patrol_wait_timer -= delta

func find_player():
	if player == null:
		player = get_tree().get_first_node_in_group("player")

func handle_no_player(delta):
	# Default behavior when no player is found
	patrol_behavior(delta)

func patrol_behavior(delta):
	if not patrol_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * speed * delta)
		apply_gravity(delta)
		return

	if patrol_wait_timer > 0:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * speed * delta)
		apply_gravity(delta)
		return

	if can_fly:
		# Flying patrol with horizontal oscillation + vertical bobbing
		var patrol_x_limit = patrol_distance
		var patrol_y_offset = 20
		
		# Calculate target X position based on patrol direction
		var target_x = patrol_origin.x + patrol_direction * patrol_x_limit
		
		# Check if reached or near patrol boundary, then reverse direction
		if abs(global_position.x - target_x) < 5:
			patrol_direction *= -1
			patrol_wait_timer = patrol_wait_time
			update_facing_direction(patrol_direction)
		
		# Vertical bobbing using sinusoidal function based on accumulated time
		var target_y = patrol_origin.y + patrol_y_offset * sin(patrol_time * 3)
		
		var target_pos = Vector2(target_x, target_y)
		var direction = (target_pos - global_position).normalized()
		velocity = velocity.move_toward(direction * patrol_speed, acceleration * speed * delta)
		
		apply_gravity(delta)
	else:
		# Ground patrol (fixed patrol behavior as before)
		var distance_from_origin = global_position.x - patrol_origin.x
		
		if patrol_direction > 0 and distance_from_origin >= patrol_distance:
			patrol_direction = -1
			update_facing_direction(patrol_direction)
			patrol_wait_timer = patrol_wait_time
		elif patrol_direction < 0 and distance_from_origin <= -patrol_distance:
			patrol_direction = 1
			update_facing_direction(patrol_direction)
			patrol_wait_timer = patrol_wait_time
		
		var target_speed = patrol_direction * patrol_speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * speed * delta)
		
		apply_gravity(delta)

func pursue_player(delta):
	if player == null:
		return
	
	var direction = (player.global_position - global_position).normalized()

	# Update facing direction based on horizontal component
	var dir_to_player = sign(player.global_position.x - global_position.x)
	update_facing_direction(dir_to_player)

	if can_fly:
		# Smoothly accelerate velocity towards player (both x and y)
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration)
		velocity.y = lerp(velocity.y, direction.y * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration)

		if can_jump and is_on_floor() and jump_timer <= 0:
			var height_difference = player.global_position.y - global_position.y
			if height_difference < -jump_height_threshold:
				velocity.y = jump_velocity
				jump_timer = jump_cooldown
				current_state = EnemyState.JUMP
			else:
				apply_gravity(delta)
		else:
			apply_gravity(delta)

func apply_gravity(delta):
	if can_fly:
		# Flying enemies ignore gravity but gradually slow vertical velocity to zero (simulate drag)
		velocity.y = lerp(velocity.y, 0.1, deceleration)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif velocity.y > 0:
			velocity.y = 0

func update_facing_direction(direction):
	if direction == 0:
		return

	if facing_direction != direction:
		facing_direction = direction
		$Sprite2D.flip_h = facing_direction < 0

func update_animation_state():
	var new_state
	
	if is_pursuing:
		new_state = EnemyState.PURSUE
	else:
		if abs(velocity.x) > 10:
			new_state = EnemyState.WALK
		else:
			new_state = EnemyState.IDLE
	
	if velocity.y < 0 and not can_fly:
		new_state = EnemyState.JUMP
	
	if new_state != current_state:
		current_state = new_state
		play_animation_for_state(current_state)

func play_animation_for_state(state):
	match state:
		EnemyState.IDLE:
			pass # $AnimationPlayer.play("idle")
		EnemyState.WALK:
			pass # $AnimationPlayer.play("walk")
		EnemyState.PURSUE:
			pass # $AnimationPlayer.play("pursue")
		EnemyState.JUMP:
			pass # $AnimationPlayer.play("jump")
		EnemyState.ATTACK:
			pass # $AnimationPlayer.play("attack")

func take_damage(amount):
	pass

func die():
	queue_free()
