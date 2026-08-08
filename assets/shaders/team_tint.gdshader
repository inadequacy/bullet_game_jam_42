shader_type canvas_item;

// Recolours the pug wizard's CLOTHES to its projectile colour, so a caster
// announces what it throws before it throws it.
//
// One sprite, three enemies. The blue, green and red casters are the same
// artwork with a different `team_color` - no separate PNG per colour, so a new
// caster colour costs a scene and nothing else.
//
// WHY A SHADER AND NOT `modulate`: the hat is near-black. Multiplying black by
// a colour leaves black, so plain modulate cannot tint it at all.
//
// The bands below were measured off the actual art, not guessed:
//
//   hat / robe fill   value 0.15 - 0.24, saturation ~0.0 - 0.18
//   ink outlines      value 0.07 - 0.12
//   pug fur           value 0.83+
//
// The gap between the robe fill and the outlines is what makes this safe: the
// fill gets recoloured and the linework stays black, so the character keeps its
// drawn edges instead of turning into a coloured blob.

uniform vec4 team_color : source_color = vec4(0.35, 0.62, 1.0, 1.0);

// Value band the clothes live in. Bottom edge sits above the outlines.
uniform float robe_low_in = 0.140;
uniform float robe_low_full = 0.175;
uniform float robe_high_full = 0.320;
uniform float robe_high_out = 0.400;
// Clothes are grey; anything more colourful than this is skin, fur or wood.
// Kept tight: the pug's dark facial creases are brown rather than grey, and a
// looser gate painted its muzzle in the team colour too.
uniform float robe_sat_full = 0.200;
uniform float robe_sat_out = 0.300;
// Brightness the band is normalised against, so the fabric keeps its folds.
uniform float robe_pivot = 0.230;

// The staff orb is the only strongly blue thing on the sprite, and it reads as
// "the spell this one casts" - so it takes the team colour too.
uniform bool tint_orb = true;
uniform float orb_min_sat = 0.250;

// The node's modulate, captured in vertex() where COLOR is the modulate alone.
// In fragment() COLOR already holds texture * modulate, so folding it in there
// would square the texture and darken the whole sprite.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float value_of(vec3 c) {
	return max(max(c.r, c.g), c.b);
}

float sat_of(vec3 c) {
	float mx = max(max(c.r, c.g), c.b);
	float mn = min(min(c.r, c.g), c.b);
	return mx <= 0.001 ? 0.0 : (mx - mn) / mx;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	float v = value_of(col);
	float s = sat_of(col);

	// Smoothstepped rather than a hard `if`, or the anti-aliased pixels along
	// every edge would flicker in and out of the band and speckle the sprite.
	float robe = smoothstep(robe_low_in, robe_low_full, v)
		* (1.0 - smoothstep(robe_high_full, robe_high_out, v))
		* (1.0 - smoothstep(robe_sat_full, robe_sat_out, s));

	vec3 robed = team_color.rgb * clamp(v / robe_pivot, 0.35, 1.25);
	col = mix(col, robed, robe);

	if (tint_orb) {
		// Blue-dominant and saturated. The orb's white-hot centre is desaturated
		// and so is left alone, which keeps its glow.
		float orb = smoothstep(orb_min_sat, orb_min_sat + 0.12, s)
			* step(col.r * 1.12, col.b) * step(col.g * 1.04, col.b);
		vec3 orbed = mix(team_color.rgb * 0.55, vec3(1.0), pow(v, 2.0));
		col = mix(col, orbed, orb * (1.0 - robe));
	}

	// Folding the modulate back in is what keeps Enemy.flash() and the ice chill
	// tint working on top of the recolour.
	COLOR = vec4(col * v_modulate.rgb, tex.a * v_modulate.a);
}
