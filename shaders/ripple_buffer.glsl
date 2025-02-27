#iChannel0 "self"

#define RIPPLE_SPEED 0.3       // UV units per second: speed at which the ripple expands
#define IMPULSE_STRENGTH 0.05  // Normalized amplitude of the ripple (height)
#define RIPPLE_SPREAD 0.02     // Half-width of the ripple ring in UV units
#define RIPPLE_DURATION 1.5    // Duration in seconds after which the ripple state is reset

void main_image(out vec4 frag_color, in vec2 frag_coord) {
    // Convert fragment coordinate to normalized UV space (0 to 1)
    vec2 uv = frag_coord / iResolution.xy;
    
    // Retrieve the previous state from the buffer
    vec4 previous_state = texture(iChannel0, uv);
    
    // The G channel stores the time at which the current impulse was initiated (in seconds)
    float active_impulse_time = previous_state.g;
    // The B and A channels store the UV coordinates of the impulse center
    vec2 active_impulse_center = vec2(previous_state.b, previous_state.a);

    // If an impulse exists and its duration has exceeded RIPPLE_DURATION, reset the impulse state.
    if (active_impulse_time > 0.0 && (iTime - active_impulse_time > RIPPLE_DURATION)) {
        active_impulse_time = 0.0;
        active_impulse_center = vec2(0.0);
    }

    // Inject a new impulse if the mouse is pressed and no impulse is active.
    // (iMouse.z > 0.0 indicates a click or touch)
    if (iMouse.z > 0.0 && active_impulse_time == 0.0) {
        active_impulse_time = iTime;
        active_impulse_center = iMouse.xy / iResolution.xy;
    }

    // Compute the ripple value (to be stored in the red channel)
    float computed_ripple_value = 0.0;
    if (active_impulse_time > 0.0) {
        // Time elapsed since the impulse was triggered (in seconds)
        float time_since_impulse = iTime - active_impulse_time;
        // Current radius of the ripple in UV space (expanding over time)
        float current_ripple_radius = RIPPLE_SPEED * time_since_impulse;
        // Distance from the current pixel to the impulse center in UV units
        float distance_from_impulse = distance(uv, active_impulse_center);
        // Linear decay factor (1.0 at impulse, fading to 0 over RIPPLE_DURATION)
        float decay_factor = clamp(1.0 - time_since_impulse / RIPPLE_DURATION, 0.0, 1.0);
        
        // Apply the ripple effect only if the pixel is within RIPPLE_SPREAD of the expanding ring
        if (abs(distance_from_impulse - current_ripple_radius) < RIPPLE_SPREAD) {
            computed_ripple_value = IMPULSE_STRENGTH * decay_factor * cos(3.14159 * (distance_from_impulse - current_ripple_radius) / RIPPLE_SPREAD);
        }
    }
    
    // Output the new state:
    // R channel: computed ripple value (for displacement)
    // G channel: active impulse time (in seconds)
    // B channel: impulse center x coordinate (UV)
    // A channel: impulse center y coordinate (UV)
    frag_color = vec4(computed_ripple_value, active_impulse_time, active_impulse_center.x, active_impulse_center.y);
}

void main() {
    main_image(gl_FragColor, gl_FragCoord.xy);
}
