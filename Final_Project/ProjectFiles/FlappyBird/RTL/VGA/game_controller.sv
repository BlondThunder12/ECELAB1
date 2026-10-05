// game controller dudy Febriary 2020
// (c) Technion IIT, Department of Electrical Engineering 2021 
//updated --Eyal Lev 2021


module	game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,  // short pulse every start of frame 30Hz 
			input	logic	drawing_request_bird,
			input	logic	bird_OOB_collision,
			input logic drawing_request_pipe,
			input logic [1:0] game_state,
			
			output logic collision, // active in case of collision between two objects
			
			output logic SingleHitPulse, // critical code, generating A single pulse in a frame 
			output logic led_collision_trigger
			
			


);

logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions 
logic collision_bird_pipe; 

assign collision_bird_pipe = (drawing_request_bird && drawing_request_pipe); 
assign collision = bird_OOB_collision || collision_bird_pipe;

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN)
	begin 
		flag	<= 1'b0;
		SingleHitPulse <= 1'b0 ; 
		led_collision_trigger <= 1'b0;
		
	end else if(game_state == START_SCREEN) begin
		flag	<= 1'b0;
		SingleHitPulse <= 1'b0 ; 
		led_collision_trigger <= 1'b0;
	
	end 
	else begin 
			SingleHitPulse <= 1'b0 ; // default 
			
		if(startOfFrame) 
				flag <= 1'b0 ; // reset for next time 
				
		else if ( collision && (flag == 1'b0)) begin
			flag <= 1'b1;
			led_collision_trigger <= 1'b1;
			SingleHitPulse <= 1'b1;
		end 
	end ;
end

endmodule