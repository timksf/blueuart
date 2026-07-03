#!/usr/bin/env python3
# SPDX-License-Identifier: MIT


import argparse
import sys
import time

import serial
from serial.tools import list_ports


READ = 0x00
WRITE = 0x01
STATUS_OK = 0x00
STATUS_BUS_ERROR = 0x01
STATUS_BAD_COMMAND = 0x02

DUMMY_MIV = 0x00
DUMMY_CTRL = 0x04
DUMMY_STATUS = 0x08
DUMMY_LOOP_WO = 0x0C
DUMMY_LOOP_RO = 0x10
DUMMY_REGFILE = 0x100


class UartAxiLiteError(RuntimeError):
    pass


class UartAxiLiteStatusError(UartAxiLiteError):
    def __init__(self, status):
        super().__init__(f"AXI-lite command returned status 0x{status:02x}")
        self.status = status


def default_port():
    ports = list(list_ports.comports())
    if len(ports) == 1:
        return ports[0].device

    for port in ports:
        text = " ".join(filter(None, [port.device, port.description, port.manufacturer]))
        if "Digilent" in text or "FTDI" in text or "USB Serial" in text:
            return port.device

    return None


def parse_int(text):
    return int(text, 0)


class UartAxiLite:
    def __init__(self, port=None, baud=115200, timeout=2.0, addr_bytes=4, data_bytes=4, serial_port=None):
        self.port = port or default_port()
        self.baud = baud
        self.timeout = timeout
        self.addr_bytes = addr_bytes
        self.data_bytes = data_bytes
        self._serial = serial_port
        self._owns_serial = serial_port is None

        if self.port is None and self._serial is None:
            raise UartAxiLiteError("no serial port selected and no obvious USB serial port found")

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()

    def open(self):
        if self._serial is None:
            self._serial = serial.Serial(self.port, self.baud, timeout=self.timeout)
            self._owns_serial = True
        return self

    def close(self):
        if self._serial is not None and self._owns_serial:
            self._serial.close()
        self._serial = None

    def _io(self):
        if self._serial is None:
            self.open()
        return self._serial

    def reset_buffers(self):
        ser = self._io()
        ser.reset_input_buffer()
        ser.reset_output_buffer()

    def _word(self, value, size):
        return int(value).to_bytes(size, "little")

    def _read_exact(self, size, what):
        data = self._io().read(size)
        if len(data) != size:
            raise TimeoutError(f"{what} timed out after {len(data)} byte(s)")
        return data

    def write_status(self, addr, data):
        ser = self._io()
        ser.write(bytes([WRITE]) + self._word(addr, self.addr_bytes) + self._word(data, self.data_bytes))
        ser.flush()
        return self._read_exact(1, "write response")[0]

    def read_status(self, addr):
        ser = self._io()
        ser.write(bytes([READ]) + self._word(addr, self.addr_bytes))
        ser.flush()
        response = self._read_exact(1 + self.data_bytes, "read response")
        return response[0], int.from_bytes(response[1:], "little")

    def write(self, addr, data, check=True):
        status = self.write_status(addr, data)
        if check and status != STATUS_OK:
            raise UartAxiLiteStatusError(status)
        return status

    def read(self, addr, check=True):
        status, data = self.read_status(addr)
        if check and status != STATUS_OK:
            raise UartAxiLiteStatusError(status)
        return data

    def raw_command_status(self, command):
        ser = self._io()
        ser.write(bytes([command]))
        ser.flush()
        return self._read_exact(1, "raw command response")[0]


def run_selftest(dev):
    dev.reset_buffers()
    time.sleep(0.05)

    status, data = dev.read_status(DUMMY_MIV)
    if status != STATUS_OK or data != 0x0001A711:
        raise UartAxiLiteError(f"MIV read returned status 0x{status:02x}, data 0x{data:08x}")

    if dev.write_status(DUMMY_CTRL, 0xBEEF0021) != STATUS_OK:
        raise UartAxiLiteError("CTRL write did not return STATUS_OK")

    status, data = dev.read_status(DUMMY_CTRL)
    if status != STATUS_OK or data != 0xBEEF0021:
        raise UartAxiLiteError(f"CTRL readback returned status 0x{status:02x}, data 0x{data:08x}")

    if dev.write_status(DUMMY_LOOP_WO, 0x13579BDF) != STATUS_OK:
        raise UartAxiLiteError("LOOP_WO write did not return STATUS_OK")

    status, data = dev.read_status(DUMMY_STATUS)
    if status != STATUS_OK or (data & 0x00000003) != 0x00000003 or (data & 0x0000FF00) != 0x00005A00:
        raise UartAxiLiteError(f"STATUS read returned status 0x{status:02x}, data 0x{data:08x}")

    status, data = dev.read_status(DUMMY_LOOP_RO)
    if status != STATUS_OK or data != 0x13579BDF:
        raise UartAxiLiteError(f"LOOP_RO read returned status 0x{status:02x}, data 0x{data:08x}")

    if dev.read_status(DUMMY_LOOP_RO)[0] != STATUS_BUS_ERROR:
        raise UartAxiLiteError("empty LOOP_RO read did not return STATUS_BUS_ERROR")

    if dev.write_status(DUMMY_REGFILE + 12, 0x2468ACE0) != STATUS_OK:
        raise UartAxiLiteError("REGFILE write did not return STATUS_OK")

    status, data = dev.read_status(DUMMY_REGFILE + 12)
    if status != STATUS_OK or data != 0x2468ACE0:
        raise UartAxiLiteError(f"REGFILE readback returned status 0x{status:02x}, data 0x{data:08x}")

    if dev.write_status(0xBAD00000, 0x00000001) != STATUS_BUS_ERROR:
        raise UartAxiLiteError("unmapped write did not return STATUS_BUS_ERROR")

    if dev.raw_command_status(0xFF) != STATUS_BAD_COMMAND:
        raise UartAxiLiteError("bad command did not return STATUS_BAD_COMMAND")


def build_parser():
    parser = argparse.ArgumentParser(description="Use the UART-to-AXI-lite-master bridge.")
    parser.add_argument("--port", default=None, help="Serial device, for example /dev/ttyUSB1.")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate.")
    parser.add_argument("--timeout", type=float, default=2.0, help="Read timeout in seconds.")
    parser.add_argument("--addr-bytes", type=int, default=4, help="Address width in bytes.")
    parser.add_argument("--data-bytes", type=int, default=4, help="Data width in bytes.")

    subparsers = parser.add_subparsers(dest="command")

    read_parser = subparsers.add_parser("read", help="Read one AXI-lite word.")
    read_parser.add_argument("addr", type=parse_int)

    write_parser = subparsers.add_parser("write", help="Write one AXI-lite word.")
    write_parser.add_argument("addr", type=parse_int)
    write_parser.add_argument("data", type=parse_int)

    subparsers.add_parser("selftest", help="Run the FPGA smoke test.")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    command = args.command or "selftest"

    try:
        with UartAxiLite(args.port, args.baud, args.timeout, args.addr_bytes, args.data_bytes) as dev:
            if command == "read":
                status, data = dev.read_status(args.addr)
                print(f"status=0x{status:02x} data=0x{data:0{args.data_bytes * 2}x}")
                return 0 if status == STATUS_OK else 1

            if command == "write":
                status = dev.write_status(args.addr, args.data)
                print(f"status=0x{status:02x}")
                return 0 if status == STATUS_OK else 1

            run_selftest(dev)
            print(f"UART AXI-lite master OK on {dev.port} @ {dev.baud}")
            return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
