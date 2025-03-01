#include "/shaders/common/constants.glsl"
#iChannel0 "self"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 normalized_coordinates = fragCoord / iResolution.xy;

    // Adjust sampling distance based on aspect ratio to ensure waves propagate consistently.
    float adjusted_sample_offset = SAMPLE_OFFSET_DISTANCE * (iResolution.x / iResolution.y);

    vec2 previous_frame_data = texture(iChannel0, normalized_coordinates).rg;

    vec2 neighbor_sample_point;

    // Sample neighboring heights with no boundary conditions (waves dissipate at edges)
    vec2 neighbor_sample_offset_x = vec2(SAMPLE_OFFSET_DISTANCE, 0.0);
    vec2 neighbor_sample_offset_y = vec2(0.0, adjusted_sample_offset);

    float height_left   = texture(iChannel0, normalized_coordinates - neighbor_sample_offset_x).r;
    float height_right  = texture(iChannel0, normalized_coordinates + neighbor_sample_offset_x).r;
    float height_bottom = texture(iChannel0, normalized_coordinates - neighbor_sample_offset_y).r;
    float height_top    = texture(iChannel0, normalized_coordinates + neighbor_sample_offset_y).r;

    float mouse_displacement = 0.0; // Default: No mouse interaction

    if (iMouse.z > 0.0) {
        float distance_from_mouse = length(iMouse.xy - fragCoord.xy) / iResolution.y;
        mouse_displacement = MOUSE_IMPACT_SCALAR * smoothstep(MOUSE_OUTER_RADIUS, MOUSE_INNER_RADIUS, distance_from_mouse);
    }

    // Compute the new wave height based on previous height data and neighbor heights.
    // This follows the finite difference wave equation:
    //
    //     h_new = h_current + ( (h_left + h_right + h_top + h_bottom) / 4 ) - h_previous
    //
    // Where:
    //   - h_current = height from last frame
    //   - h_previous = height from two frames ago
    //   - The term (h_left + h_right + h_top + h_bottom) / 4 computes an average of the neighbors.
    //   - The difference (neighbor_avg - h_previous) produces the propagation effect.

    float neighbor_average_height = (height_left + height_right + height_top + height_bottom) / 4.0;
    float wave_height = previous_frame_data.r + (neighbor_average_height - previous_frame_data.g);

    // Apply damping to gradually reduce wave energy over time.
    wave_height *= DAMPING_FACTOR;

    wave_height += mouse_displacement;

    // The red channel stores the new height.
    // The green channel stores the height from the previous frame (for next frame propagation).
    fragColor = vec4(wave_height, previous_frame_data.r, 0.0, 1.0);
}
