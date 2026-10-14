shader_type sky;
uniform sampler2D space_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction;
void sky() {
    float angle = acos(clamp(dot(normalize(EYEDIR), normalize(sun_direction)), -1.0, 1.0));
    vec3 stars = texture(space_map, SKY_COORDS + vec2(0.12, 0.0)).rgb * 0.32;
    // 0.53-degree solar diameter; only the photographic halo is enlarged.
    float disc = 1.0 - smoothstep(0.00455*3.0, 0.00475*3.0, angle);
    float halo = 1.0 * exp(-angle * 55.0) + 0.018 * exp(-angle * 14.0);
    stars *= 1.0 - 0.92 * exp(-angle * angle / 0.08);
    COLOR = stars + vec3(1.0) * disc * 8.0 + vec3(1.0, 0.96, 0.86) * halo;
}