#!/usr/bin/env python3
# SPDX-License-Identifier: MIT


import argparse
import hashlib
import sys
import time

import serial
from serial.tools import list_ports


def default_port():
    ports = list(list_ports.comports())
    if len(ports) == 1:
        return ports[0].device

    for port in ports:
        text = " ".join(filter(None, [port.device, port.description, port.manufacturer]))
        if "Digilent" in text or "FTDI" in text or "USB Serial" in text:
            return port.device

    return None


def describe_bytes(data):
    if len(data) <= 64:
        return data.hex(" ")

    head = data[:16].hex(" ")
    tail = data[-16:].hex(" ")
    digest = hashlib.sha256(data).hexdigest()[:16]
    return f"{len(data)} bytes, sha256={digest}..., head={head}, tail={tail}"


def main():
    parser = argparse.ArgumentParser(description="Exercise the BlueUART FPGA loopback top over a serial port.")
    parser.add_argument("--port", default=None, help="Serial device, for example /dev/ttyUSB1.")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate.")
    parser.add_argument("--timeout", type=float, default=2.0, help="Read timeout in seconds.")
    parser.add_argument("--length", type=int, default=256, help="Number of test bytes to send.")
    parser.add_argument(
        "--burst",
        action="store_true",
        help="Send the whole payload at once instead of waiting for each echoed byte.",
    )
    args = parser.parse_args()

    port = args.port or default_port()
    if port is None:
        print("ERROR: no serial port selected and no obvious USB serial port found", file=sys.stderr)
        print("Available ports:", file=sys.stderr)
        for p in list_ports.comports():
            print(f"  {p.device}: {p.description}", file=sys.stderr)
        return 2

    if args.length <= 0:
        print("ERROR: --length must be positive", file=sys.stderr)
        return 2

    payload = bytes(offset & 0xFF for offset in range(args.length))

    with serial.Serial(port, args.baud, timeout=args.timeout) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.05)

        received = bytearray()
        if args.burst:
            ser.write(payload)
            ser.flush()
            received.extend(ser.read(len(payload)))
        else:
            for offset, expected in enumerate(payload):
                ser.write(bytes([expected]))
                ser.flush()
                actual = ser.read(1)
                received.extend(actual)
                if actual != bytes([expected]):
                    print(f"ERROR: loopback mismatch on {port} @ {args.baud}")
                    print(f"  byte {offset}: sent {expected:02x}, received {actual.hex(' ') or '<timeout>'}")
                    print(f"  sent:     {describe_bytes(payload)}")
                    print(f"  received: {describe_bytes(bytes(received))}")
                    return 1

        received = bytes(received)

    if received != payload:
        print(f"ERROR: loopback mismatch on {port} @ {args.baud}")
        print(f"  sent:     {describe_bytes(payload)}")
        print(f"  received: {describe_bytes(received)}")
        return 1

    print(f"Loopback OK on {port} @ {args.baud}: {describe_bytes(received)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
