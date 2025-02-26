#iChannel0 "file:///Users/mac/misc_game_dev/shadertoy/textures/gray_noise_small.png" // displacement noise (stored in red)
#iChannel1 "file:///Users/mac/misc_game_dev/shadertoy/textures/rocks.jpg"          // background texture (full-color)
#iChannel2 "file:///Users/mac/misc_game_dev/shadertoy/textures/pebbles.png"        // caustics texture (noise stored in red)

#define VIRTUAL_DS_RES_X 256.0  // desired virtual width
#define VIRTUAL_DS_RES_Y 192.0  // desired virtual height

// Displacement layer 1 initial offset
#define DISP1_INITIAL_OFFSET_X   -0.1   // initial offset along X axis
#define DISP1_INITIAL_OFFSET_Y   0.0    // initial offset along Y axis

// Displacement layer 2 initial offset
#define DISP2_INITIAL_OFFSET_X   0.1    // initial offset along X axis
#define DISP2_INITIAL_OFFSET_Y   0.0    // initial offset along Y axis

// Displacement layer 1 scrolling velocities
#define DISP1_SCROLL_VELOCITY_X   0.02   // layer 1 horizontal scrolling velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)
#define DISP1_SCROLL_VELOCITY_Y   0.02   // layer 1 vertical scrolling velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)

// Displacement layer 2 scrolling velocities
#define DISP2_SCROLL_VELOCITY_X  -0.02   // layer 2 horizontal scrolling velocity
#define DISP2_SCROLL_VELOCITY_Y  -0.02   // layer 2 vertical scrolling velocity

// Caustic layer 1 scrolling velocities
#define CAUSTICS1_SCROLL_VELOCITY_X    -0.1    // layer 1 horizontal caustics velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)
#define CAUSTICS1_SCROLL_VELOCITY_Y    0.01    // layer 1 vertical caustics velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)

// Caustic layer 2 scrolling velocities
#define CAUSTICS2_SCROLL_VELOCITY_X    0.1     // layer 2 horizontal caustics velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)
#define CAUSTICS2_SCROLL_VELOCITY_Y    0.01    // layer 2 vertical caustics velocity (normalized units DEPENDS ON THE TEXTURE SIZE!!)

#define BACKGROUND_DISP_FACTOR           0.05   // background UV offset factor (normalized units DEPENDS ON THE TEXTURE SIZE!!) shifts the background based on displacement

#define DISP_LAYER_DARKENING_FACTOR      0.33   // scales down the brightness of the noise texture -> maximum brightness becomes 1/3 where raw = 1.0 (would be white)
#define CAUSTICS_LAYER_DARKENING_FACTOR  0.22   // scales down the brightness of the caustics texture -> maximum brightness becomes 2/9 where raw = 1.0 (would be white)

#define BASE_ALPHA 0.4   // 40% opacity -> grey overtone
#define FULL_ALPHA 4.0   // blast the fuck out of all 4 displacement layers 400% opacity -> white

#define NOISE_INTENSITY_THRESHOLD             0.30   // when  > 0.3, show water effect at base brightness
#define NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD 0.75   // when all_brightness > 0.75, show full white (caustics) effect

//#define DO_PIXELATION
#define SHOW_DISP_LAYER_1
#define SHOW_DISP_LAYER_2
#define SHOW_CAUSTICS_LAYER_1
#define SHOW_CAUSTICS_LAYER_2
#define SHOW_BACKGROUND

