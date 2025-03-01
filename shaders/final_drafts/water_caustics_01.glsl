#include "/shaders/common/constants.glsl"

// debug macros
//#define PIXELATE_UV
#define SHOW_NOISE_DISP_MAP_1
#define SHOW_NOISE_DISP_MAP_2
#define SHOW_CAUSTICS_DISP_MAP_1
#define SHOW_CAUSTICS_DISP_MAP_2
#define SHOW_BACKGROUND

vec4 sample_disp_map(sampler2D tex, vec2 uv, vec2 velocity, vec2 positional_offset, float intensity_factor);
vec4 sample_background_with_disp_map(sampler2D tex, vec2 uv, vec4 disp_map, float warp_factor); // This best demonstrates fundamental displacement map concept
float compute_effective_opacity(vec4 noise_disp_map_1, vec4 noise_disp_map_2, vec4 caustics_disp_map_1, vec4 caustics_disp_map_2);   
vec2 scroll_displacement_map(vec2 uv, vec2 velocity, vec2 positional_offset); 
vec2 pixelate_uv(vec2 uv);

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    vec4 noise_disp_map_1 = vec4(0.0);
    vec4 noise_disp_map_2 = vec4(0.0);
    vec4 caustics_disp_map_1 = vec4(0.0);
    vec4 caustics_disp_map_2 = vec4(0.0);
    vec4 background = vec4(0.0);

    #ifdef PIXELATE_UV
        uv = pixelate_uv(uv);
    #endif

    #ifdef SHOW_NOISE_DISP_MAP_1
        noise_disp_map_1 = sample_disp_map(
            iChannel0, uv, 
            NOISE_DISP_MAP_1_SCROLL_VELOCITY, 
            NOISE_DISP_MAP_1_INITIAL_OFFSET, 
            NOISE_DISP_MAP_DIMMING_FACTOR
        );
    #endif

    #ifdef SHOW_NOISE_DISP_MAP_2
        noise_disp_map_2 = sample_disp_map(
            iChannel0, uv, 
            NOISE_DISP_MAP_2_SCROLL_VELOCITY, 
            NOISE_DISP_MAP_2_INITIAL_OFFSET, 
            NOISE_DISP_MAP_DIMMING_FACTOR
        );
    #endif

    #ifdef SHOW_CAUSTICS_DISP_MAP_1
        caustics_disp_map_1 = sample_disp_map(
            iChannel2, uv, 
            CAUSTICS_DISP_MAP_1_SCROLL_VELOCITY, 
            ZERO_POSITIONAL_OFFSET, 
            CAUSTICS_DISP_MAP_DIMMING_FACTOR
        );
    #endif

    #ifdef SHOW_CAUSTICS_DISP_MAP_2
        caustics_disp_map_2 = sample_disp_map(
            iChannel2, uv, 
            CAUSTICS_DISP_MAP_2_SCROLL_VELOCITY, 
            ZERO_POSITIONAL_OFFSET, 
            CAUSTICS_DISP_MAP_DIMMING_FACTOR
        );
    #endif

    #ifdef SHOW_BACKGROUND
        background = sample_background_with_disp_map(
            iChannel1, uv, 
            noise_disp_map_1, 
            BACKGROUND_DISP_WARP_FACTOR
        );
    #endif

    float alpha = compute_effective_opacity(
        noise_disp_map_1, 
        noise_disp_map_2, 
        caustics_disp_map_1, 
        caustics_disp_map_2
    );

    frag_color = (noise_disp_map_1 + noise_disp_map_2) * alpha + background;
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}

