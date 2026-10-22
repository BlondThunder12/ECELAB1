// Shared pickup slots. Position belongs to the item, not to a recycled pipe.
// Hearts and coins share the same spawn/move/collect path.
module pickup_control #(
    parameter bit ENABLE_HEARTS = 1'b1,
    parameter bit ENABLE_COINS = 1'b1
)(
    input  logic        clk,
    input  logic        resetN,
    input  logic [1:0]  game_state,
    // PipeBlocks forwards pipe 0's movement report, shared by all three pipes.
    // Every active item subtracts this step on the same update clock cycle.
    input  logic        scrollUpdate,
    input  logic [10:0] scrollStep,       // Actual pipe step, in 1/64 pixel units
    input  logic [10:0] pipeSpacing,
    input  logic [32:0] pipeXPositions,
    input  logic [17:0] pipeHeights,
    input  logic [2:0]  pipeReady,
    input  logic [2:0]  pipeRecycle,
    input  logic [7:0]  random_value,
    input  logic        birdDrawingRequest,
    input  logic        pickupDrawingRequest,
    input  logic [1:0]  pickupIndex,
    output logic [2:0]  itemActive,
    output logic [32:0] itemXPositions,
    output logic [26:0] itemYPositions,
    output logic [5:0]  itemTypes,
    output logic [2:0]  itemSpawn,        // One clock per birth, for Signal Tap
    output logic        itemCollected,
    output logic [1:0]  collectedType,
    output logic        heartCollected,
    output logic        coinCollected
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING = 2'b01;
localparam logic [1:0] COIN = 2'd0;
localparam logic [1:0] HEART = 2'd1; // Same tile numbers as pickups.mif
localparam int FIXED_POINT_MULTIPLIER = 64;
localparam int SPAWN_X = 672;       // Entire 32-pixel item begins offscreen.
localparam int ITEM_WIDTH = 32;
localparam int GAP_MARGIN = 16;
// Pipe positions refer to the 64-pixel body; its 80-pixel cap extends 8 left
// and 72 right. Use the caps when checking the free horizontal interval.
localparam int CAP_LEFT = 8;
localparam int CAP_RIGHT = 72;

int itemXFixed [0:2];
logic [8:0] itemY [0:2];
logic [1:0] itemType [0:2];
logic [1:0] itemAge [0:2]; // Wait for the three-clock drawing pipeline after reuse.
logic [2:0] pipeSeen, gapHandled, gapEnabled;
int gapSpawnX [0:2];
logic [3:0] gapYOffset [0:2];
logic [1:0] gapType [0:2];
logic [1:0] nextType;
int freeSlot, gapIndex, pipeX, gapLeft, gapRight, stepPixels;
logic gapClear;
logic collectItem;

genvar i;
generate
    for (i = 0; i < 3; i++) begin : item_positions
        // Arithmetic shift rounds negative coordinates down at the left edge.
        assign itemXPositions[i*11 +: 11] = 11'(itemXFixed[i] >>> 6);
        assign itemYPositions[i*9 +: 9] = itemY[i];
        assign itemTypes[i*2 +: 2] = itemType[i];
    end
endgenerate

assign heartCollected = itemCollected && (collectedType == HEART);
// Score on the collection edge, including the last PLAYING clock before
// pause/game over. Removing the active item prevents a second award.
assign collectItem = (game_state == PLAYING) && pickupIndex < 3 &&
                     itemActive[pickupIndex] && itemAge[pickupIndex] == 2'd3 &&
                     birdDrawingRequest && pickupDrawingRequest;
assign coinCollected = collectItem && (itemType[pickupIndex] == COIN);

always_comb begin
    if (ENABLE_HEARTS && ENABLE_COINS)
        nextType = random_value[0] ? HEART : COIN;
    else if (ENABLE_HEARTS)
        nextType = HEART;
    else
        nextType = COIN;

    freeSlot = -1;
    gapIndex = -1;
    pipeX = 0;
    gapLeft = 0;
    gapRight = 0;
    gapClear = 1'b0;
    // Round the frame's movement up, so clearance also holds AFTER the step.
    stepPixels = (int'(scrollStep) + 63) >> 6;
    for (int j = 0; j < 3; j++) begin
        if (!itemActive[j] && freeSlot == -1) freeSlot = j;
        if (pipeSeen[j] && pipeReady[j] && !gapHandled[j] && gapIndex == -1 &&
            int'($signed(pipeXPositions[j*11 +: 11])) <= gapSpawnX[j])
            gapIndex = j;
    end
    if (gapIndex >= 0) begin
        pipeX = int'($signed(pipeXPositions[gapIndex*11 +: 11]));
        gapLeft = pipeX + CAP_RIGHT;
        // The following pipe may not have recycled yet. Its planned position
        // is still one spacing to the right; no change to pipe spawning needed.
        gapRight = pipeX + int'(pipeSpacing) - CAP_LEFT;
        gapClear = (gapLeft + GAP_MARGIN <= SPAWN_X) &&
                   (gapRight - stepPixels >= SPAWN_X + ITEM_WIDTH + GAP_MARGIN);
    end
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        pipeSeen <= 3'b000;
        gapHandled <= 3'b000;
        gapEnabled <= 3'b000;
        itemActive <= 3'b000;
        itemSpawn <= 3'b000;
        itemCollected <= 1'b0;
        collectedType <= HEART;
        for (int j = 0; j < 3; j++) begin
            itemXFixed[j] <= SPAWN_X * FIXED_POINT_MULTIPLIER;
            itemY[j] <= 9'd160;
            itemType[j] <= HEART;
            itemAge[j] <= 2'd0;
            gapSpawnX[j] <= SPAWN_X - CAP_RIGHT - GAP_MARGIN;
            gapYOffset[j] <= 4'd8;
            gapType[j] <= HEART;
        end
    end else begin
        itemSpawn <= 3'b000;
        itemCollected <= 1'b0;
        if (game_state == START_SCREEN) begin
            pipeSeen <= 3'b000;
            gapHandled <= 3'b000;
            gapEnabled <= 3'b000;
            itemActive <= 3'b000;
            for (int j = 0; j < 3; j++) begin
                itemXFixed[j] <= SPAWN_X * FIXED_POINT_MULTIPLIER;
                itemY[j] <= 9'd160;
                itemType[j] <= HEART;
                itemAge[j] <= 2'd0;
            end
        end else if (game_state == PLAYING) begin
            for (int j = 0; j < 3; j++) begin
                if (itemActive[j] && itemAge[j] != 2'd3)
                    itemAge[j] <= itemAge[j] + 1'b1;
                if (pipeReady[j] && (!pipeSeen[j] || pipeRecycle[j])) begin
                    pipeSeen[j] <= 1'b1;
                    gapHandled[j] <= 1'b0;
                    // Decide ONCE for the space behind this pipe. Recycling
                    // prepares a future gap; it never moves an existing item.
                    gapEnabled[j] <= (ENABLE_HEARTS || ENABLE_COINS) && random_value[j+5];
                    gapType[j] <= nextType;
                    gapYOffset[j] <= random_value[7:4];
                    // Randomize where within the gap X=672 will fall. This
                    // gives 0..63 pixels of extra clearance behind the cap.
                    gapSpawnX[j] <= SPAWN_X - CAP_RIGHT - GAP_MARGIN -
                                   int'(random_value[5:0]);
                end
                // Move this item's own position with the common scrolling.
                // A pipe wrapping to the right never resets the item's X.
                if (scrollUpdate && itemActive[j]) begin
                    itemXFixed[j] <= itemXFixed[j] - int'(scrollStep);
                    if (itemXFixed[j] - int'(scrollStep) <=
                        -ITEM_WIDTH * FIXED_POINT_MULTIPLIER)
                        itemActive[j] <= 1'b0;
                end
            end

            if (collectItem) begin
                itemActive[pickupIndex] <= 1'b0;
                itemCollected <= 1'b1;
                collectedType <= itemType[pickupIndex];
            end

            if (scrollUpdate && gapIndex >= 0) begin
                gapHandled[gapIndex] <= 1'b1; // One opportunity per gap.
                if (gapEnabled[gapIndex] && gapClear && freeSlot >= 0) begin
                    itemActive[freeSlot] <= 1'b1;
                    itemXFixed[freeSlot] <= SPAWN_X * FIXED_POINT_MULTIPLIER;
                    // Follow the opening of the pipe just passed. Latch Y so
                    // a later pipe recycle cannot move the item vertically.
                    itemY[freeSlot] <= 9'(int'(pipeHeights[gapIndex*6 +: 6])*8 +
                                              40 + int'(gapYOffset[gapIndex]));
                    itemType[freeSlot] <= gapType[gapIndex];
                    itemAge[freeSlot] <= 2'd0;
                    itemSpawn[freeSlot] <= 1'b1;
                end
            end
        end
        // Pause and game over hold item positions and pending gap decisions.
    end
end
endmodule
