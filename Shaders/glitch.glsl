uniform float leveltime;
uniform float intensity;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
    float offset = rand(vec2(screen_coords.x + leveltime, screen_coords.y + leveltime));
    bool notinvert = offset > intensity;
    if (notinvert && rand(screen_coords) > 0.7) {
        texture_coords.y -= offset;
        texture_coords.x += offset;
    }
    vec4 pixel = Texel(texture, texture_coords);
    return notinvert ? pixel * color : vec4(1.0 - pixel.r, 1.0 - pixel.g, 1.0 - pixel.b, pixel.a * color.a);
}