/*
Caustic Effect Domain & Displacement Map Sampling Summary:

1. Displacement Map Sampling & Darkening:
   Each texture pixel is an RGBA vector:
       ┌─────┐
       │  R  │
       │  G  │
       │  B  │
       │  A  │
       └─────┘
   For our grayscale textures:
       R = G = B,  A = 1.0,  with R ∈ [0, 1].

   The function sample_disp_map() samples the red channel and applies a darkening (dimming) factor:
     - For noise maps: fₙ = 0.33, so the effective red value is R_effective = R · 0.33, meaning R_effective ∈ [0, 0.33].
     - For caustics maps: f_c = 0.22, so the effective red value is R_effective = R · 0.22, meaning R_effective ∈ [0, 0.22].

2. Intensity Calculation per Displacement Map:
   • Noise Displacement Maps:
       - Two noise maps are used.
       - For a given pixel, let:
           R₁ ∈ [0, 0.33]  (from noise map 1)
           R₂ ∈ [0, 0.33]  (from noise map 2)
       - Their combined intensity is:
           I_noise = R₁ + R₂,  with I_noise ∈ [0, 0.66].

   • Caustics Displacement Maps:
       - Two caustics maps are used.
       - For a given pixel, let:
           C₁ ∈ [0, 0.22]  (from caustics map 1)
           C₂ ∈ [0, 0.22]  (from caustics map 2)
       - Their combined intensity is:
           I_caustics = C₁ + C₂,  with I_caustics ∈ [0, 0.44].

3. Total Intensity & Thresholds:
   - The overall effective intensity is the sum of noise and caustics contributions:
         I_total = I_noise + I_caustics,  with I_total ∈ [0, 1.10].

   - This intensity determines the final opacity:
         • If I_noise > NOISE_DISP_INDUCED_INTENSITY_THRESHOLD (e.g., 0.30), use NORMAL_ALPHA.
         • If I_total > ALL_DISP_MAP_INDUCED_INTENSITY_THRESHOLD (e.g., 0.75), use FULL_ALPHA.
         • Otherwise, use BLURRY_ALPHA.
*/

vec4 sample_disp_map(
    sampler2D tex, 
    vec2 uv, 
    vec2 velocity, 
    vec2 positional_offset, 
    float intensity_factor
) {
    vec2 offset_uv = scroll_displacement_map(uv, velocity, positional_offset);
    float noise_value = texture(tex, offset_uv).r; // Single-channel (red)
    float scaled_noise = noise_value * intensity_factor;   // Apply intensity/darkening factor to dim the displacement map (otherwise colors get blown out) 
    return vec4(scaled_noise, scaled_noise, scaled_noise, 1.0);
}

vec4 sample_background_with_disp_map(
    sampler2D tex, 
    vec2 uv, 
    vec4 disp_map, 
    float warp_factor
) {
    vec2 bg_uv = uv + (disp_map.r * warp_factor);
    return texture(tex, bg_uv);
}

float compute_effective_opacity(
    vec4 noise_disp_map_1, 
    vec4 noise_disp_map_2, 
    vec4 caustics_disp_map_1, 
    vec4 caustics_disp_map_2
) {
    //pull out the r channels only (everything is grayscaled) for these intensity summations
    float noise_disp_maps_grayscale_intensity_sum = noise_disp_map_1.r + noise_disp_map_2.r; 
    float all_disp_maps_grayscale_intensity_sum = noise_disp_map_1.r + noise_disp_map_2.r + caustics_disp_map_1.r + caustics_disp_map_2.r;
    
    float alpha = BLURRY_ALPHA; // trough
    
    if (noise_disp_maps_grayscale_intensity_sum > NOISE_DISP_INDUCED_INTENSITY_THRESHOLD) {
         alpha = NORMAL_ALPHA; // incline towards a peak
    }
    if (all_disp_maps_grayscale_intensity_sum > ALL_DISP_MAP_INDUCED_INTENSITY_THRESHOLD) {
         alpha = FULL_ALPHA; // peak
    }
   return alpha;
}

vec2 scroll_displacement_map(vec2 uv, vec2 velocity, vec2 positional_offset) {
    return uv + iTime * velocity + positional_offset;
}

vec2 pixelate_uv(vec2 uv) { 
    return floor(uv * vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y)) / vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y); 
}
