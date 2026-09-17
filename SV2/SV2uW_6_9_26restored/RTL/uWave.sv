// (c) Technion IIT, Department of Electrical Engineering 2018 
// Written By Liat Schwartz August 2018 
// Updated September 2020 Dudy.
// Updated by Mor Dahan - January 2022
// Updated by Aviad Etzion - October 2023
// Changed subject to microWave oven controller ( uWave )- Danny G - September 2025
// 
// Implements the state machine of the microWave mini-project

module uWave
	(
	input logic clk, 
	input logic resetN, 
	input logic startN, 
	input logic waitN, 
	input logic OneSecPulse, 
	input logic timerEnd,
	
	output logic countLoadN, 
	output logic countEnable, 
	output logic lampEnable 
   );

//-------------------------------------------------------------------------------------------

// state machine declaration 
   enum logic [2:0] {s_idle, s_arm, s_run, s_pause, s_lampOff, s_lampOn} SMuWave;
 	
//--------------------------------------------------------------------------------------------
//  syncronous code:  executed once every clock to update the current state 
always @(posedge clk or negedge resetN)
   begin
	   
   if ( !resetN ) begin // Asynchronic reset
		SMuWave <= s_idle;
		countLoadN <= 1'b1;
		countEnable <= 1'b0;
		lampEnable  <= 1'b0;
		end 

   
	else 		// Synchronic logic FSM
		begin
		// default outputs 
		countLoadN <= 1'b1;
		countEnable <= 1'b0;
		lampEnable  <= 1'b1;
		
		
	case (SMuWave) // logically defining what is the next state, and the ouptput
		
			//Note: the implementation of the idle state is already given you as an example
//      ======		
			s_idle: begin
//      ======		
				if (startN == 1'b0) 
					SMuWave <= s_arm; 
			end // idle
//--------------------------------------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste to the report #1 
//--------------------------------------------------------------------------------------------------------------------			
//		  ======		
			s_arm: begin
//      ======		
			countLoadN <= 1'b0;
			if(startN) begin
				SMuWave <= s_run;
			end	
			end // arm	
			
//		  ======		
			s_run: begin
//      ======		
			countEnable <= 1'b1;
			
			if (!waitN) begin
				SMuWave <= s_pause;
				end
			else if(timerEnd) begin
				SMuWave <= s_lampOn; 
			end
			end // run
			
//		  ======		
			s_pause: begin
//      ======		
			countEnable <= 0;
			
			if (waitN) begin
				SMuWave <= s_run;
				end
			end // pause
			
//		  ======		
			s_lampOn: begin
//      ======		
			lampEnable <= 1'b1;
			
			if (OneSecPulse) begin
				SMuWave <= s_lampOff;
				end
			end // blinking
			
//		  ======		
			s_lampOff: begin
//      ======		
			lampEnable <= 1'b0;
			
			if (OneSecPulse) begin
				SMuWave <= s_lampOn;
				end
			end // lampOff


			
//--------------------------------------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste SM to the report #1 
//--------------------------------------------------------------------------------------------------------------------			

//  		  =========		
			  default : begin   
//         =========			
					SMuWave <= s_idle;  
			 end // default
						
		endcase
	end //else
		
	end // always sync
	
		
endmodule
