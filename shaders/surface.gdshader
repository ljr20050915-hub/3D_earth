shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D day_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D night_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ocean_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sun_direction = vec3(-0.7, 0.3, 0.65);
uniform float cloud_offset = 0.0;
varying vec3 world_normal;
void vertex() { world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
    float ocean = texture(ocean_map, UV).r;
    float daylight = dot(normalize(world_normal), normalize(sun_direction));
    // Cloud shadows are subtle at the planetary scale.
    float cloud = texture(cloud_map, UV + vec2(cloud_offset, 0.0)).r;
    ALBEDO = texture(day_map, UV).rgb * (1.0 - cloud * 0.16);
    ROUGHNESS = mix(0.88, 0.27, ocean);
    SPECULAR = mix(0.15, 0.55, ocean);
    METALLIC = 0.0;
    vec3 night = texture(night_map, UV).rgb;
    float night_luminance = dot(night, vec3(0.2126, 0.7152, 0.0722));
    vec3 city_lights = night * smoothstep(0.003, 0.025, night_luminance);
    EMISSION = city_lights * (1.0 - smoothstep(-0.10, 0.0, daylight)) * 0.65 * (1.0 - cloud * 0.65);
}
