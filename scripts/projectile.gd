extends Area2D
@export var speed = 800
@export var damage = 10

var direction = Vector2.RIGHT

func _ready():
	$Lifetime.start()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_lifetime_timeout():
	queue_free()
