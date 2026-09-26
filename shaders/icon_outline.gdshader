shader_type canvas_item;
// Bordo di un pixel attorno alle icone degli oggetti (ItemSlot): lo stesso colore caldo
// dell'aura degli oggetti a terra, così un oggetto scuro si legge anche sul fondo scuro.

uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.45, 0.45);

varying vec4 tint;  // modulate del nodo: serve per rendere gli slot più o meno visibili

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		// Pixel vuoto: diventa bordo se tocca un pixel dell'oggetto.
		float near = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				near = max(near, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
			}
		}
		c = near > 0.5 ? outline_color : vec4(0.0);
	}
	COLOR = c * tint;
}
