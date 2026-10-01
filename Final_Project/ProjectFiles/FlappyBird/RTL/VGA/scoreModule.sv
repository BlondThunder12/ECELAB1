module scoreModule #(
	parameter logic [7:0] NUMBERS_COLOR = 8'b11100000,
   parameter logic [10:0] TENS_X  = 11'd300,
	parameter logic [10:0] UNITS_X = 11'd320,  
	parameter logic [10:0] SCORE_Y = 11'd20 
)(
	input logic   clk,
	input logic   resetN,
	input logic   trigger,
	input logic [10:0] pixelX,
	input logic [10:0] pixelY,

	output logic [7:0] RGBNum,
	output logic       DrawingRequest
);

logic trigger_d;
wire trigger_pulse = trigger && !trigger_d;

always_ff @(posedge clk or negedge resetN) begin
        if (!resetN)
            trigger_d <= 1'b0;
        else
            trigger_d <= trigger;
  end
  
logic [3:0] units;
logic [3:0] tens;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            units <= 4'd0;
            tens  <= 4'd0;
				
end else if (trigger_pulse) begin
            if (units == 4'd9) begin
                units <= 4'd0;
                if (tens == 4'd9)
                    tens <= 4'd0; 
                else
                    tens <= tens + 1'b1;
            end else begin
                units <= units + 1'b1;
            end
        end
 end

    logic [10:0] tens_offsetX, tens_offsetY;
    logic        tens_sq_draw;
    logic [7:0]  tens_sq_rgb;
    logic [7:0]  tens_bmp_rgb;
    logic        tens_bmp_draw;

    square_object #(
        .OBJECT_WIDTH_X(16),
        .OBJECT_HEIGHT_Y(32)
    ) tens_sq (
        .clk(clk),
        .resetN(resetN),
        .pixelX(pixelX),
        .pixelY(pixelY),
        .topLeftX(TENS_X),
        .topLeftY(SCORE_Y),
        .offsetX(tens_offsetX),
        .offsetY(tens_offsetY),
        .drawingRequest(tens_sq_draw),
        .RGBout(tens_sq_rgb)
    );

    NumbersBitMap tens_bmp (
        .clk(clk),
        .resetN(resetN),
        .offsetX(tens_offsetX),
        .offsetY(tens_offsetY),
        .InsideRectangle(tens_sq_draw),
        .digit(tens),
        .drawingRequest(tens_bmp_draw),
        .RGBout(tens_bmp_rgb)
    );

    logic [10:0] units_offsetX, units_offsetY;
    logic        units_sq_draw;
    logic [7:0]  units_sq_rgb;
    logic [7:0]  units_bmp_rgb;
    logic        units_bmp_draw;

    square_object #(
        .OBJECT_WIDTH_X(16),
        .OBJECT_HEIGHT_Y(32)
    ) units_sq (
        .clk(clk),
        .resetN(resetN),
        .pixelX(pixelX),
        .pixelY(pixelY),
        .topLeftX(UNITS_X),
        .topLeftY(SCORE_Y),
        .offsetX(units_offsetX),
        .offsetY(units_offsetY),
        .drawingRequest(units_sq_draw),
        .RGBout(units_sq_rgb)
    );

    NumbersBitMap units_bmp (
        .clk(clk),
        .resetN(resetN),
        .offsetX(units_offsetX),
        .offsetY(units_offsetY),
        .InsideRectangle(units_sq_draw),
        .digit(units),
        .drawingRequest(units_bmp_draw),
        .RGBout(units_bmp_rgb)
    );
	 always_comb begin
        if (tens_bmp_draw) begin
            RGBNum         = NUMBERS_COLOR;
            DrawingRequest = 1'b1;
        end else if (units_bmp_draw) begin
            RGBNum         = NUMBERS_COLOR;
            DrawingRequest = 1'b1;
        end else begin
            RGBNum         = 8'hFF; 
            DrawingRequest = 1'b0;
        end
    end

endmodule
