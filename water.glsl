#ifdef GL_ES
precision mediump float;
#endif

#ifdef __VSCODE__  // Only declare for VS Code linter
layout(location = 0) uniform vec3 iResolution;
layout(location = 1) uniform float iTime;
layout(location = 2) uniform float iTimeDelta;
layout(location = 3) uniform int iFrame;
layout(location = 4) uniform vec4 iMouse;
#endif  // This was missing

#define VIRTUAL_RES_X       256.0   // virtual width in pixels
#define VIRTUAL_RES_Y       192.0   // virtual height in pixels

#define ZOOM_FACTOR         1.2     // image is magnification value, 1.0 being base 256x192

#define WAVE_FREQUENCY      8.0     //The wave's spatial frequency radians per UV unit 
#define RETRO_LEVELS        4.0     // The number of discrete levels for retro quantization (dimensionless).

#define ANGLE_SPEED_1       0.1     // radians per second
#define ANGLE_SPEED_2       0.15    // radians per second

#define ANGLE_OFFSET_2      1.0     // radians 

// Time multipliers applied before being adding to the UV
// used to shift the wave computations in the x or y direction (i.e. pixel shift per second)
#define TIME_OFFSET_X_1     0.3    
#define TIME_OFFSET_Y_1    -0.3
#define TIME_OFFSET_X_2    -0.2
#define TIME_OFFSET_Y_2     0.2

#define BASE_COLOR          vec3(0.0, 0.2, 0.4) 
#define HIGHLIGHT_COLOR     vec3(0.7, 0.9, 1.0)

//pixelates fragments based on provided virtual_res and then zooms with a factor of the virtual_res
vec2 pixelate_and_zoom_uv(vec2 frag_coord, vec2 resolution, vec2 virtual_resolution, float zoom_factor);
vec2 pixelate_uv(vec2 uv, vec2 resolution, vec2 virtual_resolution);
vec2 zoom_uv(vec2 uv, float zoom_factor);

// Computes a combined wave interference pattern using rotations, sine/cosine and iTime offsets
float compute_wave_pattern(vec2 uv, float time, float frequency);
float compute_wave_interference(vec2 uv, float time, float frequency, float time_offset_x, float time_offset_y);
vec2 rotate_uv(vec2 uv, float angle);
float mix_waves(float wave1, float wave2, float mix_factor);

// Floors a value to a discrete number of levels, then applies a power function: 'levels' is a count of steps
vec3 compute_color_operations(float wave_value);
float retro_quantize(float value, float levels);
vec3 mix_colors(vec3 color_a, vec3 color_b, float factor);

float compute_wave_pattern_1(vec2 uv, float time, float frequency);
vec2 distortUV(vec2 uv, float time);
float causticSpot(vec2 uv, vec2 center, float radius);
float fbm(vec2 p);
float noise(vec2 p);

// MAIN SHADERTOY ENTRY FUNCTION
void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 final_uv = pixelate_and_zoom_uv(frag_coord, iResolution.xy, vec2(VIRTUAL_RES_X, VIRTUAL_RES_Y), ZOOM_FACTOR);
    
    float combined_wave = compute_wave_pattern_1(final_uv, iTime, WAVE_FREQUENCY);
    
    vec3 final_color = compute_color_operations(combined_wave);
    
    frag_color = vec4(final_color, 1.0);
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
    vec2 pixelated = floor(scaled * (virtual_resolution / resolution)) / (virtual_resolution / resolution);
    return pixelated / resolution;
}

vec2 zoom_uv(vec2 uv, float zoom_factor) {
    return uv * zoom_factor;
}

