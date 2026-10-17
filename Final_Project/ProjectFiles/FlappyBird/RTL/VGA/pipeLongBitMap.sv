// 50 x 8 pipe-body tile. Pixels use the project's RRRGGGBB VGA format.
// The tile repeats vertically; black and every other source color are opaque.
module pipeLongBitMap (
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] offsetX,
    input  logic [10:0] offsetY,
    input  logic        InsideRectangle,
    output logic        drawingRequest,
    output logic [7:0]  RGBout
);

localparam int TILE_WIDTH = 50;
localparam int TILE_HEIGHT = 8;
localparam int TILE_PIXELS = TILE_WIDTH * TILE_HEIGHT;

logic [8:0] address;
logic [7:0] color;
logic insideTile;

assign insideTile = InsideRectangle && (offsetX < TILE_WIDTH);
// The low three Y bits wrap at each 8-pixel chunk, even on tall pipes.
assign address = insideTile ? (offsetY[2:0] * 9'd50 + offsetX[8:0]) : 9'd0;

lpm_rom #(
    .lpm_width(8),
    .lpm_widthad(9),
    .lpm_numwords(TILE_PIXELS),
    .lpm_file("RTL/pipeLong.mif"),
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

// Register the bracket alongside the ROM address: color and request describe
// the same pixel, with the same one-clock latency as square_object.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
        drawingRequest <= 1'b0;
    else
        drawingRequest <= insideTile;
end

assign RGBout = drawingRequest ? color : 8'hFF;

endmodule
