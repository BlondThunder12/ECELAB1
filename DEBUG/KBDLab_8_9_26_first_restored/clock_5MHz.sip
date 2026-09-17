set_global_assignment -entity "clock_5MHz" -library "lib_clock_5MHz" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "clock_5MHz" -library "lib_clock_5MHz" -name IP_TOOL_VERSION "17.0"
set_global_assignment -entity "clock_5MHz" -library "lib_clock_5MHz" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_clock_5MHz" -name SPD_FILE [file join $::quartus(sip_path) "clock_5MHz.spd"]

set_global_assignment -library "lib_clock_5MHz" -name MISC_FILE [file join $::quartus(sip_path) "clock_5MHz_sim/clock_5MHz.vo"]
