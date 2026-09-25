shader_type spatial;
// Bagliore sul bordo degli oggetti a terra: un guscio appena più grande della
// mesh, disegnato in additivo, che brilla solo sulla silhouette (fresnel).
// È illuminato dalle luci della scena: nel buio totale non si vede, così gli
// oggetti si trovano solo avvicinando la torcia (pilastro "la luce è vita").
render_mode blend_add, depth_draw_never, cull_back, specular_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.45);
uniform float strength = 2.5;      // intensità del bagliore sotto la luce
uniform float grow = 0.012;        // di quanto il guscio sporge dalla mesh (m)
uniform float rim_power = 2.5;     // più alto = bordo più sottile
uniform float pulse_speed = 2.0;   // pulsazione lenta, per attirare l'occhio
uniform float pulse_amount = 0.3;
// Vicinanza: entro near_radius il bordo brilla anche al buio, svanendo fino a
// near_fade metri. La camera è in prima persona, quindi = il giocatore.
uniform float near_radius = 1.5;
uniform float near_fade = 2.5;
uniform float near_strength = 0.6;

float rim_amount(vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), rim_power);
}

float pulse_factor(float time) {
	return 1.0 - pulse_amount * (0.5 + 0.5 * sin(time * pulse_speed));
}

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = glow_color;
	float dist = distance(CAMERA_POSITION_WORLD, NODE_POSITION_WORLD);
	float near = 1.0 - smoothstep(near_radius, near_fade, dist);
	// EMISSION non dipende dalle luci: si vede anche nel buio.
	EMISSION = glow_color * rim_amount(NORMAL, VIEW) * near * near_strength
			* pulse_factor(TIME);
}

void light() {
	// LIGHT_COLOR include già un fattore PI: lo togliamo.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * rim_amount(NORMAL, VIEW)
			* strength * pulse_factor(TIME);
}
