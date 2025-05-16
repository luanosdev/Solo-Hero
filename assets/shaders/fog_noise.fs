// fog_noise.fs
// Uniforms (valores passados pelo Lua)
extern number time = 0.0;
extern number noiseScale = 5.0;
extern number noiseSpeed = 0.1;
extern vec4 fogColor = vec4(1.0, 1.0, 1.0, 1.0); // Cor base da névoa (branco)
extern number densityPower = 2.0; // Controla o contraste/densidade (maior = mais denso)

// Função de hash simples para gerar pseudo-ruído
// (Crédito: Várias fontes online, variações comuns)
float hash(vec2 p) {
    p = fract(p * vec2(123.45, 678.90));
    p += dot(p, p + 45.6);
    return fract(p.x * p.y);
}

// Função de ruído simples baseada em interpolação de hash
float simpleNoise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    // Interpolação suave (smoothstep)
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i + vec2(0.0, 0.0));
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Função principal do Fragment Shader
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Usa screen_coords normalizadas (0-1) e escala pelo noiseScale
    vec2 uv = screen_coords / love_ScreenSize.xy * noiseScale;
    
    // Adiciona movimento baseado no tempo
    uv.x += time * noiseSpeed;
    
    // Calcula o valor do ruído
    float noiseValue = simpleNoise(uv);
    
    // Mapeia o ruído para alfa (0 a 1) e aplica a densidade
    // Usamos pow para controlar a "nitidez" das nuvens
    float alpha = pow(noiseValue, densityPower);
    
    // Retorna a cor da névoa com o alfa calculado
    // Multiplica pelo alfa da cor original (se houver)
    return fogColor * vec4(1.0, 1.0, 1.0, alpha) * color.a;
} 