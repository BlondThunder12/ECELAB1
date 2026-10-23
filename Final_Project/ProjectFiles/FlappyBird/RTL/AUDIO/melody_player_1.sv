// Existing ROM note player, with event-relative timing and envelope metadata.
module melody_player_1 #(
    parameter int CLK_FREQ=31_500_000
)(
    input logic resetN, CLOCK_31p5, startMelody,
    input logic [3:0] melodySelect,
    input logic [1:0] game_state,
    output logic [3:0] tone,
    output logic [2:0] octave,
    output logic EnableSoundOut, melodyEnded, melodyBusy,
    output logic sampleTick, effectStart, noteStart,
    output logic [3:0] activeMelody,
    output logic [7:0] noteVelocity,
    output logic [15:0] noteAge, noteSamples
);
import game_sfx_data::*;
enum logic [2:0] {s_idle,s_fetch,s_load,s_playNote,s_gap,s_ended} SM_Maestro;
logic [3:0] selectedMelody;
logic [7:0] noteIndex;
logic [23:0] songs_mem;
logic [15:0] gapSamples, gapRemaining;
function automatic int rate_gcd(input int a,input int b);
    int remainder;
    begin
        while(b!=0) begin remainder=a%b; a=b; b=remainder; end
        rate_gcd=a;
    end
endfunction
localparam int RATE_DIVISOR=rate_gcd(CLK_FREQ,SFX_SAMPLE_RATE);
localparam int SAMPLE_INCREMENT=SFX_SAMPLE_RATE/RATE_DIVISOR;
localparam int SAMPLE_THRESHOLD=CLK_FREQ/RATE_DIVISOR;
localparam int ACC_BITS=$clog2(SAMPLE_THRESHOLD+SAMPLE_INCREMENT+1);
logic [ACC_BITS-1:0] sample_accumulator;
assign melodyBusy=SM_Maestro!=s_idle && SM_Maestro!=s_ended;
assign EnableSoundOut=SM_Maestro==s_playNote && tone<4'd12;
assign activeMelody=selectedMelody;
lpm_rom #(
    .lpm_width(24),.lpm_widthad(12),.lpm_numwords(4096),
    .lpm_file("RTL/AUDIO/songs.mif"),.lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"),.lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) rom_inst (
    .address({selectedMelody,noteIndex}),.inclock(CLOCK_31p5),
    .outclock(),.memenab(1'b1),.q(songs_mem)
);

// Start the sample phase at the triggering event, instead of inheriting the
// arbitrary first interval of the former free-running 30 ms note timer.
always_ff @(posedge CLOCK_31p5 or negedge resetN) begin
    if(!resetN) begin sample_accumulator<='0; sampleTick<=1'b0; end
    else begin
        sampleTick<=1'b0;
        if(startMelody || game_state==2'b00) sample_accumulator<='0;
        else if(sample_accumulator+ACC_BITS'(SAMPLE_INCREMENT)>=ACC_BITS'(SAMPLE_THRESHOLD)) begin
            sample_accumulator<=sample_accumulator+ACC_BITS'(SAMPLE_INCREMENT)-ACC_BITS'(SAMPLE_THRESHOLD);
            sampleTick<=1'b1;
        end else sample_accumulator<=sample_accumulator+ACC_BITS'(SAMPLE_INCREMENT);
    end
end

always_ff @(posedge CLOCK_31p5 or negedge resetN) begin
    if(!resetN) begin
        SM_Maestro<=s_idle;
        selectedMelody<=SFX_SCORE;
        noteIndex<='0; noteAge<='0; noteSamples<='0; noteVelocity<='0;
        gapSamples<='0; gapRemaining<='0; tone<='0; octave<=3'd3;
        melodyEnded<=1'b0; effectStart<=1'b0; noteStart<=1'b0;
    end else begin
        melodyEnded<=1'b0; effectStart<=1'b0; noteStart<=1'b0;
        if(game_state==2'b00) begin SM_Maestro<=s_idle; noteAge<='0; end
        else if(startMelody) begin
            selectedMelody<=melodySelect;
            noteIndex<='0; noteAge<='0;
            effectStart<=1'b1;
            SM_Maestro<=s_fetch;
        end else begin
            case(SM_Maestro)
                s_idle: noteIndex<='0;
                s_fetch: SM_Maestro<=s_load;
                s_load: begin
                    if(songs_mem[9:5]==0) SM_Maestro<=s_ended;
                    else begin
                        tone<=songs_mem[15:12];
                        octave<=(selectedMelody==SFX_TNT) ? {1'b0,songs_mem[11:10]} : {1'b0,songs_mem[11:10]}+3'd3;
                        noteVelocity<=songs_mem[23:16];
                        noteSamples<=16'(int'(songs_mem[9:5])*SFX_SAMPLES_PER_TICK);
                        gapSamples<=16'(int'(songs_mem[4:0])*SFX_SAMPLES_PER_TICK);
                        noteAge<='0; noteStart<=1'b1; SM_Maestro<=s_playNote;
                    end
                end
                s_playNote: if(sampleTick) begin
                    if({1'b0,noteAge}+17'd1>={1'b0,noteSamples}) begin
                        if(gapSamples==0) begin noteIndex<=noteIndex+1'b1; SM_Maestro<=s_fetch; end
                        else begin gapRemaining<=gapSamples; SM_Maestro<=s_gap; end
                    end else noteAge<=noteAge+1'b1;
                end
                s_gap: if(sampleTick) begin
                    if(gapRemaining<=1) begin noteIndex<=noteIndex+1'b1; SM_Maestro<=s_fetch; end
                    else gapRemaining<=gapRemaining-1'b1;
                end
                s_ended: begin melodyEnded<=1'b1; SM_Maestro<=s_idle; end
                default: SM_Maestro<=s_idle;
            endcase
        end
    end
end
endmodule
