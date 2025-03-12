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
// EFFECTIVE DOMAIN: [5.0, 20.0]
#define UPDATE_INTERVAL_FRAMES 10.0 // number of frames per envelope line update, controls how fast the lines update across the isometric time dimension
// EFFECTIVE DOMAIN: [0.1, 1.0]
#define ENVELOPE_SMOOTHING_FACTOR 0.2 // percent of how much of the newly ACCUMULATED amplitudes get applied to the "envelope" (line shapes) per history update

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
    vec2 previous_wave_signal_index_offset = vec2(0.0, wave_signal_vertical_index);
    vec2 target_previous_wave_signal = uv + previous_wave_signal_index_offset;
    return texture(iChannel0, target_previous_wave_signal);
}

vec4 update_envelope_history(vec2 uv) {
    float iFrame_f = float(iFrame);
    float update_progress = mod(iFrame_f, UPDATE_INTERVAL_FRAMES) / UPDATE_INTERVAL_FRAMES;
    float bin_index = floor(uv.x * NUM_BINS);
    float new_envelope = compute_envelope_for_audio_bin(bin_index);
    float prev_envelope = texture(iChannel0, uv).r;
    float blend = update_progress * ENVELOPE_SMOOTHING_FACTOR;
    float final_envelope = mix(prev_envelope, new_envelope, blend);
    return vec4(final_envelope, final_envelope, final_envelope, TOTAL_CANVAS_HEIGHT);
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