//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// System-Verilog Alex Grinshpun May 2018
// New coding convention dudy December 2018
// (c) Technion IIT, Department of Electrical Engineering 2025 


module	square_object	(	
					input		logic	clk,
					input		logic	resetN,
					input 	logic signed	[10:0] pixelX,//  current VGA pixel 
					input 	logic signed	[10:0] pixelY,
					input 	logic signed	[10:0] topLeftX, //position on the screen 
					input 	logic	signed [10:0] topLeftY,   // can be negative , if the object is partliy outside 
					
					output 	logic	[10:0] offsetX,// offset inside bracket from top left position 
					output 	logic	[10:0] offsetY,
					output	logic	drawingRequest, // indicates pixel inside the bracket
					output	logic	[7:0]	 RGBout //optional color output for mux 
);

parameter  int OBJECT_WIDTH_X = 100;
parameter  int OBJECT_HEIGHT_Y = 100;
// Optional transparent room around a rotating sprite; existing users keep 0.
parameter  int PADDING_X = 0;
parameter  int PADDING_Y = 0;
parameter  logic [7:0] OBJECT_COLOR = 8'h03 ; 
localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// bitmap  representation for a transparent pixel 
 
int rightX ; //coordinates of the sides  
int bottomY ;
logic insideBracket ; 

//////////--------------------------------------------------------------------------------------------------------------=
// Calculate object right  & bottom  boundaries
assign rightX	= (topLeftX + OBJECT_WIDTH_X + PADDING_X);
assign bottomY	= (topLeftY + OBJECT_HEIGHT_Y + PADDING_Y);
assign	insideBracket  = 	 ( (pixelX >= topLeftX - PADDING_X) && (pixelX < rightX)
						   && (pixelY >= topLeftY - PADDING_Y) && (pixelY < bottomY) );
		


//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout			<=	8'b0;
		drawingRequest	<=	1'b0;
	end
	else begin 
		// DEFUALT outputs
	      RGBout <= TRANSPARENT_ENCODING ; // so it will not be displayed 
			drawingRequest <= 1'b0 ;// transparent color 
			offsetX	<= 0; //no offset
			offsetY	<= 0; //no offset
	
 
		if (insideBracket) // test if it is inside the rectangle 
		begin 
			RGBout  <= OBJECT_COLOR ;	// colors table 
			drawingRequest <= 1'b1 ;
			offsetX	<= (pixelX - topLeftX + PADDING_X);
			offsetY	<= (pixelY - topLeftY + PADDING_Y);
		end 
		

		
	end
end 
endmodule
