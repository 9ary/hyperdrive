#!/usr/bin/env python3

import shogun

crt0 = shogun.Objects("toolchain/crt0-bsd.S", "ccas", "o")
toolchain = [ crt0 ]

obj = shogun.Objects("src/*.c", "cc", "o")
elf = shogun.Assembly("$builddir/hyperdrive.elf", "ccld", obj, crt0)
firmware = [ obj, elf ]

shogun.build(*(toolchain + firmware))
