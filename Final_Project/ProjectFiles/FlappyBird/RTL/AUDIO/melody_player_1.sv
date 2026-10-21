// (c) Technion IIT, The Faculty of Electrical and Computer Engineering, 2025
// ROM-based melody player. A new game event restarts playback with its sound.
module melody_player_1 (
    input  logic       resetN,
    input  logic       CLOCK_31p5,
    input  logic       startMelody,
    input  logic [3:0] melodySelect,
    output logic [3:0] tone,
    output logic [2:0] octave,
    output logic       EnableSoundOut,
    output logic       melodyEnded
);

enum logic [2:0] {s_idle, s_fetch, s_load, s_playNote, s_gap, s_ended} SM_Maestro;

logic [3:0] selectedMelody;
logic [7:0] noteIndex;
logic [11:0] note_address;
logic [15:0] songs_mem;
logic [4:0] noteTimeCounter;
logic [4:0] noteDuration;
logic [4:0] gapDuration;
logic hundredthSecPulse; // Existing counter output; configured here for 30 ms.

lpm_rom #(
    .lpm_width(16),
    .lpm_widthad(12),
    .lpm_numwords(4096),
    .lpm_file("RTL/AUDIO/songs.mif"),
    .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),
    .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) rom_inst (
    .address(note_address),
    .inclock(CLOCK_31p5),
    .outclock(),
    .memenab(1'b1),
    .q(songs_mem)
);

Mili_sec_counter #(
    .SIMULATION_MODE(1'b0), .mSecPerTick(30), .PLLClock(315)
) mili_sec_counter_inst (
    .clk(CLOCK_31p5),
    .resetN(resetN),
    .turbo(1'b0),
    .hundredth_sec(hundredthSecPulse)
);

always_ff @(posedge CLOCK_31p5 or negedge resetN) begin
    if (!resetN) begin
        SM_Maestro <= s_idle;
        selectedMelody <= 4'd0;
        noteIndex <= 8'd0;
        noteTimeCounter <= 5'd0;
        EnableSoundOut <= 1'b0;
        melodyEnded <= 1'b0;
    end else if (startMelody) begin
        // Accept events even while another sound is playing. Latch the choice
        // so changing selector inputs cannot switch ROM pages midway through a note.
        selectedMelody <= melodySelect;
        noteIndex <= 8'd0;
        noteTimeCounter <= 5'd0;
        EnableSoundOut <= 1'b0;
        melodyEnded <= 1'b0;
        SM_Maestro <= s_fetch;
    end else begin
        EnableSoundOut <= 1'b0;
        melodyEnded <= 1'b0;
        case (SM_Maestro)
            s_idle: begin
                noteIndex <= 8'd0;
            end
            s_fetch: begin
                // The new selectedMelody/noteIndex enter the registered ROM
                // address on this edge. Read that word in s_load next clock.
                SM_Maestro <= s_load;
            end
            s_load: begin
                noteTimeCounter <= noteDuration;
                SM_Maestro <= (noteDuration == 0) ? s_ended : s_playNote;
            end
            s_playNote: begin
                // ToneDecoder contains notes 0..11. Higher codes are silent.
                EnableSoundOut <= tone < 4'd12;
                if (noteTimeCounter == 0) begin
                    noteIndex <= noteIndex + 1'b1;
                    noteTimeCounter <= gapDuration;
                    SM_Maestro <= s_gap;
                end else if (hundredthSecPulse) begin
                    noteTimeCounter <= noteTimeCounter - 1'b1;
                end
            end
            s_gap: begin
                if (noteTimeCounter == 0) begin
                    // s_load also waits for the next ROM word when the gap is
                    // zero; its duration must not come from the previous note.
                    SM_Maestro <= s_load;
                end else if (hundredthSecPulse) begin
                    noteTimeCounter <= noteTimeCounter - 1'b1;
                end
            end
            s_ended: begin
                melodyEnded <= 1'b1;
                SM_Maestro <= s_idle;
            end
            default: SM_Maestro <= s_idle;
        endcase
    end
end

assign note_address = {selectedMelody, noteIndex};
assign tone = songs_mem[15:12];
assign octave = {1'b0, songs_mem[11:10]} + 3'd3;
assign noteDuration = songs_mem[9:5];
assign gapDuration = songs_mem[4:0];
endmodule
