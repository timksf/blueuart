// SPDX-License-Identifier: MIT

package UartRx;

import FIFOF :: *;
import GetPut :: *;

import BaudGen :: *;

interface UartRx#(numeric type n);
    (*always_enabled*) (*prefix="uart"*) 
    method Action rx(Bit#(1) rx);

    method Bool frame_error;
    method Bool ovflw_error;
    method Bool busy;
    method Bool data_valid;

    interface Get#(Bit#(n)) receive;
endinterface

typedef enum { Idle, Start, Data, Stop } RXState_t deriving(Eq, FShow, Bits);

module mkUartRxBuffered#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer buffer_depth)(UartRx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    FIFOF#(Bit#(n)) f_out <- mkSizedFIFOF(buffer_depth);

    Reg#(RXState_t) rg_state    <- mkReg(Idle);
    Reg#(Bit#(n))   rg_data     <- mkRegU;
    Reg#(Bit#(n1))  rg_bits     <- mkRegU;
    Reg#(Bit#(2))   rg_stops    <- mkRegU;
    Reg#(Bit#(2))   rg_stop_cfg <- mkReg(1);

    Reg#(Bit#(1))   rg_rx_meta  <- mkReg(1);
    Reg#(Bit#(1))   rg_rx       <- mkReg(1);

    Wire#(Bool)     bw_ovflw    <- mkDWire(False);
    Wire#(Bool)     bw_frerr    <- mkDWire(False);

    BaudGen#(16)    baud_gen   <- mkBaudGen(False);

    Bool sample = baud_gen.middle();
    Bool final_stop = rg_stops == rg_stop_cfg-1;

    rule rsynchronize;
        rg_rx <= rg_rx_meta;
    endrule

    rule ridle if(rg_state == Idle);
        //detect start bit
        rg_stops    <= 0;
        rg_bits     <= 0;
        rg_data     <= 0;
        if(rg_rx == 0) begin
            rg_state <= Start;
            rg_stop_cfg <= stop_bits;
            baud_gen.set_prescaler(prescaler);
        end else begin
            baud_gen.hold();
        end
    endrule

    rule rstart if(rg_state == Start && sample);
        if(rg_rx == 0) begin
            rg_state <= Data;
        end else begin
            //faulty start bit
            rg_state <= Idle;
        end
    endrule

    rule rdata if(rg_state == Data && sample);
        rg_data <= {rg_rx, rg_data[valueof(n)-1:1]};
        rg_bits <= rg_bits + 1;
        if(rg_bits == fromInteger(valueof(n)-1)) begin
            rg_state <= Stop;
        end
    endrule

    rule rstop_next if(rg_state == Stop && sample && rg_rx == 1 && !final_stop);
        rg_stops <= rg_stops + 1;
    endrule

    rule rstop_commit if(rg_state == Stop && sample && rg_rx == 1 && final_stop && f_out.notFull);
        f_out.enq(rg_data);
        rg_state <= Idle;
    endrule

    rule rstop_overflow if(rg_state == Stop && sample && rg_rx == 1 && final_stop && !f_out.notFull);
        bw_ovflw <= True;
        rg_state <= Idle;
    endrule

    rule rstop_error if(rg_state == Stop && sample && rg_rx == 0);
        bw_frerr <= True;
        rg_state <= Idle;
    endrule

    method ovflw_error  = bw_ovflw;
    method frame_error  = bw_frerr;
    method busy         = rg_state != Idle;
    method data_valid   = f_out.notEmpty;
    method rx           = rg_rx_meta._write;

    interface receive = toGet(f_out);

endmodule

module mkUartRx#(Bit#(2) stop_bits, Bit#(16) prescaler)(UartRx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    let uart <- mkUartRxBuffered(stop_bits, prescaler, 2);
    return uart;
endmodule

endpackage
