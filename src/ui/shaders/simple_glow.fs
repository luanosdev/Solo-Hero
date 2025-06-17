// "Outer Glow" Fragment Shader
// Based on code by grump on the LÖVE forums.
// This shader should be used in a first pass to draw the glow,
// then the original image should be drawn on top without the shader.

// The color of the glow is set by love.graphics.setColor(r,g,b,a).
// The alpha of the color will affect the final alpha of the glow.
extern float glowSize; // how many pixels to sample around the current pixel.
extern float smoothness; // affects the falloff of the glow. 1.0 is a good start.

vec4 effect(vec4 v_color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    float alpha_sum = 0.0;
    vec2 pixel_size = 1.0 / love_texture_size; // LÖVE 11.0+ built-in

    // Sample surrounding pixels
    for(float y = -glowSize; y <= glowSize; ++y) {
        for(float x = -glowSize; x <= glowSize; ++x) {
            alpha_sum += texture(tex, texture_coords + vec2(x * pixel_size.x, y * pixel_size.y)).a;
        }
    }

    // The original formula from the forum post: `a / (2 * size * smoothness + 1)`.
    // It seems to work well for controlling the spread.
    float final_alpha = min(1.0, alpha_sum / (2.0 * glowSize * smoothness + 1.0) );

    // The final color is the color set by love.graphics.setColor, but with the new alpha.
    return vec4(v_color.rgb, v_color.a * final_alpha);
} 