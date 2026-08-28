# 100 MHz system clock on the Basys 3 W5 oscillator
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]
