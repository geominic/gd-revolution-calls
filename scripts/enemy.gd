extends CharacterBody2D
class_name Enemy1

# Movement properties
@export_group("Movement")
@export var speed = 150
@export var jump_px_height = 64
@onready var jump_velocity = -sqrt(2 * gravity * jump_px_height) #convert jump px to velocity
@export var gravity = 980
@export var acceleration = 0.1
@export var deceleration = 0.2
@export var patrol_speed = 75  # Speed when not pursuing player

# Abilities
@export_group("Abilities")
@export var can_fly = true
@export var can_jump = false
@export var detection_range = 500
@export var jump_cooldown = 1.0  # Prevent jump spam

# Navigation
@export_group("Navigation")
@export var edge_detection_distance = 50  # How far ahead to check for edges
@export var gap_jump_threshold = 150  # Maximum gap width enemy can jump
@onready var gap_detection_distance = edge_detection_distance + gap_jump_threshold  # Derived from other values
@export var obstacle_detection_distance = 50  # How far ahead to check for obstacles
@onready var obstacle_jump_height = jump_velocity  # Same as jump height
@export var max_fall_height = 150  # Maximum height enemy will willingly fall
@export var pathfinding_update_time = 1.0  # How often to recalculate path

# AI behavior
@export_group("AI Behavior")
@export var patrol_enabled = true
@export var patrol_wait_time = 2.0
@export var patrol_distance = 100

# Combat properties
@export_group("Combat")
@export var max_health = 100
@export var knockback_force = 300
@export var knockback_duration = 0.2
@export var invincibility_duration = 0.5
@export var flash_intensity = 0.6  # How bright the flash is (0-1)

# State tracking
var current_health
var is_invincible = false
var knockback_timer = 0.0
var invincibility_timer = 0.0
var is_dead = false
var original_modulate
var facing_direction = -1  # -1 is left, 1 is right
var jump_timer = 0.0
var patrol_direction = 1
var patrol_origin = Vector2.ZERO
var patrol_wait_timer = 0.0
var is_pursuing = false
var patrol_time = 0.0  # Accumulated time for flying patrol motion
var pathfinding_timer = 0.0

# Navigation raycasts
@onready var edge_raycast = $EdgeDetector
@onready var obstacle_raycast = $ObstacleDetector
@onready var wall_raycast = $WallDetector
@onready var gap_raycast_near = $GapDetectorNear
@onready var gap_raycast_far = $GapDetectorFar

# Animation states
enum EnemyState {IDLE, WALK, PURSUE, JUMP, ATTACK}
var current_state = EnemyState.IDLE

# References
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	# Initialize health
	current_health = max_health
	original_modulate = $Sprite2D.modulate
	
	# Store initial position for patrol
	patrol_origin = global_position
	
	# Find player if not already in group
	find_player()
	
	# Initial direction
	update_facing_direction(-1)
	
	# Setup raycasts if they don't exist
	setup_raycasts()

func setup_raycasts():
	# Edge detection raycast
	if not has_node("EdgeDetector"):
		edge_raycast = RayCast2D.new()
		edge_raycast.name = "EdgeDetector"
		add_child(edge_raycast)
		edge_raycast.target_position = Vector2(0, edge_detection_distance)
		edge_raycast.collision_mask = 1  # Terrain layer
	else:
		edge_raycast = $EdgeDetector
	
	# Obstacle detection raycast
	if not has_node("ObstacleDetector"):
		obstacle_raycast = RayCast2D.new()
		obstacle_raycast.name = "ObstacleDetector"
		add_child(obstacle_raycast)
		obstacle_raycast.target_position = Vector2(obstacle_detection_distance, 0)
		obstacle_raycast.collision_mask = 1  # Terrain layer
	else:
		obstacle_raycast = $ObstacleDetector
	
	# Wall detection raycast
	if not has_node("WallDetector"):
		wall_raycast = RayCast2D.new()
		wall_raycast.name = "WallDetector"
		add_child(wall_raycast)
		wall_raycast.target_position = Vector2(obstacle_detection_distance, 0)
		wall_raycast.collision_mask = 1  # Terrain layer
	else:
		wall_raycast = $WallDetector
	
	# Gap detection raycasts (near and far)
	if not has_node("GapDetectorNear"):
		gap_raycast_near = RayCast2D.new()
		gap_raycast_near.name = "GapDetectorNear"
		add_child(gap_raycast_near)
		gap_raycast_near.target_position = Vector2(0, edge_detection_distance)
		gap_raycast_near.collision_mask = 1  # Terrain layer
	else:
		gap_raycast_near = $GapDetectorNear
		
	if not has_node("GapDetectorFar"):
		gap_raycast_far = RayCast2D.new()
		gap_raycast_far.name = "GapDetectorFar"
		add_child(gap_raycast_far)
		gap_raycast_far.target_position = Vector2(0, edge_detection_distance)
		gap_raycast_far.collision_mask = 1  # Terrain layer
	else:
		gap_raycast_far = $GapDetectorFar

