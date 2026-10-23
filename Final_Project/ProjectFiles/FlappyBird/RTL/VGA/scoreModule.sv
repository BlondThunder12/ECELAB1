module scoreModule #(
	parameter logic [7:0] NUMBERS_COLOR = 8'hE3, // Bright magenta: visible against day and night skies
	parameter logic [10:0] HUNDREDS_X = 11'd496,
    parameter logic [10:0] TENS_X = 11'd536,
	parameter logic [10:0] UNITS_X = 11'd576,
	parameter logic [10:0] SCORE_Y = 11'd0,
    parameter int DEMO_DEBOUNCE_CYCLES = 315_000 // 10 ms at 31.5 MHz
)(
	input logic   clk,
	input logic   resetN,
	input logic   trigger,
	input logic [10:0] pixelX,
	input logic [10:0] pixelY,
	input logic [1:0]  game_state,
	input logic        godmode_active,
	input logic        coinCollected, // One collection strobe; consecutive coins may be back-to-back
	input logic [3:0]  speed_level,
    input logic        demo_score_key, // Active-low board KEY[2]: +500 once per press.

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

localparam int DEMO_DEBOUNCE_BITS = (DEMO_DEBOUNCE_CYCLES > 1) ?
                                  $clog2(DEMO_DEBOUNCE_CYCLES) : 1;
logic demo_key_meta, demo_key_sync, demo_key_stable, demo_score_pulse;
logic [DEMO_DEBOUNCE_BITS-1:0] demo_debounce_count;

// Synchronize KEY2, reject contact bounce and rearm only after a stable release.
// Track it in every game state so holding it cannot repeatedly add points.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        demo_key_meta <= 1'b1;
        demo_key_sync <= 1'b1;
        demo_key_stable <= 1'b1;
        demo_debounce_count <= '0;
        demo_score_pulse <= 1'b0;
    end else begin
        demo_key_meta <= demo_score_key;
        demo_key_sync <= demo_key_meta;
        demo_score_pulse <= 1'b0;
        if (demo_key_sync == demo_key_stable) begin
            demo_debounce_count <= '0;
        end else if (demo_debounce_count == DEMO_DEBOUNCE_BITS'(DEMO_DEBOUNCE_CYCLES - 1)) begin
            demo_debounce_count <= '0;
            demo_key_stable <= demo_key_sync;
            demo_score_pulse <= !demo_key_sync;
        end else begin
            demo_debounce_count <= demo_debounce_count + 1'b1;
        end
    end
end

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
logic [3:0] coin_value;
logic [4:0] points_to_add;
logic [5:0] units_sum;
logic [4:0] tens_sum, hundreds_sum;
logic [11:0] next_score_bcd;

// Export the existing score; do not introduce a second score counter.
assign score = (10'd100 * hundreds) + (10'd10 * tens) + {6'd0, units};
assign current_score_bcd = {hundreds, tens, units};

// Reward uses the current level before this collection changes the score.
// Keep the table here so the coin values are easy to change in one place.
always_comb begin
    case (speed_level)
        4'd0: coin_value = 4'd2;
        4'd1: coin_value = 4'd3;
        4'd2: coin_value = 4'd4;
        4'd3: coin_value = 4'd5;
        4'd4: coin_value = 4'd6;
        4'd5: coin_value = 4'd7;
        4'd6: coin_value = 4'd8;
        4'd7: coin_value = 4'd9;
        4'd8: coin_value = 4'd10;
        4'd9: coin_value = 4'd12;
        default: coin_value = 4'd15; // Level 10 and any out-of-range input
    endcase
end

// Combine normal points with KEY2's five hundreds, then saturate at 999.
// Pipe/coin events add at most 16 to the units digit, requiring two carries.
always_comb begin
    points_to_add = (coinCollected ? {1'b0, coin_value} : 5'd0) +
                    (trigger_pulse ? 5'd1 : 5'd0);
    units_sum = {2'b00, units} + {1'b0, points_to_add};
    tens_sum = {1'b0, tens};
    hundreds_sum = {1'b0, hundreds} + (demo_score_pulse ? 5'd5 : 5'd0);
    if (units_sum >= 6'd20) begin
        units_sum = units_sum - 6'd20;
        tens_sum = tens_sum + 5'd2;
    end else if (units_sum >= 6'd10) begin
        units_sum = units_sum - 6'd10;
        tens_sum = tens_sum + 5'd1;
    end
    if (tens_sum >= 5'd10) begin
        tens_sum = tens_sum - 5'd10;
        hundreds_sum = hundreds_sum + 5'd1;
    end
    next_score_bcd = (hundreds_sum >= 5'd10) ? 12'h999 :
                     {hundreds_sum[3:0], tens_sum[3:0], units_sum[3:0]};
end

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
            // KEY2 points are eligible; Godmode still disqualifies the whole run.
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
		
	end else if (game_state == PLAYING && (points_to_add != 0 || demo_score_pulse)) begin
            {hundreds, tens, units} <= next_score_bcd;
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
