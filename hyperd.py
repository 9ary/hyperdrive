#!/usr/bin/env python3

import struct
import sys

import mpsse

with mpsse.MPSSE(mpsse.SPI0, mpsse.THIRTY_MHZ, mpsse.MSB) as spi, \
        open(sys.argv[1], "rb") as gcm:

    def read_status():
        spi.Write(b"\x01")
        return struct.unpack(">B", spi.Read(1))[0]

    def lid_close():
        spi.Write(b"\x03")

    def lid_open():
        spi.Write(b"\x04")

    def read_cmd():
        spi.Write(b"\x05")
        return struct.unpack(">LLL", spi.Read(12))

    def write_data(buf):
        spi.Write(b"\x06")
        chunksize = 32 * 1024
        while buf:
            spi.Write(buf[:chunksize])
            buf = buf[chunksize:]
        spi.Stop()
        spi.Start()

    def ack_cmd():
        spi.Write(b"\x07")

    spi.Start()

    lid_open()

    while True:
        status = read_status()

        if status & (1 << 0):
            continue
        lid_close()

        if not status & (1 << 1):
            continue

        cmd = read_cmd()
        ack_cmd()

        if cmd[0] >> 24 == 0xA8:
            print(f"Reading 0x{cmd[2]:X} bytes at 0x{cmd[1] << 2:X}")
            gcm.seek(cmd[1] << 2)
            data = gcm.read(cmd[2])
            data += bytes(cmd[2] - len(data))

            # Patch game region to PAL
            o = 0x45B - (cmd[1] << 2)
            if o >= 0 and o < cmd[2]:
                data = bytearray(data)
                data[o] = 0x02
                data = bytes(data)

            write_data(data)

        elif cmd[0] >> 24 == 0x12:
            print("Drive ID")
            write_data(struct.pack(">LLLLLLLL", 0, 0x20010608, 0x61000000, 0, 0, 0, 0, 0))

        elif cmd[0] >> 24 == 0xE0:
            print("error status")
            write_data(bytes(4))

        elif cmd[0] >> 24 == 0xE3:
            print("stop motor")
            write_data(bytes(4))

        elif cmd[0] >> 24 == 0xE4:
            print("audio streaming")
            write_data(bytes(4))

        elif cmd[0] >> 24 == 0xDF:
            print("wkf command")
            write_data(bytes(4))

        else:
            print(f"Unhandled command 0x{cmd[0]:0{8}X} 0x{cmd[1]:0{8}X} 0x{cmd[2]:0{8}X}")
            sys.exit(1)

    spi.Stop()
