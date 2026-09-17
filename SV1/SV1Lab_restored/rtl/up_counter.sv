// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements an up-counter that has also control inputs,
// loadN, enable_cnt and enable to control the count
// and data input - init[3:0] for the load functionality


module up_counter 
	(
   // Input, Output Ports
   input logic clk, 
   input logic resetN,
   input logic enable,
	input logic loadN,
   input logic enable_cnt,
   input logic [3:0] init,
   output logic [3:0] count 
   );

 	 
 
   always_ff @( posedge clk , negedge resetN )
   begin
	
//------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//------------------------------------------------------------------------------------
      
      if ( !resetN ) begin // Asynchronic reset

		// Fill your code here

		end
		
//-------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//-------------------------------------------------------------------------------------

   end // always
	 
endmodule

