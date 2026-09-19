# BlueUART

BlueUART is a small Bluespec UART module set with standalone RX/TX modules,
a CSR-controlled UART core, an AXI4-Stream bridge, and a UART-to-AXI4-Lite
master.

Reusable modules are in `hdl/src`. Tests, FPGA wrapper tops, and scripts are
kept under `hdl/test`, `hdl/src/fpga`, and `hdl/script`.

## Repository Layout

| Path | Contents |
| --- | --- |
| `hdl/src` | Bluespec UART blocks and usage-analysis wrappers. |
| `hdl/src/fpga` | 7-series FPGA wrapper tops. |
| `hdl/test` | Bluesim test modules driven by the shared `Testbench` wrapper. |
| `hdl/script` | Regression, Vivado, serial loopback, and UART AXI4-Lite scripts. |
| `dep` | Git submodules for BSVTools, BlueAXI, BlueCSR, and BlueLens. |
| `nix` | Optional shell with Bluespec, Yosys, Icarus Verilog, and Python serial tooling. |

## Toolchain

The Makefile uses BSVTools and the BlueAXI/BlueCSR submodules:

```sh
git submodule update --init --recursive
```

Optional Nix shell:

```sh
nix develop nix
```

Vivado is only needed for the FPGA scripts and the 7-series synthesis reports.

Generated files are written under `hdl/build`. If BSC reports a `.bo`
binary-version mismatch after changing toolchains, remove the cached build
products:

```sh
make -C hdl clean
```

## Simulation

Single test:

```sh
make -C hdl RUN_TEST=TestUartRx sim
```

Default regression set:

```sh
make -C hdl regression
```

Regression logs are written to `hdl/build/regression`.

## Examples

### Cmod A7 FPGA

`hdl/script/constr.xdc` contains the Cmod A7 pinout used for FPGA tests:
12 MHz clock on `clk_12`, two LEDs, and the USB-UART pins `uart_rxd` and
`uart_txd`.

`hdl/script/synth_fpga.tcl` builds FPGA tops. It reads `constr.xdc`, uses
`PROJECT_NAME` as the Vivado top, then runs synthesis, optimization, placement,
routing, physical optimization, report generation, and bitstream generation.

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

`MAIN_MODULE` is the path relative to `hdl/src`, without the `.bsv` suffix.
For this script, `PROJECT_NAME` must match the synthesized Verilog top module.

## Modules 

### UART RX

- `mkUartRx` samples a serial input into a FIFO-backed receive stream.
- Includes input synchronization, baud timing, frame/overflow pulses, and
  configurable stop-bit handling.
- `mkUartRxBuffered` exposes the output FIFO depth; `mkUartRx` keeps the legacy
  2-deep FIFO.

### UART TX

- `mkUartTx` serializes FIFO-backed transmit words onto `tx`.
- Uses the configured prescaler and one/two stop-bit mode.
- `mkUartTxBuffered` exposes the transmit FIFO depth.

### UART Core

- `mkUartCore` combines one RX, one TX, and a BlueCSR-backed AXI4-Lite slave.
- CSRs control enable, prescaler, and stop-bit mode.
- Status CSRs expose RX/TX state and errors; data FIFO CSRs can be disabled.

For UART-core builds with CSR-accessible data FIFOs, the register map is:

| Address | Register | Register Description | Field | Bits | Access | Reset | Field Description |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0x00 | MIV | Module ID and Version Register | MID | [07:00] | RC | 0xd | Unique ID for this module. |
|  |  |  | VRS | [23:16] | RC | 0x1 | Module version. |
| 0x04 | CTRL | UART control register | CTRLEN | [00:00] | RW | 0x0 | Controls whether module is enabled or not. |
|  |  |  | STOP2 | [01:01] | RW | 0x0 | Controls whether to expect 1 or 2 stop bits. |
| 0x08 | BAUD | UART prescaler register | BAUD | [15:00] | RW | 0x0 | Clock cycles per UART bit. Zero is treated as one. |
| 0x0c | STATUS | Module status register | FRERR | [00:00] | W1C | 0x0 | Last reception had malformed frame. |
|  |  |  | OVFLW | [01:01] | W1C | 0x0 | Last reception could not be stored in buffer. |
|  |  |  | TXBUSY | [08:08] | RO | 0x0 | Transmitter has queued or active data. |
|  |  |  | RXBUSY | [09:09] | RO | 0x0 | Receiver is processing a frame. |
|  |  |  | TXREADY | [10:10] | RO | 0x0 | TXDATA can accept a byte. |
|  |  |  | RXVALID | [11:11] | RO | 0x0 | RXDATA contains a byte. |
| 0x10 | TXDATA | Transmit data register | DATA | [07:00] | WO | 0x0 | Queues one byte for transmission. |
| 0x14 | RXDATA | Receive data register | DATA | [07:00] | RO | 0x0 | Dequeues one received byte. |

