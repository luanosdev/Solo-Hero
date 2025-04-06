// Simple "Outer Glow" Fragment Shader
// Adapts color based on proximity to non-transparent pixels.

extern vec4 glowColor;      // Color and intensity of the glow (alpha controls intensity/spread)
extern float glowRadius;     // How far out to check for glow (in pixels)
uniform sampler2D mainTex; // The texture being drawn (implicit in LÖVE)

// Function to get texture color, handling potential out-of-bounds
vec4 textureSafe(sampler2D tex, vec2 coord) {
    vec2 clampedCoord = clamp(coord, 0.0, 1.0);
    return texture(tex, clampedCoord);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 original_color = textureSafe(mainTex, texture_coords);

    if (original_color.a > 0.01) {
        return original_color;
    }

    float max_neighbor_alpha = 0.0;
    vec2 pixel_size = 1.0 / vec2(textureSize(mainTex, 0));

    int steps = int(max(1.0, glowRadius));
    for (int y = -steps; y <= steps; y++) {
        for (int x = -steps; x <= steps; x++) {
            if (x == 0 && y == 0) continue;

            vec2 offset = vec2(x, y) * pixel_size;
            vec4 neighbor_color = textureSafe(mainTex, texture_coords + offset);
            max_neighbor_alpha = max(max_neighbor_alpha, neighbor_color.a);
        }
    }

    float glow_intensity = max_neighbor_alpha * glowColor.a;
    return vec4(glowColor.rgb, glow_intensity);
} 