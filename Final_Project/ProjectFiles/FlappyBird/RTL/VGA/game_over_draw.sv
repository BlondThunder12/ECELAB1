// Opaque 128x96 artwork enlarged 4x to 512x384 (twice the former display size).
// One shared number-ROM port draws all six
// score digits, because the VGA visits only one pixel at a time.
module game_over_draw #(
    parameter int TOP_LEFT_X = 64,
    parameter int TOP_LEFT_Y = 48,
    parameter logic [7:0] NUMBER_COLOR = 8'h67,
    parameter logic [7:0] RECORD_COLOR = 8'hE0
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic [11:0] final_score_bcd,
    input  logic [11:0] best_score_bcd,
    input  logic        new_best,
    output logic        gameOverDrawingRequest,
    output logic [7:0]  gameOverRGB
);

localparam logic [1:0] GAME_OVER = 2'b10;
localparam logic [7:0] PANEL_BACKGROUND = 8'hF8;
int relativeX, relativeY, layoutX, layoutY, numberX, numberY;
logic insidePanel, insideNumber, bestRow;
logic [13:0] address;
logic [1:0] colorIndex;
logic [7:0] panelRGB;
logic [11:0] rowScore;
logic [3:0] digit;
logic [12:0] numberAddress;
logic numberPixel, insideNumber_d, recordDigit_d;
logic replaceHeader, headerPixel, replaceHeader_d, headerPixel_d;

assign relativeX = int'(pixelX) - TOP_LEFT_X;
assign relativeY = int'(pixelY) - TOP_LEFT_Y;
// Keep the existing 256x192 layout coordinates internally. Repeating each
// layout pixel twice enlarges artwork, digits and victory text together.
assign layoutX = relativeX >>> 1;
assign layoutY = relativeY >>> 1;
assign insidePanel = game_state == GAME_OVER &&
                     relativeX >= 0 && relativeX < 512 &&
                     relativeY >= 0 && relativeY < 384;
// Divide displayed coordinates by four to read the unchanged source image.
assign address = insidePanel ? {relativeY[8:2], relativeX[8:2]} : 14'd0;

