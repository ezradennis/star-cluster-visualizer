extends Node3D

@export var distance_scale: float = 10.0 # Parsecs to godot meters
@export var mesh: SphereMesh


var multimesh_instance: MultiMeshInstance3D

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

# HR diagram lookuup table for b-v
var main_sequence_data: Array[Vector2] = [
	Vector2(-0.3, -4.0),  # Hot blue stars
	Vector2(-0.1, -0.5),
	Vector2(0.0, 1.0),
	Vector2(0.3, 3.0),
	Vector2(0.65, 4.8),   # Sun-like stars (G-type)
	Vector2(1.0, 6.5),
	Vector2(1.4, 9.0),
	Vector2(1.7, 12.0),
	Vector2(2.0, 15.0)    # Cool red dwarfs (M-type)
]

func _ready() -> void:
	setup_renderer()
	
	var star_data = parse_hyg_csv("res://data/hyg_v42.csv")
	
	if star_data.size() > 0:
		generate_stars(star_data)

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
		var v_mag = data[i][0]
		var color_index = data[i][1]
		
		var ra = deg_to_rad(data[i][2])
		var dec = deg_to_rad(data[i][3])
		
		var abs_mag = estimate_abs_mag(color_index)
		var distance = calculate_distance(v_mag, abs_mag)
		var position = spherical_to_cartesian(distance, ra, dec)
		
		var transform = Transform3D(Basis(), position * distance_scale)
		multimesh_instance.multimesh.set_instance_transform(i, transform)
		
		# color shader stuff
		var custom_data = Color(color_index, 0.0, 0.0, 0.0)
		multimesh_instance.multimesh.set_instance_custom_data(i, custom_data)

# MATH HELPERS

func estimate_abs_mag(color: float) -> float:
	
	# if the v-i is out of bounds it just maps to the highest or lower
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

# DATA PARSER

func parse_hyg_csv(file_path: String) -> Array:
	var parsed_data = []
	
	if not FileAccess.file_exists(file_path):
		push_error("Error: Could not find the star database at: " + file_path)
		return parsed_data
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	file.get_csv_line()
	
	var ra_col = 7
	var dec_col = 8
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
		
		var mag = line[mag_col].to_float()
		var dec = line[dec_col].to_float()
		
		var ra_hours = line[ra_col].to_float()
		var ra_degrees = ra_hours * 15.0
		
		parsed_data.append([mag, color_index, ra_degrees, dec])
		
	
	file.close()
	print("Successfully loaded %d stars!" % parsed_data.size())
	return parsed_data
