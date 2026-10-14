shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
uniform vec3 sun_direction = vec3(-0.7, 0.3, 0.65);
varying vec3 world_position;
const float OUTER = 1.025;
const float SCALE_HEIGHT = 0.0065;
vec2 intersect_sphere(vec3 origin, vec3 ray, float radius) {
    float b = dot(origin, ray);
    float d = b*b - dot(origin, origin) + radius*radius;
    if (d < 0.0) return vec2(1e5, -1e5);
    float h = sqrt(d);
    return vec2(-b-h, -b+h);
}
float density(vec3 p) { return exp(-max(length(p)-1.0, 0.0) / SCALE_HEIGHT); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec3 eye = INV_VIEW_MATRIX[3].xyz;
    vec3 ray = normalize(world_position - eye);
    vec2 outer_hit = intersect_sphere(eye, ray, OUTER);
    float start = max(outer_hit.x, 0.0);
    float end = outer_hit.y;
    vec2 ground_hit = intersect_sphere(eye, ray, 1.0);
    if (ground_hit.x > 0.0 && ground_hit.x < end) end = ground_hit.x;
    float step_size = max(end-start, 0.0) / 16.0;
    vec3 beta = vec3(5.8, 13.5, 33.1);
    vec3 scattered = vec3(0.0);
    float view_depth = 0.0;
    vec3 sun = normalize(sun_direction);
    float mu = dot(ray, sun);
    float phase = 0.75 * (1.0 + mu*mu);
    for (int i = 0; i < 16; i++) {
        vec3 p = eye + ray * (start + (float(i)+0.5)*step_size);
        float local_density = density(p);
        view_depth += local_density * step_size;
        vec2 block = intersect_sphere(p, sun, 1.0);
        if (block.x > 0.0) continue;
        float sun_length = max(intersect_sphere(p, sun, OUTER).y, 0.0);
        float sun_depth = 0.0;
        for (int j = 0; j < 6; j++) {
            sun_depth += density(p + sun * ((float(j)+0.5)*sun_length/6.0)) * sun_length/6.0;
        }
        vec3 transmission = exp(-beta * (view_depth + sun_depth));
        scattered += transmission * local_density * step_size * beta;
    }
    ALBEDO = scattered * phase * 0.85;
    ALPHA = 1.0;
}
