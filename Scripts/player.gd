extends CharacterBody3D


const BASE_SPEED = 5.0

var speed : float = BASE_SPEED
var speed_mult : float = 1.0

@onready var speed_mult_label: Label = $UI/Control/SpeedMultLabel

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("LClick") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	
	# Handle vertical
	var vert_dir := Input.get_axis("Down","Up")
	if vert_dir:
		velocity.y = vert_dir * speed
	else:
		velocity.y = move_toward(velocity.y, 0, speed)
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Handle speeding up / slowing down
	if Input.is_action_just_pressed("SpeedUp"):
		speed_mult += 0.1
	if Input.is_action_just_pressed("SlowDown"):
		speed_mult -= 0.1
	
	speed = roundf(BASE_SPEED + speed_mult)
	speed_mult_label.text = "Speed Mult: " + str(speed_mult)
	
	move_and_slide()
