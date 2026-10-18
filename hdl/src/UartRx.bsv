// SPDX-License-Identifier: MIT

package UartRx;

import FIFOF :: *;
import GetPut :: *;

import BaudGen :: *;

interface UartRx#(numeric type n);
    (* always_enabled, prefix="uart" *)
    method Action rx(Bit#(1) rx);

    method Bool frame_error;
    method Bool ovflw_error;
    method Bool busy;

    interface Get#(Bit#(n)) receive;
endinterface

typedef enum { S_IDLE, S_START, S_DATA, S_STOP } RXState_t deriving(Eq, FShow, Bits);

module mkUartRx#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer buffer_depth)(UartRx#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    if(buffer_depth < 0)
        error("UART RX buffer depth must be nonnegative");

    Reg#(RXState_t) rg_state    <- mkReg(S_IDLE);
    Reg#(Bit#(n))   rg_data     <- mkRegU;
    Reg#(Bit#(n1))  rg_bits     <- mkRegU;
    Reg#(Bit#(2))   rg_stops    <- mkRegU;
    Reg#(Bit#(2))   rg_stop_cfg <- mkReg(1);

    Reg#(Bit#(1))   rg_rx_meta  <- mkReg(1);
    Reg#(Bit#(1))   rg_rx       <- mkReg(1);

    Wire#(Bool) w_overflow    <- mkDWire(False);
    Wire#(Bool) w_frame_error <- mkDWire(False);
    PulseWire   pw_received   <- mkPulseWire;

    BaudGen#(16) i_baud_gen <- mkBaudGen(False);

    Bool sample = i_baud_gen.middle();
    Bool final_stop = rg_stops == rg_stop_cfg-1;
    Bool word_ready = rg_state == S_STOP && sample && rg_rx == 1 && final_stop;
    Bool frame_start = rg_state == S_START && sample && rg_rx == 0;

    Get#(Bit#(n)) receive_ifc;

    if(buffer_depth > 0) begin
        FIFOF#(Bit#(n)) f_out <- mkSizedFIFOF(buffer_depth);

        rule r_buffer_receive (word_ready);
            f_out.enq(rg_data);
            pw_received.send;
        endrule

        receive_ifc = toGet(f_out);
    end else begin
        Reg#(Bool) rg_pending <- mkReg(False);

        // The assembly register doubles as a mailbox between frames. A confirmed
        // start retires the old word before shifting the new one into that register.
        rule r_pending;
            if(frame_start) begin
                if(rg_pending && !pw_received)
                    w_overflow <= True;
                rg_pending <= False;
            end else if(word_ready) begin
                rg_pending <= !pw_received;
            end else if(pw_received) begin
                rg_pending <= False;
            end
        endrule

        receive_ifc = interface Get;
            method ActionValue#(Bit#(n)) get if(rg_pending || word_ready);
                pw_received.send;
                return rg_data;
            endmethod
        endinterface;
    end

    rule r_synchronize;
        rg_rx <= rg_rx_meta;
    endrule

    rule r_idle (rg_state == S_IDLE);
        // Detect start bit.
        rg_stops    <= 0;
        rg_bits     <= 0;
        if(buffer_depth > 0)
            rg_data <= 0;
        if(rg_rx == 0) begin
            rg_state <= S_START;
            rg_stop_cfg <= stop_bits;
            i_baud_gen.set_prescaler(prescaler);
        end else begin
            i_baud_gen.hold();
        end
    endrule

    rule r_start (rg_state == S_START && sample);
        if(rg_rx == 0) begin
            rg_state <= S_DATA;
        end else begin
            // Reject a false start bit.
            rg_state <= S_IDLE;
        end
    endrule

    rule r_data (rg_state == S_DATA && sample);
        rg_data <= (rg_data >> 1) | (zeroExtend(rg_rx) << (valueOf(n) - 1));
        rg_bits <= rg_bits + 1;
        if(rg_bits == fromInteger(valueof(n)-1)) begin
            rg_state <= S_STOP;
        end
    endrule

    rule r_stop_next (rg_state == S_STOP && sample && rg_rx == 1 && !final_stop);
        rg_stops <= rg_stops + 1;
    endrule

    rule r_stop_commit (word_ready);
        // FIFO overflow drops the arriving word; a zero-depth result is retained.
        if(buffer_depth > 0 && !pw_received)
            w_overflow <= True;
        rg_state <= S_IDLE;
    endrule

    rule r_stop_error (rg_state == S_STOP && sample && rg_rx == 0);
        w_frame_error <= True;
        rg_state <= S_IDLE;
    endrule

    method ovflw_error  = w_overflow;
    method frame_error  = w_frame_error;
    method busy         = rg_state != S_IDLE;
    method rx           = rg_rx_meta._write;

    interface receive = receive_ifc;
endmodule

endpackage
