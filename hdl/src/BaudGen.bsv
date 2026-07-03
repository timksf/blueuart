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

    Reg#(Bit#(w)) rg_top[2] <- mkCReg(2, 0);
    Reg#(Bit#(w)) rg_cnt[2] <- mkCReg(2, 0);

    Wire#(Bool) dw_hold <- mkDWire(False);

    Bit#(w) hlf = rg_top[1] >> 1;
    Bit#(w) mid = (unpack(rg_top[1][0]) || !mid_early) ? (hlf + 1) : hlf;

    rule r_roll if(!dw_hold);
        if(rg_cnt[1] == rg_top[1]-1)
            rg_cnt[1] <= 0;
        else
            rg_cnt[1] <= rg_cnt[1] + 1;
    endrule

    method top      = rg_top[1] == 0    || rg_cnt[1] == rg_top[1]-1;
    method middle   = mid == 0          || rg_cnt[1] == mid-1;

    method hold = action
        dw_hold <= True;
    endaction;

    method set_prescaler(p) = action
        dw_hold     <= True;
        rg_top[0]   <= (p == 0) ? 1 : p;
        rg_cnt[0]   <= 0;
    endaction;

endmodule

endpackage