When `csr_fifos` is `False`, `TXDATA` and `RXDATA` are not present; the core's
external `receive` and `transmit` streams are used instead.

### UART AXIS Bridge

- `mkUartAxisBridge` maps UART bytes to AXI4-Stream beats and AXI4-Stream beats
  to UART transmit bytes.
- Uses internal UART RX/TX FIFOs plus AXIS read/write adapter FIFOs.
- `mkUartAxisBridgeBuffered` exposes the UART FIFO depths.

### UART AXI4-Lite Master

- `mkUartAxiLiteMaster` converts UART command bytes into AXI4-Lite reads and
  writes.
- UART commands are byte-oriented; AXI address/data widths are type parameters.
- `mkUartAxiLiteMasterBuffered` exposes AXI channel and UART RX/TX buffer
  depths.

Command contract:

| Command | UART request bytes | AXI action | UART response bytes |
| --- | --- | --- | --- |
| Read `0x00` | command, little-endian address | AXI4-Lite read with `prot = UNPRIV_SECURE_DATA` | status, little-endian read data |
| Write `0x01` | command, little-endian address, little-endian data | AXI4-Lite write with `strb = all ones` and `prot = UNPRIV_SECURE_DATA` | status |
| Other | command | no AXI transaction | `0x02` |

Status is `0x00` for AXI `OKAY`, `0x01` for any non-`OKAY` AXI response, and
`0x02` for an unknown command byte. The master processes commands
sequentially; deeper buffers absorb UART/AXI timing mismatch but do not make
the command parser issue multiple logical commands in parallel.

### Baud Generator

- `mkBaudGen` is the shared prescaler counter used by RX and TX.
- A frame bit lasts `prescaler` clocks after load; zero is treated as one.
- RX uses the middle-of-bit pulse for sampling; TX uses the top-of-bit pulse to
  advance serialization.

## Synthesis Overview

These out-of-context, post-synthesis Vivado 2025.2 reports use the BSVTools
`vivado_tcl` target for `xc7a35tcpg236-1` at 100 MHz. They do not include I/O
buffers, placement, routing, or bitstream generation. UART reference wrappers
use 8-bit words, one stop bit, and prescaler 868 for approximately 115200 baud.

| Module | Wrapper top | Configuration | LUTs | FFs | WNS at 100 MHz |
| --- | --- | --- | ---: | --: | ---: |
| UART RX | `mkUsageUartRxMin` | 8-bit word, 1-deep RX FIFO | 57 | 48 | 2.616 ns |
| UART RX | `mkUsageUartRxMax` | 8-bit word, 16-deep RX FIFO | 86 | 58 | 2.616 ns |
| UART TX | `mkUsageUartTxMin` | 8-bit word, 1-deep TX FIFO | 53 | 39 | 2.413 ns |
| UART TX | `mkUsageUartTxMax` | 8-bit word, 16-deep TX FIFO | 85 | 49 | 2.225 ns |
| UART core | `mkUsageUartCoreMin` | 8-bit RX/TX, 1-deep UART FIFOs, 32-bit CSR | 662 | 432 | 1.258 ns |
| UART core | `mkUsageUartCoreMax` | 8-bit RX/TX, 16-deep UART FIFOs, 32-bit CSR | 737 | 452 | 0.507 ns |
| UART AXIS bridge | `mkUsageUartAxisBridgeMin` | 8-bit stream, 1-deep UART/AXIS FIFOs | 150 | 113 | 2.410 ns |
| UART AXIS bridge | `mkUsageUartAxisBridgeMax` | 8-bit stream, 16-deep UART, 1-deep AXIS | 211 | 133 | 2.233 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMasterMin` | 8-bit AXI, 1-deep UART/AXI buffers | 268 | 188 | 1.901 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMaster8MaxUart` | 8-bit AXI, 16-deep UART, 1-deep AXI | 316 | 208 | 1.643 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMaster32MinUart` | 32-bit AXI, 1-deep UART/AXI buffers | 496 | 387 | 2.414 ns |
| UART AXI4-Lite master | `mkUsageUartAxiLiteMasterMax` | 32-bit AXI, 16-deep UART, 1-deep AXI | 570 | 407 | 1.643 ns |

