module objects_mux (
    input logic clk,
    input logic resetN,

    input logic birdDrawingRequest,
    input logic [7:0] birdRGB,

    input logic boxDrawingRequest,
    input logic [7:0] boxRGB,

    input logic heartDrawingRequest,
    input logic [7:0] heartRGB,

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

    input logic startDrawingRequest,
    input logic [7:0] startRGB,

    input logic rulebookDrawingRequest,
    input logic [7:0] rulebookRGB,

    output logic [7:0] RGBOut
);

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        RGBOut <= 8'b0;
    end else begin
        if (rulebookDrawingRequest)
            RGBOut <= rulebookRGB;
        else if (startDrawingRequest)
            RGBOut <= startRGB;
        else if (birdDrawingRequest)
            RGBOut <= birdRGB;
        else if (boxDrawingRequest)
            RGBOut <= boxRGB;
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
