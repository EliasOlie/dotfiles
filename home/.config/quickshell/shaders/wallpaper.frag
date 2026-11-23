#version 440
// Wallpaper eliasolie na GPU: grade de pontos a cada `cellStep` px sobre o void.
// Cada ponto tem uma intensidade t (0..1) que vira tamanho e cor lima:
//   brilho do mouse · onda do clique · pulso da música · pontos que acendem
//   aleatoriamente · modo descanso (pontos formam a hora, textura `matrix`).
// Compilar (gera o .qsb que o Quickshell usa):
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o wallpaper.frag.qsb wallpaper.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float cellStep;     // distância entre pontos (40)
    float glowAmount;   // 0..1 brilho do mouse
    float glowRadius;   // alcance do brilho
    vec2 res;           // tamanho da tela
    vec2 mouse;         // posição do brilho
    vec2 ripple;        // centro da onda
    float rippleR;      // raio atual (<0 = sem onda)
    float rippleMax;
    float pulse;        // 0..1 nível da música
    float time;         // segundos (só avança com o desktop à mostra)
    float twinkle;      // 0/1 pontos acendendo aleatoriamente
    float rest;         // 0..1 modo descanso
    vec2 grid;          // colunas, linhas (tamanho da textura matrix)
};
layout(binding = 1) uniform sampler2D matrix;

const vec3 VOID = vec3(0.0196, 0.0196, 0.0196);   // #050505
const vec3 BASE = vec3(0.1333, 0.1333, 0.1216);   // #22221F (ponto apagado)
const vec3 LIME = vec3(0.7843, 0.9412, 0.1922);   // #C8F031

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 cell = floor((p + 0.5 * cellStep) / cellStep);   // ponto mais próximo
    vec2 c = cell * cellStep + 0.5;                        // centro do pixel do ponto

    float t = 0.0;

    // brilho em volta do mouse
    if (glowAmount > 0.001) {
        float d = distance(c, mouse);
        if (d < glowRadius) t = max(t, pow(1.0 - d / glowRadius, 1.6) * glowAmount);
    }
    // onda do clique: anel de ~44 px que cresce e apaga
    if (rippleR >= 0.0) {
        float k = 1.0 - abs(distance(c, ripple) - rippleR) / 44.0;
        if (k > 0.0) t = max(t, k * (1.0 - rippleR / rippleMax));
    }
    // pulso da música: mais forte no centro
    if (pulse > 0.001) {
        vec2 ctr = res * 0.5;
        float pr = pow(max(0.0, 1.0 - distance(c, ctr) / length(ctr)), 1.8);
        t = max(t, pulse * 0.6 * (0.08 + 0.9 * pr));
    }
    // pontos que acendem aleatoriamente: ~1% da grade por ciclo de 7 s, cada um
    // no seu momento; sobe rápido e apaga devagar
    if (twinkle > 0.5) {
        float h = hash(cell);
        float cyc = floor(time / 7.0 + h);
        if (hash(cell + cyc * 17.13) > 0.99) {
            float ph = fract(time / 7.0 + h);
            t = max(t, smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.08, 0.55, ph)) * 0.85);
        }
    }
    // modo descanso: os pontos desenham a hora (textura com 1 pixel por ponto);
    // esses pontos crescem bem mais (até ~8 px) para a hora ler de longe
    float m = 0.0;
    if (rest > 0.001) {
        m = texture(matrix, (cell + 0.5) / grid).r * rest;
        t = max(t, m);
    }

    // tamanho do ponto cresce com a intensidade (1 px apagado, até 3 px aceso)
    float half_ = 0.5 + t + m * 3.0;
    vec2 q = abs(p - c);
    float inside = step(q.x, half_) * step(q.y, half_);

    vec3 lit = mix(VOID, LIME, 0.15 + 0.85 * t);
    vec3 dotc = t > 0.001 ? lit : BASE;
    fragColor = vec4(mix(VOID, dotc, inside), 1.0) * qt_Opacity;
}
