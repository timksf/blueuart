// SPDX-License-Identifier: MIT

package UartAxiLiteMaster;

import AXI4_Lite_Master :: *;
import AXI4_Lite_Types :: *;
import UartRx :: *;
import UartTx :: *;
import GetPut :: *;

typedef enum {
    Cmd,
    ReadAddr,
    WriteAddr,
    WriteData,
    WaitReadResp,
    SendReadStatus,
    SendReadData,
    WaitWriteResp,
    SendBadCommand
} UartAxiLiteState deriving(Bits, Eq, FShow);

interface UartAxiLiteMaster#(numeric type addrwidth, numeric type datawidth);
    (* always_enabled *) (* prefix="uart" *)
    method Action rx(Bit#(1) value);
    (* always_ready *) (* result="uart_tx" *)
    method Bit#(1) tx();

    (* prefix="M_AXI_LITE" *) interface AXI4_Lite_Master_Rd_Fab#(addrwidth, datawidth) m_rd;
    (* prefix="M_AXI_LITE" *) interface AXI4_Lite_Master_Wr_Fab#(addrwidth, datawidth) m_wr;
endinterface

function Bit#(valuewidth) put_byte_le(Bit#(valuewidth) value, UInt#(16) index, Bit#(8) octet)
    provisos(Add#(a__, 8, valuewidth));
    Bit#(valuewidth) byte_mask = zeroExtend(8'hff) << (index << 3);
    Bit#(valuewidth) byte_data = zeroExtend(octet) << (index << 3);
    return (value & ~byte_mask) | byte_data;
endfunction

function Bit#(8) get_byte_le(Bit#(valuewidth) value, UInt#(16) index)
    provisos(Add#(a__, 8, valuewidth));
    return truncate(value >> (index << 3));
endfunction

function Bit#(8) response_status(AXI4_Lite_Response response);
    return response == OKAY ? 8'h00 : 8'h01;
endfunction

module mkUartAxiLiteMasterBuffered#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer rd_buffer, Integer wr_buffer, Integer rx_buffer, Integer tx_buffer)(UartAxiLiteMaster#(addrwidth, datawidth))
    provisos(
        Add#(a__, 1, addrwidth),
        Add#(b__, 1, datawidth),
        Add#(c__, 8, addrwidth),
        Add#(d__, 8, datawidth),
        Div#(addrwidth, 8, addrbytes),
        Div#(datawidth, 8, databytes),
        Log#(8, uart_log),
        Add#(uart_log, 1, uart_log1)
    );

    UartRx#(8) uart_rx <- mkUartRxBuffered(stop_bits, prescaler, rx_buffer);
    UartTx#(8) uart_tx <- mkUartTxBuffered(stop_bits, prescaler, tx_buffer);

    AXI4_Lite_Master_Rd#(addrwidth, datawidth) m_rd_inst <- mkAXI4_Lite_Master_Rd(rd_buffer);
    AXI4_Lite_Master_Wr#(addrwidth, datawidth) m_wr_inst <- mkAXI4_Lite_Master_Wr(wr_buffer);

    Reg#(UartAxiLiteState) rg_state <- mkReg(Cmd);
    Reg#(UInt#(16)) rg_index <- mkReg(0);
    Reg#(Bit#(addrwidth)) rg_addr <- mkReg(0);
    Reg#(Bit#(datawidth)) rg_data <- mkReg(0);
    Reg#(Bit#(8)) rg_status <- mkReg(0);

    Integer addr_bytes = valueOf(addrbytes);
    Integer data_bytes = valueOf(databytes);

    rule rcmd if(rg_state == Cmd);
        let octet <- uart_rx.receive.get();
        rg_index <= 0;
        rg_addr <= 0;
        rg_data <= 0;
        if(octet == 8'h00) begin
            rg_state <= ReadAddr;
        end else if(octet == 8'h01) begin
            rg_state <= WriteAddr;
        end else begin
            rg_status <= 8'h02;
            rg_state <= SendBadCommand;
        end
    endrule

    rule rread_addr if(rg_state == ReadAddr);
        let octet <- uart_rx.receive.get();
        let next_addr = put_byte_le(rg_addr, rg_index, octet);
        rg_addr <= next_addr;
        if(rg_index == fromInteger(addr_bytes - 1)) begin
            m_rd_inst.request.put(AXI4_Lite_Read_Rq_Pkg {
                addr: next_addr,
                prot: UNPRIV_SECURE_DATA
            });
            rg_index <= 0;
            rg_state <= WaitReadResp;
        end else begin
            rg_index <= rg_index + 1;
        end
    endrule

    rule rwrite_addr if(rg_state == WriteAddr);
        let octet <- uart_rx.receive.get();
        let next_addr = put_byte_le(rg_addr, rg_index, octet);
        rg_addr <= next_addr;
        if(rg_index == fromInteger(addr_bytes - 1)) begin
            rg_index <= 0;
            rg_state <= WriteData;
        end else begin
            rg_index <= rg_index + 1;
        end
    endrule

    rule rwrite_data if(rg_state == WriteData);
        let octet <- uart_rx.receive.get();
        let next_data = put_byte_le(rg_data, rg_index, octet);
        rg_data <= next_data;
        if(rg_index == fromInteger(data_bytes - 1)) begin
            m_wr_inst.request.put(AXI4_Lite_Write_Rq_Pkg {
                addr: rg_addr,
                data: next_data,
                strb: '1,
                prot: UNPRIV_SECURE_DATA
            });
            rg_index <= 0;
            rg_state <= WaitWriteResp;
        end else begin
            rg_index <= rg_index + 1;
        end
    endrule

    rule rread_resp if(rg_state == WaitReadResp);
        let rsp <- m_rd_inst.response.get();
        rg_status <= response_status(rsp.resp);
        rg_data <= rsp.data;
        rg_index <= 0;
        rg_state <= SendReadStatus;
    endrule

    rule rsend_read_status if(rg_state == SendReadStatus);
        uart_tx.transmit.put(rg_status);
        rg_state <= SendReadData;
    endrule

    rule rsend_read_data if(rg_state == SendReadData);
        uart_tx.transmit.put(get_byte_le(rg_data, rg_index));
        if(rg_index == fromInteger(data_bytes - 1)) begin
            rg_index <= 0;
            rg_state <= Cmd;
        end else begin
            rg_index <= rg_index + 1;
        end
    endrule

    rule rwrite_resp if(rg_state == WaitWriteResp);
        let rsp <- m_wr_inst.response.get();
        uart_tx.transmit.put(response_status(rsp.resp));
        rg_state <= Cmd;
    endrule

    rule rbad_command if(rg_state == SendBadCommand);
        uart_tx.transmit.put(rg_status);
        rg_state <= Cmd;
    endrule

    method rx = uart_rx.rx;
    method tx = uart_tx.tx;

    interface m_rd = m_rd_inst.fab;
    interface m_wr = m_wr_inst.fab;
endmodule

module mkUartAxiLiteMaster#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer rd_buffer, Integer wr_buffer)(UartAxiLiteMaster#(addrwidth, datawidth))
    provisos(
        Add#(a__, 1, addrwidth),
        Add#(b__, 1, datawidth),
        Add#(c__, 8, addrwidth),
        Add#(d__, 8, datawidth),
        Div#(addrwidth, 8, addrbytes),
        Div#(datawidth, 8, databytes),
        Log#(8, uart_log),
        Add#(uart_log, 1, uart_log1)
    );

    let master <- mkUartAxiLiteMasterBuffered(stop_bits, prescaler, rd_buffer, wr_buffer, 2, 2);
    return master;
endmodule

endpackage