vec4 sample_layer(sampler2D tex, vec2 uv, vec2 velocity, vec2 offset, float intensity_factor);
vec4 sample_disp_layer_1(vec2 uv);   
vec4 sample_disp_layer_2(vec2 uv);     
vec4 sample_caustics_layer_1(vec2 uv);    
vec4 sample_caustics_layer_2(vec2 uv);    
vec4 sample_background(sampler2D tex, vec2 uv, vec4 disp_layer, float offset_factor);
float compute_effective_opacity(vec4 disp1, vec4 disp2, vec4 caustics1, vec4 caustics2);
float average_rgb(vec4 color);            
vec2 pixelate_uv(vec2 uv);              
vec2 scroll_displacement_map(vec2 uv, vec2 velocity, vec2 initial_offset); 

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    //default values for macro control/debugging
    vec4 disp_layer_1 = vec4(0.0);
    vec4 disp_layer_2 = vec4(0.0);
    vec4 caustics_layer_1 = vec4(0.0);
    vec4 caustics_layer_2 = vec4(0.0);
    vec4 background = vec4(0.0);

    #ifdef DO_PIXELATION
        uv = pixelate_uv(uv);
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
        background = sample_background(iChannel1, uv, disp_layer_1, BACKGROUND_DISP_FACTOR);
    #endif

    float alpha = compute_effective_opacity(disp_layer_1, disp_layer_2, caustics_layer_1, caustics_layer_2);
    frag_color = (disp_layer_1 + disp_layer_2) * alpha + background;
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}

vec4 sample_disp_layer_1(vec2 uv) {
    vec2 scroll_velocity = vec2(DISP1_SCROLL_VELOCITY_X, DISP1_SCROLL_VELOCITY_Y);
    vec2 initial_offset = vec2(DISP1_INITIAL_OFFSET_X, DISP1_INITIAL_OFFSET_Y);
    return sample_layer(iChannel0, uv, scroll_velocity, initial_offset, DISP_LAYER_DARKENING_FACTOR);
}

vec4 sample_disp_layer_2(vec2 uv) {
    vec2 scroll_velocity = vec2(DISP2_SCROLL_VELOCITY_X, DISP2_SCROLL_VELOCITY_Y);
    vec2 initial_offset = vec2(DISP2_INITIAL_OFFSET_X, DISP2_INITIAL_OFFSET_Y);
    return sample_layer(iChannel0, uv, scroll_velocity, initial_offset, DISP_LAYER_DARKENING_FACTOR);
}

vec4 sample_caustics_layer_1(vec2 uv) {
    vec2 scroll_velocity = vec2(CAUSTICS1_SCROLL_VELOCITY_X, CAUSTICS1_SCROLL_VELOCITY_Y);
    vec2 initial_offset = vec2(0.0, 0.0);
    return sample_layer(iChannel2, uv, scroll_velocity, initial_offset, CAUSTICS_LAYER_DARKENING_FACTOR);
}

vec4 sample_caustics_layer_2(vec2 uv) {
    vec2 scroll_velocity = vec2(CAUSTICS2_SCROLL_VELOCITY_X, CAUSTICS2_SCROLL_VELOCITY_Y);
    vec2 initial_offset = vec2(0.0, 0.0);
    return sample_layer(iChannel2, uv, scroll_velocity, initial_offset, CAUSTICS_LAYER_DARKENING_FACTOR);
}

/*
 * sample_layer - Samples a single-channel texture (stored in the red channel), applies a scrolling offset, and multiplies the 
 raw texture value by an amplitude (which acts as a "darkening" or intensity-scaling factor).
 *
 * In this shader, we use fractional factors (e.g., 1/3 ≈ 0.33 or 2/9 ≈ 0.22) to
 * reduce the maximum possible intensity of the texture (i.e. "darkening"). For example:
 *
 *   darkening_factor = 0.22  (i.e., 2/9)
 *
 *   Conceptually:
 *        [R]           [0.22]
 *        [G]     x     [0.22]
 *        [B]           [0.22]
 *        [A]           [1.00]
 *
 * Each of R, G, B is multiplied by 0.22, while alpha is set to 1.0 (fully opaque).
 * 
 * This pre-processing ensures the texture's original [0..1] range is "darkened" to
 * a more subtle level (e.g., 0.22 for noise texture or 0.33 for pebble caustics). By choosing different amplitudes for
 * different effects (water vs. caustics), we avoid overly bright or washed-out visuals.
 *
 * #define DISP_LAYER_DARKENING_FACTOR      0.33   // noise layers: 1/3
 * #define CAUSTICS_LAYER_DARKENING_FACTOR  0.22   // caustics layers: 2/9
 */

