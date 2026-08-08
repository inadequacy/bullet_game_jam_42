shader_type canvas_item;

// Inverts the texture's colors. Placeholder art: enemies are the Godot icon
// rendered as the player's negative, so the two read apart at a glance.
//
// On entry COLOR holds the node's modulate; multiplying it back in keeps
// Enemy.flash() working on top of the inversion.

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 inverted = vec3(1.0) - tex.rgb;
	COLOR = vec4(inverted * COLOR.rgb, tex.a * COLOR.a);
}
