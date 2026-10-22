onerror {quit -code 1}
set root [pwd]
set project [file join $root ProjectFiles FlappyBird]
set build [file join $root work boss-modelsim]
file mkdir $build
cd $build
if {![file exists work]} {vlib work}
vmap work [file join $build work]
set map {C:/intelFPGA_lite/17.0/quartus/bin64/quartus_map.exe}
cd $project
exec $map Lab1Demo --read_settings_files=on --write_settings_files=off --convert_bdf_to_verilog=RTL/VGA/Pipe_Object.bdf
file rename -force [file join $project RTL VGA Pipe_Object.v] [file join $build Pipe_Object.v]
cd $build
file mkdir RTL
foreach name {pipeLong pipeEdge explosion} {
    file copy -force [file join $project RTL $name.mif] [file join $build RTL $name.mif]
    set source [open [file join $project RTL $name.mif] r]
    set hex [open [file join $build $name.ver] w]
    while {[gets $source line]>=0} {
        if {[regexp {^([0-9A-Fa-f]+): ([0-9A-Fa-f]+);} $line unused address value]} {puts $hex "@$address\n$value"}
    }
    close $source
    close $hex
}
vlog [file join $build Pipe_Object.v]
foreach name {MyConstant pipe_square_object pipeLongBitMap pipeEdgeBitMap pipe_coordinate_calc pipe_color_mux pipe_move boss_control explosion_draw PipeBlocks pickup_control game_controller player_lives} {
    vlog -sv [file join $project RTL VGA $name.sv]
}
# Quartus accepts the legacy RNG's parameters after its ANSI port list;
# ModelSim 10.5 requires them before the port widths. Keep the RNG logic intact.
set source [open [file join $project RTL KEYBOARDX random.sv] r]
set rng [read $source]
close $source
regsub {(?s)parameter SIZE_BITS = 8;.*?MAX_VAL = 255;} $rng {} rng
regsub {module random} $rng {module random #(parameter SIZE_BITS=8, parameter [SIZE_BITS-1:0] MIN_VAL=0, MAX_VAL=255)} rng
set source [open random.sv w]
puts $source $rng
close $source
vlog -sv random.sv [file join $project tests boss_tnt_tb.sv]
vsim -L lpm_ver -suppress 3017 -suppress 3722 -t 1ps work.boss_tnt_tb
onfinish stop
run 20 ms
if {[examine -radix unsigned /boss_tnt_tb/passed]!=1} {error "Boss/TNT test did not finish"}
quit -code 0
