// (c) Technion IIT, Department of Electrical Engineering 2021
// Written By David Bar-On  June 2018 
// filters the output, ignores short glitches in the input 
// Dec-2024 make it sync only , no  always comb

module lpf 	
 #(parameter FILTER_SIZE = 4)
 
 ( 
 	input	   logic  clk,
	input	   logic  resetN, 
	input	   logic  in,
	
   output  logic 	out_filt	
 
  ) ;


 enum  logic {ONE_ST, ZERO_ST}  SM_LPF; // one bit holding the two states 

  logic [FILTER_SIZE-1:0] cntr ; 

	always_ff @(posedge clk or negedge resetN)
	begin
		if (resetN == 1'b0) begin 
			SM_LPF <= ZERO_ST ; 
			cntr <= {FILTER_SIZE{1'b0}}; ;
			end 	
		else begin 
			
			if (in == 1'b1) begin 
				if (cntr <  {FILTER_SIZE{1'b1}} ) //bit extension to as many ones as needed  
						cntr <= cntr + 1'b1 ; // increment the counterif the input is one 
				else 
						SM_LPF <= ONE_ST;
				end
			else begin // in == 0 
					if (cntr >  {FILTER_SIZE{1'b0}} )
						cntr <= cntr - 1'b1 ; 
					else  
						SM_LPF <= ZERO_ST;
				end ; 
			end ; 	

	end // end fsm_sync_proc
 

 // the counter isincrementted every clock, if the are enought ones, or zeros then the state changes 
 
 	
	// decoding the state to output logic 		
	
	 assign out_filt =  (SM_LPF == ONE_ST) ? 1'b1 :  1'b0 ;	

endmodule