func _physics_process(delta):
	if is_dead:
		return
		
	# Update combat timers
	update_combat_timers(delta)
	
	patrol_time += delta  # accumulate time for flying patrol
	
	# Update timers
	update_timers(delta)
	
	# Update raycast positions based on facing direction
	update_raycast_positions()
	
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
		
	if pathfinding_timer > 0:
		pathfinding_timer -= delta

func update_raycast_positions():
	# Update edge detector position (down from in front of enemy)
	edge_raycast.position = Vector2(facing_direction * 20, 0)
	edge_raycast.target_position = Vector2(0, edge_detection_distance)
	
	# Update obstacle detector position (forward from enemy)
	obstacle_raycast.position = Vector2(0, -10)  # Slightly above ground level
	obstacle_raycast.target_position = Vector2(facing_direction * obstacle_detection_distance, 0)
	
	# Update wall detector position (forward from enemy at head height)
	wall_raycast.position = Vector2(0, -30)  # At head height
	wall_raycast.target_position = Vector2(facing_direction * obstacle_detection_distance, 0)
	
	# Update gap detection raycasts
	gap_raycast_near.position = Vector2(facing_direction * 40, 0)
	gap_raycast_near.target_position = Vector2(0, edge_detection_distance)
	
	gap_raycast_far.position = Vector2(facing_direction * gap_detection_distance, 0)
	gap_raycast_far.target_position = Vector2(0, edge_detection_distance)

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
		# Ground patrol with edge detection and obstacle avoidance
		var should_turn = false
		
		# Check for edges
		edge_raycast.force_raycast_update()
		if !edge_raycast.is_colliding() and is_on_floor():
			# Check if we can jump over the gap
			if can_jump and is_on_floor() and jump_timer <= 0:
				if can_jump_over_gap():
					# Jump over gap
					velocity.y = jump_velocity
					jump_timer = jump_cooldown
					# Boost horizontal speed to clear the gap
					velocity.x = patrol_direction * speed * 1.5
					print("Enemy jumping over gap")
				else:
					should_turn = true
					print("Enemy turning at edge - can't jump gap")
			else:
				should_turn = true
				print("Enemy turning at edge - can't jump")
		
		# Check for walls
		wall_raycast.force_raycast_update()
		if wall_raycast.is_colliding():
			if can_jump and is_on_floor() and jump_timer <= 0:
				# Try to jump over wall
				velocity.y = jump_velocity
				jump_timer = jump_cooldown
				print("Enemy jumping over wall")
			else:
				should_turn = true
				print("Enemy turning at wall - can't jump")
		
		# Check for obstacles that can be jumped over
		obstacle_raycast.force_raycast_update()
		if obstacle_raycast.is_colliding() and can_jump and is_on_floor() and jump_timer <= 0:
			#Try to jump over obstacle
			velocity.y = jump_velocity
			jump_timer = jump_cooldown
			print("Enemy jumping over obstacle")
		
		if should_turn:
			patrol_direction *= -1
			update_facing_direction(patrol_direction)
			patrol_wait_timer = patrol_wait_time
		
		var target_speed = patrol_direction * patrol_speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * speed * delta)
		
		apply_gravity(delta)

