// Opaque 128x64 panel, enlarged 2x and centered on the 640x480 display.
module pause_draw #(
    parameter int TOP_LEFT_X = 192,
    parameter int TOP_LEFT_Y = 176
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    output logic        pauseDrawingRequest,
    output logic [7:0]  pauseRGB
);

localparam logic [1:0] PAUSED = 2'b11;
int relativeX, relativeY;
logic insidePanel;
logic [12:0] address;
logic [1:0] colorIndex;

assign relativeX = int'(pixelX) - TOP_LEFT_X;
assign relativeY = int'(pixelY) - TOP_LEFT_Y;
assign insidePanel = (game_state == PAUSED) &&
                     (relativeX >= 0) && (relativeX < 256) &&
                     (relativeY >= 0) && (relativeY < 128);
assign address = insidePanel ? {relativeY[6:1], relativeX[7:1]} : 13'd0;

lpm_rom #(
    .lpm_width(2),
    .lpm_widthad(13),
    .lpm_numwords(8192),
    .lpm_file("RTL/pause_screen.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) pause_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

// Match the address register so RGB and drawing request refer to one pixel.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
        pauseDrawingRequest <= 1'b0;
    else
        pauseDrawingRequest <= insidePanel;
end

// BEGIN GENERATED PALETTE
always_comb begin
    pauseRGB = 8'h00;
    if (pauseDrawingRequest) begin
        case (colorIndex)
            2'd0: pauseRGB = 8'h67;
            2'd1: pauseRGB = 8'hCB;
            2'd2: pauseRGB = 8'hE6;
            2'd3: pauseRGB = 8'hF8;
            default: pauseRGB = 8'h00;
        endcase
    end
end
// END GENERATED PALETTE
endmodule
