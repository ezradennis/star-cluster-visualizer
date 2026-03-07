extends Node3D

@export var distance_scale: float = 1.0 # Parsecs to godot meters
@export var mesh: SphereMesh


var multimesh_instance: MultiMeshInstance3D
var star_positions: PackedVector3Array
var star_database: Array
var selection_reticle: MeshInstance3D

# info ui
@onready var ui_container: MarginContainer = $UI/UIContainer
@onready var index_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/IndexLabel
@onready var distance_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/DistanceLabel
@onready var ra_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/RALabel
@onready var dec_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/DecLabel
@onready var temp_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/TempLabel
@onready var radius_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/RadiusLabel
@onready var name_label: Label = $UI/UIContainer/PanelContainer/VBoxContainer/NameLabel

# console ui
@onready var console_panel: PanelContainer = $UI/ConsolePanel
@onready var console_input: LineEdit = $UI/ConsolePanel/HBoxContainer/ConsoleInput


# HR diagram lookup table for v-i
#var main_sequence_data_vi: Array[Vector2] = [
	#Vector2(-0.4, -4.0),  # Massive blue stars
	#Vector2(-0.1, -0.5),
	#Vector2(0.3, 2.0),
	#Vector2(0.7, 4.8),    # Sun-like stars
	#Vector2(1.2, 7.5),
	#Vector2(1.6, 11.0),
	#Vector2(2.0, 13.5),   
	#Vector2(3.0, 16.0)    # Small red dwarfs
#]

# HR diagram lookuup table for b-v (b-v, abs magnitude)
var main_sequence_data: Array[Vector2] = [
	Vector2(-0.3, -4.0),  # Hot blue stars O
	Vector2(-0.1, -0.5),
	Vector2(0.0, 1.0),
	Vector2(0.3, 3.0),
	Vector2(0.65, 4.8),   # Sun-like stars (G-type)
	Vector2(1.0, 6.5),
	Vector2(1.4, 9.0),
	Vector2(1.7, 12.0),
	Vector2(2.0, 15.0)    # Cool red dwarfs (M-type)
]

# SETUP FUNCTIONS

func _ready() -> void:
	setup_renderer()
	
	star_database = parse_hyg_csv("res://data/hyg_v42.csv")
	
	if star_database.size() > 0:
		generate_stars(star_database)
	
	Globals.find_clicked_star.connect(find_star)
	Globals.fly_to_star.connect(fly_to_star)
	Globals.change_console_visible.connect(on_change_console_visible)
	console_input.text_submitted.connect(on_command_submitted)
	
	setup_reticle()

func setup_renderer() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	var multimesh = MultiMesh.new()
	
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	
	multimesh.mesh = mesh
	
	multimesh_instance.multimesh = multimesh
	add_child(multimesh_instance)

func generate_stars(data: Array) -> void:
	
	var total_stars = data.size()
	multimesh_instance.multimesh.instance_count = total_stars
	
	for i in range(total_stars):
		
		var app_mag = data[i][0]
		var color_index = data[i][1]
		var ra = deg_to_rad(data[i][2])
		var dec = deg_to_rad(data[i][3])
		var dist = data[i][4]
		
		var temp = estimate_surface_temp(color_index)
		var radius = calculate_stellar_radius(app_mag, dist, temp)
		
		var log_scale = 1.0 + (log(max(radius, 0.1)) / log(10.0)) * 3.0
		log_scale = clamp(log_scale, 0.3, 25.0)
		
		var position = spherical_to_cartesian(dist, ra, dec) * distance_scale
		star_positions.append(position)
		
		var scaled_basis = Basis().scaled(Vector3(log_scale, log_scale, log_scale))
		var transform = Transform3D(scaled_basis, position)
		multimesh_instance.multimesh.set_instance_transform(i, transform)
		
		# color shader stuff
		var custom_data = Color(color_index, 0.0, 0.0, 0.0)
		multimesh_instance.multimesh.set_instance_custom_data(i, custom_data)