float compute_wave_pattern(vec2 uv, float time, float frequency) {
    float angle1 = time * ANGLE_SPEED_1;
    vec2 rotated_uv1 = rotate_uv(uv, angle1);
    float wave_pattern_1 = compute_wave_interference(rotated_uv1, time, frequency, TIME_OFFSET_X_1, TIME_OFFSET_Y_1);

    float angle2 = time * ANGLE_SPEED_2 + ANGLE_OFFSET_2;
    vec2 rotated_uv2 = rotate_uv(uv, angle2);
    float wave_pattern_2 = compute_wave_interference(rotated_uv2, time, frequency, TIME_OFFSET_X_2, TIME_OFFSET_Y_2);

    float base_wave = mix_waves(wave_pattern_1, wave_pattern_2, 0.5);
    //return base_wave;

    //TODO: NOISE STUFF IS NOT THAT GOOD, IT DOESNT CONTROL PATTERN, ONLY SHAPE OUTLINES
    float noiseScale = 0.01;
    float noiseBlend  = 0.001; 
    float noiseValue = fbm(uv * noiseScale + time * 0.01);
    return mix(base_wave, noiseValue, noiseBlend);
}

//TODO: This is where to start next time, focus on the blobs/caustic spots, these look promising
float compute_wave_pattern_1(vec2 uv, float time, float frequency) {
    vec2 distortedUV = distortUV(uv, time);
    
    float angle1 = time * ANGLE_SPEED_1;
    vec2 rotated_uv1 = rotate_uv(distortedUV, angle1);
    float wave_pattern_1 = compute_wave_interference(rotated_uv1, time, frequency, TIME_OFFSET_X_1, TIME_OFFSET_Y_1);

    float angle2 = time * ANGLE_SPEED_2 + ANGLE_OFFSET_2;
    vec2 rotated_uv2 = rotate_uv(distortedUV, angle2);
    float wave_pattern_2 = compute_wave_interference(rotated_uv2, time, frequency, TIME_OFFSET_X_2, TIME_OFFSET_Y_2);

    float base_wave = mix_waves(wave_pattern_1, wave_pattern_2, 0.5);
    
    float blobEffect = 0.0;
    vec2 center1 = vec2(fract(sin(time + 1.0)*43758.5453), fract(cos(time + 1.0)*12345.6789));
    vec2 center2 = vec2(fract(sin(time + 2.0)*43758.5453), fract(cos(time + 2.0)*12345.6789));
    blobEffect += causticSpot(distortedUV, center1, 0.1);
    blobEffect += causticSpot(distortedUV, center2, 0.12);
    blobEffect = clamp(blobEffect, 0.0, 1.0);
    
    float finalPattern = mix(base_wave, blobEffect, 0.3);
    
    finalPattern = step(0.5, finalPattern);
    
    return finalPattern;
}

vec2 distortUV(vec2 uv, float time) {
    float offsetX = fbm(uv * 2.0 + time * 0.1) * 0.05;
    float offsetY = fbm(uv * 2.0 - time * 0.1) * 0.05;
    return uv + vec2(offsetX, offsetY);
}

float causticSpot(vec2 uv, vec2 center, float radius) {
    float d = distance(uv, center);
    return 1.0 - smoothstep(radius * 0.8, radius, d);
}

float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 1.0;
    for (int i = 0; i < 4; i++) {
        total += noise(p) * amplitude;
        p *= 2.0;
        amplitude *= 0.5;
    }
    return total;
}

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}

float compute_wave_interference(vec2 uv, float time, float frequency, float time_offset_x, float time_offset_y) {
    float wave_a = sin((uv.x + time * time_offset_x) * frequency);
    float wave_b = cos((uv.y + time * time_offset_y) * frequency);
    return (wave_a * wave_b) * 0.5 + 0.5;
}

vec2 rotate_uv(vec2 uv, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    mat2 rotation_matrix = mat2(c, -s, s, c);
    return rotation_matrix * uv;
}

float mix_waves(float wave1, float wave2, float mix_factor) {
    return mix(wave1, wave2, mix_factor);
}


vec3 compute_color_operations(float wave_value) {
    float retro_value = retro_quantize(wave_value, RETRO_LEVELS);
    return mix_colors(BASE_COLOR, HIGHLIGHT_COLOR, retro_value);
}

float retro_quantize(float value, float levels) {
    float quantized = floor(value * levels) / levels;
    return pow(quantized, 2.0);
}

vec3 mix_colors(vec3 color_a, vec3 color_b, float factor) {
    return mix(color_a, color_b, factor);
}
