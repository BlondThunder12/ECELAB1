// The supplied opaque 480x360 rulebook is displayed at native resolution.
// Up to four RGB332 colors fit in a two-bit index; no full-color screen buffer is used.
module rulebook_draw #(
    parameter int TOP_LEFT_X = 80,
    parameter int TOP_LEFT_Y = 60
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic        rules_key,
    output logic        rulebookDrawingRequest,
    output logic [7:0]  rulebookRGB
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PAUSED = 2'b11;
int relativeX, relativeY;
logic insideBook, menuState;
logic rules_key_D, show_rules;
logic [8:0] sourceX, sourceY;
logic [17:0] rowAddress, address;
logic [1:0] colorIndex;

assign relativeX = int'(pixelX) - TOP_LEFT_X;
assign relativeY = int'(pixelY) - TOP_LEFT_Y;
assign menuState = (game_state == START_SCREEN) || (game_state == PAUSED);

// Connect NumberKey[0] here. One press opens/closes the page; holding the key
// does not repeatedly toggle. Starting/resuming gameplay closes the page.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        rules_key_D <= 1'b0;
        show_rules <= 1'b0;
    end else begin
        rules_key_D <= rules_key;
        if (!menuState)
            show_rules <= 1'b0;
        else if (rules_key && !rules_key_D)
            show_rules <= ~show_rules;
    end
end

assign insideBook = show_rules && menuState &&
                    (relativeX >= 0) && (relativeX < 480) &&
                    (relativeY >= 0) && (relativeY < 360);
assign sourceX = relativeX[8:0];
assign sourceY = relativeY[8:0];
// 480*y = 512*y - 32*y. No general multiplier or image scaling is needed.
assign rowAddress = {sourceY, 9'b0} - {4'b0, sourceY, 5'b0};
assign address = insideBook ? rowAddress + {9'b0, sourceX} : 18'd0;

lpm_rom #(
    .lpm_width(2),
    .lpm_widthad(18),
    .lpm_numwords(172800),
    .lpm_file("RTL/rulebook.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) rulebook_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
        rulebookDrawingRequest <= 1'b0;
    else
        rulebookDrawingRequest <= insideBook;
end

// Index zero is an opaque palette color here; white/black are not color keys.
// BEGIN GENERATED PALETTE
always_comb begin
    rulebookRGB = 8'h00;
    if (rulebookDrawingRequest) begin
        case (colorIndex)
            2'd0: rulebookRGB = 8'h03;
            2'd1: rulebookRGB = 8'h63;
            2'd2: rulebookRGB = 8'h66;
            2'd3: rulebookRGB = 8'hFC;
            default: rulebookRGB = 8'h00;
        endcase
    end
end
// END GENERATED PALETTE
endmodule
