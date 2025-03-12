#include "/shaders/common/audio_plotting.glsl"
#iChannel0 "file://shaders/buffers/audio_feedback_envelope.glsl" // TODO: FEEDBACK BUFFERS ONLY EVER WORK ON CHANNEL0!!!!

#define LINE_RENDER_MARGIN 0.50        // amount of thickness (in fragment size/single pixel) that surrounds both sides of the wave signal lines
#define MAX_DISTANCE 1e6               // some stupid number to just initialize the min distance to closest wave signal logic

#define WHITE vec4(1.0, 1.0, 1.0, 1.0)
#define BLACK vec4(0.0, 0.0, 0.0, 1.0)

float min_distance_to_nearby_isometric_wave_signals(vec2 frag_coord);
bool is_frag_coord_within_wave_signal_line_margin(float min_distance_to_nearby_isometric_wave_signals);
float sample_wave_signal_from_envelope_buffer(float bin_index, float wave_signal_vertical_index);

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    float min_distance_to_nearby_isometric_wave_signals = min_distance_to_nearby_isometric_wave_signals(frag_coord);
    if (is_frag_coord_within_wave_signal_line_margin(min_distance_to_nearby_isometric_wave_signals)){
        frag_color = WHITE; // draw the line white
    } else {
        frag_color = BLACK; // draw the background black
    }    
}

float min_distance_to_nearby_isometric_wave_signals(vec2 frag_coord) {
    float nearest_distance_to_nearby_wave_signals = MAX_DISTANCE;
    // Loop over each wave signal (vertical index in the history).
    for (int wave_signal_index = 0; wave_signal_index < int(NUM_HISTORICAL_WAVE_SIGNAL_LINES); wave_signal_index++) {
        float wave_signal_index_f = float(wave_signal_index);

        // For each wave signal, loop through pairs of adjacent bins (line segments).
        for (int bin_index = 0; bin_index < int(NUM_BINS) - 1; bin_index++) {
            float bin_index_f        = float(bin_index);
            float next_bin_index_f   = float(bin_index + 1);

            // Fetch envelope amplitude for this bin and its neighbor 
            float current_envelope_val  = sample_wave_signal_from_envelope_buffer(bin_index_f, wave_signal_index_f);
            float neighbor_envelope_val = sample_wave_signal_from_envelope_buffer(next_bin_index_f, wave_signal_index_f);
            
            // Construct 3D coordinates (bin, amplitude, wave_signal_index).
            vec3 current_envelope_data  = vec3(bin_index_f, current_envelope_val,  wave_signal_index_f);
            vec3 neighbor_envelope_data = vec3(next_bin_index_f, neighbor_envelope_val, wave_signal_index_f);
            
            // Project both points into 2D isometric space.
            vec2 projected_current  = project_isometric(current_envelope_data);
            vec2 projected_neighbor = project_isometric(neighbor_envelope_data);
            
            // Compute how close frag_coord is to this line segment in isometric space.
            vec2 line_segment_vector  = projected_neighbor - projected_current;
            float segment_length_squared = dot(line_segment_vector, line_segment_vector);
            
            float projection_factor = dot(frag_coord - projected_current, line_segment_vector) / segment_length_squared;
            float line_segment_param = clamp(projection_factor, 0.0, 1.0);
            
            vec2 nearest_point_on_line = projected_current + line_segment_param * line_segment_vector;
            float distance_to_nearest_point = distance(frag_coord, nearest_point_on_line);
            
            nearest_distance_to_nearby_wave_signals = min(nearest_distance_to_nearby_wave_signals, distance_to_nearest_point);
        }
    }
    return nearest_distance_to_nearby_wave_signals;
}

bool is_frag_coord_within_wave_signal_line_margin(float min_distance_to_nearby_isometric_wave_signals) {
    // Multiply margin by 2.0 because the margin is pushed out from both sides of the line that makes up the projected wave signal coordinates
    return min_distance_to_nearby_isometric_wave_signals < LINE_RENDER_MARGIN * 2.0;
}

float sample_wave_signal_from_envelope_buffer(float bin_index, float wave_signal_vertical_index){
    float sample_offset = 0.5; // TODO: this eliminates the sampling issues on the edges of the line
    // horizontal sampling normalization
    float normalized_bin_index = (bin_index + sample_offset) / NUM_BINS;
    // normalize and flip the order of the wave signals to have the "closest signal"/bottom signal be the first signal in the history 
    float normalized_wave_signal_index = TOTAL_CANVAS_HEIGHT - ((wave_signal_vertical_index + sample_offset) / NUM_HISTORICAL_WAVE_SIGNAL_LINES);
    // essentially this is the abstract sampling of the envelope buffer to get:
    // horizontal data = current location in the audio bin (the amplitudes that make up the individual lines)
    // vertical data = current wave signal that will be updated/drawn to the screen (index in the envelopes discrete history)
    vec2 uv = vec2(normalized_bin_index, normalized_wave_signal_index);
    return texture(iChannel0, uv).r;
}
