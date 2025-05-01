extends Node2D

@export_group("Spawn Settings")
@export var min_distance_from_player = 500  # Minimum distance from player to spawn
@export var max_distance_from_player = 1000  # Maximum distance from player to spawn
@export var spawn_interval_seconds = 3.0  # Time between spawn attempts
@export var max_enemies = 10  # Maximum number of enemies allowed at once
@export var spawn_height_offset = 100  # How far above ground to spawn flying enemies

@export_group("Enemy Scenes")
@export var enemy_scenes: Array[PackedScene]  # Array to hold different enemy types
@export var spawn_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)  # Default spawn area

@onready var player = get_tree().get_first_node_in_group("player")
@onready var spawn_timer = $SpawnTimer

# Used for ground enemy spawning
var raycast: RayCast2D

func _ready():
	# Setup raycast for ground checking
	raycast = RayCast2D.new()
	add_child(raycast)
	raycast.target_position = Vector2(0, 1000)  # Ray length
	raycast.collision_mask = 1  # Layer for ground/terrain
	
	# Start spawn timer
	spawn_timer.wait_time = spawn_interval_seconds
	spawn_timer.start()

func _on_spawn_timer_timeout():
	attempt_spawn()

func attempt_spawn():
	# Check if we've reached max enemies
	var current_enemies = get_tree().get_nodes_in_group("enemy")
	if current_enemies.size() >= max_enemies:
		return
	
	# Check if we have enemy scenes to spawn
	if enemy_scenes.size() == 0:
		print("No enemy scenes assigned to spawner!")
		return
	
	# Get random position within bounds
	var spawn_pos = get_valid_spawn_position()
	if spawn_pos == Vector2.ZERO:  # Check for invalid position
		return
		
	# Select random enemy type
	var random_index = randi() % enemy_scenes.size()
	var enemy_scene = enemy_scenes[random_index]
	var enemy = enemy_scene.instantiate()
	
	# Set enemy position
	enemy.global_position = spawn_pos
	
	# Add enemy to scene
	get_tree().current_scene.add_child(enemy)

func get_valid_spawn_position() -> Vector2:
	var attempts = 10  # Maximum attempts to find valid position
	
	while attempts > 0:
		# Generate random position within bounds
		var random_x = randf_range(spawn_bounds.position.x, spawn_bounds.end.x)
		var random_y = randf_range(spawn_bounds.position.y, spawn_bounds.end.y)
		var test_pos = Vector2(random_x, random_y)
		
		# Check distance from player
		var distance_to_player = test_pos.distance_to(player.global_position)
		if distance_to_player < min_distance_from_player or distance_to_player > max_distance_from_player:
			attempts -= 1
			continue
		
		# For ground enemies, find ground position
		raycast.global_position = test_pos
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			var ground_pos = raycast.get_collision_point()
			# Offset slightly above ground
			return ground_pos + Vector2(0, -50)
			
		attempts -= 1
	
	return Vector2.ZERO  # Return zero vector if no valid position found
