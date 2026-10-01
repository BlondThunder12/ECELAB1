module game_manager(
	input		logic       clk,
	input		logic       resetN,
	input		logic       start_key,      // Key to start the game
	input		logic       restart_key,    // Key to Restart the game from Game Over screen
	input		logic       collision,     // to know to move to the end screen
	input		logic 		bird_hit_borders,

    output logic [1:0] game_state     // Broadcasts current state to all modules
);

// -----------------------------------------
// Game states 
// -----------------------------------------
localparam 	logic [1:0] START_SCREEN = 2'b00;
localparam 	logic [1:0] PLAYING      = 2'b01;
localparam 	logic [1:0] GAME_OVER    = 2'b10;

logic [1:0] current_state, next_state;

// -----------------------------------------
// State memory
// -----------------------------------------

always_ff @(posedge clk or negedge resetN) begin
	if(!resetN) current_state <= START_SCREEN;
	else 			current_state <= next_state;
end

// -----------------------------------------
// Next state logic
// -----------------------------------------

always_comb begin
	next_state = current_state; // Default: stay in current state

	case (current_state)
		START_SCREEN: begin
			if (start_key) next_state = PLAYING;
		end
        
      PLAYING: begin
			if (collision || bird_hit_borders) next_state = GAME_OVER;
      end
        
      GAME_OVER: begin
			if (restart_key) next_state = START_SCREEN;
		
		end
        
      default: next_state = START_SCREEN;
	endcase
end
	
assign game_state = current_state;


endmodule

