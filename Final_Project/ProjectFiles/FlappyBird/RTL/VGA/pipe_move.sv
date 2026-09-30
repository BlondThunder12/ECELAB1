// (c) Technion IIT, Department of Electrical Engineering 2025 

module pipe_move (
    input   logic clk,
    input   logic resetN,
    input   logic startOfFrame,          // Short pulse every frame
    input   logic collision,             // Freezes pipe on hit / game over
	 input	logic trigger_move,		  // to trigger when the pipe first starts to move
    
    output  logic signed [10:0] topLeftX,// Output target X coordinate
    output  logic               generateNewChunks // Pulses when pipe wraps around to pick a new height
);

int topLeftX_tmp;

// --- Parameters & Fixed-Point Constants ---
parameter int INITIAL_X       = 640;     // Starts just off the right screen boundary
parameter int INITIAL_X_SPEED = 128;     // 128 / 64 = 2.0 pixels per frame
parameter int WIDTH_OF_PIPE = 64;
parameter int WIDTH_OF_EDGE = 80;
// FIXED_POINT_MULTIPLIER enables sub-pixel precision (1/64th pixel resolution)
const logic signed [10:0] FIXED_POINT_MULTIPLIER = 64; 

// Boundary limits
const int PIPE_WIDTH    = 80;            // Maximum collar width
const int X_FRAME_LEFT  = -PIPE_WIDTH * FIXED_POINT_MULTIPLIER; // Fully hidden on the left
const int X_FRAME_RIGHT = (INITIAL_X + ((WIDTH_OF_EDGE - WIDTH_OF_PIPE) / 2) ) * FIXED_POINT_MULTIPLIER ;         // Spawn point on the right

enum logic [2:0] {
    IDLE_ST,            // Initial reset state
    MOVE_ST,            // Waiting for frame sync while monitoring collision
    START_OF_FRAME_ST,  // Collision handling at frame start
    POSITION_CHANGE_ST, // Sub-pixel coordinate update
    POSITION_LIMITS_ST,  // Boundary check and screen re-entry
	 DEAD_ST
} SM_Motion;

int Xspeed;
int Xposition;

always_ff @(posedge clk or negedge resetN) begin : fsm_sync_proc
    if (!resetN) begin
			SM_Motion         <= IDLE_ST;
			Xspeed            <= 0;
			Xposition         <= X_FRAME_RIGHT;
			generateNewChunks <= 1'b0;
    end
    else begin
			generateNewChunks <= 1'b0; // Default pulse low
			
			if (collision && (SM_Motion != IDLE_ST)) begin
				Xspeed    <= 0;
				SM_Motion <= DEAD_ST;
			end 
			else begin
				case (SM_Motion)
			
					//------------
					IDLE_ST: begin
					//------------
						Xspeed    <= 0;
						Xposition <= X_FRAME_RIGHT;
						if (trigger_move) begin
							Xspeed    <= INITIAL_X_SPEED;
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
						// If collision occurred, halt motion; otherwise advance
						if (collision) begin
							Xspeed    <= 0;
							SM_Motion <= MOVE_ST;
						end
						else begin
							SM_Motion <= POSITION_CHANGE_ST;
						end
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
							Xposition         <= X_FRAME_RIGHT;
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
	end
end // fsm_sync_proc

// Convert fixed-point coordinate back to integer pixel domain
assign topLeftX_tmp = Xposition / FIXED_POINT_MULTIPLIER;
assign topLeftX     = topLeftX_tmp[10:0];

endmodule