vec4 sample_layer(sampler2D tex, vec2 uv, vec2 velocity, vec2 offset, float intensity_factor) {
    vec2 offset_uv = scroll_displacement_map(uv, velocity, offset);
    float noise_value = texture(tex, offset_uv).r; // Single-channel (red)
    float scaled_noise = noise_value * intensity_factor;   // Apply intensity/darkening factor to scale brightness down 
    return vec4(scaled_noise, scaled_noise, scaled_noise, 1.0);
}

// Applies basic scrolling displacement layer to the background texture based on a noise texture
vec4 sample_background(sampler2D tex, vec2 uv, vec4 disp_layer, float offset_factor) {
    vec2 bg_uv = uv + (disp_layer.r * offset_factor);
    return texture(tex, bg_uv);
}

/*
================================================================================
                             DOMAIN SUMMARY (MATRICES)
================================================================================
Below is a detailed domain summary for the mean_intensity variables (the variables that decide when the effect is applied)
using matrices to illustrate how the layers are summed and averaged. All layers are grayscale, so R = G = B 
in each vec4 (RGBA) value, and A = 1.0 (opaque).

--------------------------------------------------------------------------------
 1. Displacement Layers Mean Intensity (disp_layers_mean_intensity)
--------------------------------------------------------------------------------

Each displacement layer is a grayscale matrix of vec4 (RGBA) pixels:
               ┌─               ─┐
               │ R11 R12 ... R1n │
  disp1   =    │ G21 G22 ... G2n │   ,   R_ij = G_ij = B_ij ∈ [0, 0.33], A = 1.0
               │ B31 B32 ... B3n │
               │ A41 A42 ... A4n │
               └─               ─┘

               ┌─                  ─┐
               │ R'11 R'12 ... R'1n │
  disp2   =    │ G'21 G'22 ... G'2n │ ,   R'_ij = G'_ij = B'_ij ∈ [0, 0.33], A = 1.0
               │ B'31 B'32 ... B'3n │
               │ A'41 A'42 ... A'4n │
               └─                  ─┘

Summing Displacement Layers:
               ┌─                               ─┐
               │ R11+R'11  R12+R'12 ... R1n+R'1n │
  Sum    =     │ G21+G'21  G22+G'22 ... G2n+G'2n │
               │ B31+B'31  B32+B'32 ... B3n+B'3n │
               │ A41+A'41  A42+A'42 ... A4n+A'4n │
               └─                               ─┘

Max Value per Pixel:
  - Each pixel is a sum of two grayscale values: 
      R_ij + R'_ij
  - Since each value is in [0, 0.33]:
      R_ij + R'_ij ≤ 0.33 + 0.33 = 0.66
  - This applies to all R, G, and B channels since they are equal (grayscale).

Mean Intensity Calculation:
  - Mean intensity is calculated by averaging all pixel values:
      disp_layers_mean_intensity = (1 / (m * n)) * Σ(R_ij + R'_ij)
  - The domain (possible range) of this mean intensity is:
      Domain: [0.0, 0.66]

--------------------------------------------------------------------------------
 2. All Layers Mean Intensity (all_layers_mean_intensity)
--------------------------------------------------------------------------------

Each caustics layer is also a grayscale matrix of vec4 (RGBA) pixels:
               ┌─               ─┐
               │ R11 R12 ... R1n │
  caustics1 =  │ G21 G22 ... G2n │  ,  R_ij = G_ij = B_ij ∈ [0, 0.22], A = 1.0
               │ B31 B32 ... B3n │
               │ A41 A42 ... A4n │
               └─               ─┘

               ┌─                  ─┐
               │ R'11 R'12 ... R'1n │
  caustics2 =  │ G'21 G'22 ... G'2n │ ,  R'_ij = G'_ij = B'_ij ∈ [0, 0.22], A = 1.0
               │ B'31 B'32 ... B'3n │
               │ A'41 A'42 ... A'4n │
               └─                  ─┘

Summing All Layers:
               ┌─                                         ─┐
               │ R11+R'11+R11+R'11  ...  R1n+R'1n+R1n+R'1n │
  Total  =     │ G21+G'21+G21+G'21  ...  G2n+G'2n+G2n+G'2n │
               │ B31+B'31+B31+B'31  ...  B3n+B'3n+B3n+B'3n │
               │ A41+A'41+A41+A'41  ...  A4n+A'4n+A4n+A'4n │
               └─                                         ─┘

Max Value per Pixel:
  - Displacement layers contribute up to:
      R_ij + R'_ij ≤ 0.33 + 0.33 = 0.66
  - Caustics layers contribute up to:
      G_ij + G'_ij ≤ 0.22 + 0.22 = 0.44
  - Maximum value per pixel:
      Total Max = 0.66 (displacement) + 0.44 (caustics) = 1.10
  - This applies to all R, G, and B channels since they are equal (grayscale).

Mean Intensity Calculation:
  - Mean intensity is calculated by averaging all pixel values across layers:
      all_layers_mean_intensity = (1 / (m * n)) * Σ(R_ij + R'_ij + G_ij + G'_ij)
  - The domain (possible range) of this mean intensity is:
      Domain: [0.0, 1.10]

--------------------------------------------------------------------------------
 3. Relation to Thresholds
--------------------------------------------------------------------------------
- disp_layers_mean_intensity is compared to NOISE_INTENSITY_THRESHOLD
  Example: NOISE_INTENSITY_THRESHOLD = 0.30
  Domain: [0.0, 0.66] — 0.30 fits within this range.

- all_layers_mean_intensity is compared to 
  NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD
  Example: NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD = 0.75
  Domain: [0.0, 1.10] — 0.75 fits within this range, allowing it to be 
  exceeded when multiple layers are intense enough.
================================================================================
*/ 

