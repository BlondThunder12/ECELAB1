//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// System-Verilog Alex Grinshpun May 2018
// New coding convention dudy December 2018
// (c) Technion IIT, Department of Electrical Engineering 2025 


module	pipe_coordinate_calc	(	
					input		logic	clk,
					input		logic	resetN,
					input 	logic signed	[10:0] wantedXCoordinate, // X coordinate wanted for the pipe
					input 	logic	unsigned [5:0] numberOfChunks,   	  // amount of top pipe chunks
					
					output	logic	signed [10:0] topLeftX_Pipe, 		// topLeft X pixel of long pipes
					output	logic	signed [10:0] topLeftX_Edge,		// topLeft X pixel of edges
					output	logic signed [10:0] topLeftY_TopEdge, 	// topLeft y pixel of top edge
					output	logic signed [10:0] topLeftY_BottomEdge, // topLeft y pixel of bottom edge
					output	logic signed [10:0] topLeftY_BottomPipe, // topLeft y pixel of bottom pipe
					output	logic unsigned [5:0] bottomPipeNumOfChunks // amount of chunks to draw for bottom pipe
);

parameter  int gap_size = 88;
parameter  int width_of_pipe = 64;
parameter  int width_of_edge = 80;
parameter  int height_of_edge= 20;
parameter  int ground_pixel_bottom = 480 - 32;
parameter  int height_of_pipe = 8;

logic signed [10:0] heightOfTopPipe;
logic signed [10:0] XCoordinateOfPipe;
logic signed [10:0] XCoordinateOfEdge;
logic signed [10:0] YCoordinateOfTopEdge;
logic signed [10:0] YCoordinateOfBottomEdge;
logic signed [10:0] YCoordinateOfBottomPipe;
logic unsigned [5:0]  BottomNumberOfChunks;

//////////--------------------------------------------------------------------------------------------------------------=
// Calculate object right  & bottom  boundaries
assign heightOfTopPipe = (numberOfChunks * height_of_pipe);
assign XCoordinateOfPipe = wantedXCoordinate;
assign XCoordinateOfEdge = XCoordinateOfPipe - ((width_of_edge - width_of_pipe) / 2);
assign YCoordinateOfTopEdge =  heightOfTopPipe;
assign YCoordinateOfBottomEdge = heightOfTopPipe + height_of_edge + gap_size;
assign YCoordinateOfBottomPipe = YCoordinateOfBottomEdge + height_of_edge;
assign BottomNumberOfChunks = (ground_pixel_bottom - YCoordinateOfBottomPipe ) / height_of_pipe;
		
localparam int OFFSCREEN_X = 640 + width_of_edge;
//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		topLeftX_Pipe <= OFFSCREEN_X; 		
		topLeftX_Edge <= OFFSCREEN_X - ((width_of_edge - width_of_pipe) / 2);	
		topLeftY_TopEdge <= 0;
		topLeftY_BottomEdge <= 0;
		topLeftY_BottomPipe <= 0;
		bottomPipeNumOfChunks <= 0;
	end
	else begin 
	
		topLeftX_Pipe <= XCoordinateOfPipe; 		
		topLeftX_Edge <= XCoordinateOfEdge;
		topLeftY_TopEdge <= YCoordinateOfTopEdge;
		topLeftY_BottomEdge <= YCoordinateOfBottomEdge;
		topLeftY_BottomPipe <= YCoordinateOfBottomPipe;
		bottomPipeNumOfChunks <= BottomNumberOfChunks;
	end
end 
endmodule 