lpm_rom #(
    .lpm_width(2), .lpm_widthad(14), .lpm_numwords(12288),
    .lpm_file("RTL/game_over_screen.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) panel_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

// Dots end at source X=90. Numbers start at source X=96, leaving a visible
// gap. Their centers align with dotted rows Y=31 and Y=60 in the supplied PNG.
// The original 16x32 digit cells now occupy 32x64 screen pixels.
// Constants below use the internal 256x192 layout: 1 layout pixel becomes
// 2 screen pixels, while 1 source-PNG pixel occupies 2 layout pixels.
always_comb begin
    // 192 = source X=96 * 2. Subtract the number row's left edge to get
    // its local X coordinate. On screen this begins at 64 + 192*2 = X=448.
    numberX = layoutX - 192;
    // The HIGH SCORE dots are at source Y=60 -> layout Y=120.
    // Center a 32-high digit cell there: top=120-16=104, end=104+32=136.
    // The end is exclusive, so the high-score row occupies layout Y=104..135.
    bestRow = layoutY >= 104 && layoutY < 136;
    // The SCORE dots are at source Y=31 -> layout Y=62; top=62-16=46.
    // Subtract the selected row's top (104 or 46) to get digit-local Y=0..31.
    numberY = bestRow ? layoutY - 104 : layoutY - 46;
    rowScore = bestRow ? best_score_bcd : final_score_bcd;
    digit = 4'd0;
    insideNumber = 1'b0;
    // Each digit mask is 16 wide x 32 high in layout coordinates. The three
    // slots start at X=0,20,40: 16 pixels of digit plus a 4-pixel gap.
    // Their exclusive right edges are 16,36 (=20+16), and 56 (=40+16).
    if (insidePanel && numberY >= 0 && numberY < 32) begin
        if (numberX >= 0 && numberX < 16) begin
            digit = rowScore[11:8];
            insideNumber = rowScore[11:8] != 0;
        end else if (numberX >= 20 && numberX < 36) begin
            numberX = numberX - 20;
            digit = rowScore[7:4];
            insideNumber = rowScore[11:4] != 0;
        end else if (numberX >= 40 && numberX < 56) begin
            numberX = numberX - 40;
            digit = rowScore[3:0];
            insideNumber = 1'b1;
        end
    end
    numberAddress = insideNumber ? {digit, numberY[4:0], numberX[3:0]} : 13'd0;
end

lpm_rom #(
    .lpm_width(1), .lpm_widthad(13), .lpm_numwords(8192),
    .lpm_file("RTL/numbers.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) numbers_rom (
    .address(numberAddress), .inclock(clk), .outclock(), .memenab(1'b1), .q(numberPixel)
);

// Seven 5-bit rows, from top to bottom. Only the victory message's letters
// are stored as constants, so no second full panel image or MIF is needed.
function automatic logic [34:0] letter_pixels(input logic [7:0] letter);
    case (letter)
        "A": letter_pixels = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
        "B": letter_pixels = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
        "C": letter_pixels = {5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
        "E": letter_pixels = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
        "G": letter_pixels = {5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
        "H": letter_pixels = {5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
        "M": letter_pixels = {5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
        "N": letter_pixels = {5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001};
        "O": letter_pixels = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
        "R": letter_pixels = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
        "S": letter_pixels = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
        "T": letter_pixels = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
        "U": letter_pixels = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
        "V": letter_pixels = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
        "Y": letter_pixels = {5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
        "!": letter_pixels = {5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00000,5'b00100};
        default: letter_pixels = 35'd0;
    endcase
endfunction

// Each call has a constant message and length. The fixed character positions
// unroll into simple pixel selections, avoiding hardware division/modulo by 6.
function automatic logic text_pixel(input int x, input int y,
                                    input logic [103:0] message, input int length);
    logic [34:0] glyph;
    int leftX, column;
    begin
        leftX = (128 - (length * 6 - 1)) / 2;
        column = 0;
        glyph = 35'd0;
        text_pixel = 1'b0;
        for (int character = 0; character < 13; character++) begin
            if (character < length && y >= 0 && y < 7 &&
                x >= leftX + character * 6 && x < leftX + character * 6 + 5) begin
                glyph = letter_pixels(message[103 - character * 8 -: 8]);
                column = x - (leftX + character * 6);
                text_pixel = glyph[34 - y * 5 - column];
            end
        end
    end
endfunction

// Existing 999-point victory heading: replace only the panel's title area.
// 12'h999 contains the three BCD digits 9,9,9. For other scores use the PNG.
// Layout X=2..253 and Y=2..53 correspond to source X=1..126, Y=1..26.
// These bounds leave the one-source-pixel border and the score labels intact.
assign replaceHeader = insidePanel && final_score_bcd == 12'h999 &&
                       layoutX >= 2 && layoutX < 254 &&
                       layoutY >= 2 && layoutY < 54;
// >>1 maps layout coordinates back to source-PNG coordinates for the 5x7 font.
// 6 and 16 are the two text lines' top Y positions in that source coordinate
// system; 13 and 8 are their character counts (including spaces).
// message is always 104 bits = 13 ASCII characters. Pad shorter messages with
// 40'd0 (5 unused character slots) for THE GAME.
// OR the two line pixels: a 1 draws purple ink, a 0 leaves yellow background
// when replaceHeader is active. No additional victory image is read.
assign headerPixel = text_pixel(layoutX >> 1, (layoutY >> 1) - 6, "YOU HAVE BEAT", 13) ||
                     text_pixel(layoutX >> 1, (layoutY >> 1) - 16, {"THE GAME",40'd0}, 8);

// Delay every selection flag with both ROM addresses, keeping one clock of
// latency like the start, pause and rulebook renderers.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        gameOverDrawingRequest <= 1'b0;
        insideNumber_d <= 1'b0;
        recordDigit_d <= 1'b0;
        replaceHeader_d <= 1'b0;
        headerPixel_d <= 1'b0;
    end else begin
        gameOverDrawingRequest <= insidePanel;
        insideNumber_d <= insideNumber;
        recordDigit_d <= bestRow && new_best;
        replaceHeader_d <= replaceHeader;
        headerPixel_d <= headerPixel;
    end
end

// BEGIN GENERATED PALETTE
always_comb begin
    panelRGB = 8'h00;
    if (gameOverDrawingRequest) begin
        case (colorIndex)
            2'd0: panelRGB = 8'h67;
            2'd1: panelRGB = 8'hE0;
            2'd2: panelRGB = 8'hE5;
            2'd3: panelRGB = 8'hF8;
            default: panelRGB = 8'h00;
        endcase
    end
end
// END GENERATED PALETTE

always_comb begin
    gameOverRGB = 8'h00;
    if (gameOverDrawingRequest) begin
        gameOverRGB = panelRGB;
        if (replaceHeader_d)
            gameOverRGB = headerPixel_d ? NUMBER_COLOR : PANEL_BACKGROUND;
        if (insideNumber_d && numberPixel)
            gameOverRGB = recordDigit_d ? RECORD_COLOR : NUMBER_COLOR;
    end
end
endmodule
