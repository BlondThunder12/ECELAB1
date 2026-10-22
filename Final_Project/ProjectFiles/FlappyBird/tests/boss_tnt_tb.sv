`timescale 1ns/1ps
module boss_tnt_tb;
logic clk=0;
always #5 clk=~clk;
logic resetN=0, frame=0, turbo=0;
logic [1:0] state=0;
logic [3:0] level=0;
logic signed [10:0] pixelX=0, pixelY=0;
wire pipeDR, visualDR;
wire [7:0] pipeRGB;
wire [32:0] pipeX, targetX;
wire [17:0] heights;
wire [2:0] ready, recycle, upcoming, tntCollected;
wire [10:0] step, spacing;
wire update;
logic bird=0, contact=0;
logic [1:0] pickupIndex=0;
wire [2:0] active, spawn;
wire [32:0] itemX;
wire [26:0] itemY;
wire [5:0] types;
wire collected;
int births=0, bossBirths=0, tntBirths=0, opens=0, movementChecks=0;
int normalRun=0, pendingTnt[0:2]='{0,0,0};
logic [2:0] seenReady=0, ownersSeen=0;
logic checking=0, passed=0;

PipeBlocks pipes(
    .clk(clk),.resetN(resetN),.startOfFrame(frame),.game_state(state),
    .speed_level(level),.turbo(turbo),.pixelX(pixelX),.pixelY(pixelY),
    .tntCollected(tntCollected),.pipeDR(pipeDR),.pipeVisualDR(visualDR),.pipeRGB(pipeRGB),
    .pipeXPositions(pipeX),.pipeHeights(heights),.pipeReady(ready),.pipeRecycle(recycle),
    .scrollStep(step),.scrollUpdate(update),.pipeSpacing(spacing),
    .bossUpcoming(upcoming),.bossTargetXPositions(targetX)
);
pickup_control pickups(
    .clk(clk),.resetN(resetN),.game_state(state),.scrollUpdate(update),.scrollStep(step),
    .pipeSpacing(spacing),.pipeXPositions(pipeX),.pipeHeights(heights),.pipeReady(ready),
    .pipeRecycle(recycle),.bossUpcoming(upcoming),.bossTargetXPositions(targetX),
    .random_value(8'hFF), // Stress ordinary slots with an item in every allowed gap.
    .birdDrawingRequest(bird),.pickupDrawingRequest(contact),.pickupIndex(pickupIndex),
    .itemActive(active),.itemXPositions(itemX),.itemYPositions(itemY),.itemTypes(types),
    .itemSpawn(spawn),.itemCollected(collected),.tntCollected(tntCollected)
);

// Exercise the real BDF's exported Verilog, rather than a replacement renderer.
logic shapeBoss=0, shapeOpen=0;
logic [5:0] shapeChunks=15;
logic signed [10:0] shapeX=120, shapeY=0;
wire shapeDR;
Pipe_Object shape(.clk(clk),.resetN(resetN),.pixelX(shapeX),.pixelY(shapeY),
    .wantedXCoord(11'd100),.SizeOfUpPipe(shapeChunks),.bossPipe(shapeBoss),
    .bossOpen(shapeOpen),.PipeDR(shapeDR));

logic hitBird=0, hitPipe=0, ghostPickup=0;
wire hit, invulnerable, ghostActive;
wire [1:0] lives;
game_controller collisionLogic(.clk(clk),.resetN(resetN),.startOfFrame(frame),
    .drawing_request_bird(hitBird),.bird_OOB_collision(1'b0),.drawing_request_pipe(hitPipe),
    .game_state(state),.godmode(1'b0),.invulnerable(invulnerable),.collision(hit));
player_lives #(.INVULNERABLE_CLOCKS(100),.GHOST_CLOCKS(500)) lifeLogic(
    .clk(clk),.resetN(resetN),.game_state(state),.godmode(1'b0),.collision(hit),
    .heartCollected(1'b0),.ghostCollected(ghostPickup),.lives(lives),
    .invulnerable(invulnerable),.ghost_active(ghostActive));

task automatic tick(input int n=1);
    repeat(n) begin @(posedge clk); #2; end
endtask
task automatic nextFrame;
    @(negedge clk); frame=1; tick();
    @(negedge clk); frame=0; tick(8);
endtask
task automatic pauseCheck;
    logic [32:0] savedPipes, savedItems;
    logic [2:0] savedOpen, savedExplosion;
    logic [5:0] savedFrames;
    @(negedge clk); state=3;
    savedPipes=pipeX; savedItems=itemX;
    savedOpen=pipes.bossOpen; savedExplosion=pipes.explosionActive;
    savedFrames=pipes.explosionFrames;
    repeat(22) nextFrame();
    if(pipeX!==savedPipes || itemX!==savedItems || pipes.bossOpen!==savedOpen ||
       pipes.explosionActive!==savedExplosion || pipes.explosionFrames!==savedFrames || collected)
        $fatal(1,"Pause changed boss, animation or pickup state");
    @(negedge clk); state=1; tick();
endtask
task automatic collectTnt(input int slot);
    int owner;
    logic [2:0] oldOpen;
    owner=pickups.itemBoss[slot]; oldOpen=pipes.bossOpen;
    if(!pipes.bossPipe[owner]) $fatal(1,"TNT reached bird before its owner recycled");
    if($signed(pipeX[owner*11+:11])-7 <= 314) $fatal(1,"TNT has insufficient lead at bird X=280");
    @(negedge clk); pickupIndex=2'(slot); bird=1; contact=1;
    tick();
    if(active[slot] || !collected || !pipes.bossOpen[owner] ||
       !pipes.explosionActive[owner] || pipes.explosionFrames[owner*2+:2]!==0)
        $fatal(1,"TNT did not collect/open/burst on the same edge");
    for(int j=0;j<3;j++) if(j!=owner && pipes.bossOpen[j]!==oldOpen[j])
        $fatal(1,"TNT opened a different pipe");
    opens++; ownersSeen[owner]=1;
    tick(4);
    if(collected || tntCollected) $fatal(1,"Collection repeated");
    @(negedge clk); bird=0; contact=0;
endtask
task automatic renderBoss(input string filename, input int owner);
    int fd, color;
    fd=$fopen(filename,"w");
    if(!fd) $fatal(1,"Cannot create pipe render");
    $fdisplay(fd,"P3\n96 480\n255");
    for(int y=0;y<480;y++) for(int x=0;x<96;x++) begin
        @(negedge clk);
        pixelX=11'($signed(pipeX[owner*11+:11])-23+x); pixelY=11'(y); tick();
        color=visualDR ? int'(pipeRGB) : ((y>=448)?8'h88:8'h6F);
        $fdisplay(fd,"%0d %0d %0d",((color>>5)&7)*255/7,((color>>2)&7)*255/7,(color&3)*255/3);
    end
    $fclose(fd);
endtask

always @(posedge clk) begin : monitor
    int oldFixed[0:2], oldY[0:2], oldStep, midpoint;
    logic [2:0] oldActive, oldRecycle, oldReady;
    logic stepNow;
    oldActive=active; oldRecycle=recycle; oldReady=ready;
    oldStep=step; stepNow=update;
    for(int j=0;j<3;j++) begin oldFixed[j]=pickups.itemXFixed[j]; oldY[j]=itemY[j*9+:9]; end
    #1;
    if(checking && resetN && state==1) begin
        for(int j=0;j<3;j++) begin
            if(spawn[j] && types[j*2+:2]==2) begin
                int owner, previousPipe, x;
                owner=pickups.itemBoss[j]; previousPipe=(owner==0)?2:owner-1;
                x=$signed(itemX[j*11+:11]);
                if(x<640 || x>672) $fatal(1,"TNT popped onscreen at %0d",x);
                midpoint=($signed(targetX[owner*11+:11])-111)*64;
                if(pickups.itemXFixed[j]-midpoint>63 || midpoint-pickups.itemXFixed[j]>63)
                    $fatal(1,"TNT is not at the midpoint on birth");
                if(itemY[j*9+:9]!==9'(int'(heights[previousPipe*6+:6])*8+64))
                    $fatal(1,"TNT is not centered on the preceding opening");
                pendingTnt[owner]++; tntBirths++;
                if(pendingTnt[owner]!=1) $fatal(1,"Duplicate TNT for a boss");
            end
            if(oldActive[j] && active[j] && !spawn[j]) begin
                if(pickups.itemXFixed[j]!==oldFixed[j]-(stepNow?oldStep:0) || itemY[j*9+:9]!==oldY[j])
                    $fatal(1,"Pickup drifted relative to scrolling or changed Y");
                movementChecks++;
            end
            if((oldReady[j] && !seenReady[j]) || oldRecycle[j]) begin
                births++;
                if(pipes.bossPipe[j]) begin
                    if(normalRun<5) $fatal(1,"Bosses have only %0d normals between them",normalRun);
                    if(pendingTnt[j]!=1) $fatal(1,"Boss recycled without exactly one TNT");
                    pendingTnt[j]=0;
                    normalRun=0; bossBirths++;
                end else normalRun++;
                if(oldRecycle[j] && (pipes.bossOpen[j] || pipes.explosionActive[j]))
                    $fatal(1,"Pipe recycling retained opening/animation");
            end
        end
        seenReady=oldReady;
    end
end

initial begin : run
    int expected, count, owner, runBosses;
    tick(2); @(negedge clk); resetN=1; tick(4);
    // Exact normal/closed/open geometry, including the native cap boundaries.
    for(int mode=0;mode<3;mode++) begin
        @(negedge clk); shapeBoss=(mode!=0); shapeOpen=(mode==2); shapeChunks=(mode==2)?0:15;
        tick(3);
        for(int y=0;y<480;y++) begin
            @(negedge clk); shapeY=11'(y); tick();
            expected=(mode==0)?(y<448 && !(y>=136 && y<264)):
                     (mode==1)?(y<448):(y<16 || (y>=432 && y<448));
            if(shapeDR!==1'(expected)) $fatal(1,"Geometry mode=%0d Y=%0d",mode,y);
        end
    end
    @(negedge clk); shapeY=8; shapeX=93; tick(); if(!shapeDR) $fatal(1,"Cap left edge moved");
    @(negedge clk); shapeX=156; tick(); if(!shapeDR) $fatal(1,"Cap right edge moved");
    @(negedge clk); shapeX=157; tick(); if(shapeDR) $fatal(1,"Cap stretched");

    // The unchanged shared damage path protects closed bosses with ghosts.
    @(negedge clk); state=1; ghostPickup=1; tick();
    @(negedge clk); ghostPickup=0; hitBird=1; hitPipe=1; tick(5);
    if(!ghostActive || lives!=3 || hit) $fatal(1,"Ghost protection failed");
    tick(510);
    if(lives!=2) $fatal(1,"Normal pipe collision did not cost one heart after ghost expiry");
    @(negedge clk); hitBird=0; hitPipe=0;

    for(int boost=0;boost<2;boost++) for(int speed=0;speed<=10;speed++) begin
        @(negedge clk); state=0; checking=0; turbo=1'(boost); level=4'(speed);
        tick(5);
        if(active || pipes.bossPipe || pipes.bossOpen || pipes.explosionActive || upcoming)
            $fatal(1,"Restart retained boss/TNT state");
        normalRun=0; seenReady=0; pendingTnt='{0,0,0}; runBosses=bossBirths;
        @(negedge clk); state=1; checking=1; tick(8);
        repeat(2600) begin
            nextFrame();
            for(int j=0;j<3;j++) if(active[j] && types[j*2+:2]==2 &&
                $signed(itemX[j*11+:11])<=300 && $signed(itemX[j*11+:11])>=260) begin
                owner=pickups.itemBoss[j];
                if(opens==0) renderBoss("boss-closed.ppm",owner);
                collectTnt(j);
                if(opens==1) begin
                    renderBoss("boss-open.ppm",owner);
                    // Inspect every burst pixel after the opening settles.
                    count=0;
                    for(int y=0;y<32;y++) for(int x=0;x<32;x++) begin
                        @(negedge clk);
                        pixelX=11'($signed(pipeX[owner*11+:11])+9+x);
                        pixelY=11'(int'(heights[owner*6+:6])*8+y);
                        tick();
                        if(pipeDR) $fatal(1,"Explosion is in the damaging pipe mask");
                        if(visualDR) count++;
                    end
                    if(count==0) $fatal(1,"Explosion artwork did not draw");
                    pauseCheck();
                    for(int age=1;age<=22;age++) begin
                        nextFrame();
                        if(age<22 && !pipes.explosionActive[owner]) $fatal(1,"Explosion ended early");
                        if(age<22 && pipes.explosionFrames[owner*2+:2]!==2'(age*4/22))
                            $fatal(1,"Explosion did not advance through all four frames");
                    end
                    if(pipes.explosionActive[owner] || !pipes.bossOpen[owner])
                        $fatal(1,"Explosion did not finish at 22 frames or gap closed again");
                end
            end
        end
        if(bossBirths==runBosses) $fatal(1,"No bosses exercised at speed %0d turbo %0d",speed,boost);
        pauseCheck();
    end
    @(negedge clk); state=0; checking=0; tick(3);
    if(active || pipes.bossPipe || pipes.bossOpen || pipes.explosionActive) $fatal(1,"Final restart failed");
    if(ownersSeen!=3'b111 || opens<22) $fatal(1,"Insufficient owner/speed coverage: %b, %0d",ownersSeen,opens);
    $display("PASS: %0d pipe births, %0d bosses, %0d midpoint TNT spawns, %0d openings, %0d movement checks; all 11 speeds with/without turbo, geometry, ghost, pause and restart.",births,bossBirths,tntBirths,opens,movementChecks);
    passed=1;
    $finish;
end
endmodule
