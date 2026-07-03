# SPDX-License-Identifier: MIT


from uart_axi_lite import *

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

with UartAxiLite("/dev/ttyUSB1", 115200, 2.0, 4, 4) as dev:
    status, data = dev.read_status(DUMMY_MIV)

    print(f"MIV=0x{data:08x}")

    for i in range(16):
        status = dev.write_status(DUMMY_REGFILE+i*4, i)
        if status != STATUS_OK:
            print(f"Received bad status=0x{status:02x} at i={i}")
            exit(1)

    for i in range(16):
        status, data = dev.read_status(DUMMY_REGFILE+i*4)
        print(f"REGFILE[{i:02d}]=0x{data:08x}")

    status, data = dev.read_status(DUMMY_LOOP_RO)
    print(f"Reading empty fifo: status={status:02x}")

    status = dev.write_status(DUMMY_LOOP_WO, 0xDEADBEEF)
    status = dev.write_status(DUMMY_LOOP_WO, 0xDAADAFFE)

    for i in range(2):
        status, data = dev.read_status(DUMMY_LOOP_RO)
        print(f"READ FIFO status={status:02x} data={data:08x}")


    