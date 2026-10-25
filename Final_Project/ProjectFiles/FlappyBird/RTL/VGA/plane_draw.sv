module plane_draw #(
    parameter int PLANE_WIDTH  = 64,
    parameter int PLANE_HEIGHT = 32
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,   
    
    output logic        planeDrawingRequest,
    output logic [7:0]  planeRGB
);

    localparam signed [11:0] LEFT_BOUND = -PLANE_WIDTH;
    // Origin visits, giving approximately 5.9 seconds of wait between flights.
    localparam int WAIT_6_SEC_TICKS = 18000;

    logic signed [11:0] plane_X;
    logic [15:0] move_divider;
    logic [15:0] wait_counter;
    logic        is_waiting;
    logic        origin_held;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            plane_X      <= 12'sd640;
            move_divider <= 16'd0;
            wait_counter <= 16'd0;
            is_waiting   <= 1'b0;
            origin_held  <= 1'b0;
        end else begin
            if (pixelX == 11'd0 && pixelY == 11'd0) begin
                if (!origin_held) begin
                    origin_held <= 1'b1;
                    if (game_state == 2'b01) begin
                        if (is_waiting) begin
                            if (wait_counter >= WAIT_6_SEC_TICKS - 1) begin
                                wait_counter <= 16'd0;
                                is_waiting   <= 1'b0;
                                plane_X      <= 12'sd640;
                                move_divider <= 16'd0;
                            end else begin
                                wait_counter <= wait_counter + 1'b1;
                            end
                        end else begin
                            if (move_divider >= 16'd5) begin
                                move_divider <= 16'd0;
                                if (plane_X <= LEFT_BOUND) begin
                                    is_waiting   <= 1'b1;
                                    wait_counter <= 16'd0;
                                end else begin
                                    plane_X <= plane_X - 1'b1;
                                end
                            end else begin
                                move_divider <= move_divider + 1'b1;
                            end
                        end
                    end
                end
            end else begin
                origin_held <= 1'b0;
            end
        end
    end

    localparam int PLANE_Y = 45;

    logic signed [11:0] s_pixelX, s_pixelY;
    assign s_pixelX = signed'({1'b0, pixelX});
    assign s_pixelY = signed'({1'b0, pixelY});

    logic inside_plane;
    assign inside_plane = !is_waiting &&
                          (s_pixelX >= plane_X) && (s_pixelX < plane_X + PLANE_WIDTH) &&
                          (s_pixelY >= PLANE_Y) && (s_pixelY < PLANE_Y + PLANE_HEIGHT);

    logic [10:0] rom_addr;
    assign rom_addr = 11'((s_pixelY - PLANE_Y) * PLANE_WIDTH + (s_pixelX - plane_X));

    logic [7:0] rgb_plane;

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/plane.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) plane_rom (
        .address(rom_addr),
        .inclock(clk),
        .q(rgb_plane)
    );

    always_comb begin
        if (inside_plane && (rgb_plane > 8'h00)) begin
            planeDrawingRequest = 1'b1;
            planeRGB            = rgb_plane;
        end else begin
            planeDrawingRequest = 1'b0;
            planeRGB            = 8'h00;
        end
    end

endmodule
