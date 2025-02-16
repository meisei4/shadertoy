#ifdef GL_ES
precision mediump float;
#endif

#ifdef __VSCODE__  // Only declare for VS Code linter
layout(location = 0) uniform vec3 iResolution;
layout(location = 1) uniform float iTime;
layout(location = 2) uniform float iTimeDelta;
layout(location = 3) uniform int iFrame;
layout(location = 4) uniform vec4 iMouse;
#endif  

// Texture channels (Shadertoy #iChannel directives)
// (Make sure these textures are available in your local environment.)
#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/gray_noise_small.png"
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/rocks.jpg"
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"

float avg(vec4 color) {
    return (color.r + color.g + color.b) / 3.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    float speed = 1.0;
    float caustic_scale = 0.8; // insane change from 0.8 in the original
    
    // Water opacity: higher opacity means the water reflects more light.
    float opacity = 0.5;
    
    // Use normalized UV coordinates (no pixelation/zoom)
    vec2 uv = fragCoord / iResolution.xy;
    
    vec2 scaledUv = uv * caustic_scale;

    // Water layers – two layers are sampled from noise texture to simulate water ripples.
    // The slight offsets (−0.1 and +0.1) help avoid perfect overlap.
    vec4 water1 = texture(iChannel0, scaledUv + iTime*0.02*speed - 0.1);
    vec4 water2 = texture(iChannel0, scaledUv + iTime*speed*vec2(-0.02, -0.02) + 0.1);
    
    vec4 highlights1 = texture(iChannel2, scaledUv + iTime*speed / vec2(-20, 100));
    vec4 highlights2 = texture(iChannel2, scaledUv + iTime*speed / vec2(20, 100));
    
    vec4 background = texture(iChannel1, uv + avg(water1) * 0.06);    
    
    highlights1.rgb = vec3(avg(highlights1));
    highlights2.rgb = vec3(avg(highlights2));
    
    float alpha = opacity;
    if(avg(water1 + water2) < 1.7) {
        alpha = 0.0;
    }
    if(avg(water1 + water2 + highlights1 + highlights2) < 1.25) {
        alpha = 0.5 * opacity;
    }

    fragColor = (water1 + water2) * alpha + background;
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
