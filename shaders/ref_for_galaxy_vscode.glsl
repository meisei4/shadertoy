
#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/gray_noise_small.png"
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/rocks.jpg"
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"

float avg(vec4 color) {
    return (color.r + color.g + color.b)/3.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Flow Speed, increase to make the water flow faster.
    float speed = 1.0;
    
    // Water Scale, scales the water, not the background.
    float scale = 0.8;
    
    // Water opacity, higher opacity means the water reflects more light.
    float opacity = 0.5;
 
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (fragCoord/iResolution.xy);
    vec2 scaledUv = uv*scale;

    // Water layers, layered on top of eachother to produce the reflective effect
    // Add 0.1 to both uv vectors to avoid the layers stacking perfectly and creating a huge unnatural highlight
    vec4 water1 = texture(iChannel0, scaledUv + iTime*0.02*speed - 0.1);
    vec4 water2 = texture(iChannel0, scaledUv.xy + iTime*speed*vec2(-0.02, -0.02) + 0.1);
    
    // Water highlights
    vec4 highlights1 = texture(iChannel2, scaledUv.xy + iTime*speed / vec2(-10, 100));
    vec4 highlights2 = texture(iChannel2, scaledUv.xy + iTime*speed / vec2(10, 100));
    
    // Background image
    vec4 background = texture(iChannel1, vec2(uv) + avg(water1) * 0.05);
    
    // Average the colors of the water layers (convert from 1 channel to 4 channel
    water1.rgb = vec3(avg(water1));
    water2.rgb = vec3(avg(water2));
    
    // Average and smooth the colors of the highlight layers
    highlights1.rgb = vec3(avg(highlights1)/1.5);
    highlights2.rgb = vec3(avg(highlights2)/1.5);
    
    float alpha = opacity;
    
    if(avg(water1 + water2) < 1.7) {
        alpha = 0.0;
    }
    if(avg(water1 + water2 + highlights1 + highlights2) < 1.25) {
        alpha = 0.5 * opacity;
    }

    // Output to screen
    fragColor = (water1 + water2) * alpha + background;
}


void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}