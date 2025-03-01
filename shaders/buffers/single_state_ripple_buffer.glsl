#iChannel0 "self"

#define RIPPLE_SPEED 0.3       // UV units per second: speed at which the ripple expands
#define IMPULSE_STRENGTH 0.05  // Normalized amplitude of the ripple (height)
#define RIPPLE_SPREAD 0.02     // Half-width of the ripple ring in UV units
#define RIPPLE_DURATION 1.5    // Duration in seconds after which the ripple state is reset

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    vec4 previous_state = texture(iChannel0, uv);
    float active_impulse_time = previous_state.g;
    vec2 active_impulse_center = vec2(previous_state.b, previous_state.a);

    if (active_impulse_time > 0.0 && (iTime - active_impulse_time > RIPPLE_DURATION)) {
        active_impulse_time = 0.0;
        active_impulse_center = vec2(0.0);
    }

    if (iMouse.z > 0.0 && active_impulse_time == 0.0) {
        active_impulse_time = iTime;
        active_impulse_center = iMouse.xy / iResolution.xy;
    }

    float computed_ripple_value = 0.0;
    if (active_impulse_time > 0.0) {
        float time_since_impulse = iTime - active_impulse_time;
        float current_ripple_radius = RIPPLE_SPEED * time_since_impulse;
        float distance_from_impulse = distance(uv, active_impulse_center);
        float decay_factor = clamp(1.0 - time_since_impulse / RIPPLE_DURATION, 0.0, 1.0);
        
        if (abs(distance_from_impulse - current_ripple_radius) < RIPPLE_SPREAD) {
            computed_ripple_value = IMPULSE_STRENGTH * decay_factor * cos(3.14159 * (distance_from_impulse - current_ripple_radius) / RIPPLE_SPREAD);
        }
    }
    
    frag_color = vec4(computed_ripple_value, active_impulse_time, active_impulse_center.x, active_impulse_center.y);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
