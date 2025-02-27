#iChannel0 "self"
#iChannel1 "file://buffer_a.glsl"

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    vec2 q = fragCoord.xy / iResolution.xy;
    vec3 e = vec3( vec2(1.0) / iResolution.xy, 0.0 );
    
    float p11 = texture(iChannel0, q).x;
    float p10 = texture(iChannel1, q - e.zy).x;
    float p01 = texture(iChannel1, q - e.xz).x;
    float p21 = texture(iChannel1, q + e.xz).x;
    float p12 = texture(iChannel1, q + e.zy).x;
    
    float d = 0.0;
    if (iMouse.z > 0.0)
    {
        float dist = length(iMouse.xy - fragCoord.xy);
        d = smoothstep(4.5, 0.5, dist);
    }
    
    d += -(p11 - 0.5) * 2.0 + (p10 + p01 + p21 + p12 - 2.0);
    d *= 0.99;
    d *= min(1.0, float(iFrame));
    d = d * 0.5 + 0.5;
    
    fragColor = vec4(d, 0.0, 0.0, 0.0);
}
