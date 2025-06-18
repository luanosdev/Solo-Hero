// Este shader transforma qualquer pixel não transparente de uma textura em uma cor sólida,
// mantendo a transparência original. É perfeito para criar ícones de silhueta.

// A cor base é passada de love.graphics.setColor (neste caso, será branco).
extern vec4 Color;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Pega a cor do pixel da textura original.
    vec4 tex_color = Texel(texture, texture_coords);

    // Se o pixel não for totalmente transparente (com uma pequena margem),
    // desenha-o com a cor fornecida (branca) e o alfa da textura.
    if (tex_color.a > 0.05) {
        // Multiplicamos o alfa da textura pelo alfa da cor definida para permitir fade out.
        return vec4(Color.rgb, tex_color.a * Color.a);
    }

    // Se for transparente, retorna transparente.
    return vec4(0.0, 0.0, 0.0, 0.0);
} 