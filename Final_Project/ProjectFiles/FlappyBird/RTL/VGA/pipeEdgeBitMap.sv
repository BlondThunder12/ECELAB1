// One 64 x 16 ROM serves both caps in a Pipe_Object. The source image is
// the bottom cap; the upper cap reads its rows in reverse order.
module pipeEdgeBitMap (
    input  logic               clk,
    input  logic               resetN,
    input  logic signed [10:0] pixelX,
    input  logic signed [10:0] pixelY,
    input  logic signed [10:0] topLeftX,
    input  logic signed [10:0] topLeftY_TopEdge,
    input  logic signed [10:0] topLeftY_BottomEdge,
    output logic               topDrawingRequest,
    output logic               bottomDrawingRequest,
    output logic [7:0]         RGBout
);

logic signed [11:0] relativeX, topY, bottomY;
logic insideX, insideTop, insideBottom;
logic [3:0] imageY;
logic [9:0] address;
logic [7:0] color;

assign relativeX = $signed(pixelX) - $signed(topLeftX);
assign topY = $signed(pixelY) - $signed(topLeftY_TopEdge);
assign bottomY = $signed(pixelY) - $signed(topLeftY_BottomEdge);
assign insideX = (relativeX >= 0) && (relativeX < 64);
assign insideTop = insideX && (topY >= 0) && (topY < 16);
assign insideBottom = insideX && (bottomY >= 0) && (bottomY < 16);

// For a 4-bit row, ~y is exactly 15-y. Width 64 makes y*64+x a
// concatenation, so neither flipping nor addressing needs a multiplier.
assign imageY = insideTop ? ~topY[3:0] : bottomY[3:0];
assign address = (insideTop || insideBottom) ? {imageY, relativeX[5:0]} : 10'd0;

lpm_rom #(
    .lpm_width(8),
    .lpm_widthad(10),
    .lpm_numwords(1024),
    .lpm_file("RTL/pipeEdge.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) rom_inst (
    .address(address),
    .inclock(clk),
    .outclock(),
    .memenab(1'b1),
    .q(color)
);

// Match the existing body drawing stage: one clock for color and requests.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        topDrawingRequest <= 1'b0;
        bottomDrawingRequest <= 1'b0;
    end
    else begin
        topDrawingRequest <= insideTop;
        bottomDrawingRequest <= insideBottom;
    end
end

assign RGBout = (topDrawingRequest || bottomDrawingRequest) ? color : 8'hFF;

endmodule
