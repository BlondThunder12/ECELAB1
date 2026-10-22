// (c) Technion IIT, Department of Electrical Engineering 2025 

module	bird_move	(	
 
					input	 logic clk,
					input	 logic resetN,
					input	 logic startOfFrame,      			// One pulse per VGA frame
					input	 logic Y_direction_key,   			//move Y Up   
					input  logic reverse_gravity_switch, 	//to check if we need to reverse the gravity of ther bird
					input	 logic [1:0] game_state,
					input  logic godmode,
					input  logic damage_pulse, // One clock for an accepted hit, from player_lives
					
					output logic signed 	[10:0] topLeftX, // output the top left corner 
					output logic signed	[10:0] topLeftY,  // can be negative , if the object is partliy outside
					output logic 					 bird_hit_borders,
					output logic signed [5:0] menuYOffset, // Shared with the start-screen logo
					output logic signed [5:0] bird_tilt // Degrees: -30 nose up .. +30 nose down
					
);
 int 	 topLeftX_tmp; // output the top left corner 
 int   topLeftY_tmp;  // can be negative , if the object is partliy outside 

// a module used to generate the  ball trajectory.  

parameter int INITIAL_X = 280;
parameter int INITIAL_Y = 185;
parameter int INITIAL_X_SPEED = 40;
parameter int INITIAL_Y_SPEED = 20;
parameter int Y_ACCEL = -10;

const int MAX_Y_SPEED = 500;
const logic signed 	[10:0]	FIXED_POINT_MULTIPLIER = 64; // note it must be 2^n 
// FIXED_POINT_MULTIPLIER is used to enable working with integers in high resolution so that 
// we do all calculations with topLeftX_FixedPoint to get a resolution of 1/64 pixel in calcuatuions,
// we devide at the end by FIXED_POINT_MULTIPLIER which must be 2^n, to return to the initial proportions


// birdPic.mif is cropped to 17x12 without resampling, displayed at 2x.
localparam int OBJECT_WIDTH_X = 34;
localparam int OBJECT_HEIGHT_Y = 24;
// Preserve the visible position from the former padded 64x64 drawing box.
// INITIAL_X/Y and the physics registers retain their original reference point.
localparam int DRAW_OFFSET_X = 14; // 7 cropped source columns * 2x display scale.
localparam int DRAW_OFFSET_Y = 20; // 10 cropped source rows * 2x display scale.
// These offsets preserve the bird's visible location; they add no blank pixels.
// No SafetyMargin: the visible bird now touches the ceiling/ground at contact.
localparam int PLAY_AREA_TOP = 0;
localparam int PLAY_AREA_BOTTOM = 480 - 32; // First ground row, like ground_draw.

const int x_FRAME_LEFT = -DRAW_OFFSET_X * FIXED_POINT_MULTIPLIER;
const int x_FRAME_RIGHT = (640 - DRAW_OFFSET_X - OBJECT_WIDTH_X) * FIXED_POINT_MULTIPLIER;
const int y_FRAME_TOP = (PLAY_AREA_TOP - DRAW_OFFSET_Y) * FIXED_POINT_MULTIPLIER;
const int y_FRAME_BOTTOM = (PLAY_AREA_BOTTOM - DRAW_OFFSET_Y - OBJECT_HEIGHT_Y) * FIXED_POINT_MULTIPLIER;

localparam logic signed [5:0] TILT_LEVEL = 6'sd0;
localparam int MAX_TILT_DEGREES = 30;
localparam logic signed [5:0] TILT_STEP_DEGREES = 6'sd10; // One table step per frame.
localparam int TILT_SPEED_THRESHOLD = 64; // Level within +/-1 pixel per frame.
localparam int TILT_BORDER_MARGIN = 9 * 64; // Match the renderer's vertical padding.

// Ease toward the movement's target angle by 10 degrees per frame. The renderer
// looks up sine/cosine for this angle. Borders force level to keep corners clear.
function automatic logic signed [5:0] tilt_for_motion(
    input int position, input int speed, input logic signed [5:0] current_tilt
);
    int target_tilt;
    begin
        if (speed < -TILT_SPEED_THRESHOLD) target_tilt = -MAX_TILT_DEGREES;
        else if (speed > TILT_SPEED_THRESHOLD) target_tilt = MAX_TILT_DEGREES;
        else target_tilt = 0;

        if (position <= y_FRAME_TOP + TILT_BORDER_MARGIN ||
            position >= y_FRAME_BOTTOM - TILT_BORDER_MARGIN)
            tilt_for_motion = TILT_LEVEL;
        else if (current_tilt < target_tilt)
            tilt_for_motion = current_tilt + TILT_STEP_DEGREES;
        else if (current_tilt > target_tilt)
            tilt_for_motion = current_tilt - TILT_STEP_DEGREES;
        else
            tilt_for_motion = current_tilt;
    end
