module objects_mux #(
    parameter int LIGHT_RADIUS = 190,
    parameter int INITIAL_RADIUS = 800, // Start with the whole screen visible.
    parameter int SHRINK_STEP = 4,      // Partner's transition step per VGA frame.
    parameter int EDGE_WIDTH = 30       // Narrow dimmed rim outside the clear circle.
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
localparam int EDGE_STEP = (EDGE_WIDTH + 2) / 3;
logic [25:0] edge_near_sq, edge_mid_sq, edge_outer_sq;
logic signed [12:0] diffX, diffY;
logic [25:0] dist_sq;
logic inside_spotlight;
logic bird_yellow_pixel;
logic [7:0] scene_rgb;

// Darken RGB332 channels separately so bits never spill into another color.
function automatic logic [7:0] dim_pixel(input logic [7:0] color, input logic [1:0] level);
    logic [4:0] red_times_three, green_times_three;
    logic [3:0] blue_times_three;
    begin
        red_times_three = {2'b00, color[7:5]} + {1'b0, color[7:5], 1'b0};
        green_times_three = {2'b00, color[4:2]} + {1'b0, color[4:2], 1'b0};
        blue_times_three = {2'b00, color[1:0]} + {1'b0, color[1:0], 1'b0};
        case (level)
            2'd3: dim_pixel = {red_times_three[4:2], green_times_three[4:2], blue_times_three[3:2]};
            2'd2: dim_pixel = {1'b0, color[7:6], 1'b0, color[4:3], 1'b0, color[1]};
            2'd1: dim_pixel = {2'b00, color[7], 2'b00, color[4], 2'b00};
            default: dim_pixel = 8'h00;
        endcase
    end
endfunction

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
        edge_near_sq <= 26'((INITIAL_RADIUS + EDGE_STEP) * (INITIAL_RADIUS + EDGE_STEP));
        edge_mid_sq <= 26'((INITIAL_RADIUS + 2*EDGE_STEP) * (INITIAL_RADIUS + 2*EDGE_STEP));
        edge_outer_sq <= 26'((INITIAL_RADIUS + EDGE_WIDTH) * (INITIAL_RADIUS + EDGE_WIDTH));
    end else if (game_state == START_SCREEN) begin
        current_radius <= 12'(INITIAL_RADIUS);
        current_radius_sq <= 26'(INITIAL_RADIUS * INITIAL_RADIUS);
        edge_near_sq <= 26'((INITIAL_RADIUS + EDGE_STEP) * (INITIAL_RADIUS + EDGE_STEP));
        edge_mid_sq <= 26'((INITIAL_RADIUS + 2*EDGE_STEP) * (INITIAL_RADIUS + 2*EDGE_STEP));
        edge_outer_sq <= 26'((INITIAL_RADIUS + EDGE_WIDTH) * (INITIAL_RADIUS + EDGE_WIDTH));
    end else if (game_state == PLAYING && startOfFrame) begin
        current_radius <= next_radius;
        current_radius_sq <= next_radius * next_radius;
        edge_near_sq <= (26'(next_radius) + 26'(EDGE_STEP)) * (26'(next_radius) + 26'(EDGE_STEP));
        edge_mid_sq <= (26'(next_radius) + 26'(2*EDGE_STEP)) * (26'(next_radius) + 26'(2*EDGE_STEP));
        edge_outer_sq <= (26'(next_radius) + 26'(EDGE_WIDTH)) * (26'(next_radius) + 26'(EDGE_WIDTH));
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

always_comb begin
    if (birdDrawingRequest && birdVisible)
        scene_rgb = (ghost_active && bird_yellow_pixel) ? 8'hFF : birdRGB;
    else if (pipesDrawingRequest)
        scene_rgb = pipesRGB;
    else if (heartDrawingRequest)
        scene_rgb = heartRGB;
    else if (groundDrawingRequest)
        scene_rgb = groundRGB;
    else if (cloudDrawingRequest)
        scene_rgb = cloudRGB;
    else if (planeDrawingRequest)
        scene_rgb = planeRGB;
    else if (sunMoonDrawingRequest)
        scene_rgb = sunMoonRGB;
    else if (BGDrawingRequest)
        scene_rgb = backGroundRGB;
    else
        scene_rgb = RGB_MIF;
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
                 game_state != START_SCREEN) begin
            if (inside_spotlight)
                RGBOut <= scene_rgb;
            else if (dist_sq <= edge_near_sq)
                RGBOut <= dim_pixel(scene_rgb, 2'd3);
            else if (dist_sq <= edge_mid_sq)
                RGBOut <= dim_pixel(scene_rgb, 2'd2);
            else if (dist_sq <= edge_outer_sq)
                RGBOut <= dim_pixel(scene_rgb, 2'd1);
            else
                RGBOut <= 8'h00;
        end
        else
            RGBOut <= scene_rgb;
    end
end

endmodule
