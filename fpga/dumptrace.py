#!/usr/bin/env python3

import configparser
import io
import zipfile

import serial
import serial.tools.list_ports

dev = next(serial.tools.list_ports.grep("CDC RS-232 Emulation Demo")).device
with serial.Serial(dev) as port:
    port.reset_input_buffer()
    port.reset_output_buffer()
    print("Waiting for data...")
    sample_data = port.read(2 * 1024)

probes = [
    *(f"DID{i}" for i in range(8)),
    "DICOVER",
    "DIERRB",
    "DIDSTRB",
    "DIRSTB",
    "DIBRK",
    "DIDR",
    "DIHSTRB",
]

metadata = configparser.ConfigParser()
metadata["device 1"] = {
    "capturefile": "logic-1",
    "total probes": len(probes),
    "samplerate": "100 MHz",
    "total analog": 0,
    **{f"probe{i}": name for i, name in enumerate(probes, 1)},
    "unitsize": (len(probes) + 7) // 8,
}

with zipfile.ZipFile("trace.sr", "w") as session:
    with io.TextIOWrapper(session.open("metadata", "w"), newline="\n") as f:
        metadata.write(f)

    session.writestr("version", "2")
    session.writestr("logic-1", sample_data)
