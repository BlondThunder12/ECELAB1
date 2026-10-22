// Brief frame-timed notification for real increases in the game's speed level.
module speed_up_draw #(
    parameter int BLINK_HALF_FRAMES = 12,
    parameter int FLASH_COUNT = 4
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic        startOfFrame,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic [3:0]  speed_level,
    output logic        speedUpDrawingRequest,
    output logic [7:0]  speedUpRGB
);

localparam logic [1:0] START_SCREEN = 2'b00, PLAYING = 2'b01, GAME_OVER = 2'b10;
localparam int HALF_BITS = (BLINK_HALF_FRAMES > 1) ? $clog2(BLINK_HALF_FRAMES) : 1;
localparam int PHASE_COUNT = 2 * FLASH_COUNT;
localparam int PHASE_BITS = (PHASE_COUNT > 1) ? $clog2(PHASE_COUNT) : 1;
localparam int TEXT_WIDTH = 47 * 4;
localparam int TEXT_LEFT = (640 - TEXT_WIDTH) / 2;
localparam int TEXT_TOP = 52;
// VGA_Controller maps its input as {blue[2:0], green[2:0], red[1:0]}.
localparam logic [7:0] TEXT_COLOR = 8'h1F;

// Seven rows of "SPEED UP!", using a small 5x7 pixel font enlarged 4x.
// This constant bitmap synthesizes as logic; no image ROM or framebuffer.
localparam logic [0:6][0:46] TEXT_BITS = {
    47'b01111011110011111011111011110000001000101111001,
    47'b10000010001010000010000010001000001000101000101,
    47'b10000010001010000010000010001000001000101000101,
    47'b01110011110011110011110010001000001000101111001,
    47'b00001010000010000010000010001000001000101000001,
    47'b00001010000010000010000010001000001000101000000,
    47'b11110010000011111011111011110000000111001000001
};

logic [3:0] previous_speed;
logic pending_speedup, active;
logic [HALF_BITS-1:0] phase_frames;
logic [PHASE_BITS-1:0] phase_index;
logic level_increased, visible;

assign level_increased = speed_level > previous_speed;
assign visible = active && !phase_index[0] && game_state == PLAYING;

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        previous_speed <= 0;
        pending_speedup <= 0;
        active <= 0;
        phase_frames <= 0;
        phase_index <= 0;
    end else begin
        previous_speed <= speed_level;
        if (game_state == START_SCREEN || game_state == GAME_OVER) begin
            pending_speedup <= 0;
            active <= 0;
            phase_frames <= 0;
            phase_index <= 0;
        end else if (game_state == PLAYING) begin
            // Score changes can occur between frames. Retain the event until
            // vertical blanking so a notification never starts mid-scan.
            if (level_increased) pending_speedup <= 1;
            if (startOfFrame) begin
                if (pending_speedup || level_increased) begin
                    pending_speedup <= 0;
                    active <= 1;
                    phase_frames <= 0;
                    phase_index <= 0;
                end else if (active) begin
                    if (phase_frames == HALF_BITS'(BLINK_HALF_FRAMES - 1)) begin
                        phase_frames <= 0;
                        if (phase_index == PHASE_BITS'(PHASE_COUNT - 1)) begin
                            active <= 0;
                            phase_index <= 0;
                        end else phase_index <= phase_index + 1'b1;
                    end else phase_frames <= phase_frames + 1'b1;
                end
            end
        end
        // Paused: hide the text and retain the remaining animation time.
    end
end

function automatic logic text_pixel(input logic [10:0] x, input logic [10:0] y);
    logic [10:0] relativeX, relativeY;
    begin
        relativeX = x - 11'(TEXT_LEFT);
        relativeY = y - 11'(TEXT_TOP);
        text_pixel = 1'b0;
        if (relativeX < 11'(TEXT_WIDTH) && relativeY < 11'd28)
            text_pixel = TEXT_BITS[relativeY[4:2]][relativeX[7:2]];
    end
endfunction

// Match the existing screen renderers' one-clock latency. The black shadow
// is opaque, while the area around the glyphs remains transparent.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        speedUpDrawingRequest <= 0;
        speedUpRGB <= 0;
    end else begin
        speedUpDrawingRequest <= visible &&
            (text_pixel(pixelX, pixelY) || text_pixel(pixelX - 11'd2, pixelY - 11'd2));
        speedUpRGB <= (visible && text_pixel(pixelX, pixelY)) ? TEXT_COLOR : 8'h00;
    end
end
endmodule
