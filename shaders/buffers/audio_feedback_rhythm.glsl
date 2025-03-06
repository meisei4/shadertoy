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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float current_overall = compute_audio_amplitude(0.0, 1.0, 32);
    
    // Retrieve the previous history from iChannel1:
    //   prev.r = amplitude from one frame ago
    //   prev.g = amplitude from two frames ago
    //   prev.b = amplitude from three frames ago
    //   prev.a = amplitude from four frames ago
    vec4 prev = texture(iChannel0, vec2(0.5, 0.5));
    // Shift the history:
    // R = current amplitude, G = last frame’s R, B = last frame’s G, A = last frame’s B.
    vec4 history = vec4(current_overall, prev.r, prev.g, prev.b);
    
    if (uv.x >= EQ_AREA_END_X) {
        // Fetch the four frames of amplitudes (current + 3 previous)
        // For a simple smoothing, average all four:
        float smoothed = (history.r + history.g + history.b + history.a) / 4.0;
        // Draw a white bar whose height is smoothed amplitude
        fragColor = (uv.y < smoothed) ? WHITE : vec4(0.0);
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