endfunction


// Global game states needed to update the bird movement
localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;
localparam logic [1:0] PAUSED    	= 2'b11;

enum  logic [2:0] {IDLE_ST,         	// initial state
						 MOVE_ST, 				// moving no colision 
						 START_OF_FRAME_ST, 	          // startOfFrame activity-after all data collected 
						 POSITION_CHANGE_ST, // position interpolate 
						 POSITION_LIMITS_ST, // check if inside the frame 
						 DEAD_ST
						}  SM_Motion ;

int Xspeed  ; // speed    
int Yspeed  ; 
int Xposition ; //position   
int Yposition ;  

logic Y_direction_key_D; // added an edge detector for the Y press
logic [3:0] recoilOffset; // Brief 8-pixel movement away from a pipe, then return.

// Menu animation: move one pixel every four frames, between -8 and +8.
// This display offset is separate from the gameplay position and velocity.
logic [1:0] menuFrameCounter;
logic menuMovingDown;
always_ff @(posedge clk or negedge resetN) begin
	if (!resetN) begin
		menuYOffset <= 6'sd0;
		menuFrameCounter <= 2'd0;
		menuMovingDown <= 1'b0;
	end
	else if (game_state != START_SCREEN) begin
		menuYOffset <= 6'sd0;
		menuFrameCounter <= 2'd0;
		menuMovingDown <= 1'b0;
	end
	else if (startOfFrame) begin
		menuFrameCounter <= menuFrameCounter + 2'd1;
		if (menuFrameCounter == 2'd3) begin
			if (menuMovingDown) begin
				if (menuYOffset == 6'sd8) begin
					menuYOffset <= 6'sd7;
					menuMovingDown <= 1'b0;
				end
				else menuYOffset <= menuYOffset + 6'sd1;
			end
			else begin
				if (menuYOffset == -6'sd8) begin
					menuYOffset <= -6'sd7;
					menuMovingDown <= 1'b1;
				end
				else menuYOffset <= menuYOffset - 6'sd1;
			end
		end
	end
end
 

always_ff @(posedge clk or negedge resetN)
begin : fsm_sync_proc

	if (resetN == 1'b0) begin 
		SM_Motion <= IDLE_ST ; 
		Xspeed <= 0   ; 
		Yspeed <= 0  ; 
		Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER  ; 
		Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER   ; 
		Y_direction_key_D <= 0 ;
		bird_hit_borders <= 0;	
		recoilOffset <= 4'd0;
		bird_tilt <= TILT_LEVEL;
	end 	
	else if(game_state == START_SCREEN) begin
		SM_Motion <= IDLE_ST ; 
		Xspeed <= 0   ; 
		Yspeed <= 0  ; 
		Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER  ; 
		Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER   ; 
		Y_direction_key_D <= 0 ;
		bird_hit_borders <= 0;
		recoilOffset <= 4'd0;
		bird_tilt <= TILT_LEVEL;
	end
	
	else if (game_state == GAME_OVER) begin
		bird_hit_borders <= 1'b0;
		SM_Motion <= DEAD_ST;
		// Show the panel immediately. Only the bird keeps moving, falling down
		// to the ground even if reverse gravity was selected during the run.
		if (SM_Motion != DEAD_ST)
			Yspeed <= 0;
		else if (startOfFrame) begin
			bird_tilt <= tilt_for_motion(Yposition + Yspeed, Yspeed, bird_tilt);
			if (Yposition + Yspeed >= y_FRAME_BOTTOM) begin
				Yposition <= y_FRAME_BOTTOM;
				Yspeed <= 0;
			end else begin
				Yposition <= Yposition + Yspeed;
				if (Yspeed < MAX_Y_SPEED) Yspeed <= Yspeed - Y_ACCEL;
			end
		end
	end
	else if (game_state == PAUSED) begin
		bird_hit_borders <= 1'b0; // Hold the position, velocity and recoil.
	end
	else if (damage_pulse) begin
		bird_hit_borders <= 1'b0;
		recoilOffset <= 4'd8;
		Y_direction_key_D <= Y_direction_key;
		// Rebound inward at a border; otherwise give the same lift as a flap.
		if (Yposition <= y_FRAME_TOP) Yspeed <= MAX_Y_SPEED / 2;
		else if (Yposition >= y_FRAME_BOTTOM) Yspeed <= -MAX_Y_SPEED / 2;
		else if (!reverse_gravity_switch) Yspeed <= -MAX_Y_SPEED / 2;
		else Yspeed <= MAX_Y_SPEED / 2;
		SM_Motion <= MOVE_ST;
	end
	else begin
		// A contact is a pulse, not a latched hit. Ignored contacts during the
		// cooldown must not become damage when that cooldown finishes.
		bird_hit_borders <= 1'b0;
		if (startOfFrame && recoilOffset != 0) recoilOffset <= recoilOffset - 1'b1;
	
		Y_direction_key_D <= Y_direction_key;
	
		case(SM_Motion)
		
		//------------
			IDLE_ST: begin
		//------------
		
				Xspeed  <= INITIAL_X_SPEED ;  
				Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER; 
				Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER; 
				
				if(!reverse_gravity_switch) 	Yspeed <= -MAX_Y_SPEED / 2; // if the switch isnt flipped up, normal gravity
				else 									Yspeed <= MAX_Y_SPEED / 2;
				
				SM_Motion <= MOVE_ST;

			end
	
		//------------
			MOVE_ST:  begin     // moving collecting colisions 
		//------------
		// keys direction change 
				if (Y_direction_key && !Y_direction_key_D ) begin//  if the button is pressed now and wasnt pressed last cycle
					if(!reverse_gravity_switch) Yspeed <= -MAX_Y_SPEED / 2; // if the switch isnt flipped up, normal gravity
					else Yspeed <= MAX_Y_SPEED / 2; 									// if the switch is flipped up, reverse gravity
				end
				if (startOfFrame)
					SM_Motion <= START_OF_FRAME_ST ; 
					
									
		end 
		
		//------------
			START_OF_FRAME_ST:  begin      //check if any colisin was detected 
		//------------
	
			if(!reverse_gravity_switch && Yspeed > MAX_Y_SPEED) begin
				Yspeed <= MAX_Y_SPEED;
			end
			else if(reverse_gravity_switch && Yspeed < -MAX_Y_SPEED) begin
				Yspeed <= -MAX_Y_SPEED;
			end
			
			SM_Motion <= POSITION_CHANGE_ST;
		end

		//------------------------
			POSITION_CHANGE_ST : begin  // position interpolate 
		//------------------------
	
				Yposition <= Yposition + Yspeed ;
			 
				// accelerate 
			if(!reverse_gravity_switch) begin
				if (Yspeed < MAX_Y_SPEED ) //  limit the speed while going down 
   				Yspeed <= Yspeed - Y_ACCEL ; // deAccelerate : slow the speed down every clock tick 
			end 
			else begin
				if (Yspeed > -MAX_Y_SPEED ) //  limit the speed while going up
   				Yspeed <= Yspeed + Y_ACCEL ; // deAccelerate : slow the speed up every clock tick
			end	
				
				SM_Motion <= POSITION_LIMITS_ST ; 
			end
		
		//------------------------
			POSITION_LIMITS_ST : begin  //check if still inside the frame 
		//------------------------
			
			// make sure bird X coordinates are in screen
			// Update the pose once per movement frame, alongside the new position.
			bird_tilt <= tilt_for_motion(Yposition, Yspeed, bird_tilt);
			if (Xposition < x_FRAME_LEFT) 
							Xposition <= x_FRAME_LEFT ; 
			if (Xposition > x_FRAME_RIGHT)
							Xposition <= x_FRAME_RIGHT ; 
			
			// Clamp at the visible edge and rebound inward, including during the
			// damage cooldown. A border contact costs a life only when accepted.
			if (Yposition <= y_FRAME_TOP) begin
				Yposition <= y_FRAME_TOP;
				Yspeed <= MAX_Y_SPEED / 2;
				if (!godmode) bird_hit_borders <= 1'b1;
			end
			if (Yposition >= y_FRAME_BOTTOM) begin
				Yposition <= y_FRAME_BOTTOM;
				Yspeed <= -MAX_Y_SPEED / 2;
				if (!godmode) bird_hit_borders <= 1'b1;
			end
			SM_Motion <= MOVE_ST ; 
			
			end
		//------------------------
			DEAD_ST: begin
		//------------------------
			Yspeed <= 0;
			end
		
		endcase  // case 

		
	end 

end // end fsm_sync


//return from FIXED point trunc back to prame size parameters 
  
assign 	topLeftX_tmp = Xposition / FIXED_POINT_MULTIPLIER + DRAW_OFFSET_X - int'(recoilOffset);
assign 	topLeftY_tmp = (game_state == START_SCREEN) ?
						INITIAL_Y + DRAW_OFFSET_Y + int'(menuYOffset) :
						Yposition / FIXED_POINT_MULTIPLIER + DRAW_OFFSET_Y;

assign 	topLeftX = {topLeftX_tmp[10:0]} ;   // note it must be 2^n 
assign 	topLeftY = {topLeftY_tmp[10:0]} ;    	

endmodule	
//---------------
 
