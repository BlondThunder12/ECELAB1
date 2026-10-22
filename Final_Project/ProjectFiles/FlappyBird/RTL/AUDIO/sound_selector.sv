module sound_selector #(
    parameter logic [31:0] SCORE_COOLDOWN_CYCLES = 32'd4_000_000
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic        SingleHitPulse,
    input  logic        updateScorePulse,
    input  logic        anti_gravity,
    input  logic        itemCollected,

    output logic        startMelody,
    output logic [3:0]  melodySelect
);

    typedef enum logic [3:0] {
        SND_NORMAL_SCORE = 4'd0,
        SND_AG_SCORE     = 4'd1,
        SND_AG_HIT       = 4'd2,
        SND_NORMAL_HIT   = 4'd4,
        SND_ITEM         = 4'd7
    } sound_id_e;

    logic [31:0] cooldown_cnt;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            startMelody  <= 1'b0;
            melodySelect <= SND_NORMAL_SCORE;
            cooldown_cnt <= '0;
        end else begin
            startMelody <= 1'b0;

            if (cooldown_cnt > 32'd0) begin
                cooldown_cnt <= cooldown_cnt - 1'b1;
            end

            if (SingleHitPulse) begin
                melodySelect <= (anti_gravity) ? SND_AG_HIT : SND_NORMAL_HIT;
                startMelody  <= 1'b1;
                cooldown_cnt <= SCORE_COOLDOWN_CYCLES;
            end else if (itemCollected) begin
                melodySelect <= SND_ITEM;
                startMelody  <= 1'b1;
                cooldown_cnt <= SCORE_COOLDOWN_CYCLES;
            end else if (updateScorePulse && (cooldown_cnt == 32'd0)) begin
                melodySelect <= (anti_gravity) ? SND_AG_SCORE : SND_NORMAL_SCORE;
                startMelody  <= 1'b1;
                cooldown_cnt <= SCORE_COOLDOWN_CYCLES;
            end
        end
    end

endmodule
