#ifdef GL_ES
precision mediump float;
#endif

#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/gray_noise_small.png"
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/icebergs.jpg"
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"

#define VIRTUAL_RES_X               256.0   //DS width
#define VIRTUAL_RES_Y               192.0   //DS height
#define ZOOM_FACTOR                 1.5   // Multiplies the pixelated UV coordinates: >1.0 zooms in, <1.0 zooms out (practical: 0.5–2.0).

#define TAU                         10.28318530718    // Controls turbulence periodicity (try values between 20 and 30).
#define MAX_ITER                    4                 // Sets how many iterations to compute (3–6 is common).
#define TURBULENCE_TIME_SCALE       0.5               // Higher values make turbulence animate faster (0.1–1.0).
#define TURBULENCE_TIME_OFFSET      23.0              // Shifts the phase; experiment between 0 and 50.
#define TURBULENCE_INTENSITY        0.2             // Controls distortion strength (0.001–0.02).
#define TURBULENCE_ITER_SCALE       3.5               // Affects per‐iteration influence (1.0–10.0).
#define TURBULENCE_BASE             1.17              // Base contrast for turbulence; typical values around 1.0–2.0.
#define TURBULENCE_EXPONENT         1.4               // Exponent for contrast; increasing it boosts contrast (0.5–3.0).
#define TURBULENCE_POWER            1.0               // Exaggerates the effect (1.0–10.0).
#define TURBULENCE_TINT             vec3(0.0, 1.0, 0.0)  // Shifts the final color; each channel is usually in 0.0–1.0.

//TODO: get the coloration stuff to fix

#define WATER_SPEED                 1.0     // Controls how fast the water patterns move (try 0.5–2.0).
#define CAUSTIC_SCALE               0.8     // Scales the UV for caustics; higher zooms in (0.05–0.2).
#define WATER_OPACITY               0.9     // Base opacity (0.0–1.0).
#define WATER1_OFFSET               -0.4    // Shifts the sampling coordinates (typically –1 to 1).
#define WATER2_OFFSET               0.4     
#define WATER1_TIME_MULTIPLIER      0.02    // Slows or speeds the water_layer_1 time shift (0.001–0.1).
#define WATER2_TIME_OFFSET_X        -0.02   // Time offsets (try –0.1 to 0.1).
#define WATER2_TIME_OFFSET_Y        0.02

#define HIGHLIGHT_OFFSET_X1         -10.0   // Offsets for sampling highlight textures (experiment with –100 to 100).
#define HIGHLIGHT_OFFSET_Y1         100.0   
#define HIGHLIGHT_OFFSET_X2         10.0    
#define HIGHLIGHT_OFFSET_Y2         100.0   

#define BACKGROUND_OFFSET_FACTOR    0.06    // Shifts the background UV based on water brightness (0–0.1).
#define BACKGROUND_BLEND_FACTOR     0.5     // Mixes between the turbulence and a texture (0.0 = pure turbulence, 1.0 = pure texture).

#define WARP_AMPLITUDE_X            0.01    // Sine/cosine based warp amplitude (0–0.1).
#define WARP_AMPLITUDE_Y            0.01    
#define WARP_FREQUENCY_X            10.0    // Warp frequencies (1–20).
#define WARP_FREQUENCY_Y            10.0    
#define WARP_SPEED                  1.0     // Speed of warping effect (0.1–5.0).

#define WATER_AVG_THRESHOLD         1.7     // If the water brightness falls below this (0–2), the water is not rendered.
#define COMBINED_AVG_THRESHOLD      1.25     // If water+highlights are below this (0–2), the opacity is reduced.
#define WATER_OPACITY_MULTIPLIER    0.8     // Scales opacity when below threshold (0–1).

#define SHOW_WATER_LAYER_1
#define SHOW_WATER_LAYER_2
#define SHOW_WATER_HIGHLIGHTS_1
#define SHOW_WATER_HIGHLIGHTS_2
#define SHOW_BACKGROUND

