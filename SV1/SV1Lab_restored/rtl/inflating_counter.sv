// (c) Technion IIT, Department of Electrical Engineering 2018 

// Implements the inflating counter by instantiating
// two counters and a comparator

module inflating_counter 
	(
   // Input, Output Ports
	input logic clk, 
	input logic resetN, 
	input logic enable,
   
	output logic [3:0] FastCount,
	output logic [3:0] SlowCount
   );


	logic equal; // internal variable - output of the comparator
	
//------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste into the report
//------------------------------------------------------------------------------------
	
	// Fast counter instantiation
	up_counter fastC(
				.clk(clk),
// Fill your code here
				.count(FastCount) 
				);

	// Slow counter instantiation
	up_counter slowC( 
// Fill your code here
				.count(SlowCount) 
				);	
				
	
	// Comparator instantiation
   comparator cmp 
	(
// Fill your code here
   ); 
	
//-------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste into the report 
//-------------------------------------------------------------------------------------

endmodule
