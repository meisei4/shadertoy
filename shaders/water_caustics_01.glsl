#ifdef GL_ES
precision mediump float;
#endif

#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/gray_noise_small.png" // displacement noise (stored in red)
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/rocks.jpg"          // background texture (full-color)
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"        // caustics texture (noise stored in red)

#define VIRTUAL_DS_RES_X 256.0  // desired virtual width
#define VIRTUAL_DS_RES_Y 192.0  // desired virtual height

// These control the scrolling displacement maps that mimic a water-like (or Mario Galaxy–style) effect.
#define DISP_SCROLL_SPEED         1.0     // speed multiplier for scrolling (dimensionless)
#define DISP_UV_SCALE             0.8     // scales UV when sampling displacement maps
#define DISP_OPACITY              0.5     // base opacity for the displacement effect (0.0–1.0)

#define DISP1_STATIC_OFFSET       -0.1    // static offset for displacement map layer 1 (normalized UV units)
#define DISP2_STATIC_OFFSET       0.1     // static offset for displacement map layer 2 (normalized UV units)

//TODO: wtf are these next constants they are normalized for velocity of the scrolling? rename them 
#define DISP1_TIME_MULTIPLIER     0.02    // time multiplier for layer 1 motion
#define DISP2_TIME_OFFSET_X       -0.02   // time-based horizontal offset for layer 2 (normalized units)
#define DISP2_TIME_OFFSET_Y       -0.02   // time-based vertical offset for layer 2 (normalized units)

//TODO: ^^ this is pretty much identical to the below scrolling constants, they do the same thing just for different layers
// FIX IT!!^^
#define CAUSTICS_OFFSET_X1        (1.0/-10.0)   // horizontal offset for caustics layer 1 (normalized units)
#define CAUSTICS_OFFSET_Y1        (1.0/100.0)   // vertical offset for caustics layer 1 (normalized units)
#define CAUSTICS_OFFSET_X2        (1.0/10.0)    // horizontal offset for caustics layer 2 (normalized units)
#define CAUSTICS_OFFSET_Y2        (1.0/100.0)   // vertical offset for caustics layer 2 (normalized units)

//TODO: this is a confusing constant, i dont know how to fix it, because it just completely blows up the consts below it.
#define DISP_NOISE_SCALE (1.0/3.0)
#define BACKGROUND_DISP_FACTOR    0.05   // background UV offset factor (normalized units) ??????
#define WATER_DISP_BRIGHTNESS_THRESHOLD 0.3   // if average effective brightness > 0.3, displacement effect is canceled ???
#define ALL_DISP_BRIGHTNESS_THRESHOLD   0.75  // if combined effective brightness > 0.75, opacity is boosted ???
#define DISP_OPACITY_MULTIPLIER         5.0   // multiplier applied to DISP_OPACITY when threshold is exceeded ???? EWWW

// #define DO_PIXELATION
#define SHOW_DISP_LAYER_1
#define SHOW_DISP_LAYER_2
#define SHOW_CAUSTICS_LAYER_1
#define SHOW_CAUSTICS_LAYER_2
#define SHOW_BACKGROUND

float average_rgb(vec4 color);            
vec2 pixelate_uv(vec2 uv);              
vec2 scroll_displacement_map(vec2 uv, vec2 speed, vec2 static_offset); 
vec2 scale_uv(vec2 uv);
vec3 scale_noise(vec3 noise, float factor);
vec4 sample_disp_layer_1(vec2 uv);   
vec4 sample_disp_layer_2(vec2 uv);     
vec4 sample_caustics_layer_1(vec2 uv);    
vec4 sample_caustics_layer_2(vec2 uv);    
vec4 sample_background(vec2 uv, vec4 disp_layer); 
float compute_disp_opacity(vec4 disp1, vec4 disp2, vec4 caustics1, vec4 caustics2);

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    vec4 disp_layer_1 = vec4(0.0);
    vec4 disp_layer_2 = vec4(0.0);
    vec4 caustics_layer_1 = vec4(0.0);
    vec4 caustics_layer_2 = vec4(0.0);
    vec4 background = vec4(0.0);

    #ifdef DO_PIXELATION
        uv = get_pixelated_uv(frag_coord);
    #endif
    #ifdef SHOW_DISP_LAYER_1
        disp_layer_1 = sample_disp_layer_1(uv);
    #endif
    #ifdef SHOW_DISP_LAYER_2
        disp_layer_2 = sample_disp_layer_2(uv);
    #endif
    #ifdef SHOW_CAUSTICS_LAYER_1
        caustics_layer_1 = sample_caustics_layer_1(uv);
    #endif
    #ifdef SHOW_CAUSTICS_LAYER_2
        caustics_layer_2 = sample_caustics_layer_2(uv);
    #endif
    #ifdef SHOW_BACKGROUND
        background = sample_background(uv, disp_layer_1);
    #endif

    float alpha = compute_disp_opacity(disp_layer_1, disp_layer_2, caustics_layer_1, caustics_layer_2);
    frag_color = (disp_layer_1 + disp_layer_2) * alpha + background;
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}

