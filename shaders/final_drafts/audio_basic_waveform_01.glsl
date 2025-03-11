//#iChannel0 "file://assets/audio/Hellion_v2.ogg"
#iChannel0 "file://assets/audio/experiment.mp3"


void mainImage1(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    float waveform_y_value = texture(iChannel0, vec2(uv.x, 1.0)).r;    

    vec3 color = vec3(0.0);
    if(uv.y < waveform_y_value) {
        color = vec3(1.0); // white for all values under the waveform y-value
    }
    
    fragColor = vec4(color, 1.0);
}
