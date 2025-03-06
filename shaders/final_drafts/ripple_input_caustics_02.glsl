#include "/shaders/common/constants.glsl"

#iChannel3 "file://shaders/buffers/finite_approx_ripple_buffer.glsl"

// debug macros
#define PIXELATE_UV
#define SHOW_NOISE_DISP_MAP_1
#define SHOW_NOISE_DISP_MAP_2
#define SHOW_CAUSTICS_DISP_MAP_1
#define SHOW_CAUSTICS_DISP_MAP_2
#define SHOW_BACKGROUND
#define RIPPLE_EFFECT

vec4 sample_disp_map(sampler2D tex, vec2 uv, vec2 velocity, vec2 positional_offset, float intensity_factor);
vec4 sample_background_with_disp_map(sampler2D tex, vec2 uv, vec4 disp_map, float warp_factor);
vec2 compute_ripple_offset(vec2 uv);
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

    #ifdef RIPPLE_EFFECT
        uv += compute_ripple_offset(uv);
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
        //basic dicplacement map integration
        background = sample_background_with_disp_map(iChannel1, uv, noise_disp_map_1, BACKGROUND_DISP_WARP_FACTOR);
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

//BASIC DISPLACEMENT MAP EXAMPLE INTEGRATION WITHOUT SCROLLING
vec4 sample_background_with_disp_map(
    sampler2D tex, 
    vec2 uv, 
    vec4 disp_map, 
    float warp_factor
) {
    vec2 bg_uv = uv + (disp_map.r * warp_factor);
    return texture(tex, bg_uv);
}

//TODO: THESE ARE MAYBE FUN TO FUCK WITH WITH AUDIO INPUT
#define NORMAL_SAMPLE_OFFSET     0.01 // How far we sample around uv to find local slope
#define NORMAL_Z_SCALE           1.0  // Multiplier for the Z component in the normal
#define AIR_REFRACTION_INDEX     1.0     
#define WATER_REFRACTION_INDEX   1.08      
#define REFRACTION_INDEX_RATIO   (AIR_REFRACTION_INDEX/ WATER_REFRACTION_INDEX) // For water ~0.75. Try (1.0 / 1.5)=~0.67 (glass), (1.0 / 2.4)=~0.42 (diamond), etc.
#define INCIDENT_DIRECTION       vec3(0.0, 0.0, -1.0) // "Camera is looking down" direction

vec2 compute_ripple_offset(vec2 uv) {
    // Wave simulation buffer (iChannel3) only stores a single "height" channel;
    // we sample neighbors here to derive slope (dX, dY).
    // The wave pass might use a different neighbor step (e.g. "EFFECTIVE_SAMPLE_STEP");
    // we choose NORMAL_SAMPLE_OFFSET here purely for rendering normals.
    float height_center = texture(iChannel3, uv).r;  // Might be unused if we only use neighbors
    float height_left   = texture(iChannel3, uv - vec2(NORMAL_SAMPLE_OFFSET, 0.0)).r;
    float height_right  = texture(iChannel3, uv + vec2(NORMAL_SAMPLE_OFFSET, 0.0)).r;
    float height_up     = texture(iChannel3, uv + vec2(0.0, NORMAL_SAMPLE_OFFSET)).r;
    float height_down   = texture(iChannel3, uv - vec2(0.0, NORMAL_SAMPLE_OFFSET)).r;
    float d_x = height_right - height_left;
    float d_y = height_up    - height_down;
    // --- 2. Build a 3D normal vector. 
    // Notice we multiply the Z part by NORMAL_Z_SCALE * NORMAL_SAMPLE_OFFSET
    // so we can control how "tilted" the surface is.
    vec3 raw_normal = vec3(d_x, d_y, NORMAL_Z_SCALE * NORMAL_SAMPLE_OFFSET);
    vec3 surface_normal = normalize(raw_normal);
    // --- 3. Refract the "incident direction" through this normal
    vec3 refracted = refract(INCIDENT_DIRECTION, surface_normal, REFRACTION_INDEX_RATIO);
    return refracted.xy;
}

// vec4 sample_background_with_height_map(sampler2D background_tex, vec2 uv) {
//     vec2 bg_uv = uv + refracted_offset;
//     return texture(background_tex, bg_uv);
// }

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
