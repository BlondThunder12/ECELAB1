module sun_moon_draw #(
    parameter int OBJECT_WIDTH  = 64,
    parameter int OBJECT_HEIGHT = 32
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic        night_mode,
    input  logic [1:0]  game_state,   
    
    output logic        sunMoonDrawingRequest,
    output logic [7:0]  sunMoonRGB
);

    localparam signed [11:0] LEFT_BOUND = -OBJECT_WIDTH;
    localparam int SPEED_DIV = 600;

    logic signed [11:0] object_X;
    logic [15:0] frame_count;
    logic        frame_flag;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            object_X    <= 12'sd550;
            frame_count <= 16'd0;
            frame_flag  <= 1'b0;
        end else begin
            if (pixelX == 11'd0 && pixelY == 11'd0) begin
                if (!frame_flag) begin
                    frame_flag <= 1'b1;
                    if (game_state == 2'b01) begin
                        if (frame_count >= SPEED_DIV - 1) begin
                            frame_count <= 16'd0;
                            if (object_X <= LEFT_BOUND)
                                object_X <= 12'sd640;
                            else
                                object_X <= object_X - 1'b1;
                        end else begin
                            frame_count <= frame_count + 1'b1;
                        end
                    end
                end
            end else begin
                frame_flag <= 1'b0;
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

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/sun.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) sun_rom (
        .address(rom_addr),
        .inclock(clk),
        .q(rgb_sun)
    );

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/moon.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) moon_rom (
        .address(rom_addr),
        .inclock(clk),
        .q(rgb_moon)
    );

    always_comb begin
        if (inside_object) begin
            if (night_mode) begin
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