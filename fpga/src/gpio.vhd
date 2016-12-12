library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;

library work;
use work.zpupkg.all;
use work.ZPUDevices.all;

entity gpio is
    Port
    (
        Clock : in std_logic;
        ZSelect : in std_logic;
        ZPUBusIn : in ZPUDeviceIn;
        ZPUBusOut: out ZPUDeviceOut;

        led : out std_logic_vector(7 downto 0)
    );
end gpio;

architecture Behavioral of gpio is

    signal led_reg : std_logic_vector(7 downto 0);

begin

    ZPUBusOut.mem_busy <= '0';

    led <= led_reg;

    process (Clock)
    begin
        if rising_edge(Clock) then
            if ZPUBusIn.Reset = '1' then
                led_reg <= (others => '0');
            else
                if ZSelect = '1' then
                    if ZPUBusIn.mem_writeEnable = '1' then
                        led_reg <= ZPUBusIn.mem_write(7 downto 0);

                    elsif ZPUBusIn.mem_readEnable = '1' then
                        ZPUBusOut.mem_read(7 downto 0) <= led_reg;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
