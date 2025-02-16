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
#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/noise.png"
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/rocks.jpg"
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"

// --- Resolution Control Definitions ---
// These values let you work in a “virtual” resolution that is then pixelated and zoomed.
#define VIRTUAL_RES_X       256.0   // Virtual width in pixels.
#define VIRTUAL_RES_Y       192.0   // Virtual height in pixels.
#define ZOOM_FACTOR         1.0     // 1.0 = base 256×192, > 1.0 zooms in.

// Helper functions for pixelation/zoom:
vec2 pixelate_and_zoom_uv(vec2 frag_coord, vec2 resolution, vec2 virtual_resolution, float zoom_factor);
vec2 pixelate_uv(vec2 uv, vec2 resolution, vec2 virtual_resolution);
vec2 zoom_uv(vec2 uv, float zoom_factor);
float avg(vec4 color);


void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    float speed = 0.8;
    
    float caustic_scale = 0.18;
    
    // Water opacity: higher opacity means the water reflects more light.
    float opacity = 1.0;
    
    vec2 uv = pixelate_and_zoom_uv(fragCoord, iResolution.xy, vec2(VIRTUAL_RES_X, VIRTUAL_RES_Y), ZOOM_FACTOR);
    
    vec2 scaledUv = uv * caustic_scale;

    // Water layers – two layers are sampled from noise texture to simulate water ripples.
    // The slight offsets (−0.1 and +0.1) help avoid perfect overlap.
    vec4 water1 = texture(iChannel0, scaledUv + iTime*0.01*speed - 0.5);
    vec4 water2 = texture(iChannel0, scaledUv.xy + iTime*speed*vec2(-0.01, -0.01) + 1.0);
    
    vec4 highlights1 = texture(iChannel2, scaledUv.xy + iTime*speed / vec2(-20, 100));
    vec4 highlights2 = texture(iChannel2, scaledUv.xy + iTime*speed / vec2(20, 100));
    
    vec4 background = texture(iChannel1, vec2(uv) + avg(water1) * 0.06);    
    
    highlights1.rgb = vec3(avg(highlights1) / 1.0);
    highlights2.rgb = vec3(avg(highlights2) / 1.0);
    
    float alpha = opacity;
    if(avg(water1 + water2) < 1.68) {
        alpha = 0.0;
    }
    if(avg(water1 + water2 + highlights1 + highlights2) < 1.3) {
        alpha = 0.3 * opacity;
    }

    fragColor = (water1 + water2) * alpha + background;
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}


vec2 pixelate_and_zoom_uv(vec2 frag_coord, vec2 resolution, vec2 virtual_resolution, float zoom_factor) {
    vec2 uv = frag_coord / resolution;
    vec2 pixelated_uv = pixelate_uv(uv, resolution, virtual_resolution);
    return zoom_uv(pixelated_uv, zoom_factor);
}

vec2 pixelate_uv(vec2 uv, vec2 resolution, vec2 virtual_resolution) {
    vec2 scaled = uv * resolution;
    vec2 factor = virtual_resolution / resolution;
    vec2 pixelated = floor(scaled * factor) / factor;
    return pixelated / resolution;
}

vec2 zoom_uv(vec2 uv, float zoom_factor) {
    return uv * zoom_factor;
}

float avg(vec4 color) {
    return (color.r + color.g + color.b) / 3.0;
}