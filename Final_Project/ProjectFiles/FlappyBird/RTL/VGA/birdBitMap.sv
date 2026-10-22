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
					input logic signed [5:0] bird_tilt, // Degrees -30..+30, in 10-degree steps

					output	logic	drawingRequest, //output that the pixel should be dispalyed 
					output	logic	[7:0] RGBout  //rgb value from the bitmap
 ) ;

// Transparent margins were cropped from the original 32x32 ROM; every
// remaining pixel is unchanged. Enlarge the 17x12 source exactly 2x.
localparam int SOURCE_WIDTH = 17;  // Cropped image width, in ROM pixels.
localparam int SOURCE_HEIGHT = 12; // Cropped image height, in ROM pixels.
// Match square_object's bird-only padding in Bird_Block_T.bdf. The 42x42
// bracket rotates around the original bird center without changing physics.
localparam int PADDING_X = 4;
localparam int PADDING_Y = 9;
localparam int DISPLAY_WIDTH = SOURCE_WIDTH * 2;
localparam int DISPLAY_HEIGHT = SOURCE_HEIGHT * 2;
localparam int DRAW_WIDTH = DISPLAY_WIDTH + 2 * PADDING_X;
localparam int DRAW_HEIGHT = DISPLAY_HEIGHT + 2 * PADDING_Y;
logic [5:0] angle_magnitude; // Positive and negative angles share four entries.
logic signed [9:0] cos_angle, sin_angle; // Sine/cosine scaled by 256 (Q8).
logic [7:0] address; // 17*12 = 204 ROM words, addresses 0..203; 8 bits suffice.
int dx, dy, rotatedX, rotatedY, sourceX, sourceY;
logic insideBird;   // Current pixel is inside the cropped drawing rectangle.
logic insideBird_d; // That flag delayed one clock to follow the ROM address.
logic validBirdPixel; // Follows RGBout; keep drawingRequest low during reset.


always_comb begin
    // Small sine/cosine lookup table for 0, 10, 20 and 30 degrees. Values are
    // rounded after multiplying by 256; the FPGA performs no runtime trig.
    angle_magnitude = bird_tilt < 0 ? -bird_tilt : bird_tilt;
    case (angle_magnitude)
        6'd0:  begin cos_angle = 10'sd256; sin_angle = 10'sd0;   end
        6'd10: begin cos_angle = 10'sd252; sin_angle = 10'sd44;  end
        6'd20: begin cos_angle = 10'sd241; sin_angle = 10'sd88;  end
        6'd30: begin cos_angle = 10'sd222; sin_angle = 10'sd128; end
        default: begin cos_angle = 10'sd256; sin_angle = 10'sd0; end
    endcase
    // cos(-a) = cos(a), sin(-a) = -sin(a): share the positive-angle table.
    if (bird_tilt < 0) sin_angle = -sin_angle;

    // Twice the distance from the bracket center preserves its half-pixel pivot.
    dx = (int'(offsetX) << 1) - (DRAW_WIDTH - 1);
    dy = (int'(offsetY) << 1) - (DRAW_HEIGHT - 1);
    // Inverse rotation: find the original sprite pixel for each screen pixel.
    rotatedX = dx * cos_angle + dy * sin_angle;
    rotatedY = -dx * sin_angle + dy * cos_angle;
    // Undo the 256x coefficient scale, half-pixel units and 2x sprite scale.
    sourceX = (rotatedX + (DISPLAY_WIDTH - 1) * 256) >>> 10;
    sourceY = (rotatedY + (DISPLAY_HEIGHT - 1) * 256) >>> 10;
    if (reverse_gravity_switch) sourceY = SOURCE_HEIGHT - 1 - sourceY;
    insideBird = InsideRectangle && offsetX < DRAW_WIDTH && offsetY < DRAW_HEIGHT &&
                 sourceX >= 0 && sourceX < SOURCE_WIDTH &&
                 sourceY >= 0 && sourceY < SOURCE_HEIGHT;
    // 17*y = 16*y + y; keep the existing sprite ROM and pipeline unchanged.
    address = insideBird ? 8'((sourceY << 4) + sourceY + sourceX) : 8'd0;
end

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

// pipeline (ff) to get the pixel color from the array 	 

//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		validBirdPixel <= 1'b0;
		insideBird_d <= 1'b0;

	end

	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default  
		validBirdPixel <= insideBird_d;
		// Delay the bracket alongside the ROM address before using its color.
		insideBird_d <= insideBird;

		if (insideBird_d == 1'b1 )
		begin // inside an external bracket 
			 
			RGBout <= color;
		
		end  	
	end
		
end

//////////--------------------------------------------------------------------------------------------------------------=
// decide if to draw the pixel or not 
assign drawingRequest = validBirdPixel && (RGBout != TRANSPARENT_ENCODING);

endmodule
