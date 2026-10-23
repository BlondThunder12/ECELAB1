// Gain/envelopes around the existing sine-table oscillator. TNT adds a small
// synthesized noise burst; no recorded samples or WAV data are stored.
module game_sfx_voice (
    input logic clk, resetN, sampleTick, melodyBusy, EnableSoundOut,
    input logic effectStart, noteStart,
    input logic [3:0] activeMelody,
    input logic [7:0] noteVelocity,
    input logic [15:0] noteAge, noteSamples,
    input logic signed [15:0] sinVal,
    output logic signed [15:0] audio_out
);
import game_sfx_data::*;
game_sfx_profile_t profile;
logic is_tnt;
logic [15:0] effectAge, effectiveAge, effectiveSamples, remainingSamples;
logic [8:0] attack_address, release_address;
logic [34:0] attack_scaled;
logic [31:0] release_scaled;
logic [15:0] attack_gain, release_gain, body_level, body_delta;
logic [39:0] body_decay_product, noise_decay_product, thump_decay_product;
logic [15:0] noise_envelope, thump_envelope;
logic [15:0] lfsr, next_lfsr;
logic signed [23:0] noise_target, noise_low1, noise_low2, next_low1, next_low2;
logic signed [15:0] noise_sample, shaped_noise, shaped_thump;
logic signed [32:0] noise_product, thump_product;
logic signed [17:0] tnt_wave, raw_wave;
logic [15:0] velocity_gain, body_gain;
logic signed [34:0] gain_product;
logic signed [32:0] velocity_product, body_product, attack_product, release_product;
logic signed [32:0] level_product;
logic signed [20:0] level_sample;

always_comb begin
    profile = game_sfx_profile(activeMelody);
    is_tnt = activeMelody == SFX_TNT;
    effectiveAge = is_tnt ? effectAge : noteAge;
    effectiveSamples = is_tnt ? 16'(SFX_TNT_SAMPLES) : noteSamples;
    remainingSamples = (effectiveAge < effectiveSamples) ? effectiveSamples - effectiveAge - 1'b1 : 16'd0;
    attack_scaled = effectiveAge * profile.attack_step;
    release_scaled = remainingSamples * profile.release_step;
    attack_address = (effectiveAge >= profile.attack_samples) ? 9'd500 : attack_scaled[24:16];
    release_address = (remainingSamples >= profile.release_samples) ? 9'd500 : release_scaled[24:16];
end

// Reuse the existing tiny smooth-step gain curve for attack and release.
// Its registered lookup settles long before the following audio sample tick.
lpm_rom #(
    .lpm_width(16), .lpm_widthad(9), .lpm_numwords(512),
    .lpm_file("RTL/AUDIO/menu_fade.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) attack_curve (
    .address(attack_address), .inclock(clk), .outclock(), .memenab(1'b1), .q(attack_gain)
);
lpm_rom #(
    .lpm_width(16), .lpm_widthad(9), .lpm_numwords(512),
    .lpm_file("RTL/AUDIO/menu_fade.mif"), .lpm_type("LPM_ROM"),
    .lpm_address_control("REGISTERED"), .lpm_outdata("UNREGISTERED"),
    .intended_device_family("Cyclone V")
) release_curve (
    .address(release_address), .inclock(clk), .outclock(), .memenab(1'b1), .q(release_gain)
);

assign body_delta = body_level > profile.sustain ? body_level - profile.sustain : 16'd0;
assign body_decay_product = body_delta * profile.decay;
assign noise_decay_product = noise_envelope * TNT_NOISE_DECAY;
assign thump_decay_product = thump_envelope * TNT_THUMP_DECAY;
assign next_lfsr = {lfsr[0] ^ lfsr[2] ^ lfsr[3] ^ lfsr[5], lfsr[15:1]};
assign noise_target = next_lfsr[0] ? 24'sd4161536 : -24'sd4161536;
assign next_low1 = noise_low1 + ((noise_target - noise_low1) >>> 2);
assign next_low2 = noise_low2 + ((next_low1 - noise_low2) >>> 2);
assign noise_sample = 16'(noise_low2 >>> 8);
assign noise_product = noise_sample * $signed({1'b0, noise_envelope});
assign thump_product = sinVal * $signed({1'b0, thump_envelope});
assign shaped_noise = 16'(noise_product >>> 16);
assign shaped_thump = 16'(thump_product >>> 16);
assign tnt_wave = 18'(($signed(shaped_noise) * 25'sd218 + $signed(shaped_thump) * 25'sd148) >>> 8);
assign raw_wave = is_tnt ? tnt_wave : {{2{sinVal[15]}}, sinVal};
assign velocity_gain = {noteVelocity, 8'b0} + {8'b0, noteVelocity};
assign body_gain = is_tnt ? 16'hFFFF : body_level;
// Apply the calibrated makeup gain after the envelopes. Keep the result wide
// until saturation; narrowing an amplified sine first would wrap its sign.
assign level_sample = 21'(level_product >>> 12);

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        effectAge <= '0;
        body_level <= 16'hFFFF;
        noise_envelope <= 16'hFFFF;
        thump_envelope <= 16'hFFFF;
        lfsr <= 16'hACE1;
        noise_low1 <= '0;
        noise_low2 <= '0;
    end else begin
        if (effectStart) begin
            effectAge <= '0;
            noise_envelope <= 16'hFFFF;
            thump_envelope <= 16'hFFFF;
            lfsr <= 16'hACE1;
            noise_low1 <= '0;
            noise_low2 <= '0;
        end else if (sampleTick && melodyBusy) begin
            if (effectAge != 16'hFFFF) effectAge <= effectAge + 1'b1;
            if (is_tnt) begin
                lfsr <= next_lfsr;
                noise_low1 <= next_low1;
                noise_low2 <= next_low2;
                noise_envelope <= 16'((noise_decay_product + 40'd8388608) >> 24);
                thump_envelope <= 16'((thump_decay_product + 40'd8388608) >> 24);
            end
        end
        if (noteStart) body_level <= 16'hFFFF;
        else if (sampleTick && EnableSoundOut && !is_tnt)
            body_level <= profile.sustain + 16'((body_decay_product + 40'd8388608) >> 24);
    end
end

// Separate signed fixed-point stages retain headroom and avoid sharp sustained
// tones. Silent/gap states explicitly output zero instead of a held sine value.
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        gain_product <= '0;
        velocity_product <= '0;
        body_product <= '0;
        attack_product <= '0;
        release_product <= '0;
        level_product <= '0;
        audio_out <= '0;
    end else begin
        gain_product <= raw_wave * $signed({1'b0, profile.gain});
        velocity_product <= 16'(gain_product >>> 16) * $signed({1'b0, velocity_gain});
        body_product <= 16'(velocity_product >>> 16) * $signed({1'b0, body_gain});
        attack_product <= 16'(body_product >>> 16) * $signed({1'b0, attack_gain});
        release_product <= 16'(attack_product >>> 16) * $signed({1'b0, release_gain});
        level_product <= 16'(release_product >>> 16) * $signed({1'b0, profile.level_gain});
        if (!melodyBusy || (!is_tnt && !EnableSoundOut)) audio_out <= 16'sd0;
        else if (level_sample > 21'sd32767) audio_out <= 16'sh7FFF;
        else if (level_sample < -21'sd32768) audio_out <= 16'sh8000;
        else audio_out <= level_sample[15:0];
    end
end
endmodule
