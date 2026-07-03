// SPDX-License-Identifier: MIT

package TestBaudGen;

import StmtFSM :: *;
import TestHelper :: *;

import BaudGen :: *;

(* synthesize *)
module [Module] mkTestBaudGen(TestHelper::TestHandler);

    BaudGen#(16)    dut <- mkBaudGen(False);
    Wire#(Bool)     m   <- mkWire;
    Wire#(Bool)     t   <- mkWire;

    rule con;
        m <= dut.middle();
        t <= dut.top();
    endrule

    Stmt s = seq
        $display("yo");
        dut.set_prescaler(3);
        delay(20);
        dut.set_prescaler(1);
        delay(20);
        dut.set_prescaler(4);
        delay(20);
        dut.set_prescaler(5);
        delay(20);
        dut.set_prescaler(2);
        delay(20);
    endseq;

    FSM testFSM <- mkFSM(s);

    method Action go();
        testFSM.start();
    endmethod

    method Bool done();
        return testFSM.done();
    endmethod

endmodule

endpackage
