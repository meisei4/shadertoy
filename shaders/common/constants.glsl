#ifndef CONSTS_GLSL
#define CONSTS_GLSL

#define USE_VSCODE
#ifdef USE_VSCODE
    #iChannel0 "file://assets/textures/gray_noise_small.png"  // noise displacement map (red channel)
    #iChannel1 "file://assets/textures/rocks.jpg"             // background texture (full-color)
    #iChannel2 "file://assets/textures/pebbles.png"           // caustics displacement map (red channel)
#endif

//FINITE APPOX CONSTANTS:
#define BASE_HEIGHT 0.0 // Equilibrium height of the water surface. Domain: ℝ, Units: Height units. Controls the baseline water level.
#define DAMPING_FACTOR 0.98 // Energy retention per frame. Domain: (0,1] ⊂ ℝ, Units: Scalar multiplier. Higher = longer-lasting waves.
#define SAMPLE_OFFSET_DISTANCE 5e-3 // Neighbor sampling offset. Domain: ℝ⁺, Units: UV space [0,1]. Smaller = sharper waves, larger = smoother
#define MOUSE_IMPACT_SCALAR -0.015 // Mouse displacement strength. Domain: ℝ, Units: Height units/frame. Negative = depression, positive = bump
#define MOUSE_INNER_RADIUS 0.01 // Inner radius of mouse effect. Domain: ℝ⁺, Units: UV distance. Inside this, displacement is full strength.
#define MOUSE_OUTER_RADIUS 0.045 // Outer radius of mouse effect. Domain: ℝ⁺, Units: UV distance. Beyond this, displacement fades to zero
#define NORMAL_SAMPLE_OFFSET 1e-4 // Normal sampling offset for finite difference computation. Domain: ℝ⁺, Units: UV space.
#define REFRACTION_INDEX_RATIO (1.0 / 1.333) // Refractive index ratio (air to water). Domain: ℝ⁺, Units: Scalar. Determines how much light bends
#define WARP_FACTOR 0.00008 // Maximum UV displacement. Domain: ℝ, Units: UV space. Scales the refracted displacement.

//CAUSTIC CONSTANTS:
#define VIRTUAL_DS_RES_X 256.0 // Virtual display resolution width for DS resolution; recommended range: 128.0–1024.0.
#define VIRTUAL_DS_RES_Y 192.0 // Virtual display resolution height for DS resolution; recommended range: 128.0–1024.0.

#define ZERO_POSITIONAL_OFFSET          vec2(0.0, 0.0)  // No offset
#define NOISE_DISP_MAP_1_INITIAL_OFFSET vec2(-0.1, 0.0) // Initial offset for noise map 1; small values ([-1.0, 1.0]) yield subtle movement.
#define NOISE_DISP_MAP_2_INITIAL_OFFSET vec2( 0.1, 0.0) // Initial offset for noise map 2; small values ([-1.0, 1.0]) yield subtle movement.

#define NOISE_DISP_MAP_1_SCROLL_VELOCITY vec2( 0.02,  0.02) // Scrolling velocity for noise map 1; recommended per component: [-0.1, 0.1] for natural motion.
#define NOISE_DISP_MAP_2_SCROLL_VELOCITY vec2(-0.02, -0.02) // Scrolling velocity for noise map 2; recommended per component: [-0.1, 0.1] for natural motion.

#define CAUSTICS_DISP_MAP_1_SCROLL_VELOCITY vec2(-0.1,  0.01) // Scrolling velocity for caustics map 1; horizontal: [-0.2, 0.2], vertical: [-0.1, 0.1].
#define CAUSTICS_DISP_MAP_2_SCROLL_VELOCITY vec2( 0.1,  0.01) // Scrolling velocity for caustics map 2; horizontal: [-0.2, 0.2], vertical: [-0.1, 0.1].

#define NOISE_DISP_MAP_DIMMING_FACTOR    0.33 // dims the noise texture -> maximum brightness becomes 1/3 where raw = 1.0 (would be white)
#define CAUSTICS_DISP_MAP_DIMMING_FACTOR 0.22 // dims the caustics texture -> maximum brightness becomes 2/9 where raw = 1.0 (would be white)
#define BACKGROUND_DISP_WARP_FACTOR      0.05 // simple warp factor for applying displacement map to background texture

#define BLURRY_ALPHA 0.4 // 40% opacity -> grey overtone (trough areas surrounding the inclining undulations)
#define NORMAL_ALPHA 0.0 // effectively the dark inclines in a wave undulation
#define FULL_ALPHA   4.0 // blast the fuck out of all 4 displacement maps 400% opacity -> white (catching the light at the undulation peaks)

#define NOISE_DISP_INDUCED_INTENSITY_THRESHOLD   0.30 // when noise displacement maps effect > 0.3, show water effect at normal alpha
#define ALL_DISP_MAP_INDUCED_INTENSITY_THRESHOLD 0.75 // when all_brightness > 0.75, show white full alpha
#endif
