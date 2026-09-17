// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements an up-counter that jumps from
// a number to another, then continues to count.
// Both numbers are set by parameters.

module jmp_counter 
	(
   // Input, Output Ports
   input logic clk, 
   input logic resetN, 
   output logic [3:0] count 
   );
	
//------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//------------------------------------------------------------------------------------

// Internal or local parameters/variables declarations

	localparam jmp_from = 4'h5; // <------ assign here the right value 
	localparam jmp_to = 4'hc;   // <------ assign here the right value 
 
 
   always_ff @( posedge clk or negedge resetN )
   begin
      
      if ( !resetN ) begin // Asynchronic reset
			count <= 4'h0;
		end
		else if (count == jmp_from) begin
			count <= jmp_to;
		end
		else if (count == 4'hf) begin
			count <= 4'h0;
		end
		else begin
			count <= count + 4'h1;
		end

	end // always
	
//-------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//-------------------------------------------------------------------------------------
endmodule

