module back_ground_draw #(
    parameter int SCREEN_WIDTH  = 640,
    parameter int SCREEN_HEIGHT = 480
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic        night_mode,
    input  logic [1:0]  game_state,   

    output logic [7:0]  bgRGB,
    output logic        bgDrawingRequest,
    output logic [7:0]  MIF_VGA,
    output logic        out_night_mode
);

    localparam int TWO_MIN_FRAMES = 72000;
    localparam int BUILDING_SPEED_DIV = 64;   

    logic [10:0] bg_X;
    logic [15:0] building_frame_cnt;
    logic [19:0] night_timer;
    logic        internal_night;
    logic        frame_flag;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            bg_X               <= 11'd0;
            building_frame_cnt <= 16'd0;
            night_timer        <= 20'd0;
            internal_night     <= 1'b0;
            frame_flag         <= 1'b0;
        end else begin
            if (pixelX == 11'd0 && pixelY == 11'd0) begin
                if (!frame_flag) begin
                    frame_flag <= 1'b1;
                    if (game_state == 2'b01) begin
                        if (building_frame_cnt >= BUILDING_SPEED_DIV - 1) begin
                            building_frame_cnt <= 16'd0;
                            bg_X               <= bg_X + 1'b1;
                        end else begin
                            building_frame_cnt <= building_frame_cnt + 1'b1;
                        end

                        if (night_timer >= TWO_MIN_FRAMES - 1) begin
                            night_timer    <= 20'd0;
                            internal_night <= ~internal_night;
                        end else begin
                            night_timer <= night_timer + 1'b1;
                        end
                    end
                end
            end else begin
                frame_flag <= 1'b0;
            end
        end
    end

    logic [10:0] actual_x;

    always_comb begin
        if (pixelY < 11'd128) begin
            actual_x = pixelX;
        end else begin
            actual_x = pixelX + bg_X;
        end
    end

    logic [6:0] img_x;
    logic [6:0] img_y;

    assign img_x = actual_x % 11'd128;
    assign img_y = (pixelY < 11'd128) ? 7'd0 : ((pixelY >> 2) % 11'd128);

    logic [13:0] rom_address;
    assign rom_address = (img_y * 11'd128) + img_x;

    logic [7:0] raw_bg_rgb1;
    logic [7:0] raw_bg_rgb2;

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(14),
        .LPM_NUMWORDS(16384),
        .LPM_FILE("RTL/sky_buildings_bg.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) bg_rom_inst1 (
        .address(rom_address),
        .inclock(clk),
        .q(raw_bg_rgb1)
    );

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(14),
        .LPM_NUMWORDS(16384),
        .LPM_FILE("RTL/sky_buildings_bg2.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) bg_rom_inst2 (
        .address(rom_address),
        .inclock(clk),
        .q(raw_bg_rgb2)
    );

    logic [7:0] final_rgb;
    logic select_second_mif;
    logic active_night;

    assign select_second_mif = (actual_x / 11'd128) % 2;
    assign active_night      = night_mode || internal_night;
    assign out_night_mode    = active_night;

    always_comb begin
        if (select_second_mif) begin
            final_rgb = raw_bg_rgb2;
        end else begin
            final_rgb = raw_bg_rgb1;
        end

        bgDrawingRequest = 1'b1;
        
        if (active_night) begin
            bgRGB   = final_rgb >> 2;
            MIF_VGA = final_rgb >> 2;
        end else begin
            bgRGB   = final_rgb;
            MIF_VGA = final_rgb;
        end
    end

endmodule

