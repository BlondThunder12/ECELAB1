// Title and instructions share one indexed ROM. Both source images are 128x32
// and are displayed at 2x size. Existing scenery and the bird are drawn elsewhere.
module start_screen_draw #(
    parameter int LOGO_X = 192,
    parameter int LOGO_Y = 64,
    parameter int INSTRUCTIONS_X = 192,
    parameter int INSTRUCTIONS_Y = 304
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic signed [5:0] menuYOffset,
    output logic        startDrawingRequest,
    output logic [7:0]  startRGB
);

localparam logic [1:0] START_SCREEN = 2'b00;
int logoX, logoY, instructionsX, instructionsY;
logic insideLogo, insideInstructions, insideDrawing_d;
logic [12:0] address;
logic [3:0] colorIndex;

assign logoX = int'(pixelX) - LOGO_X;
// The bird supplies the same signed offset used for its menu position.
assign logoY = int'(pixelY) - LOGO_Y - int'(menuYOffset);
assign instructionsX = int'(pixelX) - INSTRUCTIONS_X;
assign instructionsY = int'(pixelY) - INSTRUCTIONS_Y;
assign insideLogo = (game_state == START_SCREEN) &&
                    (logoX >= 0) && (logoX < 256) && (logoY >= 0) && (logoY < 64);
assign insideInstructions = (game_state == START_SCREEN) &&
                            (instructionsX >= 0) && (instructionsX < 256) &&
                            (instructionsY >= 0) && (instructionsY < 64);

always_comb begin
    address = 13'd0;
    if (insideLogo)
        address = {1'b0, logoY[5:1], logoX[7:1]};
    else if (insideInstructions)
        address = {1'b1, instructionsY[5:1], instructionsX[7:1]};
end

lpm_rom #(
    .lpm_width(4),
    .lpm_widthad(13),
    .lpm_numwords(8192),
    .lpm_file("RTL/start_screen.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) screen_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

// Register the rectangle enable alongside the ROM address. Both outputs then
// describe the same input pixel with one clock of latency, like the pipe caps.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
        insideDrawing_d <= 1'b0;
    else
        insideDrawing_d <= insideLogo || insideInstructions;
end

assign startDrawingRequest = insideDrawing_d && (colorIndex != 4'd0);
// BEGIN GENERATED PALETTE
always_comb begin
    startRGB = 8'h00;
    if (startDrawingRequest) begin
        case (colorIndex)
            4'd1: startRGB = 8'h00;
            4'd2: startRGB = 8'h67;
            4'd3: startRGB = 8'hCB;
            4'd4: startRGB = 8'hDC;
            4'd5: startRGB = 8'hE5;
            4'd6: startRGB = 8'hF8;
            default: startRGB = 8'h00;
        endcase
    end
end
// END GENERATED PALETTE
endmodule
