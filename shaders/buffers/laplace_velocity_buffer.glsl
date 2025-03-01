#iChannel0 "self"                              // Feedback from previous velocity buffer
#iChannel1 "file://laplace_height_buffer.glsl" // Feedback from previous height buffer

// BASE_HEIGHT: The equilibrium height (no ripple) is 0.0 height units.
#define BASE_HEIGHT 0.0  

// EXPECTED_MAX_IMPULSE: When the mouse impulse is applied,
// it is intended to add up to 1.0 height units per frame to the velocity.
// (Units: height units/frame.)
#define EXPECTED_MAX_IMPULSE 1.0  

// For the discrete Laplacian:
//   laplacian = (h_left + h_right + h_up + h_down) - 4.0 * h_center
// Suppose in an extreme scenario:
//   - The center pixel is at -0.5 height units (a dip)
//   - All four neighbors are at +0.5 height units (a crest)

//TODO: what defines this as an extreme scenario? is 0.5 just kind of the maximum ratio that a standard
// wave (e.g. a sine waves crest part) could have in comparison to something that is "1 pixel" away from it?
// please explain that better.

// Then:
//   laplacian = (0.5 + 0.5 + 0.5 + 0.5) - 4.0 * (-0.5) = 2.0 + 2.0 = 4.0
// So we expect the maximum absolute laplacian to be about 4.0 height units.
#define EXPECTED_MAX_LAPLACIAN 4.0  

// The velocity update formula is:
//   new_velocity = old_velocity + (WAVE_SPEED * WAVE_SPEED) * laplacian
// If WAVE_SPEED is 0.1 (in units: [height units/frame]),
// then WAVE_SPEED^2 = 0.01. Thus, in the worst case the update is:
//   0.01 * 4.0 = 0.04 (height units/frame)
// This is the maximum incremental change to velocity from the curvature term.
#define EXPECTED_MAX_VELOCITY_UPDATE 0.04 

// TODO: WAVE_SPEED seems very misleading in its name if it cant directly equate to 
// the units of pixels per second/frame the peak of the crest moves across the screen
//TODO: oh my goodness these names are out of control
#define WAVE_CURVATURE_ACCELERATION_RATE 0.1  // [height units/frame] – sets how quickly curvature affects velocity.

#define VELOCITY_DAMPING 0.995      // Each frame, velocity is multiplied by this factor to damp oscillations.

// For the impulse applied by the mouse, we want to smoothly decay the added velocity
// from the center of the impulse outward. We want full impulse at the center (dist=0)
// and zero impulse at a chosen maximum distance.
// Here, we choose the impulse to have an effect within ~5 pixels.

// TODO: does this mean that the sort of effective radius of the ripple will only really reach to a circle around the impulse of 5 pixels?
// ANSWER: Does this mean that the effective radius of the ripple is only a circle around the impulse of 5 pixels?
// Yes and No:
//- Yes: The impulse (the extra velocity added due to mouse input) is only directly applied within a 5‑pixel radius. Inside 1 pixel, the full impulse is applied; between 1 and 5 pixels, it tapers off.
//- No: Although the initial disturbance is confined to a 5‑pixel circle, the simulation itself propagates the ripple outward over time. So while the impulse is local, its effects (the wave itself) travel across the entire simulated surface.
#define MOUSE_IMPULSE_LOWER 4.0    // Lower bound for smoothstep: inside this radius, impulse is maximum.
#define MOUSE_IMPULSE_UPPER 5.0    // Upper bound: at 5 pixels, the impulse decays to zero.
// The impulse strength is set to EXPECTED_MAX_IMPULSE, meaning that at the very center,
// an additional 1.0 (height unit/frame) is added to velocity.
// TODO: i dont get why this relationship exists, nor how adjusting it will effect the visual behavior of the ripple
// ANSWER: This means that at the very center of a mouse click, you add 1.0 height unit/frame to the velocity.
// Visual Impact:
//- If you increase this value, the initial disturbance becomes stronger, potentially creating higher amplitude ripples.
//- Lowering it will make the disturbance subtler.
#define MOUSE_IMPULSE_STRENGTH EXPECTED_MAX_IMPULSE

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    // Convert pixel coordinates to normalized UV coordinates.
    vec2 uv = frag_coord / iResolution.xy;
    // 'pixel' is the UV offset corresponding to one pixel.
    vec2 pixel = 1.0 / iResolution.xy;
    
    // Retrieve previous velocity (in height units per frame)
    float old_velocity = texture(iChannel0, uv).r;
    // Retrieve previous height (in height units)
    float old_height   = texture(iChannel1, uv).r;
    
    // Sample neighboring heights for Laplace (height units)
    float height_left   = texture(iChannel1, uv + vec2(-pixel.x, 0.0)).r;
    float height_right  = texture(iChannel1, uv + vec2( pixel.x, 0.0)).r;
    float height_up     = texture(iChannel1, uv + vec2(0.0,  pixel.y)).r;
    float height_down   = texture(iChannel1, uv + vec2(0.0, -pixel.y)).r;
    
    // Compute the discrete Laplacian:
    // laplacian has units equal to height units.
    float laplacian = (height_left + height_right + height_up + height_down) - 4.0 * old_height;
    // In an extreme case, |laplacian| could approach EXPECTED_MAX_LAPLACIAN i.e. 4.0.
    
    // Update velocity:
    // (WAVE_CURVATURE_ACCELERATION_RATE * WAVE_CURVATURE_ACCELERATION_RATE) is 0.01 here, so the maximum per-frame contribution from the Laplacian is:
    // 0.01 * EXPECTED_MAX_LAPLACIAN = 0.01 * 4.0 = 0.04 height units/frame.
    float new_velocity = old_velocity + (WAVE_CURVATURE_ACCELERATION_RATE * WAVE_CURVATURE_ACCELERATION_RATE) * laplacian;
    
    // Treduce velocity overtime (like how waves slow down? due to some opposing force or something?)
    new_velocity *= VELOCITY_DAMPING;
        
    // IMPULSE: Apply a smooth impulse (i.e. an initial velocity and laplacian height) based on mouse input.
    // We want a full impulse at the center (0 pixels) and decaying to zero by 5 pixels.
    if (iMouse.z > 0.0) {
        float dist_to_mouse = length(iMouse.xy - frag_coord);
        // The smoothstep here is set so that:
        //   - For dist_to_mouse <= MOUSE_IMPULSE_LOWER, smoothstep returns 0, so (1.0 - 0) = 1 (full impulse).
        //   - For dist_to_mouse >= MOUSE_IMPULSE_UPPER, smoothstep returns 1, so (1.0 - 1) = 0 (no impulse).
        // (Note: The lower value is 1.0 and upper is 5.0 so that the full impulse applies for distances <1 pixel,
        // and decays over the range from 1 to 5 pixels.)
        float impulse = 1.0 - smoothstep(MOUSE_IMPULSE_LOWER, MOUSE_IMPULSE_UPPER, dist_to_mouse);
        // Multiply the impulse (which is in [0,1]) by the expected maximum impulse.
        new_velocity += MOUSE_IMPULSE_STRENGTH * impulse;
    }
    
    // Write the new velocity out (in height units per frame).
    frag_color = vec4(new_velocity, 0.0, 0.0, 1.0);
}

//TODO: WHY IS IT THAT WHEN I CLICK AND HOLD AT A SINGLE POSITION THE INNER RIPPLE JUST BECOMES A SORT OF BLACK HOLE, VERSUS WHEN I QUICKLY CLICK IT ACHIEVES A MORE REALISTIC KIND OF RIPPLE EFFECT
