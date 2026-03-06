shader_type spatial;

render_mode unshaded; 


uniform sampler2D color_gradient : source_color, repeat_disable;

uniform float min_vi = -0.4;
uniform float max_vi = 3.0;
uniform float emission_energy = 2.0;

varying float v_i_val;

void vertex() {
	v_i_val = INSTANCE_CUSTOM.r;
}

void fragment() {
	float uv_x = clamp((v_i_val - min_vi) / (max_vi - min_vi), 0.0, 1.0);
	
	vec3 star_color = texture(color_gradient, vec2(uv_x, 0.5)).rgb;
	
	ALBEDO = star_color;
	
	EMISSION = star_color * emission_energy;
}
