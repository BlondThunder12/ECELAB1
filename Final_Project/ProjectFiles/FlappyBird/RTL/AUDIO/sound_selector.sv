module sound_selector #(
    parameter logic [31:0] SCORE_COOLDOWN_CYCLES = 32'd4_000_000
)(
    input logic clk, resetN,
    input logic SingleHitPulse, updateScorePulse, anti_gravity, itemCollected,
    input logic [2:0] tntCollected,
    input logic [1:0] game_state,
    input logic [9:0] score,
    input logic melodyBusy, melodyEnded,
    output logic startMelody,
    output logic [3:0] melodySelect
);
import game_sfx_data::*;
localparam logic [1:0] START_SCREEN=2'b00, PLAYING=2'b01, GAME_OVER=2'b10;
logic [31:0] cooldown_cnt;
logic [1:0] previous_state, current_priority, requested_priority;
logic previous_hit, previous_score, previous_item, previous_tnt;
logic request_valid;
logic [3:0] requested_melody;

// Priority mux: ending > TNT/damage > shared pickup > score. Drop equal/lower
// priority events while busy, so frequent effects cannot restart a phrase.
always_comb begin
    request_valid=1'b0;
    requested_melody=SFX_SCORE;
    requested_priority=2'd0;
    if (game_state==GAME_OVER && previous_state!=GAME_OVER) begin
        request_valid=1'b1;
        requested_melody=(score>=10'd999) ? SFX_WIN : SFX_GAME_OVER;
        requested_priority=2'd3;
    end else if (game_state==PLAYING) begin
        if ((|tntCollected) && !previous_tnt) begin
            request_valid=1'b1;
            requested_melody=SFX_TNT;
            requested_priority=2'd2;
        end else if (SingleHitPulse && !previous_hit) begin
            request_valid=1'b1;
            requested_melody=anti_gravity ? SFX_AG_HIT : SFX_DAMAGE;
            requested_priority=2'd2;
        end else if (itemCollected && !previous_item) begin
            request_valid=1'b1;
            requested_melody=SFX_PICKUP;
            requested_priority=2'd1;
        end else if (updateScorePulse && !previous_score && cooldown_cnt==0) begin
            request_valid=1'b1;
            requested_melody=anti_gravity ? SFX_AG_SCORE : SFX_SCORE;
        end
    end
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        startMelody<=1'b0;
        melodySelect<=SFX_SCORE;
        cooldown_cnt<='0;
        current_priority<='0;
        previous_state<=START_SCREEN;
        previous_hit<=1'b0;
        previous_score<=1'b0;
        previous_item<=1'b0;
        previous_tnt<=1'b0;
    end else begin
        previous_state<=game_state;
        previous_hit<=SingleHitPulse;
        previous_score<=updateScorePulse;
        previous_item<=itemCollected;
        previous_tnt<=|tntCollected;
        startMelody<=1'b0;
        if (cooldown_cnt!=0) cooldown_cnt<=cooldown_cnt-1'b1;
        if (melodyEnded && !startMelody) current_priority<='0;
        if (game_state==START_SCREEN) begin
            cooldown_cnt<='0;
            current_priority<='0;
        end else if (request_valid && ((!melodyBusy && !startMelody) || requested_priority>current_priority)) begin
            melodySelect<=requested_melody;
            current_priority<=requested_priority;
            startMelody<=1'b1;
            cooldown_cnt<=SCORE_COOLDOWN_CYCLES;
        end
    end
end
endmodule
