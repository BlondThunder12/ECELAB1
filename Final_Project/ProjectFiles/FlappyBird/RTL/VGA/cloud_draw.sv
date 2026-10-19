module cloud_draw #(
    parameter int CLOUD_WIDTH  = 64,
    parameter int CLOUD_HEIGHT = 32
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic        night_mode,
    input  logic [1:0]  game_state,   
    
    output logic        cloudDrawingRequest,
    output logic [7:0]  cloudRGB
);

    localparam signed [11:0] LEFT_BOUND = -CLOUD_WIDTH;

    logic signed [11:0] cloud1_X, cloud2_X, cloud3_X;
    logic [15:0] frame_count1, frame_count2, frame_count3;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            cloud1_X     <= 12'sd500;
            cloud2_X     <= 12'sd300;
            cloud3_X     <= 12'sd100;
            frame_count1 <= 16'd0;
            frame_count2 <= 16'd0;
            frame_count3 <= 16'd0;
        end else if (pixelX == 0 && pixelY == 0) begin
            if (game_state == 2'b01) begin
                frame_count1 <= frame_count1 + 1'b1;
                if (frame_count1 >= 16'd2000) begin
                    frame_count1 <= 16'd0;
                    if (cloud1_X <= LEFT_BOUND)
                        cloud1_X <= 12'sd640;
                    else
                        cloud1_X <= cloud1_X - 1'b1;
                end

                frame_count2 <= frame_count2 + 1'b1;
                if (frame_count2 >= 16'd3500) begin
                    frame_count2 <= 16'd0;
                    if (cloud2_X <= LEFT_BOUND)
                        cloud2_X <= 12'sd640;
                    else
                        cloud2_X <= cloud2_X - 1'b1;
                end

                frame_count3 <= frame_count3 + 1'b1;
                if (frame_count3 >= 16'd5000) begin
                    frame_count3 <= 16'd0;
                    if (cloud3_X <= LEFT_BOUND)
                        cloud3_X <= 12'sd640;
                    else
                        cloud3_X <= cloud3_X - 1'b1;
                end
            end
        end
    end

    localparam int CLOUD1_Y = 30;
    localparam int CLOUD2_Y = 60;
    localparam int CLOUD3_Y = 90;

    logic signed [11:0] s_pixelX, s_pixelY;
    assign s_pixelX = signed'({1'b0, pixelX});
    assign s_pixelY = signed'({1'b0, pixelY});

    logic inside_cloud1, inside_cloud2, inside_cloud3;
    assign inside_cloud1 = (s_pixelX >= cloud1_X) && (s_pixelX < cloud1_X + CLOUD_WIDTH) &&
                           (s_pixelY >= CLOUD1_Y) && (s_pixelY < CLOUD1_Y + CLOUD_HEIGHT);
                           
    assign inside_cloud2 = (s_pixelX >= cloud2_X) && (s_pixelX < cloud2_X + CLOUD_WIDTH) &&
                           (s_pixelY >= CLOUD2_Y) && (s_pixelY < CLOUD2_Y + CLOUD_HEIGHT);
                           
    assign inside_cloud3 = (s_pixelX >= cloud3_X) && (s_pixelX < cloud3_X + CLOUD_WIDTH) &&
                           (s_pixelY >= CLOUD3_Y) && (s_pixelY < CLOUD3_Y + CLOUD_HEIGHT);

    logic [10:0] cloud1_addr, cloud2_addr, cloud3_addr;
    assign cloud1_addr = 11'((s_pixelY - CLOUD1_Y) * CLOUD_WIDTH + (s_pixelX - cloud1_X));
    assign cloud2_addr = 11'((s_pixelY - CLOUD2_Y) * CLOUD_WIDTH + (s_pixelX - cloud2_X));
    assign cloud3_addr = 11'((s_pixelY - CLOUD3_Y) * CLOUD_WIDTH + (s_pixelX - cloud3_X));

    logic [7:0] rgb_cloud1, rgb_cloud2, rgb_cloud3;

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/cloud_bg.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) cloud_rom1 (
        .address(cloud1_addr),
        .inclock(clk),
        .q(rgb_cloud1)
    );

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/cloud2.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) cloud_rom2 (
        .address(cloud2_addr),
        .inclock(clk),
        .q(rgb_cloud2)
    );

    lpm_rom #(
        .LPM_WIDTH(8),
        .LPM_WIDTHAD(11),
        .LPM_NUMWORDS(2048),
        .LPM_FILE("RTL/cloud3.mif"),
        .LPM_TYPE("LPM_ROM"),
        .LPM_ADDRESS_CONTROL("REGISTERED"),
        .LPM_OUTDATA("UNREGISTERED"),
        .INTENDED_DEVICE_FAMILY("Cyclone V")
    ) cloud_rom3 (
        .address(cloud3_addr),
        .inclock(clk),
        .q(rgb_cloud3)
    );

    always_comb begin
        if (night_mode) begin
            cloudDrawingRequest = 1'b0;
            cloudRGB            = 8'h00;
        end else if (inside_cloud1 && (rgb_cloud1 >= 8'hD0)) begin
            cloudDrawingRequest = 1'b1;
            cloudRGB            = 8'hFF;
        end else if (inside_cloud2 && (rgb_cloud2 >= 8'hD0)) begin
            cloudDrawingRequest = 1'b1;
            cloudRGB            = 8'hFF;
        end else if (inside_cloud3 && (rgb_cloud3 >= 8'hD0)) begin
            cloudDrawingRequest = 1'b1;
            cloudRGB            = 8'hFF;
        end else begin
            cloudDrawingRequest = 1'b0;
            cloudRGB            = 8'h00;
        end
    end

endmodule