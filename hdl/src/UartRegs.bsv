// SPDX-License-Identifier: MIT

package UartRegs;

import FIFOF :: *;
import BlueCSRCore :: *;

interface UartRegs;
    (*always_enabled*) method Action frame_error(Bool err);
    (*always_enabled*) method Action ovflw_error(Bool err);
    (*always_enabled*) method Action tx_busy(Bool busy);
    (*always_enabled*) method Action rx_busy(Bool busy);
    (*always_enabled*) method Action tx_ready(Bool value);
    (*always_enabled*) method Action rx_valid(Bool value);

    interface ReadOnly#(Bool) ctrl_en;
    interface ReadOnly#(Bool) ctrl_s2;

    interface ReadOnly#(Bit#(16)) prescaler;

    method Bool tx_data_valid;
    method Bool tx_data_ready;
    method Bit#(8) tx_data_first;
    method Action tx_data_deq;

    method Bool rx_data_ready;
    method Bool rx_data_valid;
    method Action rx_data_enq(Bit#(8) data);
endinterface

module [BlueCSRCtx_t#(32, 32)] uart_csrs#(Bool fifos)(UartRegs);

    Reg#(Bool)      rg_ctrl_en;
    Reg#(Bool)      rg_ctrl_s2;
    
    Reg#(Bit#(16))  rg_baud_pre;

    Reg#(Bool)      rg_tx_busy;
    Reg#(Bool)      rg_rx_busy;
    Reg#(Bool)      rg_tx_ready;
    Reg#(Bool)      rg_rx_valid;

    Wire#(Bool)     bw_frame_err <- mkBypassWire();
    Wire#(Bool)     bw_ovflw_err <- mkBypassWire();

    FIFOF#(Bit#(8)) f_tx_data <- mkSizedFIFOF(16);
    FIFOF#(Bit#(8)) f_rx_data <- mkSizedFIFOF(16);

    csr_regmap_def("BlueUART", "BlueUART register map");

    csr_reg_def('h00, "MIV", "Module ID and Version Register");
    csr_reg_rc('h00, Bit#(8)'('hD),   0, "MID", "Module ID",       "Unique ID for this module.");
    csr_reg_rc('h00, Bit#(8)'('h1),  16, "VRS", "Module Version",  "Module version.");

    csr_reg_def('h04, "CTRL", "UART control register");
    rg_ctrl_en  <- csr_reg_rw('h04, False,  0, "CTRLEN",    "Control Enable",       "Controls whether module is enabled or not.");
    rg_ctrl_s2  <- csr_reg_rw('h04, False,  1, "STOP2",     "Control Stop Bits",    "Controls whether to expect 1 or 2 stop bits.");

    csr_reg_def('h08, "BAUD", "UART prescaler register");
    rg_baud_pre <- csr_reg_rw('h08,     0,  0, "BAUD",      "Baud Prescaler",       "Clock cycles per UART bit. Zero is treated as one.");

    csr_reg_def('h0C, "STATUS", "Module status register");
    csr_reg_w1c('h0C, False, 0, bw_frame_err ? tagged Valid True : tagged Invalid, "FRERR", "RX Frame Error", "Last reception had malformed frame.");
    csr_reg_w1c('h0C, False, 1, bw_ovflw_err ? tagged Valid True : tagged Invalid, "OVFLW", "RX Overflow", "Last reception could not be stored in buffer.");
    rg_tx_busy  <- csr_reg_ro('h0C, False, 8,       "TXBUSY",   "TX Busy",          "Transmitter has queued or active data.");
    rg_rx_busy  <- csr_reg_ro('h0C, False, 9,       "RXBUSY",   "RX Busy",          "Receiver is processing a frame.");
    rg_tx_ready <- csr_reg_ro('h0C, False, 10,      "TXREADY",  "TX Ready",         "TXDATA can accept a byte.");
    rg_rx_valid <- csr_reg_ro('h0C, False, 11,      "RXVALID",  "RX Valid",         "RXDATA contains a byte.");

    if(fifos) begin
        csr_reg_def('h10, "TXDATA", "Transmit data register");
        csr_reg_fifo_wo('h10, f_tx_data, "DATA", "TX Data", "Queues one byte for transmission.");

        csr_reg_def('h14, "RXDATA", "Receive data register");
        csr_reg_fifo_ro('h14, f_rx_data, "DATA", "RX Data", "Dequeues one received byte.");
    end

    method frame_error  = bw_frame_err._write;
    method ovflw_error  = bw_ovflw_err._write;
    method tx_busy      = rg_tx_busy._write;
    method rx_busy      = rg_rx_busy._write;
    method tx_ready     = rg_tx_ready._write;
    method rx_valid     = rg_rx_valid._write;

    interface ctrl_en   = regToReadOnly(rg_ctrl_en);
    interface ctrl_s2   = regToReadOnly(rg_ctrl_s2);

    interface prescaler = regToReadOnly(rg_baud_pre);

    method tx_data_valid    = f_tx_data.notEmpty;
    method tx_data_ready    = f_tx_data.notFull;
    method tx_data_first    = f_tx_data.first;
    method tx_data_deq      = f_tx_data.deq;

    method rx_data_ready    = f_rx_data.notFull;
    method rx_data_valid    = f_rx_data.notEmpty;
    method rx_data_enq      = f_rx_data.enq;

endmodule

endpackage
