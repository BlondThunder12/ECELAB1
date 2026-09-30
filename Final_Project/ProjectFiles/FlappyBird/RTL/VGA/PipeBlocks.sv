module PipeBlocks #(
	parameter int NUM_PIPES = 3,       
	parameter int PIPE_SPACING = 240,  // Distance between pipes (720 total / Num_Pipes = 240)
	parameter int Max_Random_Number = 6'd35,
	parameter int Min_Random_Number = 6'd2
)(
	input  logic               clk,
	input  logic               resetN,
    input  logic               startOfFrame,
	input  logic               collision,
	input  logic               Y_direction_key, // Jump key to start the game
	input  logic signed [10:0] pixelX,
	input  logic signed [10:0] pixelY,

	output logic               pipeDR,
	output logic         [7:0] pipeRGB
);

//-----------------------------------------------------------------------------
// Internal Arrays
//-----------------------------------------------------------------------------
logic               pipe_active    [NUM_PIPES]; // Latched triggers (replaces trigger_move)
logic signed [10:0] topLeftX       [NUM_PIPES];
logic               newPipeGen     [NUM_PIPES];
logic               dr_array       [NUM_PIPES];
logic        [7:0]  rgb_array      [NUM_PIPES];
logic        [5:0]  pipe_chunks    [NUM_PIPES]; // Stores the height for each pipe
logic               pipe_active_D  [NUM_PIPES]; // Edge detectors for the latched triggers


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

//-----------------------------------------------------------------------------
// Game Start to trigger the first pipe
//-----------------------------------------------------------------------------
logic game_started;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) 
        game_started <= 1'b0;
    else if (Y_direction_key) 
        game_started <= 1'b1;
end

//-----------------------------------------------------------------------------
// Cascade Triggers for all of the pipes (Latched)
//-----------------------------------------------------------------------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        for (int j = 0; j < NUM_PIPES; j++) begin
            pipe_active[j] <= 1'b0;
        end
    end else begin
        // Pipe 0 starts immediately on first jump
        if (game_started) 
            pipe_active[0] <= 1'b1;
        
        // Pipes 1 and 2 start when the pipe ahead of them reaches X <= 400
        for (int j = 1; j < NUM_PIPES; j++) begin
            if (game_started && (topLeftX[j-1] <= (11'd640 - PIPE_SPACING))) begin
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
    else begin
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
    
        pipe_move move_inst (
            .clk                (clk),
            .resetN             (resetN),
            .startOfFrame       (startOfFrame),
            .collision          (collision),
            .trigger_move       (pipe_active[i]), // Feed the latched trigger here
            
            .topLeftX           (topLeftX[i]),
            .generateNewChunks  (newPipeGen[i])
        );

        Pipe_Object obj_inst (
            .clk                (clk),
            .resetN             (resetN),
            .pixelX             (pixelX),
            .pixelY             (pixelY),
            .wantedXCoord       (topLeftX[i]),
            .SizeOfUpPipe       (pipe_chunks[i]), // Fed by the sampler above
            
            .pipeDR             (dr_array[i]),
            .pipeRGB            (rgb_array[i])
        );
          
    end
endgenerate

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
            pipeRGB = rgb_array[j];
        end
    end
end

endmodule