#iChannel0 "self"


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

// PROP_MULTIPLIER: scales the influence of the Laplacian (unitless multiplier).
#define PROP_MULTIPLIER 1.0

// DAMPING_FACTOR: per-frame damping factor (range 0-1; closer to 1 => slower fade).
#define DAMPING_FACTOR 0.995

// CLEAR_FACTOR: clears the buffer on the first frame (usually 1.0 after the first frame).
#define CLEAR_FACTOR min(1.0, float(iFrame))

// REMAP_OFFSET: offset after propagation (shifts equilibrium).
#define REMAP_OFFSET 0.5

// REMAP_SCALE: scales the wave amplitude (controls contrast).
#define REMAP_SCALE 0.2

// MOUSE_IMPULSE_SMOOTH_UPPER: distance in pixels beyond which impulse is 0.
#define MOUSE_IMPULSE_SMOOTH_UPPER 4.0

// MOUSE_IMPULSE_SMOOTH_LOWER: distance in pixels below which impulse is 1.
#define MOUSE_IMPULSE_SMOOTH_LOWER 0.5

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 pixelOffset = 1.0 / iResolution.xy;
    
    float currentHeight = texture(iChannel0, uv).r;
    
    float heightLeft = texture(iChannel0, clamp(uv + vec2(-pixelOffset.x, 0.0), 0.0, 1.0)).r;
    float heightRight= texture(iChannel0, clamp(uv + vec2( pixelOffset.x, 0.0), 0.0, 1.0)).r;
    float heightUp   = texture(iChannel0, clamp(uv + vec2(0.0,  pixelOffset.y), 0.0, 1.0)).r;
    float heightDown = texture(iChannel0, clamp(uv + vec2(0.0, -pixelOffset.y), 0.0, 1.0)).r;

    float laplacian = (heightLeft + heightRight + heightUp + heightDown) - 4.0 * currentHeight;
    
    float impulseValue = 0.0;
    if (iMouse.z > 0.0) {
        float distToMouse = length(iMouse.xy - fragCoord);
        impulseValue = smoothstep(MOUSE_IMPULSE_SMOOTH_UPPER, MOUSE_IMPULSE_SMOOTH_LOWER, distToMouse);
    }
    
    float updatedState = currentHeight + PROP_MULTIPLIER * laplacian + impulseValue;
    updatedState *= DAMPING_FACTOR;
    updatedState *= CLEAR_FACTOR;
    updatedState = updatedState * REMAP_SCALE + REMAP_OFFSET;
    updatedState = clamp(updatedState, 0.0, 1.0);

    
    fragColor = vec4(updatedState, 0.0, 0.0, 0.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
