module sun_moon_draw #(
    parameter int OBJECT_WIDTH  = 64,
    parameter int OBJECT_HEIGHT = 32,
    parameter int SPEED_Q8 = 64, // Manual speed when CROSSING_FRAMES is zero.
    parameter int CROSSING_FRAMES = 4355 // Matches back_ground_draw.DAY_NIGHT_FRAMES.
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic        startOfFrame,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic        night_mode,
    input  logic [1:0]  game_state,   
    
    output logic        sunMoonDrawingRequest,
    output logic [7:0]  sunMoonRGB
);

    localparam signed [11:0] LEFT_BOUND = -OBJECT_WIDTH;
    localparam int FRACTION_BITS = 8;
    localparam int PIXEL_SCALE = 1 << FRACTION_BITS;
    localparam int CROSSING_PERIOD = (CROSSING_FRAMES > 0) ? CROSSING_FRAMES : 1;
    localparam int CROSSING_COUNTER_WIDTH = (CROSSING_PERIOD > 1) ? $clog2(CROSSING_PERIOD) : 1;
    localparam int CROSSING_DISTANCE_Q8 = (640 + OBJECT_WIDTH) * PIXEL_SCALE;
    localparam int STEP_Q8 = CROSSING_DISTANCE_Q8 / CROSSING_PERIOD;
    localparam int STEP_REMAINDER = CROSSING_DISTANCE_Q8 % CROSSING_PERIOD;
    localparam int INITIAL_X = (CROSSING_FRAMES > 0) ? 640 : 550;
    localparam logic [1:0] START_SCREEN = 2'b00;
    localparam logic [1:0] PLAYING = 2'b01;

    logic signed [11:0] object_X;
    logic signed [19:0] object_X_fp;
    logic [CROSSING_COUNTER_WIDTH-1:0] crossing_frame_cnt;
    logic [CROSSING_COUNTER_WIDTH:0] crossing_remainder;

    // Signed Q12.8 keeps fractional movement across frames and through pauses.
    // Round upward so the sprite stays hidden until its leading edge enters.
    assign object_X = 12'(($signed(object_X_fp) + PIXEL_SCALE - 1) >>> FRACTION_BITS);

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            object_X_fp       <= 20'(INITIAL_X * PIXEL_SCALE);
            crossing_frame_cnt <= '0;
            crossing_remainder <= '0;
        end else if (game_state == START_SCREEN) begin
            object_X_fp       <= 20'(INITIAL_X * PIXEL_SCALE);
            crossing_frame_cnt <= '0;
            crossing_remainder <= '0;
        end else if (game_state == PLAYING && startOfFrame) begin
            // Both this counter and the day/night timer start at zero in the
            // menu. Equal periods make the wrap and mode change simultaneous.
            if (CROSSING_FRAMES > 0) begin
                if (crossing_frame_cnt >= CROSSING_PERIOD - 1) begin
                    object_X_fp        <= 20'(640 * PIXEL_SCALE);
                    crossing_frame_cnt <= '0;
                    crossing_remainder <= '0;
                end else begin
                    crossing_frame_cnt <= crossing_frame_cnt + 1'b1;
                    // Distribute fractional steps across the whole crossing;
                    // rounding the speed to a single Q8 value would drift.
                    if (crossing_remainder + STEP_REMAINDER >= CROSSING_PERIOD) begin
                        crossing_remainder <= crossing_remainder + STEP_REMAINDER - CROSSING_PERIOD;
                        object_X_fp <= object_X_fp - 20'(STEP_Q8 + 1);
                    end else begin
                        crossing_remainder <= crossing_remainder + STEP_REMAINDER;
                        object_X_fp <= object_X_fp - 20'(STEP_Q8);
                    end
                end
            end else begin
                // Retain the existing SPEED_Q8 parameter for manual-speed use.
                if ($signed(object_X_fp) - SPEED_Q8 < LEFT_BOUND * PIXEL_SCALE)
                    object_X_fp <= 20'(640 * PIXEL_SCALE);
                else
                    object_X_fp <= object_X_fp - 20'(SPEED_Q8);
            end
        end
    end

    localparam int OBJECT_Y = 15;

    logic signed [11:0] s_pixelX, s_pixelY;
    assign s_pixelX = signed'({1'b0, pixelX});
    assign s_pixelY = signed'({1'b0, pixelY});

    logic inside_object;
    assign inside_object = (s_pixelX >= object_X) && (s_pixelX < object_X + OBJECT_WIDTH) &&
                           (s_pixelY >= OBJECT_Y) && (s_pixelY < OBJECT_Y + OBJECT_HEIGHT);

    logic [10:0] rom_addr;
    assign rom_addr = 11'((s_pixelY - OBJECT_Y) * OBJECT_WIDTH + (s_pixelX - object_X));

    logic [7:0] rgb_sun, rgb_moon;
    logic inside_object_d, night_mode_d;

    // The ROM registers its address. Keep its mask and sprite selection aligned.
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            inside_object_d <= 1'b0;
            night_mode_d <= 1'b0;
        end else begin
            inside_object_d <= inside_object;
            night_mode_d <= night_mode;
        end
    end

    lpm_rom #(
        .lpm_width(8),
        .lpm_widthad(11),
        .lpm_numwords(2048),
        .lpm_file("RTL/sun.mif"),
        .lpm_type("LPM_ROM"),
        .lpm_address_control("REGISTERED"),
        .lpm_outdata("UNREGISTERED"),
        .intended_device_family("Cyclone V")
    ) sun_rom (
        .address(rom_addr),
        .inclock(clk), .outclock(), .memenab(1'b1),
        .q(rgb_sun)
    );

    lpm_rom #(
        .lpm_width(8),
        .lpm_widthad(11),
        .lpm_numwords(2048),
        .lpm_file("RTL/moon.mif"),
        .lpm_type("LPM_ROM"),
        .lpm_address_control("REGISTERED"),
        .lpm_outdata("UNREGISTERED"),
        .intended_device_family("Cyclone V")
    ) moon_rom (
        .address(rom_addr),
        .inclock(clk), .outclock(), .memenab(1'b1),
        .q(rgb_moon)
    );

    always_comb begin
        if (inside_object_d) begin
            if (night_mode_d) begin
                if (rgb_moon > 8'h05) begin
                    sunMoonDrawingRequest = 1'b1;
                    sunMoonRGB            = rgb_moon;
                end else begin
                    sunMoonDrawingRequest = 1'b0;
                    sunMoonRGB            = 8'h00;
                end
            end else begin
                if (rgb_sun >= 8'hD0) begin
                    sunMoonDrawingRequest = 1'b1;
                    sunMoonRGB            = rgb_sun;
                end else begin
                    sunMoonDrawingRequest = 1'b0;
                    sunMoonRGB            = 8'h00;
                end
            end
        end else begin
            sunMoonDrawingRequest = 1'b0;
            sunMoonRGB            = 8'h00;
        end
    end

endmodule
