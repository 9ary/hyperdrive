#!/bin/sh

$3 $2 | cat vhdl/rom_prologue.vhd - vhdl/rom_epilogue.vhd \
    | sed -e "s/dualportram/hyperdrive_rom/" > $1
