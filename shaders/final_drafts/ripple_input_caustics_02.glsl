#include "/shaders/common/constants.glsl"

#iChannel3 "file://shaders/buffers/finite_approx_ripple_buffer.glsl"

// debug macros
#define PIXELATE_UV
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
    float height = texture(iChannel3, uv).r;
    
    // TODO: Compute normal vector using finite differences in the X and Y directions????????
    vec3 normal = normalize(vec3(
        texture(iChannel3, uv + vec2(NORMAL_SAMPLE_OFFSET, 0.0)).r - texture(iChannel3, uv - vec2(NORMAL_SAMPLE_OFFSET, 0.0)).r, 
        texture(iChannel3, uv + vec2(0.0, NORMAL_SAMPLE_OFFSET)).r - texture(iChannel3, uv - vec2(0.0, NORMAL_SAMPLE_OFFSET)).r, 
        2.0 * NORMAL_SAMPLE_OFFSET
    ));

    // TODO: Compute the UV offset using refractive displacement??????
    vec2 refracted_offset = refract(vec3(0.0, 0.0, -1.0), normal, REFRACTION_INDEX_RATIO).xy;

    vec2 bg_uv = uv + refracted_offset * warp_factor;
    
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
