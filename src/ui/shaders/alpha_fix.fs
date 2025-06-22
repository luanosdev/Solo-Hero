// extern -> variável que vem do código Lua
// number -> tipo da variável (pode ser float, int, etc.)
extern number threshold;

// A função que é executada para cada pixel
// color: a cor definida por love.graphics.setColor
// texture: a imagem/canvas que está sendo desenhada
// texture_coords: a coordenada (em UV) do pixel atual na textura
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Pega a cor do pixel da nossa textura (o atlas)
    vec4 pixel = Texel(texture, texture_coords);

    // Se o canal alpha (transparência) do pixel for menor que nosso limiar...
    if (pixel.a < threshold) {
        // ...torne-o completamente transparente, "apagando-o".
        pixel.a = 0.0;
    } else {
        // ...caso contrário, torne-o completamente opaco. Isso cria uma borda "dura".
        pixel.a = 1.0;
    }

    // Multiplica a cor do pixel pela cor global (útil para tinting) e retorna
    return pixel * color;
}