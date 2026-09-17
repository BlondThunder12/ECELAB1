// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements a simple up-counter 

module simple_up_counter 
	(
   // Input, Output Ports
   input logic clk, 
   input logic resetN,
   output logic [3:0] count 
   );
	
   always_ff @( posedge clk or negedge resetN )
   begin
	
//------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//------------------------------------------------------------------------------------
     
		if ( !resetN ) begin // Asynchronic reset
			count <= 4'b0000;
		end
		else if (count == 4'b1001) begin
			count <= 4'b0000;
		end
		else begin
			count <= count + 4'b0001;
		end
		
		
//-------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//-------------------------------------------------------------------------------------

	end // always
endmodule

