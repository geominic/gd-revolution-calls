extends Area2D

@export var speed: float = 800
@export var damage: int = 10
@export var gravity_strength: float = 1200.0  # Gravity acceleration in pixels/s²
@export var lifetime_sec: float = 3.0  # How long projectile lives before disappearing

var velocity: Vector2 = Vector2.ZERO

func _ready():
	# Set gravity
	gravity = gravity_strength
	
	# Aim at mouse position when spawned
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	velocity = direction * speed
	
	# Set initial rotation based on velocity
	rotation = velocity.angle()
	
	# Start lifetime timer
	$Lifetime.wait_time = lifetime_sec
	$Lifetime.start()

func _physics_process(delta):
	# Apply gravity (only affects vertical velocity)
	velocity.y += gravity * delta
	
	# Update rotation to match velocity direction
	rotation = velocity.angle()
	
	# Move projectile
	position += velocity * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_lifetime_timeout():
	queue_free()
