vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    return vec4(1.0 - pixel.r, 1.0 - pixel.g, 1.0 - pixel.b, pixel.a * color.a);
}
