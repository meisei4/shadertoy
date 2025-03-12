#include "/shaders/common/audio_plotting.glsl"
#iChannel0 "self" // TODO: FEEDBACK BUFFERS ONLY EVER WORK ON CHANNEL0!!!!
#iChannel1 "file://assets/audio/Hellion_v2.ogg"
//#iChannel2 "file://assets/audio/experiment.mp3"

/*
 * Envelope Shader
 *  - Envelope: controlled amplitude profile of the audio (including histories)
 *  - Audio Bin: a group of waveform samples (segements of amplitudes from the waveform data)
 *  - Waveform Data: amplitude data stored in the audio texture's y= 1.0 channel, i.e. values distributed all across the x=0~511 indicies.
 */

// EFFECTIVE DOMAIN: [128.0, 512.0] 
#define TOTAL_WAVEFORM_SAMPLES 512.0 // number of x-axis values read from the audio texture (at y=1.0) (max is actually 512 according to shadertoy)
// EFFECTIVE DOMAIN: {1.0}
#define WAVEFORM_DATA_COORD_Y 1.0 // fixed Y coordinate for sampling waveform data from audio texture
// EFFECTIVE DOMAIN: [0.1, 1.0]
//#define ENVELOPE_SMOOTHING_FACTOR 0.05 // percent of how much of the newly ACCUMULATED amplitudes get applied to the "envelope" (line shapes) per history update
// Define a macro for propagation speed (adjust the value as needed)
#define PROPAGATION_SPEED 0.00015

#define AUDIO_BIN_SAMPLE_COUNT (TOTAL_WAVEFORM_SAMPLES / NUM_BINS) // how many waveform x-values are grouped together to form each bin’s envelope value 

vec4 sample_previous_wave_signal(vec2 uv, float wave_signal_vertical_index);
vec4 update_envelope_history(vec2 uv);
float compute_envelope_for_audio_bin(float bin_index);

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    // Each historical row index (of the 5 wave signal lines) occupies an equal portion of the vertical display
    // this is just which line is targetted in the 1~5 lines
    float wave_signal_vertical_index = TOTAL_CANVAS_HEIGHT / NUM_HISTORICAL_WAVE_SIGNAL_LINES;
    // The bottom row (highest y-values) is where new envelope values are drawn
    // If the current fragment is not in the bottom row, draw the history through the line
    if (uv.y < TOTAL_CANVAS_HEIGHT - wave_signal_vertical_index) {
        frag_color = sample_previous_wave_signal(uv, wave_signal_vertical_index);
        return;
    }
    // otherwise update the histories
    frag_color = update_envelope_history(uv);
}

vec4 sample_previous_wave_signal(vec2 uv, float wave_signal_vertical_index) {
    // Calculate an offset based on iTime and the defined propagation speed.
    float offset = PROPAGATION_SPEED * iTime;
    vec2 previous_wave_signal_index_offset = vec2(0.0, wave_signal_vertical_index * offset);
    vec2 target_previous_wave_signal = uv + previous_wave_signal_index_offset;
    return texture(iChannel0, target_previous_wave_signal);
}

//TODO: you messed up now you have to figure out all this crazy shit later good job idiot
//TODO: refactor this to make sure that you have true control over the smoothness of the waves, and how fast they propagate in the history
// Suggested smoothing factors (tweak these until you get the desired effect)
// SLOW_SMOOTHING controls how quickly the overall envelope adapts (small values → very slow changes)
// FAST_SMOOTHING controls the fast transient contribution (higher values react quickly)
#define SLOW_SMOOTHING 0.05  
#define FAST_SMOOTHING 0.25
// A threshold to decide when to let fast transients show through
#define TRANSIENT_THRESHOLD 0.1

vec4 update_envelope_history(vec2 uv) {
    float bin_index = floor(uv.x * NUM_BINS);
    float newEnv = compute_envelope_for_audio_bin(bin_index);
    vec4 history = texture(iChannel0, uv);

    // Compute the overall (slow) and fast transient parts.
    float overall = mix(history.r, newEnv, SLOW_SMOOTHING);
    float fast    = mix(history.g, newEnv, FAST_SMOOTHING);
    float delta   = fast - overall;
    float transient = (abs(delta) > TRANSIENT_THRESHOLD) ? delta : 0.0;
    float finalEnvelope = overall + transient;

    // Shift the history:
    // New envelope becomes red, previous red -> green, green -> blue, blue -> alpha.
    return vec4(finalEnvelope, history.r, history.g, history.b);
}

float compute_envelope_for_audio_bin(float bin_index) {
    float total_amplitude = 0.0;
    for (int i = 0; i < int(AUDIO_BIN_SAMPLE_COUNT); i++) {
        float i_f = float(i);
        float sample_coord_x = (bin_index * AUDIO_BIN_SAMPLE_COUNT + i_f) / TOTAL_WAVEFORM_SAMPLES;
        vec2 sample_coords = vec2(sample_coord_x, WAVEFORM_DATA_COORD_Y);
        float sample_amplitude = texture(iChannel1, sample_coords).r;
        total_amplitude += abs(sample_amplitude);
    }
    return total_amplitude / AUDIO_BIN_SAMPLE_COUNT;
}