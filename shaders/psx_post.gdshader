shader_type canvas_item;
// Filtro retro stile PlayStation 1: bassa risoluzione, pochi colori con retino
// ordinato 4x4 (come la PS1), grana animata e vignettatura.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float target_height = 240.0;   // righe verticali "retro" (PS1: 240)
uniform float color_levels = 24.0;     // livelli per canale (PS1: 32)
uniform float dither_strength = 1.0;
uniform float grain = 0.04;
uniform float grain_fps = 12.0;        // la grana cambia a scatti, come un video vecchio
uniform float vignette = 0.45;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	// Pixel interi: a 720p ogni pixel retro è 3x3, a 1080p 5x5.
	float pixel_size = max(1.0, floor(screen_size.y / target_height + 0.5));
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;

	float n = hash(cell + floor(TIME * grain_fps) * 17.0);
	c += (n - 0.5) * grain;

	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.0;

	int i = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	float threshold = BAYER[i] / 16.0 - 0.5;
	float steps = color_levels - 1.0;
	c = floor(c * steps + 0.5 + threshold * dither_strength) / steps;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
