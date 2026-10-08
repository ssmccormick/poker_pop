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

// FINISH effects over the card face (shaders/card_fx.gdshaderinc):
// 0 none · 1 HOLO (rainbow hue shift) · 2 NEGATIVE (value inverted) ·
// 3 FOIL shimmer (riding over the Prism art).
uniform int fx_mode = 0;
uniform float fx_time = 0.0;
// The face, in card pixels (x0, y0, x1, y1): the effect stays inside it,
// so the shadow and the selection rings keep their own colours.
uniform vec4 fx_rect = vec4(-36.0, -52.0, 36.0, 52.0);

#include "res://shaders/card_fx.gdshaderinc"

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
	if (fx_mode > 0
			&& local_pos.x >= fx_rect.x && local_pos.x <= fx_rect.z
			&& local_pos.y >= fx_rect.y && local_pos.y <= fx_rect.w) {
		vec2 uv = (local_pos - fx_rect.xy) / (fx_rect.zw - fx_rect.xy);
		// The lean stands in for the surface normal; a slow drift keeps
		// the light moving on a card nobody is touching.
		vec3 n = vec3(tilt * 3.0 + vec2(sin(fx_time * 0.7), cos(fx_time * 0.5)) * 0.25, 1.0);
		vec3 c = COLOR.rgb;
		if (fx_mode == 1) {
			// HOLO: banded rainbow across the face, sliding as it leans.
			float shine = fx_shine(uv, vec2(0.2, 2.0), 16, n, 1.0) + fx_time * 0.02;
			c = mix(c, fx_holo(c, shine), 0.6);
			c = fx_shimmer(c, shine, n, 1.0, 0.6);
		} else if (fx_mode == 2) {
			// NEGATIVE: the face's light and dark swapped, with a cold
			// glint running over it.
			c = fx_invert_value(c, 1.0);
			float shine = fx_shine(uv, vec2(1.0, 1.0), 32, n, 4.0);
			c = fx_shimmer(c, shine, n, 4.0, 0.8);
		} else if (fx_mode == 3) {
			// FOIL: a light hue lift and tight shimmer bands.
			float shine = fx_shine(uv, vec2(3.0, 9.0), 4, n, 4.0);
			c = mix(c, fx_holo(c, shine), 0.18);
			c = fx_shimmer(c, shine, n, 4.0, 0.45);
		}
		COLOR.rgb = c;
	}
}
