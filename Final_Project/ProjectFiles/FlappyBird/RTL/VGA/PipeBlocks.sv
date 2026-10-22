module PipeBlocks #(
	parameter int NUM_PIPES = 3,       
	parameter int PIPE_SPACING = 240,  // Position-to-position spacing; wrap cycle = NUM_PIPES * this
	parameter int Max_Random_Number = 6'd32,
	parameter int Min_Random_Number = 6'd2,
	parameter int Bird_Threshold_X_Coor = 150
)(
	input  logic               clk,
	input  logic               resetN,
   input  logic               startOfFrame,
	input  logic        [1:0]  game_state, // Current game state to know how to handle pipes
	input  logic        [3:0]  speed_level,
	input  logic               turbo,     // Active-high board switch
	input  logic signed [10:0] pixelX,
	input  logic signed [10:0] pixelY,
    input  logic [NUM_PIPES-1:0] tntCollected,

	output logic               pipeDR,
    output logic               pipeVisualDR, // Includes the harmless explosion.
	output logic         [7:0] pipeRGB,
	output logic					updateScorePulse,
	output logic					debug_led,
    output logic [NUM_PIPES*11-1:0] pipeXPositions,
    output logic [NUM_PIPES*6-1:0] pipeHeights,
    output logic [NUM_PIPES-1:0] pipeReady,
    output logic [NUM_PIPES-1:0] pipeRecycle,
    output logic [10:0] scrollStep, // Common movement amount, in 1/64 pixel units
    output logic scrollUpdate,     // High on the clock cycle that moves all pipes
    output logic [10:0] pipeSpacing, // Horizontal distance between pipe positions
    output logic [NUM_PIPES-1:0] bossUpcoming,
    output logic [NUM_PIPES*11-1:0] bossTargetXPositions
);

//-----------------------------------------------------------------------------
// Game state declarations
//-----------------------------------------------------------------------------
localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING 		= 2'b01;
localparam logic [1:0] GAME_OVER 	= 2'b10;
localparam logic [1:0] PAUSED 		= 2'b11;
//-----------------------------------------------------------------------------
// Internal Arrays
//-----------------------------------------------------------------------------
logic               pipe_active    [NUM_PIPES]; // Latched height/scoring enable as pipes approach the screen
logic signed [10:0] topLeftX       [NUM_PIPES];
logic               newPipeGen     [NUM_PIPES];
logic               dr_array       [NUM_PIPES];
logic        [7:0]  rgb_array      [NUM_PIPES];
logic        [5:0]  pipe_chunks    [NUM_PIPES]; // Stores the height for each pipe
logic               pipe_active_D  [NUM_PIPES]; // Edge detectors for the latched triggers
// Each pipe has its own X position. These arrays collect its movement report:
// step_array[i] is how far pipe i moves; update_array[i] says when it moves.
logic [10:0] step_array [NUM_PIPES];
logic update_array [NUM_PIPES];
logic [NUM_PIPES-1:0] bossPipe, bossOpen, explosionActive;
logic [NUM_PIPES*2-1:0] explosionFrames;
logic [NUM_PIPES*9-1:0] bossOpeningProgress;
logic explosionDR;
logic [7:0] explosionRGB;
logic [NUM_PIPES*9-1:0] explosionYPositions;
logic	signed [10:0] topLeftX_prev  [NUM_PIPES]; // remembers where each pipe was 
localparam int PIPE_ACTIVATE_X = 640 + 160; // Sample height while the pipe is still offscreen.
// Every pipe_move receives the same clock, frame pulse, speed, turbo and game
// state, so all pipes report the same step and update cycle. Forward pipe 0's
// copy to the pickups; [0] does not select which pipes move. All pipes still
// move their own positions. For example, a step of 192 moves every pipe and
// active pickup left by 192/64 = 3 pixels on the same update.
assign scrollStep = step_array[0];
assign scrollUpdate = update_array[0];
// Export the existing horizontal spacing as an 11-bit value for gap checks.
assign pipeSpacing = 11'(PIPE_SPACING);