func setup_reticle() -> void:
	selection_reticle = MeshInstance3D.new()
	var reticle_mesh = SphereMesh.new()
	
	reticle_mesh.radius = 0.065
	reticle_mesh.height = 0.13
	selection_reticle.mesh = reticle_mesh
	
	var outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color(0.0, 0.8, 0.2)
	
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	
	selection_reticle.material_override = outline_mat
	selection_reticle.visible = false
	
	add_child(selection_reticle)

# MATH HELPERS

func estimate_surface_temp(color: float) -> float:
	
	# prevent divide-by-zero errors
	if color == -1.8478 or color == -0.6739:
		return 0.0
		
	var term1 = 1.0 / (0.92 * color + 1.7)
	var term2 = 1.0 / (0.92 * color + 0.62)
	
	
	return 4600 * (term1 + term2)

func estimate_abs_mag(color: float) -> float:
	
	# if the color index (currently b-v I should make this modular) 
	# is out of bounds it just maps to the highest or lowest
	if color <= main_sequence_data[0].x:
		return main_sequence_data[0].y
	
	var last_index = main_sequence_data.size() - 1
	if color >= main_sequence_data[last_index].x:
		return main_sequence_data[last_index].y
	
	# maps it to whatever place on the main sequence its closest too
	for i in range(last_index):
		var point_left = main_sequence_data[i]
		var point_right = main_sequence_data[i + 1]
		
		if color >= point_left.x and color <= point_right.x:
			var weight = (color - point_left.x) / (point_right.x - point_left.x)
			
			return lerpf(point_left.y, point_right.y, weight)
	
	return 0.0


# returns distance in parsec
func calculate_distance(apparent_mag: float, absolute_mag: float) -> float:
	var exponent = (apparent_mag - absolute_mag + 5.0) / 5.0
	return pow(10.0, exponent)

func spherical_to_cartesian(d: float, ra_rad: float, dec_rad: float) -> Vector3:
	var x = d * cos(dec_rad) * cos(ra_rad)
	var z = d * cos(dec_rad) * sin(ra_rad)
	var y = d * sin(dec_rad)
	
	return Vector3(x, y, z)

# DATA FUNCTIONS

func parse_hyg_csv(file_path: String) -> Array:
	var parsed_data = []
	
	if not FileAccess.file_exists(file_path):
		push_error("Error: Could not find the star database at: " + file_path)
		return parsed_data
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	file.get_csv_line()
	
	var name_col = 6
	var ra_col = 7
	var dec_col = 8
	var dist_col = 9
	var mag_col = 13
	var ci_col = 16
	
	var i: int = 1
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		if line.size() <= ci_col:
			continue
		
		# for missing color indexes default to 0.65
		var ci_string = line[ci_col]
		var color_index = 0.65
		if ci_string != "":
			color_index = ci_string.to_float()
		
		var star_name = "unknown"
		var name_string = line[name_col]
		if name_string != "":
			star_name = name_string
		
		var mag = line[mag_col].to_float()
		var dec = line[dec_col].to_float()
		
		var dist = line[dist_col].to_float()
		
		var ra_hours = line[ra_col].to_float()
		var ra_degrees = ra_hours * 15.0
		
		parsed_data.append([mag, color_index, ra_degrees, dec, dist, star_name])
		
	
	file.close()
	print("Successfully loaded %d stars!" % parsed_data.size())
	return parsed_data

