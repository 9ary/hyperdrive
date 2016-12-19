library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.components.all;
use work.zpupkg.all;
use work.ZPUDevices.all;

entity di is

    port
    (
        Clock : in std_logic;
        ZSelect : in std_logic;
        ZPUBusIn : in ZPUDeviceIn;
        ZPUBusOut : out ZPUDeviceOut;

        led : out std_logic_vector(7 downto 0);

        extin : in std_logic_vector(7 downto 0);
        extin_stb : in std_logic;
        extin_full : out std_logic;

        -- Audio streaming
        --AISLR : in std_logic;
        --AISD : out std_logic;
        --AISCLK : in std_logic;

        -- Control signals
        DIHSTRB : in std_logic; -- Host strobe
        DIDIR : in std_logic; -- Bus direction
        DIBRK : in std_logic; -- Host cancel
        DIRSTB : in std_logic; -- Host reset

        DIDSTRB : out std_logic; -- Drive strobe
        DIERRB : out std_logic; -- Drive error
        DICOVER : out std_logic; -- Lid state

        -- Data
        DID : inout std_logic_vector(7 downto 0)
    );

end di;

architecture Behavioral of di is

    signal di_reset : std_logic;

    signal DIHSTRB_sync : std_logic_vector(2 downto 0);
    signal DIDIR_sync : std_logic_vector(1 downto 0);
    signal DIBRK_sync : std_logic_vector(1 downto 0);
    signal DIRSTB_sync : std_logic_vector(1 downto 0);
    type DID_sync_t is array(1 downto 0) of std_logic_vector(7 downto 0);
    signal DID_sync : DID_sync_t;

    signal status_reg : std_logic_vector(1 downto 0);

    signal out_write : std_logic;
    signal out_write_data : std_logic_vector(7 downto 0);
    signal out_read : std_logic;
    signal out_read_data : std_logic_vector(7 downto 0);
    signal out_empty : std_logic;
    signal out_full : std_logic;

begin

    extin_full <= out_full;

    di_reset <= not DIRSTB_sync(1);

    DID <= (others => 'Z') when DIDIR = '0' else out_read_data;
    DICOVER <= status_reg(0);
    DIERRB <= status_reg(1);

    out_fifo : std_fifo
    port map
    (
        clk => clock,
        rst => di_reset,

        wr_en => out_write,
        din => out_write_data,
        full => out_full,

        rd_en => out_read,
        dout => out_read_data,
        empty => out_empty
    );

    -- ZPU FIFO state machine
    process (Clock)
        type cmd_buf_t is array(11 downto 0) of std_logic_vector(7 downto 0);
        variable cmd_buf : cmd_buf_t;
        variable cmd_counter : natural range 0 to 12;
        variable cmd_ready : boolean;

        constant DIDSTRB_div : natural := 8;
        variable DIDSTRB_counter : natural range 0 to DIDSTRB_div - 1;
    begin
        if rising_edge(Clock) then

            -- Sync inputs into our clock domain
            DIHSTRB_sync <= DIHSTRB_sync(1 downto 0) & DIHSTRB;
            DIDIR_sync <= DIDIR_sync(0) & DIDIR;
            DIBRK_sync <= DIBRK_sync(0) & DIBRK;
            DIRSTB_sync <= DIRSTB_sync(0) & DIRSTB;
            DID_sync <= DID_sync(0) & DID;

            -- Reset FIFO flags
            out_read <= '0';
            out_write <= '0';

            ZPUBusOut.mem_busy <= '0';

            if out_write = '1' and out_full = '1' then
                ZPUBusOut.mem_busy <= '1';
                out_write <= '1';
            end if;

            if ZPUBusIn.Reset = '1' then
                null;
            else

                if ZSelect = '1' then
                    if ZPUBusIn.mem_writeEnable = '1' then
                        case ZPUBusIn.mem_addr(5 downto 2) is
                            when x"0" =>
                                out_write <= '1';
                                out_write_data <= ZPUBusIn.mem_write(7 downto 0);

                            when x"1" =>
                                status_reg <= ZPUBusIn.mem_write(1 downto 0);
                                if ZPUBusIn.mem_write(2) = '1' then
                                    cmd_ready := false;
                                end if;

                            when others =>
                                null;
                        end case;

                    elsif ZPUBusIn.mem_readEnable = '1' then
                        case ZPUBusIn.mem_addr(5 downto 2) is
                            when x"1" =>
                                ZPUBusOut.mem_read(1 downto 0) <= status_reg;
                                ZPUBusOut.mem_read(2) <= '1';

                                if cmd_ready = true then
                                    ZPUBusOut.mem_read(2) <= '0';
                                end if;

                            when x"2" =>
                                ZPUBusOut.mem_read <= cmd_buf(0) & cmd_buf(1) & cmd_buf(2) & cmd_buf(3);

                            when x"3" =>
                                ZPUBusOut.mem_read <= cmd_buf(4) & cmd_buf(5) & cmd_buf(6) & cmd_buf(7);

                            when x"4" =>
                                ZPUBusOut.mem_read <= cmd_buf(8) & cmd_buf(9) & cmd_buf(10) & cmd_buf(11);

                            when others =>
                                null;
                        end case;
                    end if;
                end if;
            end if;

            if extin_stb = '1' then
                out_write <= '1';
                out_write_data <= extin;
            end if;

            -- Output clock generation
            if DIDSTRB_counter = DIDSTRB_div - 1 then
                DIDSTRB_counter := 0;
            else
                DIDSTRB_counter := DIDSTRB_counter + 1;
            end if;

            led <= (others => '0');
            if di_reset = '1' then
                led(0) <= '1';

                cmd_counter := 0;
                cmd_ready := false;
                DIDSTRB <= '1';
                status_reg <= (others => '1');

            else
                if DIDIR_sync(1) = '0' then
                    led(1) <= '1';
                    if cmd_counter >= 9 then
                        DIDSTRB <= '1';
                    else
                        DIDSTRB <= '0';
                    end if;

                    if DIHSTRB_sync(2 downto 1) = "01" then -- Rising edge
                        cmd_buf(cmd_counter) := DID_sync(1);

                        if cmd_counter = 8 then
                            DIDSTRB <= '1';
                        end if;

                        if cmd_counter = 11 then
                            cmd_ready := true;
                        end if;

                        cmd_counter := cmd_counter + 1;
                    end if;
                else
                    led(2) <= '1';
                    if cmd_counter = 12 and DIHSTRB_sync(1) = '1' then
                        null;
                    else
                        led(3) <= '1';
                        cmd_counter := 0;

                        if DIDSTRB_counter = 0 and out_empty = '0' then
                            out_read <= '1';
                            DIDSTRB <= '0';
                        end if;

                        if DIDSTRB_counter = DIDSTRB_div / 2 then
                            DIDSTRB <= '1';
                        end if;
                    end if;
                end if;
            end if;

        end if; -- rising_edge(Clock)

    end process;

end Behavioral;
