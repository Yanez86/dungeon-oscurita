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

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = glow_color;
}

void light() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 1.0 - pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	// LIGHT_COLOR include già un fattore PI: lo togliamo.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * rim * strength * pulse;
}
