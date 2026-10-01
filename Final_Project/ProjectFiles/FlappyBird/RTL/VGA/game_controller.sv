// game controller dudy Febriary 2020
// (c) Technion IIT, Department of Electrical Engineering 2021 
//updated --Eyal Lev 2021


module	game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,  // short pulse every start of frame 30Hz 
			input	logic	drawing_request_bird,
			input	logic	drawing_request_border,
			
			input logic drawing_request_number,
			input logic drawing_request_pipe,
			
			output logic collision, // active in case of collision between two objects
			
			output logic SingleHitPulse, // critical code, generating A single pulse in a frame 
			output logic led_collision_trigger
			
			


);

logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions 
logic collision_bird_number; // collision between bird and number - is not output
logic collision_bird_pipe; 
logic collision_bird_borders;

assign collision_bird_borders = (drawing_request_bird && drawing_request_border);
assign collision_bird_number = (drawing_request_bird && drawing_request_number);
assign collision_bird_pipe = (drawing_request_bird && drawing_request_pipe); 


assign collision = collision_bird_borders || collision_bird_number || collision_bird_pipe;


always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN)
	begin 
		flag	<= 1'b0;
		SingleHitPulse <= 1'b0 ; 
		led_collision_trigger <= 1'b0;
		
	end 
	else begin 
	
			SingleHitPulse <= 1'b0 ; // default 
			if(startOfFrame) 
				flag <= 1'b0 ; // reset for next time 
				

if ( collision_bird_number  && (flag == 1'b0)) begin 
			flag	<= 1'b1; // to enter only once 
			SingleHitPulse <= 1'b1 ; 
		end
else if ( collision && (flag == 1'b0)) begin
		flag <= 1'b1;
		led_collision_trigger <= 1'b1;
		end 
	end ;
end

endmodule