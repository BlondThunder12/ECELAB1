// Four native 32x32 frames. One shared indexed ROM serves every boss.
// Its one-clock pixel latency matches the existing pipe body/cap ROMs.
module explosion_draw #(
    parameter int NUM_PIPES = 3
)(
    input  logic clk, resetN,
    input  logic signed [10:0] pixelX, pixelY,
    input  logic [NUM_PIPES*11-1:0] pipeXPositions,
    input  logic [NUM_PIPES*9-1:0] explosionYPositions,
    input  logic [NUM_PIPES-1:0] explosionActive,
    input  logic [NUM_PIPES*2-1:0] explosionFrames,
    output logic drawingRequest,
    output logic [7:0] RGBout
);
int relativeX, relativeY;
logic insideExplosion, inside_d;
logic [11:0] address;
logic [3:0] colorIndex;
logic [7:0] pixelRGB;

always_comb begin
    address = 12'd0;
    insideExplosion = 1'b0;
    relativeX = 0;
    relativeY = 0;
    for (int j = 0; j < NUM_PIPES; j++) begin
        relativeX = int'($signed(pixelX)) -
                    (int'($signed(pipeXPositions[j*11 +: 11])) + 9);
        relativeY = int'($signed(pixelY)) - int'(explosionYPositions[j*9 +: 9]);
        if (explosionActive[j] && relativeX >= 0 && relativeX < 32 &&
            relativeY >= 0 && relativeY < 32) begin
            insideExplosion = 1'b1;
            address = {explosionFrames[j*2 +: 2], relativeY[4:0], relativeX[4:0]};
        end
    end
end

lpm_rom #(
    .lpm_width(4), .lpm_widthad(12), .lpm_numwords(4096),
    .lpm_file("RTL/explosion.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) explosion_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

// BEGIN GENERATED PALETTE
always_comb begin
    case (colorIndex)
        4'd1: pixelRGB = 8'h24;
        4'd2: pixelRGB = 8'h6D;
        4'd3: pixelRGB = 8'hA0;
        4'd4: pixelRGB = 8'hB6;
        4'd5: pixelRGB = 8'hE4;
        4'd6: pixelRGB = 8'hEC;
        4'd7: pixelRGB = 8'hF4;
        4'd8: pixelRGB = 8'hFC;
        4'd9: pixelRGB = 8'hFF;
        default: pixelRGB = 8'h00;
    endcase
end
// END GENERATED PALETTE

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) inside_d <= 1'b0;
    else inside_d <= insideExplosion;
end
assign drawingRequest = inside_d && (colorIndex != 0);
assign RGBout = drawingRequest ? pixelRGB : 8'h00;
endmodule
