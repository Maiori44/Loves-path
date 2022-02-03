uniform float leveltime;
uniform int line;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
    float check = screen_coords.y / line;
    float offset = abs(sin(leveltime));
    if (check == floor(check)) {
        texture_coords.y += texture_coords.x - offset;
        texture_coords.x += offset - 0.5;
    }
    vec4 pixel = Texel(texture, texture_coords);
    return rand(screen_coords) > 0.3 ? pixel * color : vec4(1.0 - pixel.r, 1.0 - pixel.g, 1.0 - pixel.b, pixel.a * color.a);
}