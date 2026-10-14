shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    float cloud = texture(cloud_map, UV).r;
    ALBEDO = vec3(0.94, 0.97, 1.0);
    ALPHA = smoothstep(0.08, 0.9, cloud) * 0.94;
    ROUGHNESS = 1.0;
    SPECULAR = 0.05;
}
