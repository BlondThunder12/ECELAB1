module audio_mixer (
    input  logic [15:0] sinVal,             // Shaped game effects from game_sfx_voice.
    input  logic [15:0] start_audio_out,    // Signed PCM from start_screen_audio.
    input  logic [1:0]  game_state,         // Game state from game_manager
    input  logic [1:0]  volume_level,       // Shared KEY3 master level for all audio.
    output logic [15:0] dac_audio_out       // Selected audio sent to dacdata_left / right
);

localparam logic [1:0] START_SCREEN = 2'b00;
logic signed [15:0] menu_sample;
logic signed [15:0] effect_sample;
logic signed [16:0] mixed_sample;

always_comb begin
    case (volume_level)
        2'd3: begin menu_sample = $signed(start_audio_out); effect_sample = $signed(sinVal); end
        2'd2: begin menu_sample = $signed(start_audio_out) >>> 1; effect_sample = $signed(sinVal) >>> 1; end
        2'd1: begin menu_sample = $signed(start_audio_out) >>> 2; effect_sample = $signed(sinVal) >>> 2; end
        default: begin menu_sample = 16'sd0; effect_sample = 16'sd0; end
    endcase
    mixed_sample = $signed({effect_sample[15], effect_sample}) + $signed({menu_sample[15], menu_sample});
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
