module sound_selector (
    input  logic       clk,
    input  logic       resetN,
    input  logic       SingleHitPulse,
    input  logic       updateScorePulse,
    input  logic       anti_gravity,
    
    output logic       startMelody,
    output logic [3:0] melodySelect
);

    localparam logic [3:0] SOUND_SCORE_PIPE    = 4'd0;
    localparam logic [3:0] SOUND_COLLISION     = 4'd4;
    localparam logic [3:0] SOUND_AG_SCORE_PIPE = 4'd7;
    localparam logic [3:0] SOUND_AG_COLLISION  = 4'd2;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            startMelody  <= 1'b0;
            melodySelect <= 4'd0;
        end else begin
            startMelody <= 1'b0;

            // AUDIO receives the accepted damage pulse from player_lives.
            // Contacts during invulnerability or Godmode do not play a hit.
            if (SingleHitPulse) begin
                melodySelect <= (anti_gravity) ? SOUND_AG_COLLISION : SOUND_COLLISION;
                startMelody  <= 1'b1;
            end else if (updateScorePulse) begin
                melodySelect <= (anti_gravity) ? SOUND_AG_SCORE_PIPE : SOUND_SCORE_PIPE;
                startMelody  <= 1'b1;
            end
        end
    end

endmodule
