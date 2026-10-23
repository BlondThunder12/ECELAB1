// Decimal digits for the current speed level (0..10 in game_manager).
module speed_level_digits (
    input  logic [3:0] speed_level,
    output logic [3:0] units,
    output logic [3:0] tens,
    output logic       tens_enable
);
assign tens_enable = speed_level >= 4'd10;
assign units = tens_enable ? speed_level - 4'd10 : speed_level;
assign tens = {3'b000, tens_enable};
endmodule
