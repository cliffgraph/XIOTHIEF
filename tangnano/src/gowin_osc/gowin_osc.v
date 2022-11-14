//Copyright (C)2014-2022 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//GOWIN Version: V1.9.8.08
//Part Number: GW1N-LV1QN48C6/I5
//Device: GW1N-1
//Created Time: Mon Oct 10 00:12:58 2022

module Gowin_OSC (oscout);
    output wire oscout;
    OSCH osc_inst (
        .OSCOUT(oscout)
    );
    defparam osc_inst.FREQ_DIV = 6;   // 240Mhz /  6 => OSC. 40MHz 
endmodule //Gowin_OSC
