#iChannel0 "self"
#iChannel1 "file://buffer_b.glsl"

// You can rename or omit these lines below if your environment doesn't require them.
// But in Shadertoy / glsl viewers, they tell the environment the input channel sources.

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Convert fragCoord to normalized [0, 1].
    vec2 q = fragCoord.xy / iResolution.xy;
    
    // We want to sample neighbors ± 1 pixel in x or y:
    // e.x = 1.0 / iResolution.x, e.y = 1.0 / iResolution.y
    vec3 e = vec3( vec2(1.0) / iResolution.xy, 0.0 );
    
    // The center pixel from "self" (iChannel0).
    float p11 = texture(iChannel0, q).x;
    
    // The neighbors come from the other buffer (iChannel1).
    float p10 = texture(iChannel1, q - e.zy).x;  // up    ( -1 in y )
    float p01 = texture(iChannel1, q - e.xz).x;  // left  ( -1 in x )
    float p21 = texture(iChannel1, q + e.xz).x;  // right ( +1 in x )
    float p12 = texture(iChannel1, q + e.zy).x;  // down  ( +1 in y )
    
    // Mouse interaction. If the mouse is down (iMouse.z > 0), add an impulse:
    float d = 0.0;
    if (iMouse.z > 0.0)
    {
        float dist = length(iMouse.xy - fragCoord.xy);
        // The smoothstep parameters (4.5, 0.5) can be tweaked for area of effect:
        d = smoothstep(4.5, 0.5, dist);
    }
    
    // PDE update: combination of a Laplacian-like term + damping + re-centering.
    d += -(p11 - 0.5) * 2.0 + (p10 + p01 + p21 + p12 - 2.0);
    d *= 0.99;                              // Dampening factor.
    d *= min(1.0, float(iFrame));           // Clear on the very first frame (when iFrame=0).
    d = d * 0.5 + 0.5;                      // Shift wave so that 0.5 is equilibrium.
    
    fragColor = vec4(d, 0.0, 0.0, 0.0);
}
