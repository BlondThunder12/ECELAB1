// (c) Technion IIT, Department of Electrical Engineering 2023 
// Written By David Bar-On  Nov 2023  
// generate the third digin of byterec 

module make_brake_extended_decoder	
 ( input  logic clk, 
   input  logic resetN, 
	input   logic extended,
   input   logic make,
	input   logic brakk, 
   output  logic [6:0] oSEG	
  ) ;
  
  	parameter logic SIMULATION_MODE  = 1 ;
	
	logic make_OS, brakee_OS;  // after one shot 

	
	oneshot #(.SIMULATION_MODE(SIMULATION_MODE)) oneshot (.clk(clk), .resetN(resetN), .trigger(make), .pulseOut(make_OS) );
	oneshot #(.SIMULATION_MODE(SIMULATION_MODE)) oneshot1 (.clk(clk), .resetN(resetN), .trigger(brakk), .pulseOut(brakee_OS) );
	

always_comb
begin

    oSEG = {1'b1,!make_OS,!brakee_OS,1'b1,!extended,!extended,1'b1};// 0 turns the lamp on 
end

endmodule
