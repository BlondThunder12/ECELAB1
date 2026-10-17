// Select the color belonging to the active part of Pipe_Object.
// Keep this combinational so body tiles and the existing caps stay aligned.
// Pipe_Object connects both edge RGB inputs to the shared cap ROM. Quartus
// can merge those branches; selecting between cap/body colors is still needed.
module pipe_color_mux (
    input  logic       topBodyDR,
    input  logic [7:0] topBodyRGB,
    input  logic       bottomBodyDR,
    input  logic [7:0] bottomBodyRGB,
    input  logic       topEdgeDR,
    input  logic [7:0] topEdgeRGB,
    input  logic       bottomEdgeDR,
    input  logic [7:0] bottomEdgeRGB,
    output logic [7:0] RGBout
);

always_comb begin
    RGBout = 8'hFF;
    if (topEdgeDR)
        RGBout = topEdgeRGB;
    else if (bottomEdgeDR)
        RGBout = bottomEdgeRGB;
    else if (topBodyDR)
        RGBout = topBodyRGB;
    else if (bottomBodyDR)
        RGBout = bottomBodyRGB;
end

endmodule
