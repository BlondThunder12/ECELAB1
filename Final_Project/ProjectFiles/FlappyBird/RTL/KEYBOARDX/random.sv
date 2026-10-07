// (c) Technion IIT, Department of Electrical Engineering 2025 
module random 	
 ( 
	input	logic  clk,
	input	logic  resetN, 
	input	logic	 enable,
	output logic unsigned [SIZE_BITS-1:0] dout	
  ) ;


  
parameter SIZE_BITS = 8;
parameter unsigned [SIZE_BITS-1:0] MIN_VAL = 0;  //set the min and max values 
parameter unsigned [SIZE_BITS-1:0] MAX_VAL = 255;

localparam int RANGE = MAX_VAL - MIN_VAL + 1;
logic [15:0] random_state;
	
always_ff @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			random_state <= 16'hECE2;  // random seed because we are from electrical and computer eng...
			dout <= MIN_VAL;
		end
		
		else if (enable) begin
				random_state <= {random_state[14:0], random_state[15] ^ random_state[13] ^ random_state[12] ^ random_state [10]};
				dout <= MIN_VAL + ((random_state * RANGE) >> 16 );
		end
	
	end
 
endmodule

