// (c) Technion IIT, Department of Electrical Engineering 2025 

module	bird_move	(	
 
					input	 logic clk,
					input	 logic resetN,
					input	 logic startOfFrame,      			//short pulse every start of frame 30Hz 
					input	 logic Y_direction_key,   			//move Y Up   
					input  logic reverse_gravity_switchN, 	//to check if we need to reverse the gravity of ther bird
					input	 logic [1:0] game_state,
					
					output logic signed 	[10:0] topLeftX, // output the top left corner 
					output logic signed	[10:0] topLeftY,  // can be negative , if the object is partliy outside
					output logic 					 bird_hit_borders
					
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


// movement limits 
const int   OBJECT_WIDTH_X = 64;
const int   OBJECT_HIGHT_Y = 32;
const int	SafetyMargin   =	2;

const int	x_FRAME_LEFT	=	(SafetyMargin)* FIXED_POINT_MULTIPLIER; 
const int	x_FRAME_RIGHT	=	(639 - SafetyMargin - OBJECT_WIDTH_X)* FIXED_POINT_MULTIPLIER; 
const int	y_FRAME_TOP		=	(SafetyMargin) * FIXED_POINT_MULTIPLIER;
const int	y_FRAME_BOTTOM	=	(479 -SafetyMargin - OBJECT_HIGHT_Y ) * FIXED_POINT_MULTIPLIER; //- OBJECT_HIGHT_Y


// Global game states needed to update the bird movement
localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;

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
 

  logic [4:0] hit_reg = 5'b00000;
 //---------
 
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
	
	end 	
	else if(game_state == START_SCREEN) begin
		SM_Motion <= IDLE_ST ; 
		Xspeed <= 0   ; 
		Yspeed <= 0  ; 
		Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER  ; 
		Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER   ; 
		Y_direction_key_D <= 0 ;
		bird_hit_borders <= 0;
	end
	
	else if (game_state == GAME_OVER) begin
		Yspeed    <= 0;
		SM_Motion <= DEAD_ST;
	end
	else begin

		Y_direction_key_D <= Y_direction_key;
	
		case(SM_Motion)
		
		//------------
			IDLE_ST: begin
		//------------
		
				Xspeed  <= INITIAL_X_SPEED ;  
				Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER; 
				Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER; 
				
				if(!reverse_gravity_switchN) 	Yspeed <= -MAX_Y_SPEED / 2; // if the switch isnt flipped up, normal gravity
				else 									Yspeed <= MAX_Y_SPEED / 2;
				
				SM_Motion <= MOVE_ST;

			end
	
		//------------
			MOVE_ST:  begin     // moving collecting colisions 
		//------------
		// keys direction change 
				if (Y_direction_key && !Y_direction_key_D ) begin//  if the button is pressed now and wasnt pressed last cycle
					if(!reverse_gravity_switchN) Yspeed <= -MAX_Y_SPEED / 2; // if the switch isnt flipped up, normal gravity
					else Yspeed <= MAX_Y_SPEED / 2; 									// if the switch is flipped up, reverse gravity
				end
				if (startOfFrame)
					SM_Motion <= START_OF_FRAME_ST ; 
					
									
		end 
		
		//------------
			START_OF_FRAME_ST:  begin      //check if any colisin was detected 
		//------------
	
			// Check if the bird hit the border
			if (Yposition <= y_FRAME_TOP || Yposition >= y_FRAME_BOTTOM) begin
				bird_hit_borders <= 1'b1;
			end
			
			else if(!reverse_gravity_switchN && Yspeed > MAX_Y_SPEED) begin
				Yspeed <= MAX_Y_SPEED;
			end
			else if(reverse_gravity_switchN && Yspeed < -MAX_Y_SPEED) begin
				Yspeed <= -MAX_Y_SPEED;
			end
			
			SM_Motion <= POSITION_CHANGE_ST;
		end

		//------------------------
			POSITION_CHANGE_ST : begin  // position interpolate 
		//------------------------
	
				Yposition <= Yposition + Yspeed ;
			 
				// accelerate 
			if(!reverse_gravity_switchN) begin
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
			if (Xposition < x_FRAME_LEFT) 
							Xposition <= x_FRAME_LEFT ; 
			if (Xposition > x_FRAME_RIGHT)
							Xposition <= x_FRAME_RIGHT ; 
			
			// make sure bird Y coordinates are in screen
			if (Yposition <= y_FRAME_TOP) 
							Yposition <= y_FRAME_TOP ;
			
			if (Yposition >= y_FRAME_BOTTOM) 
							Yposition <= y_FRAME_BOTTOM ; 
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
  
assign 	topLeftX_tmp = Xposition / FIXED_POINT_MULTIPLIER ;   // note it must be 2^n 
assign 	topLeftY_tmp = Yposition / FIXED_POINT_MULTIPLIER ;    

assign 	topLeftX = {topLeftX_tmp[10:0]} ;   // note it must be 2^n 
assign 	topLeftY = {topLeftY_tmp[10:0]} ;    	

endmodule	
//---------------
 
