module start_screen_audio #(
    parameter int CLK_FREQ = 31_500_000 // AUDIO uses the existing 31.5 MHz clock.
)(
    input  logic       clk,
    input  logic       resetN,
    input  logic [1:0] game_state,
    input  logic       startOfFrame,   // VGA tick for note timing (~72 Hz).
    output logic       audio_out       // Square wave audio output
);

localparam logic [1:0] START_SCREEN = 2'b00;

// Note dividers for the clock connected in AUDIO.bdf (C-major arpeggio).
localparam int NOTE_C5  = CLK_FREQ / (2 * 523);  // Do
localparam int NOTE_E5  = CLK_FREQ / (2 * 659);  // Mi
localparam int NOTE_G5  = CLK_FREQ / (2 * 784);  // Sol
localparam int NOTE_C6  = CLK_FREQ / (2 * 1047); // High Do
localparam int NOTE_OFF = 0;

// Festive 8-note melody sequence
logic [23:0] notes [0:7];
assign notes[0] = NOTE_C5;
assign notes[1] = NOTE_E5;
assign notes[2] = NOTE_G5;
assign notes[3] = NOTE_C6;
assign notes[4] = NOTE_G5;
assign notes[5] = NOTE_E5;
assign notes[6] = NOTE_C5;
assign notes[7] = NOTE_OFF;

logic [5:0]  frame_counter;
logic [2:0]  note_index;
logic [23:0] tone_counter;
logic [23:0] current_divider;

// Note Timing Controller (Changes note every 12 VGA frames).
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        frame_counter <= 6'd0;
        note_index    <= 3'd0;
    end else begin
        if (game_state == START_SCREEN) begin
            if (startOfFrame) begin
                if (frame_counter >= 6'd11) begin
                    frame_counter <= 6'd0;
                    note_index    <= note_index + 1'b1;
                end else begin
                    frame_counter <= frame_counter + 1'b1;
                end
            end
        end else begin
            frame_counter <= 6'd0;
            note_index    <= 3'd0;
        end
    end
end

// Square Wave Tone Generation
assign current_divider = notes[note_index];
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        tone_counter <= 24'd0;
        audio_out    <= 1'b0;
    end else begin
        if (game_state == START_SCREEN) begin
            if (current_divider == NOTE_OFF) begin
                audio_out    <= 1'b0;
                tone_counter <= 24'd0;
            end else if (tone_counter >= current_divider - 1'b1) begin
                tone_counter <= 24'd0;
                audio_out    <= ~audio_out;
            end else begin
                tone_counter <= tone_counter + 1'b1;
            end
        end else begin
            audio_out    <= 1'b0;
            tone_counter <= 24'd0;
        end
    end
end

endmodule
