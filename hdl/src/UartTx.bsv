// SPDX-License-Identifier: MIT

package UartTx;

import FIFOF :: *;
import GetPut :: *;

import BaudGen :: *;

interface UartTx#(numeric type n);
    (*always_ready*)
    (*result="uart_tx"*) method Bit#(1) tx();
    method Bool busy();
    interface Put#(Bit#(n)) transmit;
endinterface

typedef enum { Idle, Start, Data, Stop } TXState_t deriving(Eq, FShow, Bits);

module mkUartTxBuffered#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer buffer_depth)(UartTx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    FIFOF#(Bit#(n)) f_in <- mkSizedFIFOF(buffer_depth);

    Reg#(TXState_t) rg_state    <- mkReg(Idle);
    Reg#(Bit#(n1))  rg_bits     <- mkRegU;
    Reg#(Bit#(2))   rg_stops    <- mkRegU;
    Reg#(Bit#(2))   rg_stop_cfg <- mkReg(1);

    Reg#(Bit#(1))   rg_tx <- mkReg(1);

    BaudGen#(16)    baud_gen <- mkBaudGen(False);

    Bool top = baud_gen.top();

    rule ridle if(rg_state == Idle);
        rg_stops    <= 0;
        rg_bits     <= 0;
        if(f_in.notEmpty) begin
            rg_state    <= Start;
            rg_tx       <= 0;
            rg_stop_cfg <= stop_bits;
            baud_gen.set_prescaler(prescaler);
        end else begin
            rg_tx       <= 1;
            baud_gen.hold();
        end
    endrule

    rule rstart if(rg_state == Start);
        if(top) begin
            rg_state    <= Data;
            rg_tx       <= f_in.first[rg_bits];
        end else begin
            rg_tx <= 0;
        end
    endrule

    rule rdata if(rg_state == Data);
        if(top) begin
            if(rg_bits == fromInteger(valueof(n)-1)) begin
                rg_state <= Stop;
                rg_tx    <= 1;
            end else begin
                rg_bits <= rg_bits + 1;
                rg_tx   <= f_in.first[rg_bits + 1];
            end
        end else begin
            rg_tx <= f_in.first[rg_bits];
        end
    endrule

    rule rstop if(rg_state == Stop);
        rg_tx <= 1;
        if(top) begin
            if(rg_stops == rg_stop_cfg-1) begin
                f_in.deq;
                rg_state <= Idle;
            end else begin
                rg_stops <= rg_stops + 1;
            end
        end
    endrule

    method tx = rg_tx;
    method busy = rg_state != Idle || f_in.notEmpty;

    interface transmit = toPut(f_in);

endmodule

module mkUartTx#(Bit#(2) stop_bits, Bit#(16) prescaler)(UartTx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    let uart <- mkUartTxBuffered(stop_bits, prescaler, 2);
    return uart;
endmodule

endpackage
