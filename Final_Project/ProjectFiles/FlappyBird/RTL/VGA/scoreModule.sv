module scoreModule #(
	parameter logic [7:0] NUMBERS_COLOR = 8'hE3, // Bright magenta: visible against day and night skies
	parameter logic [10:0] HUNDREDS_X = 11'd496,
    parameter logic [10:0] TENS_X = 11'd536,
	parameter logic [10:0] UNITS_X = 11'd576,
	parameter logic [10:0] SCORE_Y = 11'd0
)(
	input logic   clk,
	input logic   resetN,
	input logic   trigger,
	input logic [10:0] pixelX,
	input logic [10:0] pixelY,
	input logic [1:0]  game_state,
	input logic        godmode_active,

	output logic [7:0] RGBNum,
	output logic       DrawingRequest,
	output logic [9:0] score,            // Binary view of the same BCD score (0..999)
	output logic [11:0] final_score_bcd, // {hundreds, tens, units}, captured at game over
	output logic [11:0] best_score_bcd,  // Cleared only by resetN, retained between runs
	output logic        new_best
);

logic trigger_d;
wire trigger_pulse = trigger && !trigger_d;

// game state definition:

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING      = 2'b01;
localparam logic [1:0] GAME_OVER    = 2'b10;
localparam logic [1:0] PAUSED       = 2'b11;

always_ff @(posedge clk or negedge resetN) begin
        if (!resetN)
            trigger_d <= 1'b0;
        else
            trigger_d <= trigger;
  end
  
logic [3:0] units;
logic [3:0] tens;
logic [3:0] hundreds;
logic [11:0] current_score_bcd;
logic [1:0] previous_state;
logic run_used_godmode;

// Export the existing score; do not introduce a second score counter.
assign score = (10'd100 * hundreds) + (10'd10 * tens) + {6'd0, units};
assign current_score_bcd = {hundreds, tens, units};

// Observe the first clock spent in GAME_OVER. The final PLAYING clock has
// already updated the BCD counter, including a point coincident with death.
// Valid packed BCD values have the same ordering as their decimal scores.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        previous_state <= START_SCREEN;
        final_score_bcd <= 12'h000;
        best_score_bcd <= 12'h000;
        new_best <= 1'b0;
        run_used_godmode <= 1'b0;
    end else begin
        previous_state <= game_state;
        if (game_state == START_SCREEN) begin
            run_used_godmode <= godmode_active;
            new_best <= 1'b0;
        end else if (game_state == PLAYING || game_state == PAUSED) begin
            // Sticky for this run, including switches changed while paused.
            run_used_godmode <= run_used_godmode || godmode_active;
        end
        if (game_state == GAME_OVER && previous_state != GAME_OVER) begin
            final_score_bcd <= current_score_bcd;
            new_best <= 1'b0;
            if (!run_used_godmode && !godmode_active &&
                current_score_bcd > best_score_bcd) begin
                best_score_bcd <= current_score_bcd;
                new_best <= 1'b1;
            end
        end
    end
end

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            units <= 4'd0;
            tens  <= 4'd0;
				hundreds <= 4'd0;
	end else if (game_state == START_SCREEN) begin
            units <= 4'd0;
            tens  <= 4'd0;	
				hundreds <= 4'd0;
		
	end else if (game_state == PLAYING && trigger_pulse && current_score_bcd != 12'h999) begin
            if (units == 4'd9) begin
                units <= 4'd0;
                if (tens == 4'd9) begin
                    tens <= 4'd0;
                    hundreds <= hundreds + 1'b1;
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
        .OBJECT_WIDTH_X(32),
        .OBJECT_HEIGHT_Y(64)
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

    NumbersBitMap #(.SCALE_2X(1'b1)) hundreds_bmp (
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
        .OBJECT_WIDTH_X(32),
        .OBJECT_HEIGHT_Y(64)
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

    NumbersBitMap #(.SCALE_2X(1'b1)) tens_bmp (
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
        .OBJECT_WIDTH_X(32),
        .OBJECT_HEIGHT_Y(64)
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

    NumbersBitMap #(.SCALE_2X(1'b1)) units_bmp (
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
