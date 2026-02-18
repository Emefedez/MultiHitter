shader_type spatial;

render_mode unshaded, fog_disabled;

uniform sampler2D screen_texture: hint_screen_texture;
uniform float pixel_size: hint_range(0.0, 20.0, 1.0);
uniform float Levels : hint_range(0.0, 100.0, 1.0);


void vertex() {
	// Called for every vertex the material is visible on.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 tex_size = vec2(textureSize(screen_texture,0));
	vec2 pixel_count = tex_size / (pixel_size*2.0);
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	vec4 color = texture(screen_texture, pixelated_uv);

	
	float grayscale = max(color.r, max(color.g, color.b)) ;

	float lower = floor(grayscale * Levels) / Levels;
	float higher = ceil(grayscale * Levels) / Levels;

	float lower_diff = abs(lower - grayscale);
	float higher_diff = abs(higher - grayscale);

	float level = lower_diff < higher_diff ? lower : higher;
	float adjustment = level/grayscale;

	color.rgb *= adjustment;

	ALBEDO = color.rgb;
	ALPHA = color.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
