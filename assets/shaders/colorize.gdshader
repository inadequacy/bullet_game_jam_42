shader_type canvas_item;

// Recolours a sprite to whatever its `modulate` is, IGNORING the source hue.
//
// For the enemy projectiles. The art is a purple orb, and the game's whole
// combat vocabulary is blue / green / red - plain modulate multiplies, so
// tinting a purple orb green gives mud, because purple has almost no green in
// it to keep. This throws the hue away and rebuilds it from brightness, so
// every kind comes out clean.
//
// enemy_projectile.gd already sets modulate per kind, including the darkened
// red it uses when a dash severs a lock, so this needs no per-kind wiring - it
// just makes the colour that file already chose come out right.
//
// READING THE TINT IS THE FIDDLY BIT. In fragment(), COLOR arrives already
// holding texture * modulate - NOT the modulate on its own - so multiplying it
// by anything derived from the texture squares the texture. An earlier version
// did exactly that and rendered identically to plain modulate, because the tint
// was scaled straight back down by the dark orb it was meant to replace.
//
// In vertex(), COLOR is the modulate alone, so it is captured there and handed
// to fragment() through a varying. (`MODULATE` is not available as a fragment
// built-in in this Godot version - it fails to compile.)

// How dark the dimmest part of the sprite is allowed to get, as a fraction of
// the tint, and how far the brightest part may overshoot it.
const float SHADE_FLOOR = 0.55;
const float SHADE_CEIL = 1.25;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = max(max(tex.r, tex.g), tex.b);

	// Never darker than SHADE_FLOOR. The source art is a dark vortex - most of
	// its body is nearly black - so scaling the tint by brightness alone left
	// blue and green as dark blobs with a thin coloured rim. In a bullet hell
	// the colour IS the instruction, so the whole silhouette has to carry it,
	// and the swirl detail rides on top as brightness instead of being the only
	// thing that is coloured.
	float shade = mix(SHADE_FLOOR, SHADE_CEIL, pow(lum, 0.65));
	vec3 col = v_modulate.rgb * shade;
	// The hot core still goes white, so the orb reads as a light source rather
	// than a flat disc.
	col = mix(col, vec3(1.0), pow(lum, 5.0) * 0.9);

	COLOR = vec4(col, tex.a * v_modulate.a);
}
