module audio_mixer (
    input  logic [15:0] sinVal,             // Original game audio from sinetable
    input  logic        start_audio_out,    // 1-bit audio from start_screen_audio
    input  logic [1:0]  game_state,         // Game state from game_manager
    output logic [15:0] dac_audio_out       // Selected audio sent to dacdata_left / right
);

localparam logic [1:0] START_SCREEN = 2'b00;

always_comb begin
    if (game_state == START_SCREEN) begin
        // Signed PCM levels: 0/FFFF would be only one DAC least-significant
        // bit apart. Use a modest +/-8192 amplitude for the menu melody.
        dac_audio_out = start_audio_out ? 16'h2000 : 16'hE000;
    end else begin
        // Pass original game sine wave during gameplay
        dac_audio_out = sinVal;
    end
end

endmodule
