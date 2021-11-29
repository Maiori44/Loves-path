uniform number darkness;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 pixel = Texel(texture, texture_coords);
	number average = (pixel.r + pixel.b + pixel.g) / darkness;
	pixel.rgb = min(pixel.rgb, average);
	return pixel * color;
}