vec2 pixelate_and_zoom_uv(vec2 frag_coord, vec2 res, vec2 virtual_res, float zoom_factor);
vec2 pixelate_uv(vec2 uv, vec2 res, vec2 virtual_res);
vec2 zoom_uv(vec2 uv, float zoom_factor);
vec3 get_turbulence_background(vec2 uv);
vec2 warp_background_uv(vec2 uv);
float avg(vec4 color) { return (color.r + color.g + color.b) / 3.0; }

vec2 get_uv(vec2 frag_coord);
vec4 get_water_layer_1(vec2 scaled_uv);
vec4 get_water_layer_2(vec2 scaled_uv);
vec4 get_water_highlights_1(vec2 scaled_uv);
vec4 get_water_highlights_2(vec2 scaled_uv);
vec4 get_texture_background(vec2 uv, vec4 water);
vec3 get_merged_background(vec2 uv, vec4 water_layer);
float get_final_opacity(vec4 water_layer_1, vec4 water_layer_2, vec4 water_highlights_1, vec4 water_highlights_2);

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = get_uv(frag_coord);
    vec2 scaled_uv = uv * CAUSTIC_SCALE;

    //TODO: Idk how macros work, but i like this better visually, define defaults first.
    vec4 water_layer_1 = vec4(0.0);
    vec4 water_layer_2 = vec4(0.0);
    vec4 water_highlights_1 = vec4(0.0);
    vec4 water_highlights_2 = vec4(0.0);
    vec3 background = vec3(0.0);

    #ifdef SHOW_WATER_LAYER_1
       water_layer_1 = get_water_layer_1(scaled_uv);
    #endif
    #ifdef SHOW_WATER_LAYER_2
        water_layer_2 = get_water_layer_2(scaled_uv);
    #endif
    #ifdef SHOW_WATER_HIGHLIGHTS_1
        water_highlights_1 = get_water_highlights_1(scaled_uv);
    #endif
    #ifdef SHOW_WATER_HIGHLIGHTS_2
        water_highlights_2 = get_water_highlights_2(scaled_uv);
    #endif
    #ifdef SHOW_BACKGROUND
       background = get_merged_background(uv, water_layer_1);
    #endif

    float final_opacity = get_final_opacity(
        water_layer_1,
        water_layer_2,
        water_highlights_1,
        water_highlights_2
    );

    frag_color = (water_layer_1 + water_layer_2) * final_opacity + vec4(background, 1.0);
}

void main() { 
    mainImage(gl_FragColor, gl_FragCoord.xy); 
}

vec2 pixelate_and_zoom_uv(vec2 frag_coord, vec2 res, vec2 virtual_res, float zoom_factor) {
    vec2 uv = frag_coord / res;
    vec2 pixel_uv = pixelate_uv(uv, res, virtual_res);
    return zoom_uv(pixel_uv, zoom_factor);
}

vec2 pixelate_uv(vec2 uv, vec2 res, vec2 virtual_res) {
    vec2 scaled = uv * res;
    vec2 factor = virtual_res / res;
    return (floor(scaled * factor) / factor) / res;
}

vec2 zoom_uv(vec2 uv, float zoom_factor) { 
    return uv * zoom_factor; 
}

vec3 get_turbulence_background(vec2 uv) {
    float t_time = iTime * TURBULENCE_TIME_SCALE + TURBULENCE_TIME_OFFSET;
    vec2 p = mod(uv * TAU, TAU) - 250.0;
    vec2 tmp = p;
    float c = 1.0;
    for (int n = 0; n < MAX_ITER; n++) {
        float t = t_time * (1.0 - (TURBULENCE_ITER_SCALE / float(n + 1)));
        tmp = p + vec2(cos(t - tmp.x) + sin(t + tmp.y), sin(t - tmp.y) + cos(t + tmp.x));
        c += 1.0 / length(vec2(p.x / (sin(tmp.x + t) / TURBULENCE_INTENSITY), p.y / (cos(tmp.y + t) / TURBULENCE_INTENSITY)));
    }
    c = TURBULENCE_BASE - pow(c / float(MAX_ITER), TURBULENCE_EXPONENT);
    vec3 col = vec3(pow(abs(c), TURBULENCE_POWER));
    return clamp(col + TURBULENCE_TINT, 0.0, 1.0);
}

