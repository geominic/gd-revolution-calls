extends Area2D

@export var speed: float = 800
@export var weapon_cooldown = 0.3
@export var damage: int = 50
@export var gravity_strength: float = 1200.0
@export var lifetime_sec: float = 3.0
@export var source_group: String = "player"  # Who fired this projectile

var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO

# Called when the projectile is initialized
func initialize(spawn_position: Vector2, target_position: Vector2 = Vector2.ZERO, initial_speed: float = -1):
	global_position = spawn_position
	
	# If target position is provided, aim at it
	if target_position != Vector2.ZERO:
		direction = (target_position - global_position).normalized()
	else:
		# Default to aiming at mouse position
		var mouse_pos = get_global_mouse_position()
		direction = (mouse_pos - global_position).normalized()
	
	# Use provided speed or default
	if initial_speed > 0:
		speed = initial_speed
	
	# Set initial velocity and rotation
	velocity = direction * speed
	rotation = velocity.angle()

func _ready():
	# Start lifetime timer
	$Lifetime.wait_time = lifetime_sec
	$Lifetime.start()

func _physics_process(delta):
	# Apply gravity
	velocity.y += gravity_strength * delta
	
	# Update rotation to match velocity direction
	rotation = velocity.angle()
	
	# Move projectile
	position += velocity * delta

func _on_body_entered(body):
	if body.is_in_group("enemy") and source_group == "player":
		body.take_damage(damage, global_position)
		queue_free()
	elif body.is_in_group("player") and source_group == "enemy":
		# Handle player damage if this is an enemy projectile
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif not body.is_in_group(source_group):
		# Hit something else (like terrain)
		queue_free()

func _on_lifetime_timeout():
	queue_free()