//-----------------------------------------------------------------------------
// The Master Random Number Generator
//-----------------------------------------------------------------------------
logic [5:0] fast_random_chunks;

// Instantiate the newly rewritten random module
random #(
    .SIZE_BITS(6),
    .MIN_VAL(Min_Random_Number),  
    .MAX_VAL(Max_Random_Number)
) master_rng (
    .clk    (clk),
    .resetN (resetN),
    .enable (1'b1),               // Hardwired to 1 so it spins continuously at 50MHz
    .dout   (fast_random_chunks)  // Connects to your fast_random_chunks wire
);

boss_control #(.NUM_PIPES(NUM_PIPES), .PIPE_SPACING(PIPE_SPACING)) bosses (
    .clk(clk), .resetN(resetN), .startOfFrame(startOfFrame), .game_state(game_state),
    .pipeXPositions(pipeXPositions), .pipeReady(pipeReady), .pipeRecycle(pipeRecycle),
    .randomBoss(fast_random_chunks[0]), .tntCollected(tntCollected),
    .bossPipe(bossPipe), .bossOpen(bossOpen), .bossUpcoming(bossUpcoming),
    .bossTargetXPositions(bossTargetXPositions), .explosionActive(explosionActive),
    .explosionFrames(explosionFrames), .bossOpeningProgress(bossOpeningProgress)
);

explosion_draw #(.NUM_PIPES(NUM_PIPES)) explosion (
    .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
    .pipeXPositions(pipeXPositions), .explosionYPositions(explosionYPositions),
    .explosionActive(explosionActive), .explosionFrames(explosionFrames),
    .drawingRequest(explosionDR), .RGBout(explosionRGB)
);

//-----------------------------------------------------------------------------
// Freeze pipes on Game Over
//-----------------------------------------------------------------------------
logic active_frame;
assign active_frame = (game_state == PLAYING) ? startOfFrame : 1'b0;

//-----------------------------------------------------------------------------
// Enable height sampling/scoring as each offset pipe approaches the screen
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge resetN) begin
	if (!resetN) begin
			for (int j = 0; j < NUM_PIPES; j++) begin
				pipe_active[j] <= 1'b0;
			end
	end
	else  if (game_state == START_SCREEN) begin
				for (int j = 0; j < NUM_PIPES; j++) begin
					pipe_active[j] <= 1'b0;
				end
			end
	
	else begin
        // Motion starts together offscreen; activation no longer sets the spacing.
        for (int j = 0; j < NUM_PIPES; j++) begin
            if (game_state == PLAYING && (topLeftX[j] <= PIPE_ACTIVATE_X)) begin
                pipe_active[j] <= 1'b1;
            end
        end
    end
end

//-----------------------------------------------------------------------------
// Random Height Sampler
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        for (int j = 0; j < NUM_PIPES; j++) begin
            pipe_chunks[j]   <= 6'd15; // Safe default height before spawning
            pipe_active_D[j] <= 1'b0;
        end
    end
    else if (game_state == START_SCREEN) begin
        for (int j = 0; j < NUM_PIPES; j++) begin
            pipe_chunks[j] <= 6'd15;
            pipe_active_D[j] <= 1'b0;
        end
    end
    // Holding the sampler during pause also handles pausing on the wrap pulse.
    else if (game_state == PLAYING) begin
        for (int j = 0; j < NUM_PIPES; j++) begin
            pipe_active_D[j] <= pipe_active[j]; // Update edge detector

            // Grab new random number on first launch OR when wrapping around
            if ((pipe_active[j] && !pipe_active_D[j]) || newPipeGen[j]) begin
                pipe_chunks[j] <= fast_random_chunks;
            end
        end
    end
end