vec2 warp_background_uv(vec2 uv) {
    uv.x += WARP_AMPLITUDE_X * sin(uv.y * WARP_FREQUENCY_Y + iTime * WARP_SPEED);
    uv.y += WARP_AMPLITUDE_Y * cos(uv.x * WARP_FREQUENCY_X + iTime * WARP_SPEED);
    return fract(uv);
}

vec2 get_uv(vec2 frag_coord) {
    vec2 res = iResolution.xy;
    vec2 virtual_res = vec2(VIRTUAL_RES_X, VIRTUAL_RES_Y);
    return pixelate_and_zoom_uv(frag_coord, res, virtual_res, ZOOM_FACTOR);
}

vec4 get_water_layer_1(vec2 scaled_uv) {
    float water_layer_1_time = iTime * WATER1_TIME_MULTIPLIER * WATER_SPEED;
    vec2 water_layer_1_uv = scaled_uv + water_layer_1_time + WATER1_OFFSET;
    return texture(iChannel0, water_layer_1_uv);
}

vec4 get_water_layer_2(vec2 scaled_uv) {
    vec2 water_layer_2_time = iTime * WATER_SPEED * vec2(WATER2_TIME_OFFSET_X, WATER2_TIME_OFFSET_Y);
    vec2 water_layer_2_uv = scaled_uv + water_layer_2_time + WATER2_OFFSET;
    return texture(iChannel0, water_layer_2_uv);
}

vec4 get_water_highlights_1(vec2 scaled_uv) {
    vec2 highlight1_time = iTime * WATER_SPEED / vec2(HIGHLIGHT_OFFSET_X1, HIGHLIGHT_OFFSET_Y1);
    vec2 highlight1_uv = scaled_uv + highlight1_time;
    return texture(iChannel2, highlight1_uv);
}

vec4 get_water_highlights_2(vec2 scaled_uv) {
    vec2 highlight2_time = iTime * WATER_SPEED / vec2(HIGHLIGHT_OFFSET_X2, HIGHLIGHT_OFFSET_Y2);
    vec2 highlight2_uv = scaled_uv + highlight2_time;
    return texture(iChannel2, highlight2_uv);
}

vec4 get_texture_background(vec2 uv, vec4 water_layer) {
    vec2 bg_offset = uv + avg(water_layer) * BACKGROUND_OFFSET_FACTOR;
    vec2 bg_uv = warp_background_uv(bg_offset);
    return texture(iChannel1, bg_uv);
}

vec3 get_merged_background(vec2 uv, vec4 water_layer) {
    vec4 tex_background = get_texture_background(uv, water_layer);
    vec3 turb_bg = get_turbulence_background(uv);
    //vec3 turb_bg = vec3(0.0);
    return mix(turb_bg, tex_background.rgb, BACKGROUND_BLEND_FACTOR);
}

float get_final_opacity(vec4 water_layer_1, vec4 water_layer_2, vec4 water_highlights_1, vec4 water_highlights_2) {
    float water_avg = avg(water_layer_1 + water_layer_2);
    float combined_avg = avg(water_layer_1 + water_layer_2 + water_highlights_1 + water_highlights_2);
    return water_avg < WATER_AVG_THRESHOLD ? 0.0 : combined_avg < COMBINED_AVG_THRESHOLD ? WATER_OPACITY_MULTIPLIER * WATER_OPACITY : WATER_OPACITY;
}
