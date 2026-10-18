// SPDX-License-Identifier: MIT

package TestBaudGen;

import StmtFSM :: *;
import TestHelper :: *;
import BaudGen :: *;

(* synthesize *)
module mkTestBaudGen(TestHandler);
    BaudGen#(16) i_late  <- mkBaudGen(False);
    BaudGen#(16) i_early <- mkBaudGen(True);

    function Action check(Bool top, Bool late_mid, Bool early_mid);
        return action
            if(i_late.top != top || i_early.top != top ||
                    i_late.middle != late_mid || i_early.middle != early_mid) begin
                $display("ERROR TestBaudGen: expected top/middle %0d/%0d/%0d, got %0d/%0d/%0d",
                    top, late_mid, early_mid, i_late.top, i_late.middle, i_early.middle);
                $finish(1);
            end
        endaction;
    endfunction

    function Action load(Bit#(16) prescaler);
        return action
            i_late.set_prescaler(prescaler);
            i_early.set_prescaler(prescaler);
        endaction;
    endfunction

    Stmt s = seq
        load(3);
        check(False, False, False); // count 0
        check(False, True,  True);  // count 1
        check(True,  False, False); // count 2
        check(False, False, False); // wrapped
        action
            check(False, True, True);
            i_late.hold;
            i_early.hold;
        endaction
        check(False, True, True); // held at count 1
        action
            check(True, False, False); // outputs still describe the old period
            load(5);
        endaction
        check(False, False, False);
        check(False, False, False);
        check(False, True,  True);
        check(False, False, False);
        check(True,  False, False);
        load(0);
        check(True, True, True);
        check(True, True, True);
        load(1);
        check(True, True, True);
        load(2);
        check(False, False, True);
        check(True,  True,  False);
        check(False, False, True);
        load(4);
        check(False, False, False);
        check(False, False, True);
        check(False, True,  False);
        check(True,  False, False);
        $display("All tests finished successfully");
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

endpackage
