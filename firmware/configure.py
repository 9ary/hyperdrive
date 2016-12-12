#!/usr/bin/env python3

import shogun

romgen = shogun.Objects("toolchain/zpuromgen.c", "hostcc", "elf")
crt0 = shogun.Objects("toolchain/crt0-bsd.S", "ccas", "o")
toolchain = [ romgen, crt0 ]

obj = shogun.Objects("src/*.c", "cc", "o")
elf = shogun.Assembly("$builddir/hyperdrive.elf", "ccld", obj, crt0)
binary = shogun.Assembly("$builddir/hyperdrive.bin", "bin", elf)
vhdl = shogun.Assembly("$builddir/hyperdrive-rom.vhd", "romgen", binary, romgen)
firmware = [ obj, elf, binary, vhdl ]

shogun.build(*(toolchain + firmware))
