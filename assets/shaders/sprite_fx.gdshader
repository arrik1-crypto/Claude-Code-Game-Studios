shader_type canvas_item;
render_mode unshaded;

// Shared effects shader for every character sprite.
//
// Replaces three things that were previously faked with `modulate`:
//
//   * HIT FLASH — modulating to white washes the sprite towards white but keeps
//     its shading, so a dark enemy barely reads as hit. Mixing to a flat colour
//     in the fragment stage gives a true silhouette flash.
//   * DEATH DISSOLVE — a threshold burn against procedural noise, with a bright
//     rim at the burn edge. No noise texture asset is required.
//   * MIST FORM — the Mist Dash. Alpha falls off with a vertical gradient and
//     the sprite is tinted, so the character reads as dissipating upward rather
//     than simply going transparent.
//
// `render_mode unshaded` keeps characters out of the 2D light pass. They are
// lit by the ambient CanvasModulate and their own lantern instead, which stops
// a torch from blowing out a sprite it happens to stand next to.

// --- Hit flash --------------------------------------------------------------
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- Death dissolve ---------------------------------------------------------
// 0 is untouched, 1 is fully burned away.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float dissolve_edge_width : hint_range(0.0, 0.3) = 0.08;
uniform float dissolve_noise_scale = 28.0;

// --- Mist form --------------------------------------------------------------
uniform float mist_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 mist_color : source_color = vec4(0.62, 0.86, 1.0, 1.0);

// Cheap value noise. A texture would look better but costs an asset, a sampler
// and a binding per sprite; at 80x80 and only during a death animation this is
// indistinguishable.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Smoothstep the interpolant so the noise has no visible grid seams.
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// --- Mist form: tint, then fade from the feet upward.
	if (mist_amount > 0.0) {
		tex.rgb = mix(tex.rgb, mist_color.rgb, mist_amount * 0.75);
		float vertical = smoothstep(0.0, 1.0, 1.0 - UV.y);
		tex.a *= mix(1.0, 0.35 + vertical * 0.4, mist_amount);
	}

	// --- Death dissolve: burn away below a noise threshold, with a hot rim.
	if (dissolve > 0.0) {
		float n = value_noise(UV * dissolve_noise_scale);
		// Bias the burn so it starts at the top of the sprite and eats downward.
		n = n * 0.75 + (1.0 - UV.y) * 0.25;
		if (n < dissolve) {
			tex.a = 0.0;
		} else if (n < dissolve + dissolve_edge_width) {
			tex.rgb = dissolve_edge_color.rgb;
			tex.a *= dissolve_edge_color.a;
		}
	}

	// --- Hit flash last, so a flashing sprite still respects the dissolve mask.
	tex.rgb = mix(tex.rgb, flash_color.rgb, flash_amount);

	COLOR = tex;
}
