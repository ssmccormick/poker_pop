shader_type canvas_item;

// Overlays a repeating grayscale pattern (hatching / dither / crosshatch,
// borrowed from the UltimateToon pack's pattern textures) onto whatever the
// card draws. Dark parts of the pattern darken the card, giving the face a
// printed / sketched material feel.
//
// It also carries the hover TILT: the card turns in 3D toward the cursor and
// is projected with real perspective, so the side under the pointer recedes.
// The pattern samples the untilted position, so it stays on the card surface.

uniform sampler2D pattern_tex : repeat_enable, filter_linear;
uniform float tile_px = 200.0;  // card-pixels covered by one texture tile
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.3;
// Radians: x turns about the card's vertical axis, y about its horizontal.
uniform vec2 tilt = vec2(0.0);
// Eye distance in card pixels; smaller means stronger perspective.
uniform float focal = 320.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
	if (tilt != vec2(0.0)) {
		float cy = cos(tilt.x);
		float sy = sin(tilt.x);
		float cx = cos(tilt.y);
		float sx = sin(tilt.y);
		// Turn about the vertical axis, then the horizontal one; +z points
		// away from the viewer, so the cursor's side sinks back.
		float x1 = VERTEX.x * cy;
		float z1 = VERTEX.x * sy;
		float y2 = VERTEX.y * cx - z1 * sx;
		float z2 = VERTEX.y * sx + z1 * cx;
		VERTEX = vec2(x1, y2) * (focal / (focal + z2));
	}
}

void fragment() {
	float p = texture(pattern_tex, local_pos / tile_px).r;
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * p, pattern_strength);
}
