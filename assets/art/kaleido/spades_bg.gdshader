shader_type canvas_item;
// Poker Pop: Spades background - six-fold kaleidoscope of spades, cool gunmetal, pewter and midnight with a brass glint.
// Put on a full-screen ColorRect (or TextureRect) behind the board. Works in GL Compatibility and on mobile.

uniform sampler2D suits_solid : repeat_enable, filter_linear_mipmap;    // spades_tile_solid.png
uniform sampler2D suits_outline : repeat_enable, filter_linear_mipmap;  // spades_tile_outline.png

uniform int segments : hint_range(3, 16) = 6;          // mirror slices (8 = classic kaleidoscope)
uniform float zoom = 0.8;                               // tiles across the half-screen
uniform float spin_speed = 0.025;                       // radians / sec
uniform float drift_speed = 0.035;                      // tile scroll / sec (near layer)
uniform float color_speed = 0.045;                      // palette cycles / sec
uniform float intensity : hint_range(0.0, 1.0) = 0.75;  // keep low so the board stays readable
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float t_extra = 0.0;                            // pushed forward by a scoring lurch

uniform vec4 bg : source_color = vec4(0.082, 0.063, 0.047, 1.0);      // coal #15100C
uniform vec4 col_a : source_color = vec4(0.290, 0.353, 0.416, 1.0);   // gunmetal #4A5A6A
uniform vec4 col_b : source_color = vec4(0.690, 0.541, 0.290, 1.0);   // brass #B08A4A
uniform vec4 col_c : source_color = vec4(0.541, 0.561, 0.588, 1.0);   // pewter #8A8F96
uniform vec4 col_d : source_color = vec4(0.180, 0.227, 0.314, 1.0);   // midnight #2E3A50

vec3 palette(float h) {
	h = fract(h) * 4.0;
	float f = smoothstep(0.0, 1.0, fract(h));
	int i = int(floor(h));
	vec3 c0 = i == 0 ? col_a.rgb : i == 1 ? col_b.rgb : i == 2 ? col_c.rgb : col_d.rgb;
	vec3 c1 = i == 0 ? col_b.rgb : i == 1 ? col_c.rgb : i == 2 ? col_d.rgb : col_a.rgb;
	return mix(c0, c1, f);
}

void fragment() {
	float t = TIME + t_extra;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x) + t * spin_speed;
	float seg = 6.2831853 / float(segments);
	a = mod(a, seg);
	a = abs(a - seg * 0.5);                      // mirror inside each slice
	vec2 q = vec2(cos(a), sin(a)) * r;

	// two layers at different scale + drift = parallax depth inside the mirror
	vec2 uv_far  = q * zoom * 1.7 + vec2(t * drift_speed * 0.5, -t * drift_speed * 0.3);
	vec2 uv_near = q * zoom       + vec2(-t * drift_speed, t * drift_speed * 0.6);
	float far  = texture(suits_solid, uv_far).a;
	float near = texture(suits_outline, uv_near).a;

	float h = t * color_speed + r * 0.45;
	vec3 c_far  = palette(h);
	vec3 c_near = palette(h + 0.37);

	vec3 col = bg.rgb;
	col = mix(col, c_far, far * intensity * 0.85);
	col = mix(col, mix(c_near, vec3(0.90, 0.84, 0.69), 0.25), near * intensity);
	col *= 1.0 - smoothstep(0.25, 1.05, r) * vignette;
	// faint centre bloom
	col += palette(h + 0.2) * 0.06 * (1.0 - smoothstep(0.0, 0.45, r));
	COLOR = vec4(col, 1.0);
}
