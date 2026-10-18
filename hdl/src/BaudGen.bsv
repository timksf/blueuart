// SPDX-License-Identifier: MIT

package BaudGen;

interface BaudGen#(numeric type w);
    method Bool top();
    method Bool middle();

    method Action hold();
    method Action set_prescaler(Bit#(w) v);
endinterface

//strictly integer division
module mkBaudGen#(Bool mid_early)(BaudGen#(w));

    Reg#(Bit#(w))   rg_top  <- mkReg(0);
    Reg#(Bit#(w))   rg_cnt  <- mkReg(0);
    RWire#(Bit#(w)) rw_load <- mkRWire;
    PulseWire      pw_hold <- mkPulseWire;

    Bit#(w) hlf = rg_top >> 1;
    Bit#(w) mid = (unpack(rg_top[0]) || !mid_early) ? (hlf + 1) : hlf;

    // Timing outputs describe registered state. A load takes effect at the edge,
    // avoiding a configuration-to-status scheduling path through a CReg port.
    rule r_roll;
        if(rw_load.wget matches tagged Valid .prescaler) begin
            rg_top <= prescaler == 0 ? 1 : prescaler;
            rg_cnt <= 0;
        end else if(!pw_hold) begin
            if(rg_cnt == rg_top - 1)
                rg_cnt <= 0;
            else
                rg_cnt <= rg_cnt + 1;
        end
    endrule

    method top    = rg_top == 0 || rg_cnt == rg_top - 1;
    method middle = mid == 0 || rg_cnt == mid - 1;

    method Action hold;
        pw_hold.send;
    endmethod

    method Action set_prescaler(Bit#(w) p);
        rw_load.wset(p);
    endmethod

endmodule

endpackage
