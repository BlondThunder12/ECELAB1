module game_manager(
	input		logic       clk,
	input		logic       resetN,
	input		logic       start_key,     // Key to start the game
	input		logic       restart_key,   // Key to Restart the game from Game Over screen
	input		logic			pause_key, 		// Key to pause the game and can be continued with the same key
	input		logic       collision,     // to know to move to the end screen
	input		logic 		bird_hit_borders,
	input       logic [9:0] score,       // Binary value of the existing displayed score
	input       logic godmode_switch,   // Active-high SW[8], asynchronous to clk

    output logic [1:0] game_state,    // Broadcasts current state to all modules
    output logic [3:0] speed_level,   // Custom score ranges, capped at level 10
    output logic godmode_active      // Synchronized mode shared by collision/motion logic
);

// -----------------------------------------
// Game states 
// -----------------------------------------
localparam 	logic [1:0] START_SCREEN = 2'b00;
localparam 	logic [1:0] PLAYING      = 2'b01;
localparam 	logic [1:0] GAME_OVER    = 2'b10;
localparam	logic [1:0] PAUSED		 = 2'b11;

logic [1:0] current_state, next_state;
logic			pause_key_D; 				 	// Edge detector
logic godmode_meta;

// Synchronize the physical switch once, then distribute the same mode to all users.
always_ff @(posedge clk or negedge resetN) begin
	if (!resetN) begin
		godmode_meta <= 1'b0;
		godmode_active <= 1'b0;
	end else begin
		godmode_meta <= godmode_switch;
		godmode_active <= godmode_meta;
	end
end
// -----------------------------------------
// State memory
// -----------------------------------------

always_ff @(posedge clk or negedge resetN) begin
	if(!resetN) begin
		current_state <= START_SCREEN;
		pause_key_D <= 1'b0;
	end
	else begin
		current_state <= next_state;
		pause_key_D <= pause_key;
	end
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
			// Winning ends the run even when Godmode suppresses ordinary hazards.
			if (score >= 10'd999) next_state = GAME_OVER;
			else if (!godmode_active && (collision || bird_hit_borders)) next_state = GAME_OVER;
			else if(pause_key && !pause_key_D) next_state = PAUSED;
      end
        
      GAME_OVER: begin
			if (restart_key) next_state = START_SCREEN;
		end
		
		PAUSED: begin
			if(pause_key && !pause_key_D) next_state = PLAYING;
		end
        
      default: next_state = START_SCREEN;
	endcase
end
	
assign game_state = current_state;

// Combinational score-to-level table; preserve reset/start-screen behavior.
always_comb begin
    if (!resetN || current_state == START_SCREEN) speed_level = 4'd0;
    else if (score < 10'd5)   speed_level = 4'd0;
    else if (score < 10'd15)  speed_level = 4'd1;
    else if (score < 10'd30)  speed_level = 4'd2;
    else if (score < 10'd40)  speed_level = 4'd3;
    else if (score < 10'd50)  speed_level = 4'd4;
    else if (score < 10'd60)  speed_level = 4'd5;
    else if (score < 10'd80)  speed_level = 4'd6;
    else if (score < 10'd120) speed_level = 4'd7;
    else if (score < 10'd180) speed_level = 4'd8;
    else if (score < 10'd255) speed_level = 4'd9;
    else                     speed_level = 4'd10;
end


endmodule

