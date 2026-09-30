
// (c) Technion IIT, Department of Electrical Engineering 2025 
//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// SystemVerilog version Alex Grinshpun May 2018
// coding convention dudy December 2018

//-- Eyal Lev 31 Jan 2021

module	objects_mux	(	
//		--------	Clock Input	 	
					input		logic	clk,
					input		logic	resetN,
		   // smiley 
					input		logic	birdDrawingRequest, // two set of inputs per unit
					input		logic	[7:0] birdRGB, 
					     
		  // add the box here 
					input		logic boxDrawingRequest,
					input		logic [7:0] boxRGB,
			  
		  ////////////////////////
		  // background 
					input    logic heartDrawingRequest, // box of numbers
					input		logic	[7:0] heartRGB,   
					input		logic	[7:0] backGroundRGB, 
					input		logic	BGDrawingRequest, 
					input		logic	[7:0] RGB_MIF,
			// Pipes Inputs
					input		logic pipesDrawingRequest,
					input 	logic [7:0] pipesRGB,
			  
				   output	logic	[7:0] RGBOut
);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
			RGBOut	<= 8'b0;
	end
	
	else begin
		if (birdDrawingRequest == 1'b1 )   
			RGBOut <= birdRGB;  //first priority 
		 
//--- add logic for box here ------------------------------------------------------		

		else if (boxDrawingRequest == 1'b1) RGBOut <= boxRGB;

		else if (pipesDrawingRequest == 1'b1) RGBOut <= pipesRGB;
//---------------------------------------------------------------------------------		
 		else if (heartDrawingRequest == 1'b1)
				RGBOut <= heartRGB;
		else if (BGDrawingRequest == 1'b1)
				RGBOut <= backGroundRGB ;
		else RGBOut <= RGB_MIF ;// last priority 
		end ; 
	end

endmodule


