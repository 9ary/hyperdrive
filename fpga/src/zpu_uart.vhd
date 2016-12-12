library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.components.all;
use work.zpupkg.all;
use work.ZPUDevices.all;

entity zpu_uart is
    port
    (
        Clock : in std_logic;
        ZSelect : in std_logic;
        ZPUBusIn : in ZPUDeviceIn;
        ZPUBusOut : out ZPUDeviceOut;

        tx : out std_logic;
        rx : in std_logic
    );
end zpu_uart;

architecture Behavioral of zpu_uart is

    signal tx_stb : std_logic;
    signal tx_ack : std_logic;

    signal tx_write : std_logic;
    signal tx_write_data : std_logic_vector(7 downto 0);
    signal tx_read : std_logic;
    signal tx_read_data : std_logic_vector(7 downto 0);
    signal tx_empty : std_logic;
    signal tx_full : std_logic;

    signal rx_write : std_logic;
    signal rx_write_data : std_logic_vector(7 downto 0);
    signal rx_read : std_logic;
    signal rx_read_data : std_logic_vector(7 downto 0);
    signal rx_empty : std_logic;
    signal rx_full : std_logic;

begin

    inst_uart : uart
    generic map
    (
        baud => 200000,
        clock_frequency => 100000000
    )
    port map
    (
        clock => clock,
        reset => ZPUBusIn.reset,

        data_stream_in => tx_read_data,
        data_stream_in_stb => tx_stb,
        data_stream_in_ack => tx_ack,

        data_stream_out => rx_write_data,
        data_stream_out_stb => rx_write,

        tx => tx,
        rx => rx
    );

    tx_fifo : std_fifo
    port map
    (
        clk => clock,
        rst => ZPUBusIn.reset,

        wr_en => tx_write,
        din => tx_write_data,
        full => tx_full,

        rd_en => tx_read,
        dout => tx_read_data,
        empty => tx_empty
    );

    rx_fifo : std_fifo
    port map
    (
        clk => clock,
        rst => ZPUBusIn.reset,

        wr_en => rx_write,
        din => rx_write_data,
        full => rx_full,

        rd_en => rx_read,
        dout => rx_read_data,
        empty => rx_empty
    );

    process (Clock)
    begin
        if rising_edge(Clock) then
            tx_read <= '0';
            tx_write <= '0';
            rx_read <= '0';

            ZPUBusOut.mem_busy <= '0';

            if rx_read = '1' then
                ZPUBusOut.mem_busy <= '1';
            end if;
            ZPUBusOut.mem_read(7 downto 0) <= rx_read_data;

            if ZPUBusIn.Reset = '1' then
                tx_stb <= '0';
            else

                -- Move data out to the UART
                if tx_stb = '0' and tx_empty = '0' then
                    tx_read <= '1';
                    tx_stb <= '1';
                elsif tx_stb = '1' and tx_ack = '1' then
                    tx_stb <= '0';
                end if;

                if ZSelect = '1' then
                    if ZPUBusIn.mem_writeEnable = '1' then
                        tx_write <= '1';
                        tx_write_data <= ZPUBusIn.mem_write(7 downto 0);

                    elsif ZPUBusIn.mem_readEnable = '1' then
                        if ZPUBusIn.mem_addr(2) = '0' then
                            ZPUBusOut.mem_busy <= '1';
                            rx_read <= '1';
                        else
                            ZPUBusOut.mem_read(0) <= tx_full;
                            ZPUBusOut.mem_read(1) <= rx_empty;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
