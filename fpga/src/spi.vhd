library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;

entity spi_slave is
    generic (
        constant data_width : positive := 8
    );
    port (
        clk : in std_logic;

        data_in : out std_logic_vector(data_width - 1 downto 0);
        data_out : in std_logic_vector(data_width - 1 downto 0);
        enable : out std_logic;
        strobe : out std_logic;
        push : in std_logic;

        sclk : in std_logic;
        mosi : in std_logic;
        miso : out std_logic;
        scs : in std_logic
    );
end spi_slave;

architecture serial of spi_slave is
begin
    process (clk)
        variable sclk_prev : std_logic;
        variable sclk_sync : std_logic;
        variable mosi_sync : std_logic;
        variable scs_sync : std_logic;

        variable sr : std_logic_vector(data_width - 1 downto 0);
        variable bitcount : natural range 0 to data_width - 1;
    begin
        if rising_edge(clk) then
            enable <= not scs_sync;
            strobe <= '0';

            if scs_sync = '1' then
                sr := (others => '1');
                bitcount := 0;

                miso <= 'Z';
            else
                if sclk_prev = '0' and sclk_sync = '1' then
                    sr := sr(data_width - 2 downto 0) & mosi_sync;
                    bitcount := bitcount + 1;

                    if bitcount = 0 then
                        data_in <= sr;
                        sr := data_out;
                        strobe <= '1';
                    end if;
                end if;

                if push = '1' then
                    sr := data_out;
                end if;

                miso <= sr(data_width - 1);
            end if;

            sclk_prev := sclk_sync;
            sclk_sync := sclk;
            mosi_sync := mosi;
            scs_sync := scs;
        end if;
    end process;
end serial;
