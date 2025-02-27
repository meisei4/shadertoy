#iChannel0 "file://0_ripple_velocity_buffer.glsl" // Read the newly updated velocity from Buffer A.
#iChannel1 "self"                              // Feedback from previous height.

#define HEIGHT_BASELINE 0.0
#define RESTORE_RATE 0.1      // How fast the height drifts back toward the baseline.
#define HEIGHT_CLAMP_MIN -1.0
#define HEIGHT_CLAMP_MAX 1.0

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    
    // Read new velocity (from Buffer A).
    float velocity = texture(iChannel0, uv).r;
    // Read previous height from Buffer B.
    float oldHeight = texture(iChannel1, uv).r;
    
    // Update height by integrating the velocity.
    float newHeight = oldHeight + velocity;
    
    // Apply a very small restoring force to pull the water toward the baseline.
    newHeight = mix(newHeight, HEIGHT_BASELINE, RESTORE_RATE);
    
    // Clamp the height to avoid runaway values.
    newHeight = clamp(newHeight, HEIGHT_CLAMP_MIN, HEIGHT_CLAMP_MAX);
    
    fragColor = vec4(newHeight, 0.0, 0.0, 1.0);
}
