// One-bit 16x32 digit mask, optionally displayed at 2x without a larger ROM.
// The PNG's color is replaced by digit_color.
module NumbersBitMap #(
    parameter logic [7:0] digit_color = 8'hFF,
    parameter bit SCALE_2X = 1'b0
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] offsetX,
    input  logic [10:0] offsetY,
    input  logic        InsideRectangle,
    input  logic [3:0]  digit,
    output logic        drawingRequest,
    output logic [7:0]  RGBout
);

logic [12:0] address;
logic [3:0] sourceX;
logic [4:0] sourceY;
logic color, insideDigit, insideDigit_d;
assign insideDigit = InsideRectangle && offsetX < (SCALE_2X ? 32 : 16) &&
                     offsetY < (SCALE_2X ? 64 : 32) && digit < 10;
assign sourceX = SCALE_2X ? offsetX[4:1] : offsetX[3:0];
assign sourceY = SCALE_2X ? offsetY[5:1] : offsetY[4:0];
// Each glyph occupies 512 words: digit*512 + y*16 + x.
assign address = insideDigit ? {digit, sourceY, sourceX} : 13'd0;

lpm_rom #(
    .lpm_width(1), .lpm_widthad(13), .lpm_numwords(8192),
    .lpm_file("RTL/numbers.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) rom_inst (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(color)
);

// Match the ROM address register; avoid mixing the next rectangle with color.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) insideDigit_d <= 1'b0;
    else insideDigit_d <= insideDigit;
end
assign drawingRequest = insideDigit_d && color;
assign RGBout = digit_color;
endmodule
