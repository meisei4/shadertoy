#iChannel0 "self"
//#iChannel1 "file://assets/audio/output.ogg"
#iChannel1 "file://assets/audio/Hellion_v2.ogg"

const int BASS_BAR_COUNT      = 2;
const int BASS_SAMPLE_COUNT   = 16;
const int MID_BAR_COUNT       = 8;
const int MID_SAMPLE_COUNT    = 16;
const int TREBLE_BAR_COUNT    = 32;
const int TREBLE_SAMPLE_COUNT = 16;
const float EQ_AREA_START_X   = 0.0;
const float EQ_AREA_END_X     = 0.9;
const float EQ_AREA_WIDTH     = EQ_AREA_END_X - EQ_AREA_START_X;
const float BASS_RATIO        = 0.33;
const float MID_RATIO         = 0.33;
const float TREBLE_RATIO      = 0.34;

const float BASS_FREQ_MIN     = 0.00;
const float BASS_FREQ_MAX     = 0.10;
const float MID_FREQ_MIN      = 0.10;
const float MID_FREQ_MAX      = 0.40;
const float TREBLE_FREQ_MIN   = 0.40;
const float TREBLE_FREQ_MAX   = 1.0;

const vec4 RED    = vec4(1.0, 0.0, 0.0, 1.0);
const vec4 GREEN  = vec4(0.0, 1.0, 0.0, 1.0);
const vec4 BLUE   = vec4(0.0, 0.0, 1.0, 1.0);
const vec4 WHITE  = vec4(1.0, 1.0, 1.0, 1.0);

float compute_audio_amplitude(float frequency_start, float frequency_end, int num_samples);
vec4 render_eq_bar(float normalized_y, float section_relative_x, int bar_count, float freq_min, float freq_max, int sample_count, vec4 bar_color);
vec4 render_eq(vec2 uv);

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    // Normalize coordinates
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    vec2 history_coord = vec2(0.995, 0.995); // or 0.99, 0.99, etc.
    vec4 prev = texture(iChannel0, history_coord);
    
    // Because we stored: R= current amplitude, G= old R, B= old G, A= old B
    // last frame, we can now shift to get new history:
    float current_overall = compute_audio_amplitude(0.0, 1.0, 16);
    vec4 history = vec4(current_overall, prev.r, prev.g, prev.b);
    
    //store history data in the top right fragment of the shader
    if (uv.x >= 0.99 && uv.y >= 0.99) {
        // This pixel becomes our "data storage" for next frame
        fragColor = history;
        return;
    }
    if (uv.x >= EQ_AREA_END_X) {
        // 1) Smooth over 4 frames:
        float smoothed = (history.r + history.g + history.b + history.a) / 4.0;

        // 2) Convert amplitude to decibels in [minDB..maxDB], then clamp:
        float amplitude = clamp(smoothed, 1e-6, 1.0);
        float dB        = 20.0 * log(amplitude);

        float min_dB         = -35.0;
        float max_dB         = 0.0;
        float normalized_DB  = (dB - min_dB) / (max_dB - min_dB);
        normalized_DB        = clamp(normalized_DB, 0.0, 1.0);

        // 3) Apply an S-curve (logistic) to exaggerate mid-range changes:
        float alpha   = 40.0; 
        float s_value  = 1.0 / (1.0 + exp(-alpha * (normalized_DB - 0.5)));
        float bar_height = s_value;
        fragColor = (uv.y < bar_height) ? WHITE : vec4(0.0);
    } else {
        fragColor = render_eq(uv);
    }
}

float compute_audio_amplitude(float frequency_start, float frequency_end, int num_samples) {
    float amplitude_accumulator = 0.0;
    for (int sample_index = 0; sample_index < num_samples; sample_index++) {
        float sample_fraction = (float(sample_index) + 0.5) / float(num_samples);
        float sample_frequency = mix(frequency_start, frequency_end, sample_fraction);
        amplitude_accumulator += texture(iChannel1, vec2(sample_frequency, 0.0)).r;
    }
    return amplitude_accumulator / float(num_samples);
}

vec4 render_eq_bar(float normalized_y, float section_relative_x, int bar_count, float freq_min, float freq_max, int sample_count, vec4 bar_color) {
    int bar_index = int(floor(section_relative_x * float(bar_count)));
    float bar_freq_start = freq_min + (freq_max - freq_min) * (float(bar_index) / float(bar_count));
    float bar_freq_end   = freq_min + (freq_max - freq_min) * (float(bar_index + 1) / float(bar_count));
    float bar_amplitude = compute_audio_amplitude(bar_freq_start, bar_freq_end, sample_count);
    return (normalized_y < bar_amplitude) ? bar_color : vec4(0.0);
}

vec4 render_eq(vec2 uv) {
    float bass_end_x = EQ_AREA_START_X + EQ_AREA_WIDTH * BASS_RATIO;
    float mid_start_x = bass_end_x;
    float mid_end_x = mid_start_x + EQ_AREA_WIDTH * MID_RATIO;
    float treble_start_x = mid_end_x;
    float treble_end_x = EQ_AREA_END_X;
    
    if (uv.x < bass_end_x) {
        float section_relative_x = (uv.x - EQ_AREA_START_X) / (bass_end_x - EQ_AREA_START_X);
        return render_eq_bar(uv.y, section_relative_x, BASS_BAR_COUNT, BASS_FREQ_MIN, BASS_FREQ_MAX, BASS_SAMPLE_COUNT, RED);
    } else if (uv.x < mid_end_x) {
        float section_relative_x = (uv.x - mid_start_x) / (mid_end_x - mid_start_x);
        return render_eq_bar(uv.y, section_relative_x, MID_BAR_COUNT, MID_FREQ_MIN, MID_FREQ_MAX, MID_SAMPLE_COUNT, GREEN);
    } else {
        float section_relative_x = (uv.x - treble_start_x) / (treble_end_x - treble_start_x);
        return render_eq_bar(uv.y, section_relative_x, TREBLE_BAR_COUNT, TREBLE_FREQ_MIN, TREBLE_FREQ_MAX, TREBLE_SAMPLE_COUNT, BLUE);
    }
}
