shader_type canvas_item;

// Nudges Max's CLOTHES - hat, brim and hoodie - a little way from blue toward
// purple, without repainting the art.
//
// WHY: purple is Max's colour. His shots are purple (see player_projectile.gd),
// and his hat and hoodie were the same royal blue as the blue caster's robe and
// its shots. Leaning them toward violet ties the wizard to his own magic and
// takes him out of the enemy palette. Deliberately a nudge and not a repaint -
// the art is a blue-hooded corgi and should still look like one.
//
// WHY A HUE ROTATION AND NOT `modulate`: modulate multiplies. Multiplying a
// blue by a purple mostly just darkens it, and it would drag the fur, the
// glasses and the hat's stars along with it. Rotating hue leaves value and
// saturation where the artist put them, so the fabric keeps its folds.
//
// The band below is measured off the actual art, not guessed:
//
//   hat / hoodie   hue 0.587 - 0.592, saturation ~0.68
//   fur            hue ~0.09 (orange)
//   hat stars      hue ~0.13 (yellow)
//   glasses, ink   saturation ~0.0
//
// So a hue gate around 0.59 plus a saturation floor catches the clothes and
// nothing else: the only other blue on the sprite is its white highlights, and
// those are far below the saturation floor.

// How far around the wheel to turn the clothes, in turns. 0.06 lands blue 0.59
// on ~0.65 - indigo. Past about 0.09 it stops reading as "blue hoodie".
uniform float hue_shift : hint_range(0.0, 0.2) = 0.06;
// Violet reads weaker than blue at the same saturation, so a touch of it back.
uniform float sat_boost : hint_range(1.0, 1.5) = 1.06;

// Hue band the clothes live in, with smoothstepped edges - a hard `if` would
// speckle every anti-aliased pixel along the hood's outline.
uniform float hue_low_in = 0.500;
uniform float hue_low_full = 0.545;
uniform float hue_high_full = 0.640;
uniform float hue_high_out = 0.690;
// Below this the pixel is white, grey or ink rather than fabric.
uniform float sat_min_in = 0.180;
uniform float sat_min_full = 0.300;

// The node's modulate, captured in vertex() where COLOR is the modulate alone.
// In fragment() COLOR already holds texture * modulate, so folding it in there
// would square the texture and darken the whole sprite.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(tex.rgb);

	float clothes = smoothstep(hue_low_in, hue_low_full, hsv.x)
		* (1.0 - smoothstep(hue_high_full, hue_high_out, hsv.x))
		* smoothstep(sat_min_in, sat_min_full, hsv.y);

	hsv.x = fract(hsv.x + hue_shift * clothes);
	hsv.y = clamp(hsv.y * mix(1.0, sat_boost, clothes), 0.0, 1.0);

	// Folding the modulate back in is what keeps the dash tint and the hurt
	// flash in movement.gd working on top of the recolour.
	COLOR = vec4(hsv_to_rgb(hsv) * v_modulate.rgb, tex.a * v_modulate.a);
}