vec4 sample_disp_layer_1(vec2 uv) {
    vec2 scaled_uv = scale_uv(uv);
    vec2 velocity = vec2(DISP1_TIME_MULTIPLIER);
    vec2 offset_uv = scroll_displacement_map(scaled_uv, velocity, vec2(DISP1_STATIC_OFFSET));
    vec4 color = texture(iChannel0, offset_uv);
    color.rgb = vec3(scale_noise(vec3(color.r), 1.0)); //TODO: explain wtf this line is doing, and what is 1.0
    return color;
}

vec4 sample_disp_layer_2(vec2 uv) {
    vec2 scaled_uv = scale_uv(uv);
    vec2 velocity = vec2(DISP2_TIME_OFFSET_X, DISP2_TIME_OFFSET_Y);
    vec2 offset_uv = scroll_displacement_map(scaled_uv, velocity, vec2(DISP2_STATIC_OFFSET));
    vec4 color = texture(iChannel0, offset_uv);
    color.rgb = vec3(scale_noise(vec3(color.r), 1.0));  //TODO: explain wtf this line is doing, and what is 1.0
    return color;
}

vec4 sample_caustics_layer_1(vec2 uv) {
    vec2 scaled_uv = scale_uv(uv);
    vec2 velocity = vec2(CAUSTICS_OFFSET_X1, CAUSTICS_OFFSET_Y1);
    vec2 offset_uv = scroll_displacement_map(scaled_uv, velocity, vec2(0.0)); //TODO: just have default to no offset vec2(0.0)?
    vec4 color = texture(iChannel2, offset_uv);
    color.rgb = vec3(scale_noise(vec3(color.r), 2.0/3.0)); //TODO: explain wtf this line is doing, and what is 2.0/3.0
    return color;
}

vec4 sample_caustics_layer_2(vec2 uv) {
    vec2 scaled_uv = scale_uv(uv);
    vec2 velocity = vec2(CAUSTICS_OFFSET_X2, CAUSTICS_OFFSET_Y2);
    vec2 offset_uv = scroll_displacement_map(scaled_uv, velocity, vec2(0.0)); //TODO: just have default to no offset vec2(0.0)?
    vec4 color = texture(iChannel2, offset_uv);
    color.rgb = vec3(scale_noise(vec3(color.r), 2.0/3.0)); //TODO: explain wtf this line is doing, and what is 2.0/3.0
    return color;
}

vec4 sample_background(vec2 uv, vec4 disp_layer) {
    vec2 bg_uv = uv + (disp_layer.r) * BACKGROUND_DISP_FACTOR;
    return texture(iChannel1, bg_uv);
}

float compute_disp_opacity(vec4 disp1, vec4 disp2, vec4 caustics1, vec4 caustics2) {
    float alpha = DISP_OPACITY;
    float water_brightness = average_rgb(disp1 + disp2);
    float all_brightness = average_rgb(disp1 + disp2 + caustics1 + caustics2);
    if (water_brightness > WATER_DISP_BRIGHTNESS_THRESHOLD) { 
        alpha = 0.0; 
    }
    if (all_brightness > ALL_DISP_BRIGHTNESS_THRESHOLD) { 
        alpha = DISP_OPACITY_MULTIPLIER * DISP_OPACITY; 
    }
    return alpha;
}

vec2 scroll_displacement_map(vec2 uv, vec2 speed, vec2 static_offset) {
    return uv + iTime * DISP_SCROLL_SPEED * speed + static_offset;
}

vec2 scale_uv(vec2 uv) {
    return uv * DISP_UV_SCALE;
}

vec3 scale_noise(vec3 noise, float factor) {
    return noise * DISP_NOISE_SCALE * factor;
}

float average_rgb(vec4 color) { 
    return (color.r + color.g + color.b) / 3.0; 
}

vec2 get_pixelated_uv(vec2 frag_coord) { 
    return pixelate_uv(frag_coord / iResolution.xy); 
}

vec2 pixelate_uv(vec2 uv) { 
    return floor(uv * vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y)) / vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y); 
}
