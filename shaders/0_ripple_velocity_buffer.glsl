#iChannel0 "self"                           // Feedback from previous velocity
#iChannel1 "file://1_ripple_height_buffer.glsl" // Previous height from Buffer B

#define WAVE_SPEED 1.0
#define VELOCITY_DAMPING 0.995

#define MOUSE_IMPULSE_UPPER  4.0
#define MOUSE_IMPULSE_LOWER  0.5
#define MOUSE_IMPULSE_STRENGTH 0.3

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 pixel = 1.0 / iResolution.xy;
    
    // Read previous velocity from Buffer A.
    float oldVelocity = texture(iChannel0, uv).r;
    // Read previous height from Buffer B.
    float oldHeight   = texture(iChannel1, uv).r;
    
    // Compute Laplacian of height (using clamped UVs to avoid wrapping).
    float hL = texture(iChannel1, uv + vec2(-pixel.x, 0.0)).r;
    float hR = texture(iChannel1, clamp(uv + vec2( pixel.x, 0.0), 0.0, 1.0)).r;
    float hU = texture(iChannel1, clamp(uv + vec2(0.0,  pixel.y), 0.0, 1.0)).r;
    float hD = texture(iChannel1, clamp(uv + vec2(0.0, -pixel.y), 0.0, 1.0)).r;
    
    float laplacian = (hL + hR + hU + hD) - 4.0 * oldHeight;
    
    // Update velocity using the wave equation (acceleration ~ laplacian)
    float newVelocity = oldVelocity + (WAVE_SPEED * WAVE_SPEED) * laplacian;
    
    // Apply damping to velocity.
    newVelocity *= VELOCITY_DAMPING;
    
    // Add a mouse impulse to velocity.
    if (iMouse.z > 0.0) {
        float distToMouse = length(iMouse.xy - fragCoord);
        float impulse = smoothstep(MOUSE_IMPULSE_UPPER, MOUSE_IMPULSE_LOWER, distToMouse);
        newVelocity += MOUSE_IMPULSE_STRENGTH * impulse;
    }
    
    fragColor = vec4(newVelocity, 0.0, 0.0, 1.0);
}