func find_star(mouse_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var closest_star_index = -1
	var closest_distance = INF
	var max_click_radius = 0.5
	
	for i in range(star_positions.size()):
		var star_pos = star_positions[i]
		
		# skip stars perpendicular to or behind camera
		if ray_direction.dot(star_pos - ray_origin) <= 0:
			continue
		
		var point_to_origin = star_pos - ray_origin
		var distance_to_ray = point_to_origin.cross(ray_direction).length()
		
		if distance_to_ray < closest_distance and distance_to_ray < max_click_radius:
			closest_distance = distance_to_ray
			closest_star_index = i
	
	if closest_star_index != -1:
		
		Globals.current_selected_star_index = closest_star_index
		
		var star_data = star_database[closest_star_index]
		
		var app_mag = star_data[0]
		var color = star_data[1]
		var ra = star_data[2]
		var dec = star_data[3]
		var dist = star_data[4]
		var star_name = star_data[5]
		
		var temp = estimate_surface_temp(color)
		var radius = calculate_stellar_radius(app_mag, dist, temp)
		
		var log_scale = 1.0 + (log(max(radius, 0.1)) / log(10.0)) * 3.0
		log_scale = clamp(log_scale, 0.3, 25.0)
		
		selection_reticle.scale = Vector3(log_scale, log_scale, log_scale)
		selection_reticle.global_position = star_positions[closest_star_index]
		selection_reticle.visible = true
		
		
		index_label.text = "Database Index: %d" % closest_star_index
		distance_label.text = "Distance: %.2f Parsecs" % dist
		ra_label.text = "Right Ascension: %.2f" % ra
		dec_label.text = "Declination: %.2f" % dec
		temp_label.text = "Temperature: %d K" % temp
		radius_label.text = "Solar Radii: %.2f" % radius
		name_label.text = "Name: %s" % star_name
		
		ui_container.visible = true
		
	else:
		
		Globals.current_selected_star_index = -1
		selection_reticle.visible = false
		ui_container.visible = false

func calculate_stellar_radius(app_mag: float, dist: float, temp: float) -> float:
	
	if temp <= 0.0 or dist <= 0.0:
		return 1.0
	
	var abs_mag = app_mag - 5.0 * (log(dist) / log(10.0)) + 5.0
	
	var luminosity_ratio = pow(10.0, 0.4 * (4.83 - abs_mag))
	
	var temp_ratio = 5778.0 / temp
	var solar_radii = sqrt(luminosity_ratio) * pow(temp_ratio, 2.0)
	
	return solar_radii

func lookup_data(data: Array) -> void:
	pass

# MOVEMENT FUNCTIONS

func fly_to_star() -> void:
	var target_index = Globals.current_selected_star_index
	
	var camera = get_viewport().get_camera_3d()
	if not camera:return
	
	
	var target_pos = star_positions[target_index]
	
	
	var direction_to_star = camera.global_position.direction_to(target_pos)
	var stop_distance = 0.5
	var final_camera_pos = target_pos - (direction_to_star * stop_distance)
	
	var target_transform = camera.global_transform.looking_at(target_pos, Vector3.UP)
	var target_rotation = target_transform.basis.get_rotation_quaternion()
	
	var tween = create_tween()
	
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camera, "global_position", final_camera_pos, 2.0)
	tween.tween_property(camera, "quaternion", target_rotation, 2.0)

# CONSOLE FUNCTIONS

func on_change_console_visible() -> void:
	console_panel.visible = !console_panel.visible
	if console_panel.visible:
		console_input.grab_focus()
		console_input.clear()

func on_command_submitted(command_text: String) -> void:
	command_text = command_text.strip_edges().to_lower()
	console_panel.visible = false
	Globals.can_move = true
	
	match command_text.get_slice(" ", 0):
		"tp":
			var target_name = command_text.trim_prefix("tp ").strip_edges()
			execute_tp_command(target_name)
		_:
			print("Unknown comand: ", command_text)

func execute_tp_command(star_name: String) -> void:
	
	for i in range(star_database.size()):
		var data = star_database[i]
		
		var current_star_name = str(data[5].to_lower())
		
		if current_star_name == star_name:
			Globals.current_selected_star_index = i
			fly_to_star()
			return
	print("Error: Could not find star named '", star_name, "'")
