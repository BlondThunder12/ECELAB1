module objects_mux #(
    parameter int LIGHT_RADIUS = 190,
    parameter int INITIAL_RADIUS = 800, // Start with the whole screen visible.
    parameter int SHRINK_STEP = 4       // Partner's transition step per VGA frame.
)(
    input logic clk,
    input logic resetN,

    input logic birdDrawingRequest,
    input logic [7:0] birdRGB,

    input logic boxDrawingRequest,
    input logic [7:0] boxRGB,

    input logic heartDrawingRequest,
    input logic [7:0] heartRGB,
    input logic livesDrawingRequest, // HUD and pickups share the heart ROM's RGB.
    input logic birdVisible,         // Blinking affects drawing, not collision masks.

    input logic [7:0] backGroundRGB,
    input logic BGDrawingRequest,

    input logic [7:0] RGB_MIF,

    input logic pipesDrawingRequest,
    input logic [7:0] pipesRGB,

    input logic cloudDrawingRequest,
    input logic [7:0] cloudRGB,

    input logic groundDrawingRequest,
    input logic [7:0] groundRGB,

    input logic sunMoonDrawingRequest,
    input logic [7:0] sunMoonRGB,

    input logic planeDrawingRequest,
    input logic [7:0] planeRGB,

    input logic screenDrawingRequest,
    input logic [7:0] screenRGB,

    input logic [10:0] pixelX,
    input logic [10:0] pixelY,
    input logic signed [10:0] birdX,
    input logic signed [10:0] birdY,
    input logic night_mode,
    input logic [1:0] game_state,
    input logic ghost_active,
    input logic startOfFrame,

    output logic [7:0] RGBOut
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING = 2'b01;
logic [11:0] current_radius, next_radius;
logic [25:0] current_radius_sq;
logic signed [12:0] diffX, diffY;
logic [25:0] dist_sq;
logic inside_spotlight;
logic bird_yellow_pixel;

// Yellow body shades from birdPic.mif; retain the outline, eyes and red beak.
assign bird_yellow_pixel = (birdRGB == 8'hF0) || (birdRGB == 8'hF8) ||
                          (birdRGB == 8'hFC) || (birdRGB == 8'hFE);

// Merge the partner's shrink/expand animation with the current pause and
// ghost rendering. Clamp the last step so neither radius is overshot.
always_comb begin
    next_radius = current_radius;
    if (night_mode && current_radius > LIGHT_RADIUS)
        next_radius = (current_radius <= LIGHT_RADIUS + SHRINK_STEP) ?
                      12'(LIGHT_RADIUS) : current_radius - 12'(SHRINK_STEP);
    else if (!night_mode && current_radius < INITIAL_RADIUS)
        next_radius = (int'(current_radius) + SHRINK_STEP >= INITIAL_RADIUS) ?
                      12'(INITIAL_RADIUS) : current_radius + 12'(SHRINK_STEP);
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        current_radius <= 12'(INITIAL_RADIUS);
        current_radius_sq <= 26'(INITIAL_RADIUS * INITIAL_RADIUS);
    end else if (game_state == START_SCREEN) begin
        current_radius <= 12'(INITIAL_RADIUS);
        current_radius_sq <= 26'(INITIAL_RADIUS * INITIAL_RADIUS);
    end else if (game_state == PLAYING && startOfFrame) begin
        current_radius <= next_radius;
        current_radius_sq <= next_radius * next_radius;
    end
end

// birdX/Y are the visible 34x24 bird's top-left corner, including recoil.
// Compare squared distances to draw a circle without calculating a square root.
// Keep enough bits for the products and sum, including signed bird positions.
always_comb begin
    diffX = $signed({2'b00, pixelX}) - ($signed(birdX) + 13'sd17);
    diffY = $signed({2'b00, pixelY}) - ($signed(birdY) + 13'sd12);
    dist_sq = (diffX * diffX) + (diffY * diffY);
    inside_spotlight = dist_sq <= current_radius_sq;
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        RGBOut <= 8'b0;
    end else begin
        if (screenDrawingRequest)
            RGBOut <= screenRGB;
        else if (livesDrawingRequest)
            RGBOut <= heartRGB;
        else if (boxDrawingRequest) // Score, lives and menus stay readable at night.
            RGBOut <= boxRGB;
        else if ((night_mode || current_radius < INITIAL_RADIUS) &&
                 game_state != START_SCREEN && !inside_spotlight)
            RGBOut <= 8'h00;
        else if (birdDrawingRequest && birdVisible)
            RGBOut <= (ghost_active && bird_yellow_pixel) ? 8'hFF : birdRGB;
        else if (pipesDrawingRequest)
            RGBOut <= pipesRGB;
        else if (heartDrawingRequest)
            RGBOut <= heartRGB;
        else if (groundDrawingRequest)
            RGBOut <= groundRGB;
        else if (cloudDrawingRequest)
            RGBOut <= cloudRGB;
        else if (planeDrawingRequest)
            RGBOut <= planeRGB;
        else if (sunMoonDrawingRequest)
            RGBOut <= sunMoonRGB;
        else if (BGDrawingRequest)
            RGBOut <= backGroundRGB;
        else
            RGBOut <= RGB_MIF;
    end
end

endmodule
