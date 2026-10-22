// Plan bosses before recycling so their midpoint TNT enters from offscreen.
// Only the current generation changes the pipe's drawing/collision geometry.
module boss_control #(
    parameter int NUM_PIPES = 3,
    parameter int PIPE_SPACING = 240,
    parameter int MIN_NORMAL_PIPES = 5,
    parameter int EXPLOSION_FRAMES = 22 // About 0.3 seconds at this VGA's ~72 Hz
)(
    input  logic clk, resetN, startOfFrame,
    input  logic [1:0] game_state,
    input  logic [NUM_PIPES*11-1:0] pipeXPositions,
    input  logic [NUM_PIPES-1:0] pipeReady, pipeRecycle,
    input  logic randomBoss,
    input  logic [NUM_PIPES-1:0] tntCollected,
    output logic [NUM_PIPES-1:0] bossPipe, bossOpen, bossUpcoming,
    output logic [NUM_PIPES*11-1:0] bossTargetXPositions,
    output logic [NUM_PIPES-1:0] explosionActive,
    output logic [NUM_PIPES*2-1:0] explosionFrames
);
localparam logic [1:0] START_SCREEN = 2'd0, PLAYING = 2'd1;
localparam int WRAP_DISTANCE = NUM_PIPES * PIPE_SPACING;
// Decide the following boss by the time its predecessor approaches X=800.
localparam int PLAN_NEXT_X = 800 + PIPE_SPACING - WRAP_DISTANCE;
localparam int AGE_BITS = (EXPLOSION_FRAMES < 2) ? 1 : $clog2(EXPLOSION_FRAMES);
logic [NUM_PIPES-1:0] initialPlanned, nextPlanned, nextBoss;
logic [NUM_PIPES-1:0] planInitial, planNext, chooseBoss;
logic [AGE_BITS-1:0] explosionAge [0:NUM_PIPES-1];
int normalsSinceBoss, nextNormalCount;

always_comb begin
    planInitial = '0;
    planNext = '0;
    chooseBoss = '0;
    nextNormalCount = normalsSinceBoss;
    // Initial pipes precede the first recycled generation, including when
    // their planning thresholds happen on the same clock.
    for (int j = 0; j < NUM_PIPES; j++) begin
        if (pipeReady[j] && !initialPlanned[j]) begin
            planInitial[j] = 1'b1;
            chooseBoss[j] = nextNormalCount >= MIN_NORMAL_PIPES && randomBoss;
            if (chooseBoss[j]) nextNormalCount = 0;
            else if (nextNormalCount < MIN_NORMAL_PIPES) nextNormalCount++;
        end
    end
    for (int j = 0; j < NUM_PIPES; j++) begin
        if (initialPlanned[j] && !nextPlanned[j] && !pipeRecycle[j] &&
            int'($signed(pipeXPositions[j*11 +: 11])) <= PLAN_NEXT_X) begin
            planNext[j] = 1'b1;
            chooseBoss[j] = nextNormalCount >= MIN_NORMAL_PIPES && randomBoss;
            if (chooseBoss[j]) nextNormalCount = 0;
            else if (nextNormalCount < MIN_NORMAL_PIPES) nextNormalCount++;
        end
    end
end

genvar i;
generate
for (i = 0; i < NUM_PIPES; i++) begin : targets
    int targetX;
    assign targetX = int'($signed(pipeXPositions[i*11 +: 11])) +
                     (nextPlanned[i] ? WRAP_DISTANCE : 0);
    // Clamp only far-offscreen coordinates, as pipe_move already does.
    assign bossTargetXPositions[i*11 +: 11] =
        (targetX > 1023) ? 11'd1023 : 11'(targetX);
    assign bossUpcoming[i] = nextPlanned[i] ? nextBoss[i] : bossPipe[i];
    assign explosionFrames[i*2 +: 2] =
        (int'(explosionAge[i])*4 < EXPLOSION_FRAMES) ? 2'd0 :
        (int'(explosionAge[i])*4 < EXPLOSION_FRAMES*2) ? 2'd1 :
        (int'(explosionAge[i])*4 < EXPLOSION_FRAMES*3) ? 2'd2 : 2'd3;
end
endgenerate

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        initialPlanned <= '0;
        nextPlanned <= '0;
        nextBoss <= '0;
        bossPipe <= '0;
        bossOpen <= '0;
        explosionActive <= '0;
        normalsSinceBoss <= 0;
        for (int j = 0; j < NUM_PIPES; j++) explosionAge[j] <= '0;
    end else if (game_state == START_SCREEN) begin
        initialPlanned <= '0;
        nextPlanned <= '0;
        nextBoss <= '0;
        bossPipe <= '0;
        bossOpen <= '0;
        explosionActive <= '0;
        normalsSinceBoss <= 0;
        for (int j = 0; j < NUM_PIPES; j++) explosionAge[j] <= '0;
    end else if (game_state == PLAYING) begin
        normalsSinceBoss <= nextNormalCount;
        for (int j = 0; j < NUM_PIPES; j++) begin
            if (planInitial[j]) begin
                initialPlanned[j] <= 1'b1;
                bossPipe[j] <= chooseBoss[j];
            end
            if (planNext[j]) begin
                nextPlanned[j] <= 1'b1;
                nextBoss[j] <= chooseBoss[j];
            end
            if (startOfFrame && explosionActive[j]) begin
                if (explosionAge[j] == AGE_BITS'(EXPLOSION_FRAMES-1))
                    explosionActive[j] <= 1'b0;
                else explosionAge[j] <= explosionAge[j] + 1'b1;
            end
            if (tntCollected[j] && bossPipe[j] && !bossOpen[j]) begin
                bossOpen[j] <= 1'b1; // Open on the first burst.
                explosionActive[j] <= 1'b1;
                explosionAge[j] <= '0;
            end
            if (pipeRecycle[j]) begin
                bossPipe[j] <= nextBoss[j];
                bossOpen[j] <= 1'b0;
                explosionActive[j] <= 1'b0;
                explosionAge[j] <= '0;
                nextPlanned[j] <= 1'b0;
                nextBoss[j] <= 1'b0;
            end
        end
    end
    // Pause/game over hold the animation and both pipe generations.
end
endmodule
