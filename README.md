# BlueUART

Bluespec UART RX/TX blocks, a plain UART core, an AXI4-Lite CSR peripheral,
and bridges to AXI4-Stream and AXI4-Lite. Sources are in `hdl/src`, tests in
`hdl/test`, and FPGA examples in `hdl/src/fpga`.

## Build and test

```sh
git submodule update --init --recursive
nix develop nix
make -C hdl regression
```

- BSVTools, BlueAXI and BlueCSR are included as submodules
- BlueCSR's AXI adapter also needs BlueLib on the BSV search path.
- Run a test with `make -C hdl RUN_TEST=TestUartRxHold sim`.

## UART modules

Import `BlueUART::*` for the RX, TX, plain core and CSR peripheral:

```bsv
UartRx#(8) i_rx           <- mkUartRx(stop_bits, prescaler, rx_depth);
UartTx#(8) i_tx           <- mkUartTx(stop_bits, prescaler, tx_depth);
UartCore_ifc#(8) i_uart   <- mkUartCore(enable, stop_bits, prescaler, rx_depth, tx_depth);
UartCsr_ifc i_peripheral  <- mkUartCsr(rx_depth, tx_depth);
```

RX and the plain core expose a guarded `Get` named `receive`, TX and the plain
core expose a guarded `Put` named `transmit`. 
The CSR peripheral transfers data through registers. 
Serial pins use `rx`/`tx` methods. Each module provides busy status, RX and the plain core also expose framing and overflow error pulses.

One or two stop bits are supported. The 16-bit prescaler sets clocks per bit;
zero means one clock. Settings are captured at frame start. 
As an example, 868 clocks per bit gives about 115200 baud at 100 MHz. 
RX includes a two-register input synchronizer.

Disabling the plain core masks RX high and blocks new transmit requests.
Queued and active TX words finish. Change enable while idle for a clean RX
boundary. Reset clears pending data and queues, idles the state machines and drives
TX high.

### Buffer depths

Depths are elaboration-time integers and count FIFO entries, excluding the
RX assembly register and TX active-word register.

| Setting | Behavior |
| --- | --- |
| RX depth 0 | Hold the completed word in the assembly register until consumed. A new confirmed start bit discards an unread word and pulses overflow. The new word becomes readable after successful reception. |
| RX depth > 0 | Queue completed words in a FIFO. When full, drop the arriving word and pulse overflow. |
| TX depth 0 | Accept a word when idle and serialize it from the active-word register. |
| TX depth > 0 | Queue words in a FIFO; release each queue slot when its word starts transmission. |

A false start leaves a held RX word intact. Consuming the held word on the same
cycle as a confirmed start avoids overflow. Replacement happens at start
confirmation, even if the new frame later has a framing error. Reception
continues when the consumer stalls.

TX busy includes queued and active words. RX busy describes reception of a
frame, it may be false while a completed word is waiting to be read.

## CSR peripheral

`mkUartCsr(rx_depth, tx_depth)` provides a 32-bit AXI4-Lite slave through `s_rd`
and `s_wr`. Both depths must be positive and set the byte queues in `UartRegs`.
Its RX/TX engines use depth zero. RX can hold one additional completed byte in
its assembly register while the CSR queue is full. Further frames replace that
held byte and set overflow; bytes already in the FIFO keep their order.

The register map is generated from `UartRegs` by BlueCSR's
`doc_blue_csr_markdown`. Regenerate it in the Nix shell with
`make -C hdl csr_docs`.

"<!-- BEGIN GENERATED CSR MAP -->

| Address | Register | Register Description | Field | Bits | Access | Reset | Field Description |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0x00 | MIV | Module ID and Version Register | MID | [07:00] | RC | 0xd | Unique ID for this module. |
|  |  |  | VRS | [23:16] | RC | 0x1 | Module version. |
| 0x04 | CTRL | UART control register | CTRLEN | [00:00] | RW | 0x0 | Controls whether module is enabled or not. |
|  |  |  | STOP2 | [01:01] | RW | 0x0 | Controls whether to expect 1 or 2 stop bits. |
| 0x08 | BAUD | UART prescaler register | BAUD | [15:00] | RW | 0x0 | Clock cycles per UART bit. Zero is treated as one. |
| 0x0c | STATUS | Module status register | FRERR | [00:00] | W1C | 0x0 | Last reception had malformed frame. |
|  |  |  | OVFLW | [01:01] | W1C | 0x0 | Received data was dropped or overwritten. |
|  |  |  | TXBUSY | [08:08] | RO | 0x0 | Transmitter has queued or active data. |
|  |  |  | RXBUSY | [09:09] | RO | 0x0 | Receiver is processing a frame. |
|  |  |  | TXREADY | [10:10] | RO | 0x0 | The selected transmit data interface can accept a byte. |
|  |  |  | RXVALID | [11:11] | RO | 0x0 | Received data is available at the selected data interface. |
| 0x10 | TXDATA | Transmit data register | DATA | [07:00] | WO | 0x0 | Queues one byte for transmission. |
| 0x14 | RXDATA | Receive data register | DATA | [07:00] | RO | 0x0 | Dequeues one received byte. |

TXDATA and RXDATA are optional FIFO registers: mkUartCsr includes them;
the control-only mkUartAxisBridgeCsr uses registers 0x00-0x0c only.

<!-- END GENERATED CSR MAP -->


TXBUSY includes the CSR TX queue while disabled. TXREADY/RXVALID describe the
CSR queues; status registers are sampled each clock.

TXDATA requires byte strobe `0x1`. Invalid strobes, writes to a full TX queue
and reads from an empty RX queue return AXI `SLVERR`.

