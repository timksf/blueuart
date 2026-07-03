// SPDX-License-Identifier: MIT

package STARTUPE2;

import Clocks :: *;

(* always_enabled, always_ready *)
interface STARTUPE2_ifc;
    interface Reset eos;

    method Action gsr(Bit#(1) value);
    method Action gts(Bit#(1) value);
    method Action keyclearb(Bit#(1) value);
    method Action pack(Bit#(1) value);
    method Action usrcclko(Bit#(1) value);
    method Action usrcclkts(Bit#(1) value);
    method Action usrdoneo(Bit#(1) value);
    method Action usrdonets(Bit#(1) value);
endinterface

import "BVI" STARTUPE2 =
module vMkSTARTUPE2#(Clock clk)(STARTUPE2_ifc);

    default_clock no_clock;
    default_reset no_reset;

    input_clock startup_clk(CLK) = clk;

    output_reset eos(EOS) clocked_by(startup_clk);

    method gsr(GSR)                 enable((*inhigh*) EN_GSR)       clocked_by(startup_clk) reset_by(no_reset);
    method gts(GTS)                 enable((*inhigh*) EN_GTS)       clocked_by(startup_clk) reset_by(no_reset);
    method keyclearb(KEYCLEARB)     enable((*inhigh*) EN_KEYCLEARB) clocked_by(startup_clk) reset_by(no_reset);
    method pack(PACK)               enable((*inhigh*) EN_PACK)      clocked_by(startup_clk) reset_by(no_reset);
    method usrcclko(USRCCLKO)       enable((*inhigh*) EN_USRCCLKO)  clocked_by(startup_clk) reset_by(no_reset);
    method usrcclkts(USRCCLKTS)     enable((*inhigh*) EN_USRCCLKTS) clocked_by(startup_clk) reset_by(no_reset);
    method usrdoneo(USRDONEO)       enable((*inhigh*) EN_USRDONEO)  clocked_by(startup_clk) reset_by(no_reset);
    method usrdonets(USRDONETS)     enable((*inhigh*) EN_USRDONETS) clocked_by(startup_clk) reset_by(no_reset);

    schedule (gsr, gts, keyclearb, pack, usrcclko, usrcclkts, usrdoneo, usrdonets) CF
             (gsr, gts, keyclearb, pack, usrcclko, usrcclkts, usrdoneo, usrdonets);

endmodule

module mkSTARTUPE2EOSReset(Reset);
    Clock clk <- exposeCurrentClock;
    let startup <- vMkSTARTUPE2(clk);

    (* fire_when_enabled, no_implicit_conditions *)
    rule rtie_startup_inputs;
        startup.gsr(0);
        startup.gts(0);
        startup.keyclearb(1);
        startup.pack(0);
        startup.usrcclko(0);
        startup.usrcclkts(1);
        startup.usrdoneo(1);
        startup.usrdonets(1);
    endrule

    return startup.eos;
endmodule

endpackage
