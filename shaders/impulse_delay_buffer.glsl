#iChannel0 "self"

// =======================
// OLD (DEAD) Implementation
// =======================
/*
#define OLD_DECAY 0.99             // Multiplier to reduce ripple amplitude each frame.
#define OLD_IMPULSE_STRENGTH 0.05  // Impulse strength for the ring.
#define RING_RADIUS 0.025          // Desired ring radius in UV space.
#define RING_SPREAD 0.03           // Tolerance range for the ring impulse in UV space.

vec4 blur(sampler2D tex, vec2 uv) {
    vec2 pixelSize = 1.0 / iResolution.xy; // One pixel size in UV space.
    vec4 sum = vec4(0.0);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            sum += texture(tex, uv + pixelSize * vec2(x, y));
        }
    }
    return sum / 9.0;
}

void mainImage_DEAD( out vec4 fragColor, in vec2 frag_coord ) {
    vec2 uv = frag_coord / iResolution.xy;
    float ripple = texture(iChannel0, uv).r;
    ripple *= OLD_DECAY;
    ripple = blur(iChannel0, uv).r;
    if (iMouse.z > 0.0) {
        vec2 mouseUV = iMouse.xy / iResolution.xy;
        float distFromMouse = distance(uv, mouseUV);
        if (abs(distFromMouse - RING_RADIUS) < RING_SPREAD) {
            float ringImpulse = OLD_IMPULSE_STRENGTH * cos(3.14159 * (distFromMouse - RING_RADIUS) / RING_SPREAD);
            ripple += ringImpulse;
        }
    }
    fragColor = vec4(ripple, 0.0, 0.0, 1.0);
}
*/

// =======================
// New Propagation Implementation
// =======================

// --- New Constants for Propagation ---
// PROP_MULTIPLIER: scales the influence of the Laplacian (unitless multiplier).
#define PROP_MULTIPLIER 1.0

// DAMPING_FACTOR: per-frame damping factor (unitless, range 0-1; closer to 1 means slower fade).
#define DAMPING_FACTOR 0.99

// CLEAR_FACTOR: clears the buffer on the first frame (usually 1.0 after the first frame).
#define CLEAR_FACTOR min(1.0, float(iFrame))

// REMAP_OFFSET: offset to add after propagation (in water-height units, typically shifts the equilibrium value).
#define REMAP_OFFSET 1.0

// REMAP_SCALE: scaling factor applied before adding offset (unitless; controls the contrast of the water height).
#define REMAP_SCALE 0.2

// MOUSE_IMPULSE_SMOOTH_UPPER: upper limit (in pixels) for the smoothstep function for impulse injection.
#define MOUSE_IMPULSE_SMOOTH_UPPER 4.5

// MOUSE_IMPULSE_SMOOTH_LOWER: lower limit (in pixels) for the smoothstep function; below this, impulse is maximum.
#define MOUSE_IMPULSE_SMOOTH_LOWER 0.5

// ----------------------
// Variable naming notes:
// - "uv": normalized coordinate (range [0,1]) of the current fragment.
// - "pixelOffset": UV units corresponding to one pixel (1/iResolution.xy).
// - "currentHeight": water height at the current pixel (read from red channel).
// - "neighborHeightLeft/Right/Up/Down": water height at adjacent pixels.
// - "laplacian": difference between the sum of neighbor heights and 4 times the current height.
// - "impulseValue": additional disturbance injected when the mouse is pressed.
// ----------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    // Convert screen coordinate to normalized UV coordinate (0 to 1).
    vec2 uv = fragCoord / iResolution.xy;
    
    // Compute pixel offset in UV space.
    vec2 pixelOffset = 1.0 / iResolution.xy;
    
    // Sample the current water height (state) at this pixel.
    float currentHeight = texture(iChannel0, uv).r;
    
    // Sample the water height at the four immediate neighbors.
    // Here, "left" means a shift by -pixelOffset.x and "up" means +pixelOffset.y, etc.
    float heightLeft  = texture(iChannel0, uv + vec2(-pixelOffset.x, 0.0)).r;
    float heightRight = texture(iChannel0, uv + vec2(pixelOffset.x, 0.0)).r;
    float heightUp    = texture(iChannel0, uv + vec2(0.0, pixelOffset.y)).r;
    float heightDown  = texture(iChannel0, uv + vec2(0.0, -pixelOffset.y)).r;
    
    // Alternative neighbor sampling using a precomputed offset vector "e" (as in the original code):
    // vec3 e = vec3(pixelOffset, 0.0);
    // float heightLeft  = texture(iChannel0, uv - e.zy).r;
    // float heightUp    = texture(iChannel0, uv - e.xz).r;
    // float heightRight = texture(iChannel0, uv + e.xz).r;
    // float heightDown  = texture(iChannel0, uv + e.zy).r;
    
    // Compute the Laplacian: a discrete approximation of the second spatial derivative.
    // The Laplacian is given by the sum of the neighbor heights minus four times the center height.
    float laplacian = (heightLeft + heightRight + heightUp + heightDown) - 4.0 * currentHeight;
    
    // Initialize the impulseValue variable.
    // If the mouse is pressed, we compute an impulse based on the distance (in pixels) between
    // the current fragment and the mouse position. The smoothstep function ensures that the impulse
    // smoothly decreases from a maximum at very close distances to zero at the upper limit.
    float impulseValue = 0.0;
    if (iMouse.z > 0.0) {
        // Compute the Euclidean distance (in pixel units) between fragCoord and the mouse position.
        float distanceToMouse = length(iMouse.xy - fragCoord);
        impulseValue = smoothstep(MOUSE_IMPULSE_SMOOTH_UPPER, MOUSE_IMPULSE_SMOOTH_LOWER, distanceToMouse);
    }
    
    // Combine the impulse injection with the propagation update.
    // The propagation update adds the Laplacian (scaled by PROP_MULTIPLIER) to the impulse.
    float updatedState = impulseValue + (currentHeight + PROP_MULTIPLIER * laplacian);
    
    // Apply damping to the updated state so that the ripples gradually fade over time.
    updatedState *= DAMPING_FACTOR;
    
    // If this is the first frame, CLEAR_FACTOR will reset the buffer (typically 1 on subsequent frames).
    updatedState *= CLEAR_FACTOR;
    
    // Remap the updated state into the desired range.
    // REMAP_SCALE adjusts the contrast, and REMAP_OFFSET shifts the equilibrium level.
    updatedState = updatedState * REMAP_SCALE + REMAP_OFFSET;
    
    // Output the final water height into the red channel.
    fragColor = vec4(updatedState, 0.0, 0.0, 0.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
