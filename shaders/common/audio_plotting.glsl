#define NUM_BINS 128.0 // how to subdivide the 512 samples from the waveform data (effectively length of the wave signals data) 
#define NUM_HISTORICAL_WAVE_SIGNAL_LINES 5.0 // how many wave signals to propagate a history for
#define TOTAL_CANVAS_HEIGHT 1.0  //used for flipping the order of the lines

//TODO: properly refactor this whole utility code so that things actually make sense and are customizable
#define AMPLITUDE_SCALE 120.0    // scaling
#define ISOMETRIC_ZOOM 3.0       // more scalling
#define ROW_SPACING 8.0          // again.. a scaling thing
#define HALF_SCREEN 0.5          // Constant 0.5 for centering calculations.

vec2 project(vec3 envelope_data) {
    float bin_index = envelope_data.x;         
    float envelope_value = envelope_data.y;    
    float history_row = envelope_data.z;      
    
    float effective_row = history_row * ROW_SPACING;
    
    float proj_x = bin_index - effective_row;
    float proj_y = (bin_index + effective_row) * HALF_SCREEN - envelope_value * AMPLITUDE_SCALE;
    
    return vec2(proj_x, proj_y) * ISOMETRIC_ZOOM;
}

vec2 compute_envelope_grid_center() {
    float num_bins_minus_one = NUM_BINS - 1.0;
    float num_history_rows_minus_one = NUM_HISTORICAL_WAVE_SIGNAL_LINES - 1.0;
    
    vec2 proj_bottom_left  = project(vec3(0.0, 0.0, 0.0));
    vec2 proj_bottom_right = project(vec3(num_bins_minus_one, 0.0, 0.0));
    vec2 proj_top_left     = project(vec3(0.0, 1.0, num_history_rows_minus_one));
    vec2 proj_top_right    = project(vec3(num_bins_minus_one, 1.0, num_history_rows_minus_one));
    
    vec2 min_corner = min(min(proj_bottom_left, proj_bottom_right), min(proj_top_left, proj_top_right));
    vec2 max_corner = max(max(proj_bottom_left, proj_bottom_right), max(proj_top_left, proj_top_right));
    
    return (min_corner + max_corner) * HALF_SCREEN;
}

vec2 project_isometric(vec3 envelope_data) {
    vec2 raw_proj    = project(envelope_data);
    vec2 grid_center = compute_envelope_grid_center();
    vec2 screen_center = iResolution.xy * HALF_SCREEN;
    return raw_proj + (screen_center - grid_center);
}
