--
-- Warning: this file is a huge fucking mess and probably doesn't work for now
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.components.all;

entity di is

    port
    (
        clk : in std_logic;
        led : out std_logic_vector(7 downto 0);
        --sw : in std_logic_vector(3 downto 0);

        tx : out std_logic;
        rx : in std_logic;

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

    signal g_reset : std_logic;

    signal DIHSTRB_sync : std_logic_vector(1 downto 0);
    signal DIDIR_sync : std_logic_vector(1 downto 0);
    signal DIBRK_sync : std_logic_vector(1 downto 0);
    signal DIRSTB_sync : std_logic_vector(1 downto 0);

    constant DIDSTRB_div : integer := 8;
    signal DIDSTRB_counter : integer range 0 to DIDSTRB_div - 1;

    constant reset_delay : integer := 50000000;
    signal reset_counter : integer range 0 to reset_delay;

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

begin

    g_reset <= not DIRSTB_sync(1);

    DIERRB <= '1';

    process (clk, g_reset)
    begin

        if rising_edge(clk) then
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

            if g_reset = '1' then
                state <= reset;
                DIDSTRB <= '1';
                reset_counter <= 0;
                DICOVER <= '1';

            else
                case state is
                    when reset =>
                        led(0) <= '1';

                        reset_counter <= reset_counter + 1;
                        if reset_counter = reset_delay then
                            state <= precmd;
                            DICOVER <= '0';
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
                                reset_counter <= 0;
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

                            if DIDIR_sync(1) = '0' then
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
