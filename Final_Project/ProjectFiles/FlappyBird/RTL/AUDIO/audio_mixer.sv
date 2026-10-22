module audio_mixer (
    input  logic [15:0] sinVal,             // Original game audio from sinetable
    input  logic [15:0] start_audio_out,    // Signed PCM from start_screen_audio.
    input  logic [1:0]  game_state,         // Game state from game_manager
    input  logic [1:0]  volume_level,       // Same KEY3 level used by the sine table.
    output logic [15:0] dac_audio_out       // Selected audio sent to dacdata_left / right
);

localparam logic [1:0] START_SCREEN = 2'b00;
logic signed [15:0] menu_sample;
logic signed [16:0] mixed_sample;

always_comb begin
    case (volume_level)
        2'd3: menu_sample = $signed(start_audio_out);
        2'd2: menu_sample = $signed(start_audio_out) >>> 1;
        2'd1: menu_sample = $signed(start_audio_out) >>> 2;
        default: menu_sample = 16'sd0;
    endcase
    mixed_sample = $signed({sinVal[15], sinVal}) + $signed({menu_sample[15], menu_sample});
    if (game_state == START_SCREEN) begin
        dac_audio_out = menu_sample;
    end else begin
        // Finish the short menu fade over game effects. Saturate signed PCM.
        if (mixed_sample > 17'sd32767) dac_audio_out = 16'h7FFF;
        else if (mixed_sample < -17'sd32768) dac_audio_out = 16'h8000;
        else dac_audio_out = mixed_sample[15:0];
    end
end

endmodule
