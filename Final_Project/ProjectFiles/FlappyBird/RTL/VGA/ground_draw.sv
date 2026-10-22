module ground_draw #(
    parameter int GROUND_HEIGHT = 32
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic        scrollUpdate,
    input  logic [10:0] scrollStep, // Actual pipe movement, in 1/64 pixel units

    output logic        groundDrawingRequest,
    output logic [7:0]  groundRGB
);

    localparam logic [1:0] START_SCREEN = 2'b00;
    localparam logic [1:0] PLAYING = 2'b01;

    logic [10:0] ground_X;
    // 7 texture-coordinate bits + 6 fractional bits wrap at 128 pixels.
    logic [12:0] ground_X_fixed;
    assign ground_X = {4'b0000, ground_X_fixed[12:6]};

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            ground_X_fixed <= 13'd0;
        end else if (game_state == START_SCREEN) begin
            ground_X_fixed <= 13'd0;
        end else if (game_state == PLAYING && scrollUpdate) begin
            // Use the pipes' leftward position and fractional rounding.
            ground_X_fixed <= ground_X_fixed - {2'b00, scrollStep};
        end
    end

    localparam int GROUND_START_Y = 480 - GROUND_HEIGHT;

    logic inside_ground;
    assign inside_ground = (pixelY >= GROUND_START_Y) && (pixelY < 480);

    logic [6:0] img_x;
    logic [6:0] img_y;

    assign img_x = (pixelX - ground_X) % 11'd128;
    
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
