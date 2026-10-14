shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 sun_uv = vec2(-2.0);
uniform vec2 resolution = vec2(1920.0, 1080.0);
uniform float visibility = 0.0;
uniform float angular_pixel_radius = 6.0;
uniform vec3 camera_position;
uniform mat3 camera_basis;
uniform float tan_half_fov = 0.383864;
void fragment() {
    vec2 p = (UV - sun_uv) * resolution;
    float unit = max(resolution.y / 1080.0, 0.5);
    p /= unit;
    float r = length(p);
    float a = atan(p.y, p.x);
    float core_radius = 1.0*max(angular_pixel_radius / unit, 1.0);
    float core = 5.0 * exp(-pow(r / (core_radius * 1.12), 2.0));
    float halo_radius = 200.0;   // 光晕范围
	float halo_strength = 1.0;  // 光晕亮度
	float bloom = halo_strength * exp(-pow(r / halo_radius, 1.5));
    // Same e-folding lengths as before multiplied by 0.4: 60% shorter.
    float rays = pow(abs(cos(a * 4.0 + 0.15)), 56.0) * exp(-r / 92.0);
    rays += 0.25 * pow(abs(cos(a * 6.0 + 0.4)), 80.0) * exp(-r / 60.0);
    float streak = exp(-abs(p.y) / 1.6) * exp(-abs(p.x) / 200.0) * 0.16;
    float intensity = core + bloom + rays * 0.26 * smoothstep(5.0, 15.0, r) + streak;
    // Protect the entire planet and atmospheric rim from the overlay.
    // Camera rays are in world space; the globe is centred at the origin.
    vec2 ndc = UV * 2.0 - 1.0;
    vec3 ray = normalize(camera_basis * vec3(ndc.x * resolution.x / resolution.y * tan_half_fov, -ndc.y * tan_half_fov, -1.0));
    float along_ray = dot(camera_position, ray);
    float miss_distance = length(cross(camera_position, ray));
    float earth_mask = along_ray < 0.0 ? smoothstep(1.025, 1.028, miss_distance) : 1.0;
    vec3 tint = mix(vec3(1.0, 0.96, 0.88), vec3(1.0), exp(-r / 22.0));
    COLOR = vec4(tint * intensity * visibility * earth_mask, 1.0);
}