## Bridges

Import `UartAxisBridge::*` or `UartAxiLiteMaster::*` as needed.

```bsv
let i_axis      <- mkUartAxisBridge(stop_bits, prescaler, m_axis_depth, s_axis_depth, rx_depth, tx_depth);
let i_axis_csr  <- mkUartAxisBridgeCsr(m_axis_depth, s_axis_depth, rx_depth, tx_depth);
let i_master    <- mkUartAxiLiteMaster(stop_bits, prescaler, rd_depth, wr_depth, rx_depth, tx_depth);
```

UART depths may be zero. AXIS and AXI adapter queues have separate depth
parameters.

The AXIS bridge maps UART words to beats and sends incoming beat data over
UART. The CSR variant adds registers 0x00–0x0c for control/status, with data
flowing through AXIS. Its TXREADY/RXVALID bits report `S_AXIS.TREADY` and
`M_AXIS.TVALID`.

The AXI4-Lite master accepts these UART commands. Addresses and data are
little-endian, sized to the AXI interface widths.

| Command | Request after command byte | AXI operation | UART response |
| --- | --- | --- | --- |
| 0x00 | Address | Read | Status, then data |
| 0x01 | Address, data | Write, all byte strobes asserted | Status |
| Other | — | — | 0x02 |

Status is `0x00` for AXI `OKAY` and `0x01` for a bus error. Transactions use
`UNPRIV_SECURE_DATA`. Commands execute sequentially.

## FPGA examples

The Cmod A7 examples use a 12 MHz clock, two LEDs and USB-UART pins defined in
`hdl/script/constr.xdc`. Vivado is required for synthesis and bitstreams.

```sh
make -C hdl \
  MAIN_MODULE=fpga/TestFpgaUartAxiLiteMaster \
  TOP_MODULE=mkUartAxiLiteMasterFpga \
  PROJECT_NAME=mkUartAxiLiteMasterFpga \
  SIM_TYPE=VERILOG \
  PART="--part xc7a35tcpg236-1" \
  SCRIPT="--script $PWD/hdl/script/synth_fpga.tcl" \
  vivado_tcl
```

Set `MAIN_MODULE` to the source path under `hdl/src`, without `.bsv`.
`PROJECT_NAME` and `TOP_MODULE` must name the same Verilog top.

## FPGA usage

Vivado 2025.2, Bluespec 2024.07 from the Nix flake, `xc7a35tcpg236-1`, 100 MHz.
These are out-of-context synthesis results; WNS is estimated slack before
placement and routing. Fixed UART settings are one stop bit and prescaler 868;
CSR variants retain runtime configuration. All entries use zero BRAM and DSP
blocks. Depths count FIFO entries as described above.

| Module | Wrapper top | Configuration | LUTs | FFs | WNS at 100 MHz |
| --- | --- | --- | ---: | ---: | ---: |
| UART RX | `mkUsageUartRxMin` | 8-bit, RX depth 0 | 33 | 36 | 5.625 ns |
| UART RX | `mkUsageUartRxMax` | 8-bit, RX depth 16 | 64 | 54 | 5.422 ns |
| UART TX | `mkUsageUartTxMin` | 8-bit, TX depth 0 | 32 | 34 | 5.589 ns |
| UART TX | `mkUsageUartTxMax` | 8-bit, TX depth 16 | 58 | 53 | 5.608 ns |
| Plain UART core | `mkUsageUartCoreMin` | 8-bit, RX/TX depths 0/0 | 61 | 70 | 5.600 ns |
| Plain UART core | `mkUsageUartCoreMax` | 8-bit, RX/TX depths 16/16 | 121 | 107 | 5.418 ns |
| CSR UART | `mkUsageUartCsrMin` | 8-bit, Regs RX/TX depths 1/1 | 517 | 403 | 2.053 ns |
| CSR UART | `mkUsageUartCsrMax` | 8-bit, Regs RX/TX depths 16/16 | 578 | 423 | 2.075 ns |
| UART AXIS bridge | `mkUsageUartAxisBridgeMin` | 8-bit, UART/AXIS depths 1/1 | 101 | 113 | 5.600 ns |
| UART AXIS bridge | `mkUsageUartAxisBridgeMax` | 8-bit, UART depth 16, AXIS depth 1 | 166 | 133 | 5.425 ns |
| UART AXIS + control CSRs | `mkUsageUartAxisBridgeCsrMin` | 8-bit, UART depth 0, AXIS depth 1 | 506 | 404 | 3.004 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMasterMin` | 8-bit AXI, UART/AXI depths 1/1 | 214 | 188 | 5.414 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMaster8MaxUart` | 8-bit AXI, UART depth 16, AXI depth 1 | 269 | 208 | 5.136 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMaster32MinUart` | 32-bit AXI, UART/AXI depths 1/1 | 455 | 387 | 5.249 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMasterMax` | 32-bit AXI, UART depth 16, AXI depth 1 | 521 | 407 | 5.267 ns |
| Narrow plain core | `mkUsageUartNarrow` | 1-bit word, RX/TX depths 0/0 | 47 | 49 | 5.624 ns |

Regenerate the reports from the Nix shell with Vivado on `PATH`:

```sh
make -C hdl SIM_TYPE=VERILOG compile_top
blueuart_bsc_lib=$(bsc -help | sed -n 's/^Bluespec directory: //p')
vivado -mode batch -nojournal -nolog \
  -source hdl/script/report_usage.tcl \
  -tclargs hdl/build/verilog "$blueuart_bsc_lib" hdl/build/usage
```

Utilization, timing and `usage.tsv` reports are written to `hdl/build/usage`.
