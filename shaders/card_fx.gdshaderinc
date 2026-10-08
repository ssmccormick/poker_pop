// Card finish effects, ported from the Binbun CardFX pack
// (BinbunVFX/card_effects/src/shader/util): the HSV helpers, the
// stepped "shine" band, the holo hue shift and the shimmer. The pack's
// spatial shaders read the mesh NORMAL; on our 2D cards the hover tilt
// stands in for it, and the pack's pixel snap is dropped (the card art
// is painted, not pixel art).

vec3 fx_rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 fx_hsv2rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

// Flips brightness, keeps hue: whites go dark, darks go light.
vec3 fx_invert_value(vec3 c, float amount) {
	vec3 hsv = fx_rgb2hsv(c);
	hsv.z = mix(hsv.z, 1.0 - hsv.z, amount);
	return fx_hsv2rgb(hsv);
}

// The diagonal band the light sits on: where on the card (uv · size),
// nudged by the lean of the card, quantized into `steps` bands.
float fx_shine(vec2 uv, vec2 size, int steps, vec3 normal, float view_affect) {
	float shine = (dot(uv, size) + (normal.y - normal.x) * (view_affect * 0.1)) * 0.3;
	if (steps > 0) {
		shine = floor(shine * float(steps)) / float(steps);
	}
	return shine;
}

vec3 fx_holo(vec3 rgb, float shine) {
	vec3 hsv = fx_rgb2hsv(rgb);
	hsv.x += shine;
	return fx_hsv2rgb(hsv);
}

vec3 fx_shimmer(vec3 rgb, float shine, vec3 normal, float view_affect, float strength) {
	float s = 1.0 + max(sin(shine * 16.0 + (normal.y - normal.x) * view_affect), 0.0) * strength;
	vec3 hsv = fx_rgb2hsv(rgb);
	hsv.z *= s;
	return fx_hsv2rgb(hsv);
}
