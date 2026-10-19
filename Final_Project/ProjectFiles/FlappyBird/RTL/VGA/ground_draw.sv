module ground_draw #(
    parameter int GROUND_HEIGHT = 32
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,

    output logic        groundDrawingRequest,
    output logic [7:0]  groundRGB
);

    logic [10:0] ground_X;
    logic [15:0] frame_count;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            ground_X    <= 11'd0;
            frame_count <= 16'd0;
        end else if (pixelX == 0 && pixelY == 0) begin
            if (game_state == 2'b01) begin
                frame_count <= frame_count + 1'b1;
                if (frame_count >= 16'd3000) begin
                    frame_count <= 16'd0;
                    ground_X    <= ground_X + 1'b1;
                end
            end
        end
    end

    localparam int GROUND_START_Y = 480 - GROUND_HEIGHT;

    logic inside_ground;
    assign inside_ground = (pixelY >= GROUND_START_Y) && (pixelY < 480);

    logic [6:0] img_x;
    logic [6:0] img_y;

    assign img_x = (pixelX + ground_X) % 11'd128;
    
    always_comb begin
        if (pixelY - GROUND_START_Y < 12)
            img_y = pixelY - GROUND_START_Y;
        else
            img_y = 7'd11;
    end

    logic [13:0] rom_address;
    assign rom_address = (img_y * 11'd128) + img_x;

    logic [7:0] raw_ground_rgb;

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(14),
        .LPM_NUMWORDS(16384),
        .LPM_FILE("RTL/ground_bg.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) ground_rom_inst (
        .address(rom_address),
        .inclock(clk),
        .q(raw_ground_rgb)
    );

    always_comb begin
        if (inside_ground) begin
            groundDrawingRequest = 1'b1;
            groundRGB            = raw_ground_rgb;
        end else begin
            groundDrawingRequest = 1'b0;
            groundRGB            = 8'h00;
        end
    end

endmodule