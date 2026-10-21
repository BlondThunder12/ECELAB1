// System-Verilog 'written by Alex Grinshpun May 2018
// New bitmap dudy February 2025
// (c) Technion IIT, Department of Electrical Engineering 2025 



module	birdBitMap	(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] offsetX,// offset from top left  position 
					input logic	[10:0] offsetY,
					input	logic	InsideRectangle, //input that the pixel is within a bracket 
					input logic reverse_gravity_switch,

					output	logic	drawingRequest, //output that the pixel should be dispalyed 
					output	logic	[7:0] RGBout,  //rgb value from the bitmap 
				   output   logic	[2:0] HitEdgeCode 
 ) ;

// Transparent margins were cropped from the original 32x32 ROM; every
// remaining pixel is unchanged. Enlarge the 17x12 source exactly 2x.
localparam int SOURCE_WIDTH = 17;  // Cropped image width, in ROM pixels.
localparam int SOURCE_HEIGHT = 12; // Cropped image height, in ROM pixels.
logic [7:0] address; // 17*12 = 204 ROM words, addresses 0..203; 8 bits suffice.
logic [4:0] sourceX; // Source column 0..16 needs 5 bits.
logic [3:0] sourceY; // Source row 0..11 needs 4 bits.
logic insideBird;   // Current pixel is inside the cropped drawing rectangle.
logic insideBird_d; // That flag delayed one clock to follow the ROM address.

 logic	[10:0] HitCodeX ;// offset of Hitcode 
 logic	[10:0] HitCodeY ; 

// Map back to the original 16x16 hit-code grid after removing its padding.
// First >>1: displayed pixel -> source pixel (the bird is enlarged 2x).
// 7 = source columns removed from the LEFT of the original 32x32 image.
// 10 = source rows removed from its TOP. Adding these restores the old
// source coordinates for the legacy hit_colors table; it adds no image padding.
// Final >>1: original 32x32 source coordinate -> 16x16 hit-code grid cell.
assign HitCodeX = ((offsetX >> 1) + 11'd7) >> 1;
assign HitCodeY = ((offsetY >> 1) + 11'd10) >> 1;


assign insideBird = InsideRectangle && (offsetX < 34) && (offsetY < 24);
assign sourceX = offsetX[5:1];
assign sourceY = reverse_gravity_switch ? 4'd11 - offsetY[4:1] : offsetY[4:1];
// 17*y = 16*y + y; only constant shifts/addition are required.
assign address = insideBird ? ({sourceY, 4'b0} + {4'b0, sourceY} + {3'b0, sourceX}) : 8'd0;

// generating a smiley bitmap from a MIF file

logic	[7:0] color;
localparam logic [7:0] TRANSPARENT_ENCODING = 8'h1F ;// RGB value in the bitmap representing a transparent pixel 
lpm_rom #(
    .lpm_width(8),
    .lpm_widthad(8),
    .lpm_numwords(204),
    .lpm_file("RTL/birdPic.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), // Capture address on a rising inclock edge.
    .lpm_outdata("UNREGISTERED"),       // No extra output register inside the ROM.
    .intended_device_family("Cyclone V")
) rom_inst (
    .address(address),
	 .inclock(clk),
    .outclock(),      // Explicitly unconnected: ROM output is UNREGISTERED.
    .memenab(1'b1),   // Keep the ROM output enabled for every pixel.
    .q(color)
);

 logic [0:15] [0:15] [2:0] hit_colors = 
		  {48'o4433333333333344,     
			48'o4443333333333444,    
			48'o1444333333334442, 
			48'o1144433333344422,
			48'o1114443333444222,
			48'o1111444334442222,
			48'o1111144444422222,
			48'o1111114444222222,
			48'o1111114444222222,
			48'o1111144444422222,
			48'o1111444004442222,
			48'o1114440000444222,
			48'o1144400000044422,
			48'o1444000000004442,
			48'o4440000000000444,
			48'o4400000000000044};
 
// pipeline (ff) to get the pixel color from the array 	 

//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		HitEdgeCode <= 3'h0;
		insideBird_d <= 1'b0;

	end

	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default  
		HitEdgeCode <= 3'h0;
		// Delay the bracket alongside the ROM address before using its color.
		insideBird_d <= insideBird;

		if (insideBird_d == 1'b1 )
		begin // inside an external bracket 
			 
			RGBout <= color;
			HitEdgeCode <= hit_colors[HitCodeY][HitCodeX];	//get hit edge code from the colors table  
		
		end  	
	end
		
end

//////////--------------------------------------------------------------------------------------------------------------=
// decide if to draw the pixel or not 
assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; // get optional transparent command from the bitmpap   

endmodule
