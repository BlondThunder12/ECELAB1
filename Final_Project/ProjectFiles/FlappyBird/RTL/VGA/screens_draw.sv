// One top-level drawing block for menu, pause and end screens. game_manager owns game_state;
// the renderers use that state and the rulebook's key-toggle flag to draw.
module screens_draw (
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic signed [5:0] menuYOffset,
    input  logic        rules_key,
    input  logic [11:0] final_score_bcd,
    input  logic [11:0] best_score_bcd,
    input  logic        new_best,
    output logic        screenDrawingRequest,
    output logic [7:0]  screenRGB
);

logic startDR, rulebookDR, pauseDR, gameOverDR;
logic [7:0] startRGB, rulebookRGB, pauseRGB, gameOverRGB;

start_screen_draw start_screen (
    .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
    .game_state(game_state), .menuYOffset(menuYOffset),
    .startDrawingRequest(startDR), .startRGB(startRGB)
);

rulebook_draw rulebook (
    .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
    .game_state(game_state), .rules_key(rules_key),
    .rulebookDrawingRequest(rulebookDR), .rulebookRGB(rulebookRGB)
);

pause_draw pause_screen (
    .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
    .game_state(game_state), .pauseDrawingRequest(pauseDR), .pauseRGB(pauseRGB)
);

game_over_draw game_over_screen (
    .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
    .game_state(game_state), .final_score_bcd(final_score_bcd),
    .best_score_bcd(best_score_bcd), .new_best(new_best),
    .gameOverDrawingRequest(gameOverDR), .gameOverRGB(gameOverRGB)
);

// All renderers have one clock of latency. Combining them here adds no clock.
// The opaque rulebook covers either menu panel while its page is open.
always_comb begin
    screenDrawingRequest = 1'b0;
    screenRGB = 8'h00;
    if (rulebookDR) begin
        screenDrawingRequest = 1'b1;
        screenRGB = rulebookRGB;
    end
    else if (gameOverDR) begin
        screenDrawingRequest = 1'b1;
        screenRGB = gameOverRGB;
    end
    else if (pauseDR) begin
        screenDrawingRequest = 1'b1;
        screenRGB = pauseRGB;
    end
    else if (startDR) begin
        screenDrawingRequest = 1'b1;
        screenRGB = startRGB;
    end
end
endmodule
