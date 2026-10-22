// Lives and damage cooldown for the existing 31.5 MHz game clock.
module player_lives #(
    parameter int INVULNERABLE_CLOCKS = 31500000,
    parameter int GHOST_CLOCKS = 3 * 31500000 // Three seconds at the existing game clock
)(
    input  logic       clk,
    input  logic       resetN,
    input  logic [1:0] game_state,
    input  logic       godmode,
    input  logic       collision,
    input  logic       heartCollected,
    input  logic       ghostCollected,
    output logic [1:0] lives,
    output logic       damage_pulse,
    output logic       invulnerable,
    output logic       birdVisible,
    output logic       ghost_active
);

localparam logic [1:0] START_SCREEN = 2'b00;
localparam logic [1:0] PLAYING = 2'b01;
localparam int MAX_PROTECTION_CLOCKS = (GHOST_CLOCKS > INVULNERABLE_CLOCKS) ?
                                      GHOST_CLOCKS : INVULNERABLE_CLOCKS;
// $clog2 is the base-2 logarithm rounded up, evaluated at compile time.
// It sizes the timer automatically when durations change. The +1 includes
// every count from zero through MAX_PROTECTION_CLOCKS; keep at least one bit.
localparam int TIMER_BITS = (MAX_PROTECTION_CLOCKS < 2) ? 1 : $clog2(MAX_PROTECTION_CLOCKS + 1);
// Preserve the original damage blink rate when widening the shared timer.
localparam int DAMAGE_TIMER_BITS = (INVULNERABLE_CLOCKS < 2) ? 1 : $clog2(INVULNERABLE_CLOCKS + 1);
localparam int BLINK_BIT = (DAMAGE_TIMER_BITS > 3) ? DAMAGE_TIMER_BITS - 3 : 0;
logic [TIMER_BITS-1:0] invulnerability_timer;

assign invulnerable = (invulnerability_timer != 0);
// Blink only the rendered bird. Collision detection continues using its full mask.
assign birdVisible = (game_state == 2'b10) || ghost_active || !invulnerable || godmode ||
                     !invulnerability_timer[BLINK_BIT];

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        lives <= 2'd3;
        damage_pulse <= 1'b0;
        invulnerability_timer <= '0;
        ghost_active <= 1'b0;
    end else begin
        damage_pulse <= 1'b0;
        if (game_state == START_SCREEN) begin
            lives <= 2'd3;
            invulnerability_timer <= '0;
            ghost_active <= 1'b0;
        end else if (game_state == PLAYING) begin
            if (invulnerable) begin
                invulnerability_timer <= invulnerability_timer - 1'b1;
                if (invulnerability_timer == 1)
                    ghost_active <= 1'b0;
            end

            // A damaging hit wins over a simultaneous heart. The last life
            // cannot be rescued by a pickup collected on that same clock.
            if (collision && !godmode && !invulnerable && !ghostCollected && lives != 0) begin
                lives <= lives - 1'b1;
                damage_pulse <= 1'b1;
                invulnerability_timer <= TIMER_BITS'(INVULNERABLE_CLOCKS);
            end else if (heartCollected && lives != 0 && lives < 3) begin
                lives <= lives + 1'b1;
            end
            // Collection wins over a coincident hit/expiry and refreshes to
            // three seconds. This never changes Godmode's high-score flags.
            if (ghostCollected && lives != 0) begin
                invulnerability_timer <= TIMER_BITS'(GHOST_CLOCKS);
                ghost_active <= 1'b1;
            end
        end
        // Pause and game over hold both the lives and cooldown timer.
    end
end
endmodule
