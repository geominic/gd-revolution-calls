extends Area2D

@export var speed: float = 800
@export var damage: int = 50
@export var gravity_strength: float = 1200.0
@export var lifetime_sec: float = 3.0

var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO

func _ready():
	# Aim at mouse position when spawned
	var mouse_pos = get_global_mouse_position()
	direction = (mouse_pos - global_position).normalized()
	velocity = direction * speed
	
	# Set initial rotation based on velocity
	rotation = velocity.angle()
	
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
	if body.is_in_group("enemy"):
		body.take_damage(damage, global_position)
		queue_free()
func _on_lifetime_timeout():
	queue_free()