float compute_effective_opacity(vec4 disp1, vec4 disp2, vec4 caustics1, vec4 caustics2) {
    float disp_layers_mean_intensity = average_rgb(disp1 + disp2);
    float all_layers_mean_intensity = average_rgb(disp1 + disp2 + caustics1 + caustics2);
    
    float alpha = BASE_ALPHA;  // Start out with half opaque base effect
    
    // If the first noise texture layers are too intense NEGATE THE EFFECT
    if (disp_layers_mean_intensity > NOISE_INTENSITY_THRESHOLD) {
         alpha = 0.0; // NEGATE THE EFFECT
    }
    // If the combined layers are too intense BLAST EFFECT TO FULL WHITE 
    if (all_layers_mean_intensity > NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD) {
         alpha = FULL_ALPHA; //BLASTS THE EFFECT TO WHITE
    }
    // ^^ the above thresholds are respectively "NEGATE EFFECT" and "APPLY WHITE EFFECT" to achieve unaligned more natural caustics
    // ESSENTIALLY: if we have the first threshold APPLY the 40% opacity effect instead of NEGATE it, the grey layer and the white layer align with eachother and its gross
    return alpha;
}

vec2 scroll_displacement_map(vec2 uv, vec2 velocity, vec2 initial_offest) {
    return uv + iTime * velocity + initial_offest;
}

float average_rgb(vec4 color) { 
    return (color.r + color.g + color.b) / 3.0; 
}

vec2 pixelate_uv(vec2 uv) { 
    return floor(uv * vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y)) / vec2(VIRTUAL_DS_RES_X, VIRTUAL_DS_RES_Y); 
}
