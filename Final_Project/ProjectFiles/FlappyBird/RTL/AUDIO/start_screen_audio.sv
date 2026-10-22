// Little Wings: one plucked voice, 32 VGA frames per beat, 16 bars per loop.
// Note instructions drive a 24-bit phase accumulator and one 256-entry wave.
// The 16 kHz synthesizer shares the existing 16-bit codec and KEY3 volume path.
module start_screen_audio #(
    parameter int CLK_FREQ = 31_500_000
)(
    input  logic               clk,
    input  logic               resetN,
    input  logic [1:0]         game_state,
    input  logic               startOfFrame,
    output logic signed [15:0] audio_out
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam int SAMPLE_RATE = 16_000;
localparam logic [15:0] SUSTAIN_Q16 = 16'd53739; // 82%, instead of fading notes almost to silence.
function automatic int rate_gcd(input int a, input int b);
    int remainder;
    begin
        while (b != 0) begin
            remainder = a % b;
            a = b;
            b = remainder;
        end
        rate_gcd = a;
    end
endfunction
// Reduce the rational rate before building its counter. At 31.5 MHz this
// is +4 modulo 7875, without constant low bits or a 32-bit feedback adder.
localparam int RATE_DIVISOR = rate_gcd(CLK_FREQ, SAMPLE_RATE);
localparam int SAMPLE_INCREMENT = SAMPLE_RATE / RATE_DIVISOR;
localparam int SAMPLE_THRESHOLD = CLK_FREQ / RATE_DIVISOR;
localparam int ACC_BITS = $clog2(SAMPLE_THRESHOLD + SAMPLE_INCREMENT);
logic in_menu, was_in_menu;
logic [ACC_BITS-1:0] sample_accumulator;
logic sample_tick;
logic [3:0] millisecond_samples;
logic [8:0] fade_step;
logic [1:0] fade_out_thirds;
logic [3:0] frame_counter;
logic [6:0] halfbeat_index;
logic score_request;
logic [1:0] score_load_pipe;
logic [31:0] score_word;
logic voice_active;
logic [12:0] note_age, note_duration;
logic [7:0] note_velocity;
logic [23:0] wave_phase, pitch_word, pitch_increment;
logic [15:0] note_envelope, release_gain, note_gain;
logic [13:0] samples_remaining;
logic [15:0] wave_word, fade_word;
logic signed [24:0] velocity_product;
logic signed [32:0] release_product, fade_product;
logic signed [15:0] velocity_sample, released_sample;

assign in_menu = game_state == START_SCREEN;
assign samples_remaining = (voice_active && note_duration > note_age) ?
                           {1'b0, note_duration} - {1'b0, note_age} : 14'd0;
// Linear 32 ms release. min() joins it continuously to the current body level.
assign release_gain = (samples_remaining >= 14'd512) ? 16'hFFFF : {samples_remaining[8:0], 7'd0};
assign note_gain = (note_envelope < release_gain) ? note_envelope : release_gain;
assign velocity_sample = 16'(velocity_product >>> 8);
assign released_sample = 16'(release_product >>> 16);

lpm_rom #(
    .lpm_width(32), .lpm_widthad(7), .lpm_numwords(128),
    .lpm_file("RTL/AUDIO/menu_score.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) score_rom (
    .address(halfbeat_index), .inclock(clk), .outclock(), .memenab(1'b1), .q(score_word)
);
lpm_rom #(
    .lpm_width(24), .lpm_widthad(4), .lpm_numwords(16),
    .lpm_file("RTL/AUDIO/menu_pitch.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) pitch_rom (
    // Prefetch during score loading, then latch the frequency with the note.
    .address(score_word[31:28]), .inclock(clk), .outclock(), .memenab(1'b1), .q(pitch_word)
);
lpm_rom #(
    .lpm_width(16), .lpm_widthad(8), .lpm_numwords(256),
    .lpm_file("RTL/AUDIO/menu_wave.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) wave_rom (
    .address(wave_phase[23:16]), .inclock(clk), .outclock(), .memenab(1'b1), .q(wave_word)
);
lpm_rom #(
    .lpm_width(16), .lpm_widthad(9), .lpm_numwords(512),
    .lpm_file("RTL/AUDIO/menu_fade.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) fade_rom (
    .address(fade_step), .inclock(clk), .outclock(), .memenab(1'b1), .q(fade_word)
);

// Exact average 16 kHz from 31.5 MHz, with a separate millisecond fade timer.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        sample_accumulator <= 0;
        sample_tick <= 0;
        millisecond_samples <= 0;
        fade_step <= 0;
        fade_out_thirds <= 0;
    end else begin
        sample_tick <= 0;
        if (sample_accumulator + ACC_BITS'(SAMPLE_INCREMENT) >= ACC_BITS'(SAMPLE_THRESHOLD)) begin
            sample_accumulator <= sample_accumulator + ACC_BITS'(SAMPLE_INCREMENT) - ACC_BITS'(SAMPLE_THRESHOLD);
            sample_tick <= 1;
        end else begin
            sample_accumulator <= sample_accumulator + ACC_BITS'(SAMPLE_INCREMENT);
        end
        if (sample_tick) begin
            if (millisecond_samples == 4'd15) begin
                millisecond_samples <= 0;
                if (in_menu) begin
                    if (fade_step < 9'd500) fade_step <= fade_step + 1'b1;
                    fade_out_thirds <= 0;
                end else begin
                    // 3, 3, 4 steps per millisecond: 500 -> 0 in 150 ms.
                    if (fade_out_thirds == 2'd2) begin
                        fade_step <= (fade_step > 9'd4) ? fade_step - 9'd4 : 9'd0;
                        fade_out_thirds <= 0;
                    end else begin
                        fade_step <= (fade_step > 9'd3) ? fade_step - 9'd3 : 9'd0;
                        fade_out_thirds <= fade_out_thirds + 1'b1;
                    end
                end
            end else begin
                millisecond_samples <= millisecond_samples + 1'b1;
            end
        end
    end
end

// An eighth note is 16 frames, a beat is 32, and a bar/bob is 128.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        was_in_menu <= 0;
        frame_counter <= 0;
        halfbeat_index <= 0;
        score_request <= 0;
    end else begin
        was_in_menu <= in_menu;
        score_request <= 0;
        if (in_menu) begin
            if (!was_in_menu) begin
                frame_counter <= startOfFrame ? 4'd1 : 4'd0;
                halfbeat_index <= 0;
                score_request <= 1;
            end else if (startOfFrame) begin
                if (frame_counter == 4'd15) begin
                    frame_counter <= 0;
                    halfbeat_index <= halfbeat_index + 1'b1;
                    score_request <= 1;
                end else begin
                    frame_counter <= frame_counter + 1'b1;
                end
            end
        end else begin
            frame_counter <= 0;
            halfbeat_index <= 0;
        end
    end
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        score_load_pipe <= 0;
        voice_active <= 0;
        pitch_increment <= 0;
        wave_phase <= 0;
        note_envelope <= 0;
        note_age <= 0;
        note_duration <= 0;
        note_velocity <= 0;
    end else begin
        // Wait for the registered ROM address before consuming this score slot.
        score_load_pipe <= {score_load_pipe[0], score_request};
        if (in_menu && !was_in_menu) begin
            voice_active <= 0;
            note_age <= 0;
            wave_phase <= 0;
            note_envelope <= 0;
        end else if (in_menu && score_load_pipe[1] && score_word[27:15] != 0) begin
            voice_active <= 1;
            pitch_increment <= pitch_word;
            note_duration <= score_word[27:15];
            note_velocity <= score_word[14:7];
            note_age <= 0;
            wave_phase <= 0;
            note_envelope <= 0;
        end else if (!in_menu && fade_step == 0) begin
            voice_active <= 0;
            note_age <= 0;
            wave_phase <= 0;
            note_envelope <= 0;
        end else if (sample_tick && voice_active) begin
            if (note_age + 1'b1 >= note_duration) begin
                voice_active <= 0;
                note_age <= 0;
                note_envelope <= 0;
            end else begin
                note_age <= note_age + 1'b1;
                wave_phase <= wave_phase + pitch_increment;
                // 8 ms attack, gentle decay to a sustained audible body.
                if (note_age < 13'd127)
                    note_envelope <= note_envelope + 16'd512;
                else if (note_age == 13'd127)
                    note_envelope <= 16'hFFFF;
                else if (note_envelope > SUSTAIN_Q16 + 16'd8)
                    note_envelope <= note_envelope - 16'd8;
                else
                    note_envelope <= SUSTAIN_Q16;
            end
        end
    end
end

// Fixed-point gain stages have explicit signed widths. No full-note recordings
// are stored: every pitch reuses the same periodic waveform and envelope logic.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        velocity_product <= 0;
        release_product <= 0;
        fade_product <= 0;
        audio_out <= 0;
    end else begin
        velocity_product <= $signed(wave_word) * $signed({1'b0, note_velocity});
        release_product <= velocity_sample * $signed({1'b0, note_gain});
        fade_product <= released_sample * $signed({1'b0, fade_word});
        audio_out <= 16'(fade_product >>> 16);
    end
end
endmodule
