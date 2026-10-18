// SPDX-License-Identifier: MIT

package UartTx;

import FIFOF :: *;
import GetPut :: *;

import BaudGen :: *;

interface UartTx#(numeric type n);
    (* always_ready, result="uart_tx" *) method Bit#(1) tx();
    method Bool busy();
    interface Put#(Bit#(n)) transmit;
endinterface

typedef enum { S_IDLE, S_START, S_DATA, S_STOP } TXState_t deriving(Eq, FShow, Bits);

module mkUartTx#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer buffer_depth)(UartTx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    if(buffer_depth < 0)
        error("UART TX buffer depth must be nonnegative");

    Reg#(TXState_t) rg_state    <- mkReg(S_IDLE);
    Reg#(Bit#(n1))  rg_bits     <- mkRegU;
    Reg#(Bit#(2))   rg_stops    <- mkRegU;
    Reg#(Bit#(2))   rg_stop_cfg <- mkReg(1);
    Reg#(Bit#(n))   rg_data     <- mkRegU;

    Reg#(Bit#(1))   rg_tx <- mkReg(1);

    BaudGen#(16)    i_baud_gen <- mkBaudGen(False);
    RWire#(Bit#(n)) rw_start <- mkRWire;

    Bool top = i_baud_gen.top();
    Bool queued;
    Put#(Bit#(n)) transmit_ifc;

    if(buffer_depth > 0) begin
        FIFOF#(Bit#(n)) f_in <- mkSizedFIFOF(buffer_depth);

        rule r_load_word (rg_state == S_IDLE);
            rw_start.wset(f_in.first);
            f_in.deq;
        endrule

        transmit_ifc = toPut(f_in);
        queued = f_in.notEmpty;
    end else begin
        transmit_ifc = interface Put;
            method Action put(Bit#(n) data) if(rg_state == S_IDLE);
                rw_start.wset(data);
            endmethod
        endinterface;
        queued = False;
    end

    rule r_idle (rg_state == S_IDLE);
        rg_stops    <= 0;
        rg_bits     <= 0;
        if(rw_start.wget matches tagged Valid .data) begin
            rg_data     <= data;
            rg_state    <= S_START;
            rg_tx       <= 0;
            rg_stop_cfg <= stop_bits;
            i_baud_gen.set_prescaler(prescaler);
        end else begin
            rg_tx       <= 1;
            i_baud_gen.hold();
        end
    endrule

    rule r_start (rg_state == S_START);
        if(top) begin
            rg_state    <= S_DATA;
            rg_tx       <= rg_data[rg_bits];
        end else begin
            rg_tx <= 0;
        end
    endrule

    rule r_data (rg_state == S_DATA);
        if(top) begin
            if(rg_bits == fromInteger(valueof(n)-1)) begin
                rg_state <= S_STOP;
                rg_tx    <= 1;
            end else begin
                rg_bits <= rg_bits + 1;
                rg_tx   <= rg_data[rg_bits + 1];
            end
        end else begin
            rg_tx <= rg_data[rg_bits];
        end
    endrule

    rule r_stop (rg_state == S_STOP);
        rg_tx <= 1;
        if(top) begin
            if(rg_stops == rg_stop_cfg-1) begin
                rg_state <= S_IDLE;
            end else begin
                rg_stops <= rg_stops + 1;
            end
        end
    endrule

    method tx = rg_tx;
    method busy = rg_state != S_IDLE || queued;

    interface transmit = transmit_ifc;
endmodule

endpackage
