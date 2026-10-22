// HartsMatrixBitMap: the existing heart renderer now shares one indexed ROM
// between moving pickups and the three remaining-life icons in the HUD.
module HartsMatrixBitMap (
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [1:0]  game_state,
    input  logic [1:0]  lives,
    input  logic [32:0] itemXPositions,
    input  logic [26:0] itemYPositions,
    input  logic [2:0]  itemActive,
    input  logic [5:0]  itemTypes,
    output logic        drawingRequest,       // World pickup only, for collection/mux
    output logic        livesDrawingRequest,  // HUD only, drawn above pipes
    output logic [7:0]  RGBout,
    output logic [1:0]  pickupIndex
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] HEART_TILE = 2'd1; // icons.png order: coin, heart, TNT, ghost
int sourceX, sourceY, pickupX, pickupY, relativeX, relativeY;
logic worldInside, hudInside;
logic [1:0] selectedPickup;
logic [1:0] selectedType;
logic [11:0] address;
logic [3:0] colorIndex;
logic [7:0] pixelRGB, pixelRGB_d;
logic world_d, hud_d, world_dd, hud_dd;
logic [1:0] pickup_d, pickup_dd;

always_comb begin
    sourceX = 0;
    sourceY = 0;
    pickupX = 0;
    pickupY = 0;
    relativeX = 0;
    relativeY = 0;
    worldInside = 1'b0;
    hudInside = 1'b0;
    selectedPickup = 2'd0;
    selectedType = HEART_TILE;
    if (game_state != START_SCREEN) begin
        for (int j = 0; j < 3; j++) begin
            pickupX = int'($signed(itemXPositions[j*11 +: 11]));
            pickupY = int'(itemYPositions[j*9 +: 9]);
            relativeX = int'(pixelX) - pickupX;
            relativeY = int'(pixelY) - pickupY;
            if (itemActive[j] && relativeX >= 0 && relativeX < 32 &&
                relativeY >= 0 && relativeY < 32) begin
                sourceX = relativeX;
                sourceY = relativeY;
                worldInside = 1'b1;
                selectedPickup = 2'(j);
                selectedType = itemTypes[j*2 +: 2];
            end
        end
        // Native 32x32 HUD cells at X=16,56,96 and Y=16. One ROM port is
        // sufficient because the VGA requests just one screen pixel at a time.
        if (pixelY >= 16 && pixelY < 48) begin
            if (lives >= 1 && pixelX >= 16 && pixelX < 48) begin
                sourceX = int'(pixelX) - 16;
                hudInside = 1'b1;
            end else if (lives >= 2 && pixelX >= 56 && pixelX < 88) begin
                sourceX = int'(pixelX) - 56;
                hudInside = 1'b1;
            end else if (lives >= 3 && pixelX >= 96 && pixelX < 128) begin
                sourceX = int'(pixelX) - 96;
                hudInside = 1'b1;
            end
            if (hudInside) begin
                sourceY = int'(pixelY) - 16;
                selectedType = HEART_TILE;
                worldInside = 1'b0; // A HUD heart can never be collected.
            end
        end
    end
    address = (worldInside || hudInside) ? {selectedType,sourceY[4:0],sourceX[4:0]} : 12'd0;
end

lpm_rom #(
    .lpm_width(4), .lpm_widthad(12), .lpm_numwords(4096),
    .lpm_file("RTL/pickups.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) pickups_rom (
    .address(address), .inclock(clk), .outclock(), .memenab(1'b1), .q(colorIndex)
);

// BEGIN GENERATED PALETTE
always_comb begin
    case (colorIndex)
        4'd1: pixelRGB = 8'h00;
        4'd2: pixelRGB = 8'h24;
        4'd3: pixelRGB = 8'h40;
        4'd4: pixelRGB = 8'h80;
        4'd5: pixelRGB = 8'h81;
        4'd6: pixelRGB = 8'hC1;
        4'd7: pixelRGB = 8'hDB;
        4'd8: pixelRGB = 8'hE8;
        4'd9: pixelRGB = 8'hF2;
        4'd10: pixelRGB = 8'hF4;
        4'd11: pixelRGB = 8'hFB;
        4'd12: pixelRGB = 8'hFF;
        default: pixelRGB = 8'h00;
    endcase
end
// END GENERATED PALETTE

// Three clocks, matching square_object + birdBitMap. Keep the pickup ID
// beside its ROM pixel so an overlap always removes the correct pickup slot.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        world_d <= 1'b0;
        hud_d <= 1'b0;
        world_dd <= 1'b0;
        hud_dd <= 1'b0;
        pickup_d <= 2'd0;
        pickup_dd <= 2'd0;
        pickupIndex <= 2'd0;
        pixelRGB_d <= 8'h00;
        RGBout <= 8'h00;
        drawingRequest <= 1'b0;
        livesDrawingRequest <= 1'b0;
    end else begin
        world_d <= worldInside;
        hud_d <= hudInside;
        pickup_d <= selectedPickup;
        world_dd <= world_d && colorIndex != 0;
        hud_dd <= hud_d && colorIndex != 0;
        pickup_dd <= pickup_d;
        pixelRGB_d <= pixelRGB;
        drawingRequest <= world_dd;
        livesDrawingRequest <= hud_dd;
        pickupIndex <= pickup_dd;
        RGBout <= (world_dd || hud_dd) ? pixelRGB_d : 8'h00;
    end
end
endmodule
