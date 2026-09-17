// (c) Technion IIT, Department of Electrical Engineering 2023 
// Written By Eyal Lev   Nov 2023  
// generate a long pulse,  so it can be seen on a LED 


module oneshot(

  
  // Declare a signal to trigger the one-shot
  input  logic clk, 
  input  logic resetN, 
  input logic trigger,

  // Declare a signal to output the one-shot pulseOut

  output logic pulseOut
);
  // Declare a variable to track the one-shot state
 
	parameter logic SIMULATION_MODE  = 1 ; 
 
	localparam Top_count_REAL = 26'd1_000_000;  // board running
	localparam Top_count_SIM = 26'd20;  //simulation
   localparam Top_count = SIMULATION_MODE ? Top_count_SIM : Top_count_REAL;
  // Declare a counter for timing purposes
  logic [25:0] local_count;

  // Define the one-shot behavior
 
   always_ff @( posedge clk or negedge resetN ) begin
		if ( !resetN ) begin
				pulseOut <= 0;
				local_count <= 0;
		end // if (!resetN)
	else
    if (trigger || (local_count !=0))
	     begin

        if (local_count < Top_count) 
          pulseOut <= 1;
        // else 
        //  pulseOut <= 0;
        

        // Increment counter
        local_count <= local_count + 1;

        // Return to idle state after pulseOut is generated
        if (local_count >= Top_count-1) begin
			 local_count <= 0;
           pulseOut <= 0;
			 end
   
	 end //if (trigger || (count !=0))
  end



endmodule
