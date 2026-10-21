// (c) Technion IIT, Department of Electrical Engineering 2025 

module pipe_move (
    input   logic clk,
    input   logic resetN,
    input   logic startOfFrame,          // Short pulse every frame
	 input	logic trigger_move,		  // to trigger when the pipe first starts to move
	 input	logic [1:0] game_state,
    input   logic [3:0] speed_level,
    input   logic turbo,                 // Active-high temporary 2x movement
    
    output  logic signed [10:0] topLeftX,// Output target X coordinate
    output  logic               generateNewChunks, // Pulses when pipe wraps around to pick a new height
    output  logic [10:0]         scrollStep,        // Shared step, in 1/64 pixel units
    output  logic               scrollUpdate       // Same edge that advances Xposition
);

int topLeftX_tmp;

// --- Parameters & Fixed-Point Constants ---
parameter int INITIAL_X       = 640;     // Starts just off the right screen boundary
parameter int INITIAL_X_SPEED = 128;     // 128 / 64 = 2.0 pixels per frame
parameter int WIDTH_OF_PIPE = 64;
parameter int WIDTH_OF_EDGE = 80;
parameter int INITIAL_X_OFFSET = 0;     // Initial offscreen spacing, in pixels
parameter int WRAP_DISTANCE = 720;      // Full cycle: NUM_PIPES * PIPE_SPACING
// FIXED_POINT_MULTIPLIER enables sub-pixel precision (1/64th pixel resolution)
const logic signed [10:0] FIXED_POINT_MULTIPLIER = 64; 

// Boundary limits
const int X_FRAME_RIGHT = (INITIAL_X + ((WIDTH_OF_EDGE - WIDTH_OF_PIPE) / 2) ) * FIXED_POINT_MULTIPLIER ;         // Spawn point on the right
const int X_FRAME_LEFT = X_FRAME_RIGHT - WRAP_DISTANCE * FIXED_POINT_MULTIPLIER;
const int X_INITIAL_POSITION = X_FRAME_RIGHT + INITIAL_X_OFFSET * FIXED_POINT_MULTIPLIER;

// State definitions for the diff states of the game
localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;
localparam logic [1:0] PAUSED			= 2'b11;

enum logic [2:0] {
    IDLE_ST,            // Initial reset state
    MOVE_ST,            // Waiting for frame sync; manager controls game state
    START_OF_FRAME_ST,  // Sample movement speed at frame start
    POSITION_CHANGE_ST, // Sub-pixel coordinate update
    POSITION_LIMITS_ST,  // Boundary check and screen re-entry
	 DEAD_ST
} SM_Motion;

int Xspeed;
int Xposition;

logic turbo_meta, turbo_sync;
int normal_Xspeed;
int effective_Xspeed;

// Synchronize the physical switch to the existing clock; no new clock domain.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        turbo_meta <= 1'b0;
        turbo_sync <= 1'b0;
    end else begin
        turbo_meta <= turbo;
        turbo_sync <= turbo_meta;
    end
end

// Preserve frame-based fixed-point motion: 128..512 units = 2..8 px/frame.
// Clamp the input defensively; integer division gives gradual 1/64-pixel steps.
assign normal_Xspeed = INITIAL_X_SPEED +
                       (INITIAL_X_SPEED * 3 * ((speed_level > 4'd10) ? 4'd10 : speed_level)) / 10;
assign effective_Xspeed = turbo_sync ? (normal_Xspeed * 2) : normal_Xspeed;
// Report the actual subtraction made in POSITION_CHANGE_ST. PipeBlocks uses
// pipe 0's copy because all pipe instances move by the same amount and cycle.
// These outputs describe normal scrolling; wrapping a pipe does not move items.
assign scrollStep = 11'(Xspeed);
assign scrollUpdate = (game_state == PLAYING) && (SM_Motion == POSITION_CHANGE_ST);

always_ff @(posedge clk or negedge resetN) begin : fsm_sync_proc
    if (!resetN) begin
			SM_Motion         <= IDLE_ST;
			Xspeed            <= 0;
			Xposition         <= X_INITIAL_POSITION;
			generateNewChunks <= 1'b0;
    end
	 else if( game_state == START_SCREEN) begin
			SM_Motion         <= IDLE_ST;
			Xspeed            <= 0;
			Xposition         <= X_INITIAL_POSITION;
			generateNewChunks <= 1'b0;
	 end
	 
	 else if( game_state == GAME_OVER) begin
			SM_Motion         <= DEAD_ST;
			Xspeed            <= 0;
	 end
	 else if( game_state == PAUSED) begin
		// do nothing :)
	 end
    else begin
			generateNewChunks <= 1'b0; // Default pulse low
			
			// Collision decisions belong to game_manager; react only to game_state.
			case (SM_Motion)
			
					//------------
					IDLE_ST: begin
					//------------
						Xspeed    <= 0;
						Xposition <= X_INITIAL_POSITION;
						if (trigger_move) begin
							Xspeed    <= effective_Xspeed;
							SM_Motion <= MOVE_ST;
						end
					end

					//------------
					MOVE_ST: begin
					//------------
						// Wait for the VGA frame pulse to step motion
						if (startOfFrame)
							SM_Motion <= START_OF_FRAME_ST;
					end

					//------------
					START_OF_FRAME_ST: begin
					//------------
						// Sample the requested speed before the existing position update.
						Xspeed <= effective_Xspeed;
						SM_Motion <= POSITION_CHANGE_ST;
					end

					//------------------------
					POSITION_CHANGE_ST: begin
					//------------------------
						// Move pipe to the left
						Xposition <= Xposition - Xspeed;
						SM_Motion <= POSITION_LIMITS_ST;
					end

					//------------------------
					POSITION_LIMITS_ST: begin
					//------------------------
						// If completely off the left edge, wrap around to the right
						if (Xposition <= X_FRAME_LEFT) begin
							// Carry any overshoot through the wrap to preserve pipe spacing.
							Xposition         <= Xposition + WRAP_DISTANCE * FIXED_POINT_MULTIPLIER;
							generateNewChunks <= 1'b1; // Trigger LFSR for new pipe opening
						end

						SM_Motion <= MOVE_ST;
					end
					//------------------------
					DEAD_ST: begin
					//------------------------
						Xspeed <= 0;
			end

					default: SM_Motion <= IDLE_ST;

			endcase
	end
end // fsm_sync_proc

// Round down consistently across X=0 to preserve integer-pixel spacing too.
assign topLeftX_tmp = Xposition >>> 6; // FIXED_POINT_MULTIPLIER = 64
// Later pipes can start beyond signed 11-bit range; keep them safely offscreen.
assign topLeftX = (topLeftX_tmp > 1023) ? 11'sd1023 : topLeftX_tmp[10:0];

endmodule
