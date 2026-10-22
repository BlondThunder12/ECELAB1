module audio_mixer (
    input  logic [15:0] sinVal,             // Original game audio from sinetable
    input  logic        start_audio_out,    // 1-bit audio from start_screen_audio
    input  logic [1:0]  game_state,         // Game state from game_manager
    input  logic [1:0]  volume_level,       // Same KEY3 level used by the sine table.
    output logic [15:0] dac_audio_out       // Selected audio sent to dacdata_left / right
);

localparam logic [1:0] START_SCREEN = 2'b00;
logic signed [15:0] menu_sample;

assign menu_sample = start_audio_out ? 16'sh2000 : -16'sh2000;

always_comb begin
    if (game_state == START_SCREEN) begin
        // Signed PCM levels: 0/FFFF would be only one DAC least-significant
        // bit apart. Use a modest +/-8192 amplitude for the menu melody.
        case (volume_level)
            2'd3: dac_audio_out = menu_sample;
            2'd2: dac_audio_out = menu_sample >>> 1;
            2'd1: dac_audio_out = menu_sample >>> 2;
            default: dac_audio_out = 16'h0000;
        endcase
    end else begin
        // The sine table already applies this shared volume level.
        dac_audio_out = sinVal;
    end
end

endmodule
