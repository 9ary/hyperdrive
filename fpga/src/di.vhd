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

    signal DIHSTRB_sync : std_logic_vector(1 downto 0);
    signal DIDIR_sync : std_logic_vector(1 downto 0);
    signal DIBRK_sync : std_logic_vector(1 downto 0);
    signal DIRSTB_sync : std_logic_vector(1 downto 0);

    constant DIDSTRB_div : integer := 8;
    signal DIDSTRB_counter : integer range 0 to DIDSTRB_div - 1;

    signal cmd_counter : integer range 0 to 11;

    type states is
    (
        reset,
        precmd,
        cmd,
        prereply,
        reply
    );
    signal state : states;

    signal out_write : std_logic;
    signal out_write_data : std_logic_vector(7 downto 0);
    signal out_read : std_logic;
    signal out_read_data : std_logic_vector(7 downto 0);
    signal out_empty : std_logic;
    signal out_full : std_logic;

    signal in_write : std_logic;
    signal in_write_data : std_logic_vector(7 downto 0);
    signal in_read : std_logic;
    signal in_read_data : std_logic_vector(7 downto 0);
    signal in_empty : std_logic;
    signal in_full : std_logic;

    signal DICOVER_reg : std_logic;
    signal DIERRB_reg : std_logic;
    signal busy : std_logic;

begin

    di_reset <= not DIRSTB_sync(1);

    DICOVER <= DICOVER_reg;
    DIERRB <= DIERRB_reg;

    out_fifo : std_fifo
    port map
    (
        clk => clock,
        rst => '0',

        wr_en => out_write,
        din => out_write_data,
        full => out_full,

        rd_en => out_read,
        dout => out_read_data,
        empty => out_empty
    );

    in_fifo : std_fifo
    port map
    (
        clk => clock,
        rst => di_reset,

        wr_en => in_write,
        din => in_write_data,
        full => in_full,

        rd_en => in_read,
        dout => in_read_data,
        empty => in_empty
    );

    -- ZPU FIFO state machine
    process (Clock)
    begin
        if rising_edge(Clock) then
            out_write <= '0';
            in_read <= '0';

            ZPUBusOut.mem_busy <= '0';

            busy <= '1';

            if in_read = '1' then
                ZPUBusOut.mem_busy <= '1';
                if in_empty = '1' then
                    in_read <= '1';
                end if;
            end if;
            ZPUBusOut.mem_read(7 downto 0) <= in_read_data;

            if out_write = '1' and out_full = '1' then
                ZPUBusOut.mem_busy <= '1';
                out_write <= '1';
            end if;

            if ZPUBusIn.Reset = '1' then
                null;
            else

                if ZSelect = '1' then
                    if ZPUBusIn.mem_writeEnable = '1' then
                        case ZPUBusIn.mem_addr(3 downto 0) is
                            when x"0" =>
                                out_write <= '1';
                                out_write_data <= ZPUBusIn.mem_write(7 downto 0);

                            when x"4" =>
                                DICOVER_reg <= ZPUBusIn.mem_write(0);
                                DIERRB_reg <= ZPUBusIn.mem_write(1);
                                busy <= ZPUBusIn.mem_write(2);

                            when others =>
                                null;
                        end case;

                    elsif ZPUBusIn.mem_readEnable = '1' then
                        case ZPUBusIn.mem_addr(3 downto 0) is
                            when x"0" =>
                                ZPUBusOut.mem_busy <= '1';
                                in_read <= '1';

                            when x"4" =>
                                ZPUBusOut.mem_read(0) <= DICOVER_reg;
                                ZPUBusOut.mem_read(1) <= DIERRB_reg;
                                ZPUBusOut.mem_read(2) <= busy;

                            when others =>
                                null;
                        end case;
                    end if;
                end if;
            end if;

            -- DI state
            led <= (others => '0');

            -- Reset FIFO flags
            out_read <= '0';
            in_write <= '0';

            -- Sync control signals into our clock domain
            DIHSTRB_sync <= DIHSTRB_sync(0) & DIHSTRB;
            DIDIR_sync <= DIDIR_sync(0) & DIDIR;
            DIBRK_sync <= DIBRK_sync(0) & DIBRK;
            DIRSTB_sync <= DIRSTB_sync(0) & DIRSTB;

            DID <= (others => 'Z');

            if di_reset = '1' then
                state <= reset;
                DIDSTRB <= '1';
                DICOVER_reg <= '1';
                DIERRB_reg <= '1';

            else
                case state is
                    when reset =>
                        led(0) <= '1';

                        if busy = '0' then
                            state <= precmd;
                        end if;

                    when precmd =>
                        cmd_counter <= 0;
                        DIDSTRB <= '0';
                        state <= cmd;

                    when cmd =>
                        led(1) <= '1';

                        if DIHSTRB_sync = "01" then
                            in_write <= '1';
                            in_write_data <= DID;

                            cmd_counter <= cmd_counter + 1;

                            if cmd_counter = 8 then
                                DIDSTRB <= '1';
                            end if;

                            if cmd_counter = 11 then
                                state <= prereply;
                            end if;
                        end if;

                    when prereply =>
                        if DIDIR_sync(1) = '1' and DIHSTRB_sync(1) = '0' then
                            state <= reply;
                        end if;
                        DIDSTRB_counter <= DIDSTRB_div - 1;

                    when reply =>
                        led(2) <= '1';

                        DID <= out_read_data;

                        -- Output clock
                        if DIDSTRB_counter = DIDSTRB_div - 1 then
                            if out_empty = '0' then
                                DIDSTRB_counter <= 0;
                                DIDSTRB <= '0';
                                out_read <= '1';
                            end if;

                            if DIDIR_sync(1) = '0' and busy = '0' then
                                state <= precmd;
                            end if;
                        else
                            if DIDSTRB_counter = DIDSTRB_div / 2 then
                                DIDSTRB <= '1';
                            end if;
                            DIDSTRB_counter <= DIDSTRB_counter + 1;
                        end if;

                end case;
            end if;

        end if;

    end process;

end Behavioral;
