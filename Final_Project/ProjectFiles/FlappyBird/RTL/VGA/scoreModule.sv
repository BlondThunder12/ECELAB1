module scoreModule #(
	parameter logic [7:0] NUMBERS_COLOR = 8'b11100000,
	parameter logic [10:0] HUNDREDS_X = 11'd560,
   parameter logic [10:0] TENS_X  = 11'd580,
	parameter logic [10:0] UNITS_X = 11'd600,
	parameter logic [10:0] SCORE_Y = 11'd20 
)(
	input logic   clk,
	input logic   resetN,
	input logic   trigger,
	input logic [10:0] pixelX,
	input logic [10:0] pixelY,
	input logic [1:0]  game_state,

	output logic [7:0] RGBNum,
	output logic       DrawingRequest
);

logic trigger_d;
wire trigger_pulse = trigger && !trigger_d;

// game state definition:

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;

always_ff @(posedge clk or negedge resetN) begin
        if (!resetN)
            trigger_d <= 1'b0;
        else
            trigger_d <= trigger;
  end
  
logic [3:0] units;
logic [3:0] tens;
logic [3:0] hundreds;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            units <= 4'd0;
            tens  <= 4'd0;
				hundreds <= 4'd0;
	end else if (game_state == START_SCREEN) begin
            units <= 4'd0;
            tens  <= 4'd0;	
				hundreds <= 4'd0;
		
	end else if (trigger_pulse) begin
            if (units == 4'd9) begin
                units <= 4'd0;
                if (tens == 4'd9) begin
                    tens <= 4'd0;
                    if (hundreds == 4'd9) begin
                        hundreds <= 4'd0; 
                    end else begin
                        hundreds <= hundreds + 1'b1; 
                    end
                end else begin
                    tens <= tens + 1'b1;
                end
            end else begin
                units <= units + 1'b1;
            end
        end
    end
// HUNDREDS ASSIGNMENTS
	 logic [10:0] hundreds_offsetX, hundreds_offsetY;
    logic        hundreds_sq_draw;
    logic [7:0]  hundreds_sq_rgb;
    logic [7:0]  hundreds_bmp_rgb;
    logic        hundreds_bmp_draw;

    square_object #(
        .OBJECT_WIDTH_X(16),
        .OBJECT_HEIGHT_Y(32)
    ) hundreds_sq (
        .clk(clk),
        .resetN(resetN),
        .pixelX(pixelX),
        .pixelY(pixelY),
        .topLeftX(HUNDREDS_X),
        .topLeftY(SCORE_Y),
        .offsetX(hundreds_offsetX),
        .offsetY(hundreds_offsetY),
        .drawingRequest(hundreds_sq_draw),
        .RGBout(hundreds_sq_rgb)
    );

    NumbersBitMap hundreds_bmp (
        .clk(clk),
        .resetN(resetN),
        .offsetX(hundreds_offsetX),
        .offsetY(hundreds_offsetY),
        .InsideRectangle(hundreds_sq_draw),
        .digit(hundreds),
        .drawingRequest(hundreds_bmp_draw),
        .RGBout(hundreds_bmp_rgb)
    );

// TENS ASSIGNMENTS
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

//UNITS ASSIGNMENTS
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

//Mux to know which digit to show and when
logic show_tens, show_hundreds;

    always_comb begin
        // Determine which digits are allowed to draw (hide leading zeros)
        show_hundreds = (hundreds > 0);
        show_tens     = (tens > 0) || show_hundreds;
        
        if (show_hundreds && hundreds_bmp_draw) begin
            RGBNum         = NUMBERS_COLOR;
            DrawingRequest = 1'b1;
        end else if (show_tens && tens_bmp_draw) begin
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
