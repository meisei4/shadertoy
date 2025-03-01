#include "/shaders/common/constants.glsl"
#iChannel0 "self"

#define WAKE_SAMPLE_STEP 0.005 // kept constant because it works well across scales, figure it out later

// IMPULSE_CORE_RADIUS is the full-strength zone.
// Example: A small finger dip might be 0.0025; a large splash might be 0.05 or higher.
#define IMPULSE_CORE_RADIUS  0.0025

#define IMPULSE_TRANSITION_MULTIPLIER 2.0 // Transition multiplier for the impulse fade zone.
#define IMPULSE_FADE_RADIUS (IMPULSE_CORE_RADIUS + IMPULSE_TRANSITION_MULTIPLIER * WAKE_SAMPLE_STEP)

#define BASE_IMPULSE_STRENGTH -0.015 // Base impulse strength (height units per frame)

// using this to be able to tie the propagation and the dampening such that:
#define BASE_PROPAGATION 1.0 // the effective propagation factor to vary between 1.0 and 1.15,
#define BASE_DAMPING 0.95 // the effective damping to vary between 0.95 and 0.8645

#define PROPAGATION_INTENSITY 0.0 // 0.0 means no extra propagation (default), 1.0 means maximum extra propagation (along with increase in dampening rate).

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    // Adjust the y sample offset to compensate for non-square resolutions.
    // Without this, a fixed UV step would correspond to different pixel distances in x and y,
    // resulting in anisotropic (e.g. elliptical) ripples.
    float adjusted_sample_step = WAKE_SAMPLE_STEP * (iResolution.x / iResolution.y);
    vec2 neighbor_offset_x = vec2(WAKE_SAMPLE_STEP, 0.0);
    vec2 neighbor_offset_y = vec2(0.0, adjusted_sample_step);
    
    // Retrieve previous frame height data:
    //   prev_height: height from 1 frame ago (red channel)
    //   prev_prev_height: height from 2 frames ago (green channel)
    vec2 prev_heights = texture(iChannel0, uv).rg;
    
    float height_left   = texture(iChannel0, uv - neighbor_offset_x).r;
    float height_right  = texture(iChannel0, uv + neighbor_offset_x).r;
    float height_bottom = texture(iChannel0, uv - neighbor_offset_y).r;
    float height_top    = texture(iChannel0, uv + neighbor_offset_y).r;
    
    float mouse_impulse = 0.0;
    if (iMouse.z > 0.0) {
        float distance_from_mouse = length(iMouse.xy - frag_coord.xy) / iResolution.y;
        // Apply smoothstep: full impulse for distances <= IMPULSE_CORE_RADIUS, fading to zero by IMPULSE_FADE_RADIUS.
        mouse_impulse = BASE_IMPULSE_STRENGTH * smoothstep(IMPULSE_FADE_RADIUS, IMPULSE_CORE_RADIUS, distance_from_mouse);
    }
    
    float avg_neighbor_height = (height_left + height_right + height_top + height_bottom) / 4.0;
    float effective_propagation = BASE_PROPAGATION + 0.15 * PROPAGATION_INTENSITY;  // Ranges from 1.0 to 1.15.
    float new_height = prev_heights.r + effective_propagation * (avg_neighbor_height - prev_heights.g) * (TIME_SCALE * TIME_SCALE);
    // SCALE THE DAMPENING INVERSLY WITH THE INTESITY TO NOT BLOW SHIT UP!
    float effective_damping = BASE_DAMPING - 0.09 * PROPAGATION_INTENSITY; // Ranges from 0.95 down to 0.8645, CAUSE I SAID SO...
    new_height *= effective_damping;
    new_height += mouse_impulse;
    frag_color = vec4(new_height, prev_heights.r, 0.0, 1.0);
}
