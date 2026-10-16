shader_type canvas_item;
// Poker Pop: suit parallax background (Diagonal).
// mirror bands on a 45° angle, layers drift up-right along them. Same suit tiles and palette as kaleido_suits.gdshader.
// Put on a full-screen ColorRect behind the board. GL Compatibility + mobile safe.

uniform sampler2D suits_solid : repeat_enable, filter_linear_mipmap;    // suits_tile_solid.png
uniform sampler2D suits_outline : repeat_enable, filter_linear_mipmap;  // suits_tile_outline.png

uniform float band = 0.5;                                // height of one mirror band (screen heights). 0 = no mirroring
uniform float speed = 0.06;                              // near-layer scroll speed (screen heights / sec)
uniform float zoom = 0.8;                                // near-layer suit size (bigger = smaller suits)
uniform float color_speed = 0.045;                       // palette cycles / sec
uniform float color_wave = 0.25;                         // how much the colour shifts along the scroll axis
uniform float intensity : hint_range(0.0, 1.0) = 0.75;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float t_extra = 0.0;                            // pushed forward by a scoring lurch

uniform vec4 bg : source_color = vec4(0.082, 0.063, 0.047, 1.0);      // coal #15100C
uniform vec4 col_a : source_color = vec4(0.486, 0.122, 0.086, 1.0);   // oxblood #7C1F16
uniform vec4 col_b : source_color = vec4(0.690, 0.541, 0.290, 1.0);   // brass #B08A4A
uniform vec4 col_c : source_color = vec4(0.247, 0.420, 0.388, 1.0);   // patina teal #3F6B63
uniform vec4 col_d : source_color = vec4(0.373, 0.247, 0.471, 1.0);   // plum #5F3F78

vec3 palette(float h) {
	h = fract(h) * 4.0;
	float f = smoothstep(0.0, 1.0, fract(h));
	int i = int(floor(h));
	vec3 c0 = i == 0 ? col_a.rgb : i == 1 ? col_b.rgb : i == 2 ? col_c.rgb : col_d.rgb;
	vec3 c1 = i == 0 ? col_b.rgb : i == 1 ? col_c.rgb : i == 2 ? col_d.rgb : col_a.rgb;
	return mix(c0, c1, f);
}

vec2 rot(vec2 v, float a) { float c = cos(a), s = sin(a); return vec2(c * v.x - s * v.y, s * v.x + c * v.y); }

float fold_band(float x) {
	if (band <= 0.0) return x;
	return abs(mod(x + band * 0.5, band * 2.0) - band);   // mirrored, repeating bands
}

void fragment() {
	float t = TIME + t_extra;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
	vec2 d = rot(p, 0.785398); vec2 q = vec2(d.x, fold_band(d.y));
	vec2 dir = vec2(1.0, 0.0);

	// three layers: far (small, slow), mid, near (outlined, fastest) = parallax
	float far  = texture(suits_solid,   q * zoom * 2.2 - dir * t * speed * 0.35 + vec2(0.37, 0.11)).a;
	float mid  = texture(suits_solid,   q * zoom * 1.4 - dir * t * speed * 0.65 + vec2(0.71, 0.53)).a;
	float near = texture(suits_outline, q * zoom       - dir * t * speed).a;

	float h = t * color_speed + ((p.x + p.y) * 0.7071) * color_wave;
	vec3 col = bg.rgb;
	col = mix(col, palette(h + 0.55), far * intensity * 0.3);
	col = mix(col, palette(h + 0.2), mid * intensity * 0.55);
	col = mix(col, mix(palette(h), vec3(0.90, 0.84, 0.69), 0.25), near * intensity);
	float r = length(p * vec2(0.8, 1.0));
	col *= 1.0 - smoothstep(0.35, 1.0, r) * vignette;
	COLOR = vec4(col, 1.0);
}
