// Generated control constants; contains no recorded audio.
package game_sfx_data;
localparam int SFX_SAMPLE_RATE = 48000;
localparam int SFX_SAMPLES_PER_TICK = 1440;
localparam logic [3:0] SFX_SCORE = 4'd0, SFX_AG_SCORE = 4'd1, SFX_AG_HIT = 4'd2, SFX_DAMAGE = 4'd4,
                       SFX_PICKUP = 4'd7, SFX_TNT = 4'd8, SFX_GAME_OVER = 4'd9, SFX_WIN = 4'd10;
localparam int SFX_TNT_SAMPLES = 10080;
localparam logic [23:0] TNT_NOISE_DECAY = 24'd16769451;
localparam logic [23:0] TNT_THUMP_DECAY = 24'd16772224;
typedef struct packed {
    logic [15:0] gain, level_gain, sustain; // gain/sustain: Q0.16; level_gain: Q4.12.
    logic [23:0] decay;
    logic [15:0] attack_samples, release_samples;
    logic [18:0] attack_step;
    logic [15:0] release_step;
} game_sfx_profile_t;
function automatic game_sfx_profile_t game_sfx_profile(input logic [3:0] melody);
    case (melody)
        4'd0, 4'd1: game_sfx_profile = {16'd24903, 16'd18176, 16'd16384, 24'd16768480, 16'd96, 16'd864, 19'd341333, 16'd37926}; // score
        4'd2, 4'd4: game_sfx_profile = {16'd36700, 16'd15872, 16'd11796, 24'd16771840, 16'd96, 16'd1056, 19'd341333, 16'd31030}; // damage
        4'd7: game_sfx_profile = {16'd41942, 16'd11520, 16'd14418, 24'd16771392, 16'd96, 16'd1152, 19'd341333, 16'd28444}; // pickup
        4'd8: game_sfx_profile = {16'd34078, 16'd15360, 16'd0, 24'd16772224, 16'd96, 16'd1200, 19'd341333, 16'd27307}; // tnt
        4'd9: game_sfx_profile = {16'd41287, 16'd12288, 16'd19661, 24'd16775552, 16'd192, 16'd2160, 19'd170667, 16'd15170}; // game_over
        4'd10: game_sfx_profile = {16'd47185, 16'd7168, 16'd44564, 24'd16776422, 16'd192, 16'd1728, 19'd170667, 16'd18963}; // win
        default: game_sfx_profile = '0;
    endcase
endfunction
endpackage
