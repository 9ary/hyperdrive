#!/bin/bash

set -e

projname="hyperdrive"
ucf="mimas.ucf"
partname="xc6slx9"
partpackage="tqg144"
partspeed="2"
spipart="M25P16"
spisize="2048"
workdir="work"

# Get ourselves into a sane environment
[[ -z "${XILINX_ISE}" ]] && echo 'Please set ${XILINX_ISE} to path where ISE tools are installed' && exit 1
basedir=$(cd "${0%/*}" && echo ${PWD})
mkdir -p "${workdir}"
cd "${workdir}"

build() {
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

    # Post-PAR timing report
    "${XILINX_ISE}/trce" -v -n -fastpaths "${projname}.ncd" -o "${projname}.twr" "${projname}_map.pcf"

    # BitGen options
    cat > "${projname}.ut" << EOF
-w
-g Binary:Yes
-g Compress
-g UnusedPin:PullNone
EOF

    "${XILINX_ISE}/bitgen" -f "${projname}.ut" "${projname}.ncd"
}

_impact() {
    cat > "${projname}_impact.cmd" << EOF
setMode -bs
setCable -p usb21 -b 12000000
addDevice -p 1 -file ${projname}.bit
attachFlash -p 1 -spi ${spipart}
assignFileToAttachedFlash -p 1 -file ${projname}.mcs
program -p 1 $@
exit
EOF

    "${XILINX_ISE}/impact" -batch "${projname}_impact.cmd"
}

load() {
    _impact
}

flash() {
    "${XILINX_ISE}/promgen" -u 0000 "${projname}.bit" -s ${spisize} -spi -w -o "${projname}"

    _impact -spionly -e -v -loadfpga
}

for action in $@; do
    $action
done
