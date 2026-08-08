shader_type canvas_item;

// Overlays a repeating grayscale pattern (hatching / dither / crosshatch,
// borrowed from the UltimateToon pack's pattern textures) onto whatever the
// card draws. Dark parts of the pattern darken the card, giving the face a
// printed / sketched material feel.

uniform sampler2D pattern_tex : repeat_enable, filter_linear;
uniform float tile_px = 200.0;  // card-pixels covered by one texture tile
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.3;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float p = texture(pattern_tex, local_pos / tile_px).r;
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * p, pattern_strength);
}