func can_jump_over_gap() -> bool:
	# Check if there's a gap we can jump over
	gap_raycast_near.force_raycast_update()
	gap_raycast_far.force_raycast_update()
	
	# If near edge doesn't hit but far edge does, it's a jumpable gap
	if !gap_raycast_near.is_colliding() and gap_raycast_far.is_colliding():
		return true
	
	# If both don't hit, check if it's within max jump distance
	if !gap_raycast_near.is_colliding() and !gap_raycast_far.is_colliding():
		# This is a larger gap or a drop - check if it's within max fall height
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			global_position + Vector2(facing_direction * 40, 0),
			global_position + Vector2(facing_direction * gap_detection_distance, max_fall_height)
		)
		query.collision_mask = 1  # Terrain layer
		var result = space_state.intersect_ray(query)
		
		if result:
			# There's ground within jumpable distance and acceptable fall height
			return true
	
	# Not a jumpable gap
	return false

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
		# Ground-based pursuit with pathfinding
		
		# Check for edges before moving
		edge_raycast.force_raycast_update()
		if !edge_raycast.is_colliding() and is_on_floor():
			# Check if we can jump over the gap to reach the player
			if can_jump and jump_timer <= 0 and can_jump_over_gap():
				velocity.y = jump_velocity
				jump_timer = jump_cooldown
				#Boost horizontal speed to clear the gap
				velocity.x = dir_to_player * speed * 1.5
				print("Enemy jumping over gap to pursue player")
				return
			
			# Don't walk off edges when pursuing unless player is below
			if player.global_position.y > global_position.y:
				var height_diff = player.global_position.y - global_position.y
				if height_diff < max_fall_height:
					#Safe to jump down
					velocity.x = direction.x * speed
					print("Enemy walking off edge to pursue player below")
				else:
					velocity.x = 0
					print("Edge too high to safely drop")
			else:
				velocity.x = 0
				print("Not walking off edge - player not below")
			
			return
		
		#Check for walls that need to be jumped over
		wall_raycast.force_raycast_update()
		if wall_raycast.is_colliding() and can_jump and is_on_floor() and jump_timer <= 0:
			velocity.y = jump_velocity
			jump_timer = jump_cooldown
			current_state = EnemyState.JUMP
			print("Enemy jumping over wall to pursue player")
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, acceleration)

		#Check for obstacles in path
		obstacle_raycast.force_raycast_update()
		if obstacle_raycast.is_colliding() and can_jump and is_on_floor() and jump_timer <= 0:
			velocity.y = jump_velocity
			jump_timer = jump_cooldown
			current_state = EnemyState.JUMP
			print("Enemy jumping over obstacle to pursue player")
		
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

func update_combat_timers(delta):
	if knockback_timer > 0:
		knockback_timer -= delta
		if knockback_timer <= 0:
			velocity = Vector2.ZERO  # Reset velocity after knockback
	
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			$Sprite2D.modulate = original_modulate  # Reset color

func take_damage(amount, source_position = null):
	print("Enemy taking damage: ", amount)
	if is_invincible or is_dead:
		return
		
	current_health -= amount
	print("Enemy health: ", current_health)
	
	# Visual feedback
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	# Flash effect
	var flash_color = Color(1 + flash_intensity, 1 + flash_intensity, 1 + flash_intensity, 1)
	$Sprite2D.modulate = flash_color
	
	# Apply knockback if source position is provided
	if source_position:
		var knockback_direction = (global_position - source_position).normalized()
		velocity = knockback_direction * knockback_force
		knockback_timer = knockback_duration
	
	# Check for death
	if current_health <= 0:
		die()
		
	else:
		pass
func die():
	is_dead = true
	print("Died")
	# Optional: Play death animation
	# $AnimationPlayer.play("death")
	
	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Optional: Spawn particles, play sound, etc.
	
	# Queue free after delay (or after animation)
	queue_free()
