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
    vec4 pixel = Texel(tex, texture_coords);
    float dist = length(texture_coords - vec2(0.5, 0.5));
    float glow = smoothstep(glowRadius, 0.0, dist);
    return mix(pixel, glowColor, glow * glowColor.a);
} 