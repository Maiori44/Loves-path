uniform vec2 pos;
uniform float scale;
uniform float light;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    float dist = min(distance(screen_coords.xy, pos.xy), 160 * scale);
    vec4 result = mix(pixel, vec4(0, 0, 0, pixel.a), dist / (light * scale));
    result.a *= color.a;
    return result;
}
