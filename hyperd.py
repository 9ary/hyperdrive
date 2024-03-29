#!/usr/bin/env python3
# This script requires my personal fork of libmpsse
# https://github.com/9ary/libmpsse

import binascii
import signal
import struct
import sys

import mpsse

STATUS_CMD_READY = 1 << 0
STATUS_RESET = 1 << 1
STATUS_BREAK = 1 << 2
STATUS_COVER = 1 << 3
STATUS_ERROR = 1 << 4

signal.signal(signal.SIGINT, signal.SIG_DFL)

with mpsse.MPSSE(mpsse.SPI0, mpsse.THIRTY_MHZ, mpsse.MSB) as spi, \
        open(sys.argv[1], "rb") as gcm:

    def hyperdrive_read():
        spi.Start()
        d = spi.Read(13) # Status register + 12 byte command
        spi.Stop()
        return d[0], struct.unpack(">LLL", d[1:])

    def hyperdrive_write(status, buf = None):
        spi.Start()
        buf = bytes([status | 1 << 7]) + (buf or bytes())
        chunksize = 32 * 1024
        while buf:
            spi.Write(buf[:chunksize])
            buf = buf[chunksize:]
        spi.Stop()

    spi.SetDirection(0b11010111)

    while True:
        spi.WaitIO(True)
        status, cmd = hyperdrive_read()

        setstatus = 0

        if status & STATUS_RESET:
            setstatus |= STATUS_RESET

        if status & STATUS_BREAK:
            setstatus |= STATUS_BREAK

        if status & STATUS_COVER:
            setstatus |= STATUS_COVER

        if not status & STATUS_CMD_READY:
            hyperdrive_write(setstatus)
            continue

        setstatus |= STATUS_CMD_READY

        if cmd[0] >> 24 == 0xA8:
            print(f"Reading 0x{cmd[2]:X} bytes at 0x{cmd[1] << 2:X}")
            gcm.seek(cmd[1] << 2)
            data = gcm.read(cmd[2])
            data += bytes(cmd[2] - len(data))

            # Patch game region to NTSC-U
            o = 0x45B - (cmd[1] << 2)
            if o >= 0 and o < cmd[2]:
                data = bytearray(data)
                data[o] = 0x01
                data = bytes(data)

            write_buf = data

        elif cmd[0] >> 24 == 0x12:
            print("Drive ID")
            write_buf = struct.pack(">LLLLLLLL", 0, 0x20010608, 0x61000000, 0, 0, 0, 0, 0)

        elif cmd[0] >> 24 == 0xE0:
            print("error status")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xE3:
            print("stop motor")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xE4:
            print("audio streaming setup")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xE1:
            print("play audio stream")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xE2:
            print("audio streaming status")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xDF:
            print("wkf command")
            write_buf = bytes(4)

        elif cmd[0] >> 24 == 0xFE:
            print("DMA write test")
            hyperdrive_write(setstatus)
            spi.Start()
            print(binascii.hexlify(spi.Read(cmd[2])))
            spi.Stop()
            continue

        else:
            print(f"Unhandled command 0x{cmd[0]:08X} 0x{cmd[1]:08X} 0x{cmd[2]:08X}")
            sys.exit(1)

        hyperdrive_write(setstatus, write_buf)