//-----------------------------------------------------------------------------
// To Generate N pipes using move and objects
//-----------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i < NUM_PIPES; i++) begin : gen_pipes
        assign pipeXPositions[i*11 +: 11] = topLeftX[i];
        assign pipeHeights[i*6 +: 6] = pipe_chunks[i];
        assign pipeReady[i] = pipe_active_D[i]; // Height has already been sampled.
        assign pipeRecycle[i] = newPipeGen[i];
        // Center the burst on the closed pipe's touching caps; retain this
        // height after opening so the animation does not jump to the top.
        assign explosionYPositions[i*9 +: 9] = {pipe_chunks[i], 3'b000};
    
        pipe_move #(
            .INITIAL_X_OFFSET   (i * PIPE_SPACING),
            .WRAP_DISTANCE      (NUM_PIPES * PIPE_SPACING)
        ) move_inst (
            .clk                (clk),
            .resetN             (resetN),
            .startOfFrame       (active_frame),
            .speed_level        (speed_level),
            .turbo              (turbo),
            .trigger_move       (1'b1), // All pipes share frame timing; initial offsets provide spacing
				.game_state			  (game_state),
            
            .topLeftX           (topLeftX[i]),
            .generateNewChunks  (newPipeGen[i]),
            .scrollStep         (step_array[i]),
            .scrollUpdate       (update_array[i])
        );

        Pipe_Object obj_inst (
            .clk                (clk),
            .resetN             (resetN),
            .pixelX             (pixelX),
            .pixelY             (pixelY),
            .wantedXCoord       (topLeftX[i]),
            .SizeOfUpPipe       (pipe_chunks[i]),
            .bossPipe           (bossPipe[i]),
            .bossOpen           (bossOpen[i]),
            .bossOpeningProgress(bossOpeningProgress[i*9 +: 9]),
            
            .PipeDR             (dr_array[i]),
            .pipeRGB            (rgb_array[i])
        );
          
    end
endgenerate

//-----------------------------------------------------------------------------
// Score Update Detector
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			updateScorePulse <= 1'b0;
			for (int j = 0; j < NUM_PIPES; j++) begin
				topLeftX_prev[j] <= 11'd0;
			end
		end 
		else begin
			updateScorePulse <= 1'b0; // Default to 0, ensuring it only pulses for 1 clock cycle

			for (int j = 0; j < NUM_PIPES; j++) begin
            // Store the current position for the next clock cycle to compare against
				topLeftX_prev[j] <= topLeftX[j]; 

            // Check for the crossing transition
				if (pipe_active[j] && 
					(topLeftX_prev[j] >  Bird_Threshold_X_Coor) && 
					(topLeftX[j]      <= Bird_Threshold_X_Coor)) begin
                
					updateScorePulse <= 1'b1; // Trigger the score counter
                
            end
        end
    end
end

//-----------------------------------------------------------------------------
// Output handling using a mux and an OR gate for the Draw requests
//-----------------------------------------------------------------------------
always_comb begin
    pipeDR  = 1'b0;
    pipeRGB = 8'h00;
    
    // Scans through all pipes. If any pipe wants to draw, output its color.
    for (int j = 0; j < NUM_PIPES; j++) begin
        if (dr_array[j]) begin
            pipeDR  = 1'b1;
            // RRRGGGBB: swap the equally sized red/green channels. This
            // preserves the existing tile's shading, outline and highlights.
            pipeRGB = bossPipe[j] ? {rgb_array[j][4:2], rgb_array[j][7:5], rgb_array[j][1:0]} : rgb_array[j];
        end
    end
    pipeVisualDR = pipeDR || explosionDR;
    if (explosionDR) pipeRGB = explosionRGB;
end
//-----------------------------------------------------------------------------
// Debug Toggle for Red LED
//-----------------------------------------------------------------------------

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) 
        debug_led <= 1'b0;
    else if (updateScorePulse) 
        debug_led <= ~debug_led; // Flip state when a pipe passes
end

endmodule
