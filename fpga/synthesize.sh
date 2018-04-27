#!/usr/bin/env bash

set -e

projname="hyperdrive"
ucf="mimas.ucf"
partname="xc6slx9"
partpackage="tqg144"
partspeed="2"
workdir="work"

# Get ourselves into a sane environment
[[ -z "${XILINX_ISE}" ]] && echo 'Please set ${XILINX_ISE} to path where ISE tools are installed' && exit 1
basedir=$(cd "${0%/*}" && echo ${PWD})
mkdir -p "${workdir}"
cd "${workdir}"

# XST options
cat > "${projname}.xst" << EOF
run
-ifn ${projname}.prj
-ofn ${projname}
-ofmt NGC
-p ${partname}-${partspeed}-${partpackage}
-top ${projname}
-opt_mode speed
-opt_level 1
EOF

# HDL file listing
find "${basedir}/src" -iname *.vhd -fprintf "${projname}.prj" 'vhdl work "%p"\n'

"${XILINX_ISE}/xst" -ifn "${projname}.xst" -ofn "${projname}.syr"

"${XILINX_ISE}/ngdbuild" -dd _ngo -uc "${basedir}/${ucf}" -p "${partname}-${partpackage}-${partspeed}" "${projname}.ngc" "${projname}.ngd"

"${XILINX_ISE}/map" -p "${partname}-${partpackage}-${partspeed}" -w -mt 2 -o "${projname}_map.ncd" "${projname}.ngd"

"${XILINX_ISE}/par" -w -mt 4 "${projname}_map.ncd" "${projname}.ncd"

# TODO generate timing report?
#trce -v 3 -s 2 -n 3 -fastpaths -xml hyperdrive.twx hyperdrive.ncd -o hyperdrive.twr hyperdrive.pcf

# BitGen options
cat > "${projname}.ut" << EOF
-w
-g Binary:Yes
-g Compress
-g UnusedPin:PullNone
EOF

"${XILINX_ISE}/bitgen" -f "${projname}.ut" "${projname}.ncd"

# Impact options
cat > "${projname}_impact.cmd" << EOF
setMode -bs
setCable -p usb21 -b 12000000
addDevice -p 1 -file ${projname}.bit
program -p 1
exit
EOF

[[ "$1" == "load" ]] && "${XILINX_ISE}/impact" -batch "${projname}_impact.cmd"