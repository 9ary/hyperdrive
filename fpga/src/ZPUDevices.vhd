----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2016, Ingo Korb <ingo@akana.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE.
--
-- ZPUDevices.vhd: component definitions for the ZPU devices
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.zpupkg.all;

package ZPUDevices is

  type ZPUDeviceIn is record
    Reset          : std_logic;
    mem_write      : std_logic_vector(31 downto 0);
    mem_addr       : std_logic_vector(31 downto 0);
    mem_writeEnable: std_logic;
    mem_readEnable : std_logic;
  end record;

  type ZPUDeviceOut is record
    mem_busy: std_logic;
    mem_read: std_logic_vector(wordSize-1 downto 0);
  end record;

  type ZPUMuxSelects is array(natural range <>) of std_logic;
  type ZPUMuxDevOuts is array(natural range <>) of ZPUDeviceOut;

end ZPUDevices;

package body ZPUDevices is
end ZPUDevices;
