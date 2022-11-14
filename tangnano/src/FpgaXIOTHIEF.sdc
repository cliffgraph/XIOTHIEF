//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.08 
//Created Time: 2022-10-12 23:08:03
create_clock -name msx_clock -period 279.408 -waveform {0 139.704} [get_ports {msx_clock}]
create_clock -name sysclk -period 25 -waveform {0 12.5} [get_pins {u_osc/osc_inst/OSCOUT}]
